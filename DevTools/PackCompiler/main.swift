#!/usr/bin/env swift

import Foundation

// MARK: - Pack Compiler CLI
// Usage: swift main.swift [command] [options]
//
// Commands:
//   validate <pack-path>     Validate a content pack
//   validate-all <dir>       Validate all packs in directory
//   info <pack-path>         Show pack information
//   help                     Show this help message

// MARK: - Color Output

enum ANSIColor: String {
    case red = "\u{001B}[31m"
    case green = "\u{001B}[32m"
    case yellow = "\u{001B}[33m"
    case blue = "\u{001B}[34m"
    case reset = "\u{001B}[0m"

    static func colored(_ text: String, _ color: ANSIColor) -> String {
        return "\(color.rawValue)\(text)\(ANSIColor.reset.rawValue)"
    }
}

// MARK: - CLI

struct PackCompilerCLI {
    let arguments: [String]

    init(arguments: [String] = CommandLine.arguments) {
        self.arguments = arguments
    }

    func run() -> Int32 {
        guard arguments.count > 1 else {
            printHelp()
            return 1
        }

        let command = arguments[1]

        switch command {
        case "validate":
            return validateCommand()
        case "validate-all":
            return validateAllCommand()
        case "info":
            return infoCommand()
        case "help", "--help", "-h":
            printHelp()
            return 0
        default:
            print(ANSIColor.colored("Unknown command: \(command)", .red))
            printHelp()
            return 1
        }
    }

    // MARK: - Commands

    private func validateCommand() -> Int32 {
        guard arguments.count > 2 else {
            print(ANSIColor.colored("Error: Missing pack path", .red))
            print("Usage: packcompiler validate <pack-path>")
            return 1
        }

        let packPath = arguments[2]
        let packURL = URL(fileURLWithPath: packPath)

        guard FileManager.default.fileExists(atPath: packPath) else {
            print(ANSIColor.colored("Error: Pack not found at \(packPath)", .red))
            return 1
        }

        print(ANSIColor.colored("Validating pack: \(packPath)", .blue))
        print("")

        let result = validatePack(at: packURL)
        return result ? 0 : 1
    }

    private func validateAllCommand() -> Int32 {
        guard arguments.count > 2 else {
            print(ANSIColor.colored("Error: Missing directory path", .red))
            print("Usage: packcompiler validate-all <directory>")
            return 1
        }

        let dirPath = arguments[2]
        let dirURL = URL(fileURLWithPath: dirPath)

        guard FileManager.default.fileExists(atPath: dirPath) else {
            print(ANSIColor.colored("Error: Directory not found at \(dirPath)", .red))
            return 1
        }

        print(ANSIColor.colored("Validating all packs in: \(dirPath)", .blue))
        print("")

        var allValid = true
        let contents = try? FileManager.default.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: [.isDirectoryKey])

        guard let packDirs = contents else {
            print(ANSIColor.colored("Error: Could not read directory", .red))
            return 1
        }

        for packDir in packDirs {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: packDir.path, isDirectory: &isDir) && isDir.boolValue {
                // Check if it has a manifest.json
                let manifestPath = packDir.appendingPathComponent("manifest.json")
                if FileManager.default.fileExists(atPath: manifestPath.path) {
                    print(String(repeating: "-", count: 50))
                    let isValid = validatePack(at: packDir)
                    allValid = allValid && isValid
                }
            }
        }

        print("")
        print(String(repeating: "=", count: 50))
        if allValid {
            print(ANSIColor.colored("ALL PACKS VALID", .green))
        } else {
            print(ANSIColor.colored("SOME PACKS HAVE ERRORS", .red))
        }

        return allValid ? 0 : 1
    }

    private func infoCommand() -> Int32 {
        guard arguments.count > 2 else {
            print(ANSIColor.colored("Error: Missing pack path", .red))
            print("Usage: packcompiler info <pack-path>")
            return 1
        }

        let packPath = arguments[2]
        let packURL = URL(fileURLWithPath: packPath)

        guard FileManager.default.fileExists(atPath: packPath) else {
            print(ANSIColor.colored("Error: Pack not found at \(packPath)", .red))
            return 1
        }

        return showPackInfo(at: packURL) ? 0 : 1
    }

    // MARK: - Validation

    private func validatePack(at url: URL) -> Bool {
        // Load manifest
        guard let manifest = loadManifest(at: url) else {
            return false
        }

        print("Pack: \(manifest.packId)")
        print("Version: \(manifest.version)")
        print("Type: \(manifest.packType.rawValue)")
        print("")

        // Run validation
        var errors = 0
        var warnings = 0

        // Check manifest
        if !manifest.isCompatibleWithCore() {
            printError("Core version incompatible: requires \(manifest.coreVersionMin)")
            errors += 1
        }

        // Check required paths exist
        let pathChecks: [(String, String?)] = [
            ("Regions", manifest.regionsPath),
            ("Events", manifest.eventsPath),
            ("Heroes", manifest.heroesPath),
            ("Cards", manifest.cardsPath),
            ("Balance", manifest.balancePath),
            ("Localization", manifest.localizationPath)
        ]

        for (name, path) in pathChecks {
            if let path = path {
                let fullPath = url.appendingPathComponent(path)
                if !FileManager.default.fileExists(atPath: fullPath.path) {
                    printWarning("\(name) path not found: \(path)")
                    warnings += 1
                }
            }
        }

        // Try to load content
        do {
            let pack = try loadPackContent(manifest: manifest, from: url)

            print("Content loaded:")
            print("  Regions: \(pack.regions.count)")
            print("  Events: \(pack.events.count)")
            print("  Anchors: \(pack.anchors.count)")
            print("  Heroes: \(pack.heroes.count)")
            print("  Cards: \(pack.cards.count)")
            print("  Balance: \(pack.balanceConfig != nil ? "Yes" : "No")")
            print("")

            // Validate cross-references
            let refErrors = validateReferences(pack: pack, manifest: manifest)
            errors += refErrors.errors
            warnings += refErrors.warnings

        } catch {
            printError("Failed to load content: \(error.localizedDescription)")
            errors += 1
        }

        // Summary
        print("")
        if errors == 0 && warnings == 0 {
            print(ANSIColor.colored("VALID (no issues)", .green))
        } else if errors == 0 {
            print(ANSIColor.colored("VALID with \(warnings) warning(s)", .yellow))
        } else {
            print(ANSIColor.colored("INVALID: \(errors) error(s), \(warnings) warning(s)", .red))
        }

        return errors == 0
    }

    private func showPackInfo(at url: URL) -> Bool {
        guard let manifest = loadManifest(at: url) else {
            return false
        }

        print(ANSIColor.colored("=== Pack Information ===", .blue))
        print("")
        print("ID:          \(manifest.packId)")
        print("Name (EN):   \(manifest.displayName.en)")
        print("Name (RU):   \(manifest.displayName.ru)")
        print("Version:     \(manifest.version)")
        print("Type:        \(manifest.packType.rawValue)")
        print("Core Min:    \(manifest.coreVersionMin)")
        print("Locales:     \(manifest.supportedLocales.joined(separator: ", "))")

        if let entryRegion = manifest.entryRegionId {
            print("Entry:       \(entryRegion)")
        }

        if !manifest.dependencies.isEmpty {
            print("Dependencies:")
            for dep in manifest.dependencies {
                let optional = dep.isOptional ? " (optional)" : ""
                print("  - \(dep.packId) >= \(dep.minVersion)\(optional)")
            }
        }

        print("")
        print("Paths:")
        print("  Regions:      \(manifest.regionsPath ?? "not set")")
        print("  Events:       \(manifest.eventsPath ?? "not set")")
        print("  Heroes:       \(manifest.heroesPath ?? "not set")")
        print("  Cards:        \(manifest.cardsPath ?? "not set")")
        print("  Balance:      \(manifest.balancePath ?? "not set")")
        print("  Localization: \(manifest.localizationPath ?? "not set")")

        return true
    }

    // MARK: - Reference Validation

    private func validateReferences(pack: SimplePack, manifest: PackManifest) -> (errors: Int, warnings: Int) {
        var errors = 0
        var warnings = 0

        // Region neighbors
        for (id, region) in pack.regions {
            for neighborId in region.neighborIds {
                if pack.regions[neighborId] == nil {
                    printError("Region '\(id)' references unknown neighbor '\(neighborId)'")
                    errors += 1
                }
            }
        }

        // Anchor regions
        for (id, anchor) in pack.anchors {
            if pack.regions[anchor.regionId] == nil {
                printError("Anchor '\(id)' references unknown region '\(anchor.regionId)'")
                errors += 1
            }
        }

        // Hero cards
        for (id, hero) in pack.heroes {
            for cardId in hero.startingDeckCardIDs {
                if pack.cards[cardId] == nil {
                    printError("Hero '\(id)' references unknown card '\(cardId)'")
                    errors += 1
                }
            }
        }

        // Entry region
        if let entryRegionId = manifest.entryRegionId {
            if pack.regions[entryRegionId] == nil {
                printError("Entry region '\(entryRegionId)' not found")
                errors += 1
            }
        }

        return (errors, warnings)
    }

    // MARK: - Helpers

    private func loadManifest(at url: URL) -> SimpleManifest? {
        let manifestURL = url.appendingPathComponent("manifest.json")

        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            printError("manifest.json not found")
            return nil
        }

        do {
            let data = try Data(contentsOf: manifestURL)
            let manifest = try JSONDecoder().decode(SimpleManifest.self, from: data)
            return manifest
        } catch {
            printError("Failed to parse manifest: \(error.localizedDescription)")
            return nil
        }
    }

    private func loadPackContent(manifest: SimpleManifest, from url: URL) throws -> SimplePack {
        var pack = SimplePack()

        // Load regions
        if let path = manifest.regionsPath {
            pack.regions = try loadContent(from: url.appendingPathComponent(path), type: [String: SimpleRegion].self) ?? [:]
        }

        // Load events
        if let path = manifest.eventsPath {
            pack.events = try loadContent(from: url.appendingPathComponent(path), type: [String: SimpleEvent].self) ?? [:]
        }

        // Load anchors
        if let path = manifest.anchorsPath {
            pack.anchors = try loadContent(from: url.appendingPathComponent(path), type: [String: SimpleAnchor].self) ?? [:]
        }

        // Load heroes
        if let path = manifest.heroesPath {
            if let heroes: [SimpleHero] = try loadContent(from: url.appendingPathComponent(path), type: [SimpleHero].self) {
                for hero in heroes {
                    pack.heroes[hero.id] = hero
                }
            }
        }

        // Load cards
        if let path = manifest.cardsPath {
            if let cards: [SimpleCard] = try loadContent(from: url.appendingPathComponent(path), type: [SimpleCard].self) {
                for card in cards {
                    pack.cards[card.id] = card
                }
            }
        }

        // Load balance
        if let path = manifest.balancePath {
            pack.balanceConfig = try loadContent(from: url.appendingPathComponent(path), type: SimpleBalance.self)
        }

        return pack
    }

    private func loadContent<T: Decodable>(from url: URL, type: T.Type) throws -> T? {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return nil
        }

        if isDir.boolValue {
            // Look for main file in directory
            let jsonFile = url.appendingPathComponent(url.lastPathComponent + ".json")
            if FileManager.default.fileExists(atPath: jsonFile.path) {
                let data = try Data(contentsOf: jsonFile)
                return try JSONDecoder().decode(T.self, from: data)
            }
            return nil
        } else {
            // It's a file
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        }
    }

    private func printError(_ message: String) {
        print(ANSIColor.colored("[ERROR] \(message)", .red))
    }

    private func printWarning(_ message: String) {
        print(ANSIColor.colored("[WARNING] \(message)", .yellow))
    }

    private func printHelp() {
        print("""
        Pack Compiler - Content Pack Development Tool

        Usage: packcompiler <command> [options]

        Commands:
          validate <pack-path>     Validate a content pack
          validate-all <directory> Validate all packs in a directory
          info <pack-path>         Show pack information
          help                     Show this help message

        Examples:
          packcompiler validate ContentPacks/TwilightMarches
          packcompiler validate-all ContentPacks/
          packcompiler info ContentPacks/TwilightMarches

        """)
    }
}

// MARK: - Simple Models (for standalone CLI)

struct SimpleManifest: Decodable {
    let id: String
    let name: LocalizedName
    let version: String
    let type: String
    let coreVersionMin: String?
    let dependencies: [SimpleDependency]?
    let entryRegion: String?
    let locales: [String]?
    let regionsPath: String?
    let eventsPath: String?
    let questsPath: String?
    let anchorsPath: String?
    let heroesPath: String?
    let cardsPath: String?
    let balancePath: String?
    let localizationPath: String?

    var packId: String { id }

    var displayName: LocalizedName { name }

    var packType: PackType {
        PackType(rawValue: type) ?? .full
    }

    var supportedLocales: [String] {
        locales ?? ["en"]
    }

    var entryRegionId: String? { entryRegion }

    func isCompatibleWithCore() -> Bool {
        // Simple check - could be enhanced
        return true
    }

    enum CodingKeys: String, CodingKey {
        case id, name, version, type
        case coreVersionMin = "core_version_min"
        case dependencies
        case entryRegion = "entry_region"
        case locales
        case regionsPath = "regions_path"
        case eventsPath = "events_path"
        case questsPath = "quests_path"
        case anchorsPath = "anchors_path"
        case heroesPath = "heroes_path"
        case cardsPath = "cards_path"
        case balancePath = "balance_path"
        case localizationPath = "localization_path"
    }
}

struct LocalizedName: Decodable {
    let en: String
    let ru: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        en = try container.decodeIfPresent(String.self, forKey: DynamicCodingKey(stringValue: "en")!) ?? ""
        ru = try container.decodeIfPresent(String.self, forKey: DynamicCodingKey(stringValue: "ru")!) ?? ""
    }
}

struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}

struct SimpleDependency: Decodable {
    let packId: String
    let minVersion: String
    let isOptional: Bool

    enum CodingKeys: String, CodingKey {
        case packId = "pack_id"
        case minVersion = "min_version"
        case isOptional = "optional"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        packId = try container.decode(String.self, forKey: .packId)
        minVersion = try container.decodeIfPresent(String.self, forKey: .minVersion) ?? "1.0.0"
        isOptional = try container.decodeIfPresent(Bool.self, forKey: .isOptional) ?? false
    }
}

enum PackType: String, Decodable {
    case campaign, character, balance, rulesExtension, full
    // Support legacy "investigator" type for backwards compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        if rawValue == "investigator" {
            self = .character
        } else if let type = PackType(rawValue: rawValue) {
            self = type
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown pack type: \(rawValue)")
        }
    }
}

struct SimplePack {
    var regions: [String: SimpleRegion] = [:]
    var events: [String: SimpleEvent] = [:]
    var anchors: [String: SimpleAnchor] = [:]
    var heroes: [String: SimpleHero] = [:]
    var cards: [String: SimpleCard] = [:]
    var balanceConfig: SimpleBalance?
}

struct SimpleRegion: Decodable {
    let id: String
    let neighborIds: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case neighborIds = "neighbor_ids"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        neighborIds = try container.decodeIfPresent([String].self, forKey: .neighborIds) ?? []
    }
}

struct SimpleEvent: Decodable {
    let id: String
}

struct SimpleAnchor: Decodable {
    let id: String
    let regionId: String

    enum CodingKeys: String, CodingKey {
        case id
        case regionId = "region_id"
    }
}

struct SimpleHero: Decodable {
    let id: String
    let startingDeckCardIDs: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case startingDeckCardIDs = "starting_deck"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        startingDeckCardIDs = try container.decodeIfPresent([String].self, forKey: .startingDeckCardIDs) ?? []
    }
}

struct SimpleCard: Decodable {
    let id: String
}

struct SimpleBalance: Decodable {
    // Just a placeholder for validation
}

// MARK: - Main

let cli = PackCompilerCLI()
exit(cli.run())

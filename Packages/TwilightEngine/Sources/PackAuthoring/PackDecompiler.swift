import Foundation
import TwilightEngine

// MARK: - Pack Decompiler
// Extracts binary .pack files back to JSON directory structure for editing

/// Decompiles binary .pack files back to JSON directory structure
public enum PackDecompiler {

    /// Decompile a .pack file to a JSON directory
    /// - Parameters:
    ///   - packURL: URL to .pack file
    ///   - outputURL: Destination directory URL
    /// - Throws: Error if decompilation fails
    public static func decompile(from packURL: URL, to outputURL: URL) throws {
        // 1. Load pack content
        let content = try BinaryPackReader.loadContent(from: packURL)

        // 2. Create output directory
        let fm = FileManager.default
        if fm.fileExists(atPath: outputURL.path) {
            try fm.removeItem(at: outputURL)
        }
        try fm.createDirectory(at: outputURL, withIntermediateDirectories: true)

        // 3. Track which paths are written
        var writtenPaths = WrittenPaths()

        // 4. Write content files based on pack type
        let packType = content.manifest.packType

        // Campaign content (regions, events, quests, anchors)
        if packType == .campaign || packType == .full {
            let campaignDir = outputURL.appendingPathComponent("Campaign")
            try fm.createDirectory(at: campaignDir, withIntermediateDirectories: true)

            if !content.regions.isEmpty {
                try writeJSONArray(Array(content.regions.values), to: campaignDir.appendingPathComponent("regions.json"))
                writtenPaths.regions = "Campaign/regions.json"
            }
            if !content.events.isEmpty {
                try writeJSONArray(Array(content.events.values), to: campaignDir.appendingPathComponent("events.json"))
                writtenPaths.events = "Campaign/events.json"
            }
            if !content.quests.isEmpty {
                try writeJSONArray(Array(content.quests.values), to: campaignDir.appendingPathComponent("quests.json"))
                writtenPaths.quests = "Campaign/quests.json"
            }
            if !content.anchors.isEmpty {
                try writeJSONArray(Array(content.anchors.values), to: campaignDir.appendingPathComponent("anchors.json"))
                writtenPaths.anchors = "Campaign/anchors.json"
            }
        }

        // Character content (heroes, abilities)
        if packType == .character || packType == .full {
            let charactersDir = outputURL.appendingPathComponent("Characters")
            try fm.createDirectory(at: charactersDir, withIntermediateDirectories: true)

            if !content.heroes.isEmpty {
                try writeJSONArray(Array(content.heroes.values), to: charactersDir.appendingPathComponent("heroes.json"))
                writtenPaths.heroes = "Characters/heroes.json"
            }
            if !content.abilities.isEmpty {
                try writeJSONArray(content.abilities, to: charactersDir.appendingPathComponent("hero_abilities.json"))
                writtenPaths.abilities = "Characters/hero_abilities.json"
            }
        }

        // Cards
        if !content.cards.isEmpty {
            let cardsDir = outputURL.appendingPathComponent("Cards")
            try fm.createDirectory(at: cardsDir, withIntermediateDirectories: true)
            try writeJSONArray(Array(content.cards.values), to: cardsDir.appendingPathComponent("cards.json"))
            writtenPaths.cards = "Cards/cards.json"
        }

        // Enemies
        if !content.enemies.isEmpty {
            let enemiesDir = outputURL.appendingPathComponent("Enemies")
            try fm.createDirectory(at: enemiesDir, withIntermediateDirectories: true)
            try writeJSONArray(Array(content.enemies.values), to: enemiesDir.appendingPathComponent("enemies.json"))
            writtenPaths.enemies = "Enemies/enemies.json"
        }

        // Fate Cards
        if !content.fateCards.isEmpty {
            let fateDir = outputURL.appendingPathComponent("FateDeck")
            try fm.createDirectory(at: fateDir, withIntermediateDirectories: true)
            try writeJSONArray(Array(content.fateCards.values), to: fateDir.appendingPathComponent("fate_cards.json"))
            writtenPaths.fateDeck = "FateDeck/fate_cards.json"
        }

        // Balance Config
        if let balanceConfig = content.balanceConfig {
            let balanceDir = outputURL.appendingPathComponent("Balance")
            try fm.createDirectory(at: balanceDir, withIntermediateDirectories: true)
            try writeJSON(balanceConfig, to: balanceDir.appendingPathComponent("balance.json"))
            writtenPaths.balance = "Balance/balance.json"
        }

        // 5. Write manifest.json with correct paths
        let manifestURL = outputURL.appendingPathComponent("manifest.json")
        try writeManifest(content.manifest, paths: writtenPaths, to: manifestURL)
    }

    /// Tracks which content paths were written
    private struct WrittenPaths {
        var regions: String?
        var events: String?
        var quests: String?
        var anchors: String?
        var heroes: String?
        var abilities: String?
        var cards: String?
        var enemies: String?
        var fateDeck: String?
        var balance: String?
    }

    /// Result of decompilation
    public struct DecompileResult {
        public let packId: String
        public let packType: PackType
        public let outputURL: URL
        public let filesWritten: Int

        public var summary: String {
            "Decompiled '\(packId)' (\(packType.rawValue)) → \(outputURL.lastPathComponent)/ (\(filesWritten) files)"
        }
    }

    /// Decompile with result summary
    public static func decompileWithResult(from packURL: URL, to outputURL: URL) throws -> DecompileResult {
        let content = try BinaryPackReader.loadContent(from: packURL)

        try decompile(from: packURL, to: outputURL)

        // Count files
        var fileCount = 1 // manifest.json
        if !content.regions.isEmpty { fileCount += 1 }
        if !content.events.isEmpty { fileCount += 1 }
        if !content.quests.isEmpty { fileCount += 1 }
        if !content.anchors.isEmpty { fileCount += 1 }
        if !content.heroes.isEmpty { fileCount += 1 }
        if !content.abilities.isEmpty { fileCount += 1 }
        if !content.cards.isEmpty { fileCount += 1 }
        if !content.enemies.isEmpty { fileCount += 1 }
        if !content.fateCards.isEmpty { fileCount += 1 }
        if content.balanceConfig != nil { fileCount += 1 }

        return DecompileResult(
            packId: content.manifest.packId,
            packType: content.manifest.packType,
            outputURL: outputURL,
            filesWritten: fileCount
        )
    }

    // MARK: - Private Helpers

    private static func writeManifest(_ manifest: PackManifest, paths: WrittenPaths, to url: URL) throws {
        // Use correct JSON keys from PackManifest.CodingKeys (snake_case)
        // All non-optional fields must be present for Codable decoding
        var dict: [String: Any] = [
            "id": manifest.packId,
            "name": manifest.displayName.toDictionary(),
            "description": manifest.description.toDictionary(),
            "version": manifest.version.description,
            "type": manifest.packType.rawValue,
            "core_version_min": manifest.coreVersionMin.description,
            "author": manifest.author,
            // Required arrays (must be present even if empty)
            "dependencies": manifest.dependencies.map { dep in
                ["packId": dep.packId, "minVersion": dep.minVersion.description]
            },
            "required_capabilities": manifest.requiredCapabilities,
            "recommended_heroes": manifest.recommendedHeroes,
            "locales": manifest.supportedLocales
        ]

        // Optional fields
        if let entryRegion = manifest.entryRegionId {
            dict["entry_region"] = entryRegion
        }
        if let entryQuest = manifest.entryQuestId {
            dict["entry_quest"] = entryQuest
        }
        if let coreVersionMax = manifest.coreVersionMax {
            dict["core_version_max"] = coreVersionMax.description
        }

        // Set only paths that were actually written
        if let path = paths.regions { dict["regions_path"] = path }
        if let path = paths.events { dict["events_path"] = path }
        if let path = paths.quests { dict["quests_path"] = path }
        if let path = paths.anchors { dict["anchors_path"] = path }
        if let path = paths.heroes { dict["heroes_path"] = path }
        if let path = paths.abilities { dict["abilities_path"] = path }
        if let path = paths.cards { dict["cards_path"] = path }
        if let path = paths.enemies { dict["enemies_path"] = path }
        if let path = paths.fateDeck { dict["fate_deck_path"] = path }
        if let path = paths.balance { dict["balance_path"] = path }

        let data = try JSONSerialization.data(
            withJSONObject: dict,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: url)
    }

    private static func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(value)
        try data.write(to: url)
    }

    private static func writeJSONArray<T: Encodable>(_ array: [T], to url: URL) throws {
        try writeJSON(array, to: url)
    }
}

// MARK: - LocalizedString Helper

private extension LocalizedString {
    func toDictionary() -> [String: String] {
        return ["en": en, "ru": ru]
    }
}

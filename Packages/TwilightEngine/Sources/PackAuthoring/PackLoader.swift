/// Файл: Packages/TwilightEngine/Sources/PackAuthoring/PackLoader.swift
/// Назначение: Содержит реализацию файла PackLoader.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation
import CryptoKit
import TwilightEngine

// MARK: - Pack Loader

/// Loads content pack data from JSON source directories (authoring/compilation only).
/// Runtime uses BinaryPackReader — do NOT use PackLoader in production code paths.
public enum PackLoader {
    // MARK: - Main Loading

    /// Load a pack from a manifest and source URL
    /// - Parameters:
    ///   - manifest: The pack manifest
    ///   - url: URL to the pack directory
    /// - Returns: Fully loaded pack
    /// - Throws: PackLoadError if loading fails
    public static func load(manifest: PackManifest, from url: URL) throws -> LoadedPack {
        try load(manifest: manifest, from: url, localizationManager: LocalizationManager())
    }

    /// Load a pack from a manifest and source URL
    /// - Parameters:
    ///   - manifest: The pack manifest
    ///   - url: URL to the pack directory
    ///   - localizationManager: Resolver for pack string tables (shared across loads if desired)
    /// - Returns: Fully loaded pack
    /// - Throws: PackLoadError if loading fails
    public static func load(
        manifest: PackManifest,
        from url: URL,
        localizationManager: LocalizationManager
    ) throws -> LoadedPack {
        // Verify checksums before loading content (Epic 0.3)
        if let checksums = manifest.checksums {
            try verifyChecksums(checksums, in: url)
        }

        var pack = LoadedPack(
            manifest: manifest,
            sourceURL: url,
            loadedAt: Date()
        )

        // Load regions
        if let regionsPath = manifest.regionsPath {
            pack.regions = try loadRegions(from: url.appendingPathComponent(regionsPath))
            #if DEBUG
            print("PackLoader: Loaded \(pack.regions.count) regions from \(regionsPath)")
            #endif
        }

        // Load events
        if let eventsPath = manifest.eventsPath {
            pack.events = try loadEvents(from: url.appendingPathComponent(eventsPath))
            #if DEBUG
            print("PackLoader: Loaded \(pack.events.count) events from \(eventsPath)")
            #endif
        }

        // Load quests
        if let questsPath = manifest.questsPath {
            pack.quests = try loadQuests(from: url.appendingPathComponent(questsPath))
            #if DEBUG
            print("PackLoader: Loaded \(pack.quests.count) quests from \(questsPath)")
            #endif
        }

        // Load anchors
        if let anchorsPath = manifest.anchorsPath {
            pack.anchors = try loadAnchors(from: url.appendingPathComponent(anchorsPath))
            #if DEBUG
            print("PackLoader: Loaded \(pack.anchors.count) anchors from \(anchorsPath)")
            #endif
        }

        // Load hero abilities (before heroes, so abilities are available)
        if let abilitiesPath = manifest.abilitiesPath {
            pack.abilities = try loadAbilities(from: url.appendingPathComponent(abilitiesPath))
        }

        // Load heroes
        if let heroesPath = manifest.heroesPath {
            pack.heroes = try loadHeroes(
                from: url.appendingPathComponent(heroesPath),
                abilities: pack.abilities
            )
            #if DEBUG
            print("PackLoader: Loaded \(pack.heroes.count) heroes from \(heroesPath)")
            #endif
        }

        // Load cards
        if let cardsPath = manifest.cardsPath {
            pack.cards = try loadCards(from: url.appendingPathComponent(cardsPath))
            #if DEBUG
            print("PackLoader: Loaded \(pack.cards.count) cards from \(cardsPath)")
            #endif
        }

        // Load balance configuration
        if let balancePath = manifest.balancePath {
            pack.balanceConfig = try loadBalanceConfig(from: url.appendingPathComponent(balancePath))
            #if DEBUG
            print("PackLoader: Loaded balance config from \(balancePath)")
            #endif
        }

        // Load enemies
        if let enemiesPath = manifest.enemiesPath {
            pack.enemies = try loadEnemies(from: url.appendingPathComponent(enemiesPath))
            #if DEBUG
            print("PackLoader: Loaded \(pack.enemies.count) enemies from \(enemiesPath)")
            #endif
        }

        // Load behaviors
        if let behaviorsPath = manifest.behaviorsPath {
            pack.behaviors = try loadBehaviors(from: url.appendingPathComponent(behaviorsPath))
            #if DEBUG
            print("PackLoader: Loaded \(pack.behaviors.count) behaviors from \(behaviorsPath)")
            #endif
        }

        // Load fate deck cards
        if let fateDeckPath = manifest.fateDeckPath {
            pack.fateCards = try loadFateCards(from: url.appendingPathComponent(fateDeckPath))
            #if DEBUG
            print("PackLoader: Loaded \(pack.fateCards.count) fate cards from \(fateDeckPath)")
            #endif
        }

        // Load localization string tables (Epic 5)
        if let localizationPath = manifest.localizationPath {
            let locURL = url.appendingPathComponent(localizationPath)
            try localizationManager.loadStringTables(
                for: manifest.packId,
                from: locURL,
                locales: manifest.supportedLocales
            )
        }

        #if DEBUG
        print("PackLoader: ✅ Pack '\(manifest.packId)' loaded successfully")
        print("  📦 Content summary: \(pack.regions.count) regions, \(pack.events.count) events, \(pack.quests.count) quests, \(pack.heroes.count) heroes, \(pack.cards.count) cards, \(pack.enemies.count) enemies")
        #endif

        return pack
    }

    // MARK: - Content Loading

    /// Load regions from path (file or directory)
    private static func loadRegions(from url: URL) throws -> [String: RegionDefinition] {
        var regions: [String: RegionDefinition] = [:]

        if isDirectory(url) {
            // Load all JSON files in directory
            let files = try jsonFiles(in: url)
            for file in files {
                let fileRegions = try loadJSONArray(RegionDefinition.self, from: file)
                for region in fileRegions {
                    regions[region.id] = region
                }
            }
        } else {
            // Load single file
            let fileRegions = try loadJSONArray(RegionDefinition.self, from: url)
            for region in fileRegions {
                regions[region.id] = region
            }
        }

        return regions
    }

    /// Load events from path (file or directory)
    private static func loadEvents(from url: URL) throws -> [String: EventDefinition] {
        var events: [String: EventDefinition] = [:]

        if isDirectory(url) {
            let files = try jsonFiles(in: url)
            for file in files {
                let fileEvents = try loadJSONArray(EventDefinition.self, from: file)
                for event in fileEvents {
                    events[event.id] = event
                }
            }
        } else {
            let fileEvents = try loadJSONArray(EventDefinition.self, from: url)
            for event in fileEvents {
                events[event.id] = event
            }
        }

        return events
    }

    /// Load quests from path (file or directory)
    private static func loadQuests(from url: URL) throws -> [String: QuestDefinition] {
        var quests: [String: QuestDefinition] = [:]

        if isDirectory(url) {
            let files = try jsonFiles(in: url)
            for file in files {
                let fileQuests = try loadJSONArray(QuestDefinition.self, from: file)
                for quest in fileQuests {
                    quests[quest.id] = quest
                }
            }
        } else {
            let fileQuests = try loadJSONArray(QuestDefinition.self, from: url)
            for quest in fileQuests {
                quests[quest.id] = quest
            }
        }

        return quests
    }

    /// Load anchors from path (file or directory)
    private static func loadAnchors(from url: URL) throws -> [String: AnchorDefinition] {
        var anchors: [String: AnchorDefinition] = [:]

        if isDirectory(url) {
            let files = try jsonFiles(in: url)
            for file in files {
                let fileAnchors = try loadJSONArray(AnchorDefinition.self, from: file)
                for anchor in fileAnchors {
                    anchors[anchor.id] = anchor
                }
            }
        } else {
            let fileAnchors = try loadJSONArray(AnchorDefinition.self, from: url)
            for anchor in fileAnchors {
                anchors[anchor.id] = anchor
            }
        }

        return anchors
    }

    /// Load abilities from path (file or directory).
    private static func loadAbilities(from url: URL) throws -> [String: HeroAbility] {
        var abilities: [String: HeroAbility] = [:]

        func loadFromFile(_ file: URL) throws {
            let jsonAbilities = try loadJSONArray(JSONAbilityDefinition.self, from: file)
            for jsonAbility in jsonAbilities {
                guard let ability = jsonAbility.toHeroAbility() else {
                    throw PackLoadError.invalidManifest(
                        reason: "Invalid ability '\(jsonAbility.id)' in \(file.lastPathComponent)"
                    )
                }
                abilities[ability.id] = ability
            }
        }

        if isDirectory(url) {
            for file in try jsonFiles(in: url) {
                try loadFromFile(file)
            }
        } else {
            try loadFromFile(url)
        }

        return abilities
    }

    /// Load heroes from path (file or directory).
    /// Tries StandardHeroDefinition (editor format) first, falls back to PackHeroDefinition (legacy).
    private static func loadHeroes(
        from url: URL,
        abilities: [String: HeroAbility]
    ) throws -> [String: StandardHeroDefinition] {
        var heroes: [String: StandardHeroDefinition] = [:]

        func loadFromFile(_ file: URL) throws {
            if let standard = try? loadJSONArray(StandardHeroDefinition.self, from: file) {
                for hero in standard { heroes[hero.id] = hero }
            } else {
                let fileHeroes = try loadJSONArray(PackHeroDefinition.self, from: file)
                for hero in fileHeroes {
                    let standard = try hero.toStandard(abilities: abilities)
                    heroes[standard.id] = standard
                }
            }
        }

        if isDirectory(url) {
            for file in try jsonFiles(in: url) { try loadFromFile(file) }
        } else {
            try loadFromFile(url)
        }

        return heroes
    }

    /// Load cards from path (file or directory).
    /// Tries PackCardDefinition (legacy with `name_ru` / `description_ru`) first to avoid localization loss,
    /// then falls back to StandardCardDefinition (editor format).
    private static func loadCards(from url: URL) throws -> [String: StandardCardDefinition] {
        var cards: [String: StandardCardDefinition] = [:]

        func loadFromFile(_ file: URL) throws {
            if let legacyCards = try? loadJSONArray(PackCardDefinition.self, from: file) {
                for card in legacyCards {
                    let standard = card.toStandard()
                    cards[standard.id] = standard
                }
            } else {
                let standardCards = try loadJSONArray(StandardCardDefinition.self, from: file)
                for card in standardCards { cards[card.id] = card }
            }
        }

        if isDirectory(url) {
            for file in try jsonFiles(in: url) { try loadFromFile(file) }
        } else {
            try loadFromFile(url)
        }

        return cards
    }

    /// Load balance configuration
    private static func loadBalanceConfig(from url: URL) throws -> BalanceConfiguration {
        return try loadJSON(BalanceConfiguration.self, from: url)
    }

    /// Load enemies from path (file or directory)
    private static func loadEnemies(from url: URL) throws -> [String: EnemyDefinition] {
        var enemies: [String: EnemyDefinition] = [:]

        if isDirectory(url) {
            let files = try jsonFiles(in: url)
            for file in files {
                let fileEnemies = try loadJSONArray(EnemyDefinition.self, from: file)
                for enemy in fileEnemies {
                    enemies[enemy.id] = enemy
                }
            }
        } else {
            let fileEnemies = try loadJSONArray(EnemyDefinition.self, from: url)
            for enemy in fileEnemies {
                enemies[enemy.id] = enemy
            }
        }

        return enemies
    }

    /// Load behavior definitions from JSON
    private static func loadBehaviors(from url: URL) throws -> [String: BehaviorDefinition] {
        var behaviors: [String: BehaviorDefinition] = [:]
        let defs = try loadJSONArray(BehaviorDefinition.self, from: url)
        for def in defs {
            behaviors[def.id] = def
        }
        return behaviors
    }

    /// Load fate cards from JSON
    private static func loadFateCards(from url: URL) throws -> [String: FateCard] {
        var fateCards: [String: FateCard] = [:]

        if isDirectory(url) {
            let files = try jsonFiles(in: url)
            for file in files {
                let fileCards = try loadJSONArray(FateCard.self, from: file)
                for card in fileCards {
                    fateCards[card.id] = card
                }
            }
        } else {
            let fileCards = try loadJSONArray(FateCard.self, from: url)
            for card in fileCards {
                fateCards[card.id] = card
            }
        }

        return fateCards
    }

    // MARK: - JSON Helpers

    /// Load a single JSON object
    private static func loadJSON<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: data)
        } catch {
            throw PackLoadError.contentLoadFailed(file: url.lastPathComponent, underlyingError: error)
        }
    }

    /// Load a JSON array (or single object as array)
    private static func loadJSONArray<T: Decodable>(_ type: T.Type, from url: URL) throws -> [T] {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw PackLoadError.contentLoadFailed(file: url.lastPathComponent, underlyingError: error)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        // Try array first
        do {
            return try decoder.decode([T].self, from: data)
        } catch let arrayError {
            #if DEBUG
            // Detailed error diagnostics
            print("PackLoader: Failed to decode \(url.lastPathComponent) as [\(T.self)]")
            if let decodingError = arrayError as? DecodingError {
                switch decodingError {
                case .typeMismatch(let type, let context):
                    print("  → typeMismatch: expected \(type)")
                    print("  → path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    print("  → description: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("  → valueNotFound: \(type)")
                    print("  → path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .keyNotFound(let key, let context):
                    print("  → keyNotFound: \(key.stringValue)")
                    print("  → path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .dataCorrupted(let context):
                    print("  → dataCorrupted: \(context.debugDescription)")
                    print("  → path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                @unknown default:
                    print("  → unknown error: \(decodingError)")
                }
            }
            #endif

            // Try single object as fallback
            do {
                let single = try decoder.decode(T.self, from: data)
                return [single]
            } catch {
                // Report the array error since that's what we expected
                throw PackLoadError.contentLoadFailed(file: url.lastPathComponent, underlyingError: arrayError)
            }
        }
    }

    // MARK: - File System Helpers

    /// Check if URL is a directory
    private static func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    /// Get all JSON files in a directory
    private static func jsonFiles(in url: URL) throws -> [URL] {
        let contents = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil
        )
        return contents.filter { $0.pathExtension.lowercased() == "json" }
    }

    // MARK: - Checksum Verification (Epic 0.3)

    /// Verify file checksums against manifest
    /// - Parameters:
    ///   - checksums: Dictionary of relative paths to expected SHA256 hashes
    ///   - packURL: Root URL of the pack
    /// - Throws: PackLoadError.checksumMismatch if verification fails
    private static func verifyChecksums(_ checksums: [String: String], in packURL: URL) throws {
        for (relativePath, expectedHash) in checksums {
            let fileURL = packURL.appendingPathComponent(relativePath)

            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                throw PackLoadError.fileNotFound(relativePath)
            }

            let actualHash = try computeSHA256(of: fileURL)

            if actualHash.lowercased() != expectedHash.lowercased() {
                throw PackLoadError.checksumMismatch(
                    file: relativePath,
                    expected: expectedHash,
                    actual: actualHash
                )
            }
        }
    }

    /// Compute SHA256 hash of a file
    /// - Parameter url: File URL
    /// - Returns: Hex-encoded SHA256 hash string
    public static func computeSHA256(of url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

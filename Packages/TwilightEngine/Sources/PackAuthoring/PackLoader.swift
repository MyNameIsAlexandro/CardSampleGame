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
            loadAbilities(from: url.appendingPathComponent(abilitiesPath))
        }

        // Load heroes
        if let heroesPath = manifest.heroesPath {
            pack.heroes = try loadHeroes(from: url.appendingPathComponent(heroesPath))
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

        // Load localization string tables (Epic 5)
        if let localizationPath = manifest.localizationPath {
            let locURL = url.appendingPathComponent(localizationPath)
            try LocalizationManager.shared.loadStringTables(
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

    /// Load abilities from JSON file (registers in AbilityRegistry)
    private static func loadAbilities(from url: URL) {
        // Abilities are registered globally in AbilityRegistry
        AbilityRegistry.shared.loadFromJSON(at: url)
    }

    /// Load heroes from path (file or directory)
    private static func loadHeroes(from url: URL) throws -> [String: StandardHeroDefinition] {
        var heroes: [String: StandardHeroDefinition] = [:]

        if isDirectory(url) {
            let files = try jsonFiles(in: url)
            for file in files {
                let fileHeroes = try loadJSONArray(PackHeroDefinition.self, from: file)
                for hero in fileHeroes {
                    let standard = hero.toStandard()
                    heroes[standard.id] = standard
                }
            }
        } else {
            let fileHeroes = try loadJSONArray(PackHeroDefinition.self, from: url)
            for hero in fileHeroes {
                let standard = hero.toStandard()
                heroes[standard.id] = standard
            }
        }

        return heroes
    }

    /// Load cards from path (file or directory) with localization
    private static func loadCards(from url: URL) throws -> [String: StandardCardDefinition] {
        var cards: [String: StandardCardDefinition] = [:]

        if isDirectory(url) {
            let files = try jsonFiles(in: url)
            for file in files {
                let fileCards = try loadJSONArray(PackCardDefinition.self, from: file)
                for card in fileCards {
                    let standard = card.toStandard()
                    cards[standard.id] = standard
                }
            }
        } else {
            let fileCards = try loadJSONArray(PackCardDefinition.self, from: url)
            for card in fileCards {
                let standard = card.toStandard()
                cards[standard.id] = standard
            }
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

// MARK: - Pack Hero Definition

/// JSON структура для stats героя
private struct PackHeroStats: Codable {
    public let health: Int
    public let maxHealth: Int
    public let strength: Int
    public let dexterity: Int
    public let constitution: Int
    public let intelligence: Int
    public let wisdom: Int
    public let charisma: Int
    public let faith: Int
    public let maxFaith: Int
    public let startingBalance: Int

    public func toHeroStats() -> HeroStats {
        HeroStats(
            health: health,
            maxHealth: maxHealth,
            strength: strength,
            dexterity: dexterity,
            constitution: constitution,
            intelligence: intelligence,
            wisdom: wisdom,
            charisma: charisma,
            faith: faith,
            maxFaith: maxFaith,
            startingBalance: startingBalance
        )
    }
}

/// JSON-совместимое определение героя для загрузки из Content Pack
/// Статы загружаются из JSON (data-driven)
private struct PackHeroDefinition: Codable {
    public let id: String
    public let name: String
    public let nameRu: String?
    public let description: String
    public let descriptionRu: String?
    public let icon: String
    public let baseStats: PackHeroStats
    public let abilityId: String
    public let startingDeckCardIds: [String]
    public let availability: String?

    /// Конвертация в StandardHeroDefinition
    public func toStandard() -> StandardHeroDefinition {
        // Определяем доступность
        let heroAvailability: HeroAvailability
        switch availability?.lowercased() {
        case "always_available", nil:
            heroAvailability = .alwaysAvailable
        case let str where str?.hasPrefix("requires_unlock:") == true:
            let condition = String(str!.dropFirst("requires_unlock:".count))
            heroAvailability = .requiresUnlock(condition: condition)
        case let str where str?.hasPrefix("dlc:") == true:
            let packId = String(str!.dropFirst("dlc:".count))
            heroAvailability = .dlc(packID: packId)
        default:
            heroAvailability = .alwaysAvailable
        }

        // Convert legacy name/nameRu to LocalizableText
        // If nameRu is provided, create inline LocalizedString
        // Otherwise, assume it might be a StringKey (if it looks like one) or use as single-language text
        let localizedName: LocalizableText
        if name.contains(".") && !name.contains(" ") && name.first?.isLowercase == true {
            // Looks like a StringKey (e.g., "hero.ragnar.name")
            localizedName = .key(StringKey(name))
        } else {
            // Legacy format: inline LocalizedString
            localizedName = .inline(LocalizedString(en: name, ru: nameRu ?? name))
        }

        let localizedDescription: LocalizableText
        if description.contains(".") && !description.contains(" ") && description.first?.isLowercase == true {
            // Looks like a StringKey
            localizedDescription = .key(StringKey(description))
        } else {
            // Legacy format: inline LocalizedString
            localizedDescription = .inline(LocalizedString(en: description, ru: descriptionRu ?? description))
        }

        // Получаем способность по ID
        guard let ability = HeroAbility.forAbilityId(abilityId) else {
            #if DEBUG
            print("PackLoader: ERROR - Unknown ability ID '\(abilityId)' for hero '\(id)'")
            #endif
            fatalError("Missing ability definition for '\(abilityId)'. Add it to HeroAbility.forAbilityId() or hero_abilities.json")
        }

        return StandardHeroDefinition(
            id: id,
            name: localizedName,
            description: localizedDescription,
            icon: icon,
            baseStats: baseStats.toHeroStats(),
            specialAbility: ability,
            startingDeckCardIDs: startingDeckCardIds,
            availability: heroAvailability
        )
    }
}

// MARK: - Pack Card Definition

/// JSON-совместимое определение карты для загрузки из Content Pack с локализацией
private struct PackCardDefinition: Codable {
    public let id: String
    public let name: String
    public let nameRu: String?
    public let cardType: CardType
    public let rarity: CardRarity
    public let description: String
    public let descriptionRu: String?
    public let icon: String
    public let expansionSet: ExpansionSet
    public let ownership: CardOwnership
    public let abilities: [CardAbility]
    public let faithCost: Int
    public let balance: CardBalance?
    public let role: CardRole?
    public let power: Int?
    public let defense: Int?
    public let health: Int?
    public let realm: Realm?
    public let curseType: CurseType?

    /// Конвертация в StandardCardDefinition с локализацией
    public func toStandard() -> StandardCardDefinition {
        // Convert legacy name/nameRu to LocalizableText
        // If name looks like a StringKey (lowercase.dot.separated), treat it as key
        // Otherwise, create inline LocalizedString from legacy format
        let localizedName: LocalizableText
        if name.contains(".") && !name.contains(" ") && name.first?.isLowercase == true {
            // Looks like a StringKey (e.g., "card.strike.name")
            localizedName = .key(StringKey(name))
        } else {
            // Legacy format: inline LocalizedString
            localizedName = .inline(LocalizedString(en: name, ru: nameRu ?? name))
        }

        let localizedDescription: LocalizableText
        if description.contains(".") && !description.contains(" ") && description.first?.isLowercase == true {
            // Looks like a StringKey
            localizedDescription = .key(StringKey(description))
        } else {
            // Legacy format: inline LocalizedString
            localizedDescription = .inline(LocalizedString(en: description, ru: descriptionRu ?? description))
        }

        return StandardCardDefinition(
            id: id,
            name: localizedName,
            cardType: cardType,
            rarity: rarity,
            description: localizedDescription,
            icon: icon,
            expansionSet: expansionSet,
            ownership: ownership,
            abilities: abilities,
            faithCost: faithCost,
            balance: balance,
            role: role,
            power: power,
            defense: defense,
            health: health,
            realm: realm,
            curseType: curseType
        )
    }
}

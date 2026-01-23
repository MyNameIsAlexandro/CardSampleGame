import Foundation
import CryptoKit

// MARK: - Pack Loader

/// Loads content pack data from disk
/// Supports JSON format (Protobuf support planned)
enum PackLoader {
    // MARK: - Main Loading

    /// Load a pack from a manifest and source URL
    /// - Parameters:
    ///   - manifest: The pack manifest
    ///   - url: URL to the pack directory
    /// - Returns: Fully loaded pack
    /// - Throws: PackLoadError if loading fails
    static func load(manifest: PackManifest, from url: URL) throws -> LoadedPack {
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
        }

        // Load events
        if let eventsPath = manifest.eventsPath {
            pack.events = try loadEvents(from: url.appendingPathComponent(eventsPath))
        }

        // Load quests
        if let questsPath = manifest.questsPath {
            pack.quests = try loadQuests(from: url.appendingPathComponent(questsPath))
        }

        // Load anchors
        if let anchorsPath = manifest.anchorsPath {
            pack.anchors = try loadAnchors(from: url.appendingPathComponent(anchorsPath))
        }

        // Load hero abilities (before heroes, so abilities are available)
        if let abilitiesPath = manifest.abilitiesPath {
            loadAbilities(from: url.appendingPathComponent(abilitiesPath))
        }

        // Load heroes
        if let heroesPath = manifest.heroesPath {
            pack.heroes = try loadHeroes(from: url.appendingPathComponent(heroesPath))
        }

        // Load cards
        if let cardsPath = manifest.cardsPath {
            pack.cards = try loadCards(from: url.appendingPathComponent(cardsPath))
        }

        // Load balance configuration
        if let balancePath = manifest.balancePath {
            pack.balanceConfig = try loadBalanceConfig(from: url.appendingPathComponent(balancePath))
        }

        // Load enemies
        if let enemiesPath = manifest.enemiesPath {
            pack.enemies = try loadEnemies(from: url.appendingPathComponent(enemiesPath))
        }

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
    static func computeSHA256(of url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Balance Configuration

/// Configuration for game balance parameters
/// This replaces hardcoded balance values like TwilightMarchesConfig
struct BalanceConfiguration: Codable {
    // MARK: - Resources

    /// Resource definitions
    let resources: ResourceBalanceConfig

    // MARK: - Pressure/Tension

    /// Pressure system configuration
    let pressure: PressureBalanceConfig

    // MARK: - Combat

    /// Combat system configuration
    let combat: CombatBalanceConfig?

    // MARK: - Time

    /// Time system configuration
    let time: TimeBalanceConfig

    // MARK: - Anchors

    /// Anchor system configuration
    let anchor: AnchorBalanceConfig

    // MARK: - End Conditions

    /// Game end conditions
    let endConditions: EndConditionConfig

    // MARK: - Balance System (optional)

    /// Light/Dark balance system configuration
    let balanceSystem: BalanceSystemConfig?

    // MARK: - Defaults

    static let `default` = BalanceConfiguration(
        resources: .default,
        pressure: .default,
        combat: nil,
        time: .default,
        anchor: .default,
        endConditions: .default,
        balanceSystem: nil
    )
}

/// Resource balance configuration
struct ResourceBalanceConfig: Codable {
    /// Starting health
    let startingHealth: Int

    /// Maximum health
    let maxHealth: Int

    /// Starting faith
    let startingFaith: Int

    /// Maximum faith
    let maxFaith: Int

    /// Starting supplies
    let startingSupplies: Int

    /// Maximum supplies
    let maxSupplies: Int

    /// Starting gold
    let startingGold: Int

    /// Maximum gold
    let maxGold: Int

    /// Health restored when resting (optional, default 3)
    let restHealAmount: Int?

    /// Starting balance value (optional)
    let startingBalance: Int?

    static let `default` = ResourceBalanceConfig(
        startingHealth: 20,
        maxHealth: 30,
        startingFaith: 10,
        maxFaith: 20,
        startingSupplies: 5,
        maxSupplies: 10,
        startingGold: 0,
        maxGold: 100,
        restHealAmount: 3,
        startingBalance: 50
    )
}

/// Pressure system balance configuration
struct PressureBalanceConfig: Codable {
    /// Starting pressure level
    let startingPressure: Int

    /// Minimum pressure
    let minPressure: Int

    /// Maximum pressure
    let maxPressure: Int

    /// Pressure gain per turn
    let pressurePerTurn: Int

    /// Days between tension ticks (when tension increases automatically)
    /// Also accepts escalation_interval from JSON
    let tensionTickInterval: Int?

    /// Escalation interval (alias for tensionTickInterval)
    let escalationInterval: Int?

    /// Pressure thresholds for escalation
    let thresholds: PressureThresholds

    /// Degradation settings
    let degradation: DegradationConfig

    /// Get the effective tick interval
    var effectiveTickInterval: Int {
        tensionTickInterval ?? escalationInterval ?? 3
    }

    static let `default` = PressureBalanceConfig(
        startingPressure: 0,
        minPressure: 0,
        maxPressure: 100,
        pressurePerTurn: 5,
        tensionTickInterval: 3,
        escalationInterval: nil,
        thresholds: .default,
        degradation: .default
    )
}

/// Pressure thresholds
struct PressureThresholds: Codable {
    /// Threshold for increased event danger
    let warning: Int

    /// Threshold for critical pressure
    let critical: Int

    /// Threshold for game loss
    let catastrophic: Int

    static let `default` = PressureThresholds(
        warning: 30,
        critical: 60,
        catastrophic: 100
    )
}

/// Degradation configuration
struct DegradationConfig: Codable {
    /// Chance for region degradation at each threshold
    let warningChance: Double

    /// Chance at critical level
    let criticalChance: Double

    /// Chance at catastrophic level (optional)
    let catastrophicChance: Double?

    /// Base chance for anchor integrity loss per turn
    let anchorDecayChance: Double

    static let `default` = DegradationConfig(
        warningChance: 0.1,
        criticalChance: 0.25,
        catastrophicChance: nil,
        anchorDecayChance: 0.05
    )
}

/// Combat balance configuration
struct CombatBalanceConfig: Codable {
    /// Base damage for attacks
    let baseDamage: Int

    /// Damage modifier per power point
    let powerModifier: Double

    /// Defense damage reduction
    let defenseReduction: Double

    /// Maximum dice value (optional)
    let diceMax: Int?

    /// Actions per turn (optional)
    let actionsPerTurn: Int?

    /// Cards drawn per turn (optional)
    let cardsDrawnPerTurn: Int?

    /// Maximum hand size (optional)
    let maxHandSize: Int?

    static let `default` = CombatBalanceConfig(
        baseDamage: 3,
        powerModifier: 1.0,
        defenseReduction: 0.5,
        diceMax: 6,
        actionsPerTurn: 3,
        cardsDrawnPerTurn: 5,
        maxHandSize: 7
    )
}

/// Time system balance configuration
struct TimeBalanceConfig: Codable {
    /// Time units per day
    let unitsPerDay: Int

    /// Starting time of day
    let startingTime: Int

    /// Maximum days for campaign
    let maxDays: Int?

    /// Time cost for travel
    let travelCost: Int

    /// Time cost for exploration
    let exploreCost: Int

    /// Time cost for rest
    let restCost: Int

    /// Time cost for strengthening anchor (optional)
    let strengthenAnchorCost: Int?

    /// Time cost for instant actions (optional)
    let instantCost: Int?

    static let `default` = TimeBalanceConfig(
        unitsPerDay: 24,
        startingTime: 8,
        maxDays: nil,
        travelCost: 2,
        exploreCost: 1,
        restCost: 4,
        strengthenAnchorCost: 1,
        instantCost: 0
    )
}

/// End condition configuration
struct EndConditionConfig: Codable {
    /// Health threshold for death
    let deathHealth: Int

    /// Pressure threshold for loss
    let pressureLoss: Int?

    /// Breach count for loss
    let breachLoss: Int?

    /// Victory conditions (quest IDs)
    let victoryQuests: [String]

    /// Flag set when main quest completes (optional)
    let mainQuestCompleteFlag: String?

    /// Flag set when critical anchor destroyed (optional)
    let criticalAnchorDestroyedFlag: String?

    static let `default` = EndConditionConfig(
        deathHealth: 0,
        pressureLoss: 100,
        breachLoss: nil,
        victoryQuests: [],
        mainQuestCompleteFlag: nil,
        criticalAnchorDestroyedFlag: nil
    )
}

/// Anchor system balance configuration
struct AnchorBalanceConfig: Codable {
    /// Maximum anchor integrity
    let maxIntegrity: Int

    /// Amount to strengthen per action
    let strengthenAmount: Int

    /// Faith cost to strengthen
    let strengthenCost: Int

    /// Integrity threshold for stable status
    let stableThreshold: Int

    /// Integrity threshold for breach
    let breachThreshold: Int

    /// Base decay rate per turn in threatened regions
    let decayPerTurn: Int

    static let `default` = AnchorBalanceConfig(
        maxIntegrity: 100,
        strengthenAmount: 15,
        strengthenCost: 5,
        stableThreshold: 70,
        breachThreshold: 0,
        decayPerTurn: 5
    )
}

/// Balance system configuration for Light/Dark alignment
struct BalanceSystemConfig: Codable {
    /// Minimum balance value
    let min: Int

    /// Maximum balance value
    let max: Int

    /// Initial balance value
    let initial: Int

    /// Threshold for light alignment
    let lightThreshold: Int

    /// Threshold for dark alignment
    let darkThreshold: Int

    static let `default` = BalanceSystemConfig(
        min: 0,
        max: 100,
        initial: 50,
        lightThreshold: 70,
        darkThreshold: 30
    )
}

// MARK: - Pack Hero Definition

/// JSON структура для stats героя
private struct PackHeroStats: Codable {
    let health: Int
    let maxHealth: Int
    let strength: Int
    let dexterity: Int
    let constitution: Int
    let intelligence: Int
    let wisdom: Int
    let charisma: Int
    let faith: Int
    let maxFaith: Int
    let startingBalance: Int

    func toHeroStats() -> HeroStats {
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
    let id: String
    let name: String
    let nameRu: String?
    let description: String
    let descriptionRu: String?
    let icon: String
    let baseStats: PackHeroStats
    let abilityId: String
    let startingDeckCardIds: [String]
    let availability: String?

    /// Конвертация в StandardHeroDefinition
    func toStandard() -> StandardHeroDefinition {
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

        // Локализованное имя и описание
        // Determine language: check Bundle localizations, then Locale.preferredLanguages, then Locale.current
        let isRussian: Bool = {
            if let bundleLang = Bundle.main.preferredLocalizations.first, bundleLang.hasPrefix("ru") {
                return true
            }
            if let systemLang = Locale.preferredLanguages.first, systemLang.hasPrefix("ru") {
                return true
            }
            if Locale.current.language.languageCode?.identifier == "ru" {
                return true
            }
            return false
        }()
        let localizedName = isRussian ? (nameRu ?? name) : name
        let localizedDescription = isRussian ? (descriptionRu ?? description) : description

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
    let id: String
    let name: String
    let nameRu: String?
    let cardType: CardType
    let rarity: CardRarity
    let description: String
    let descriptionRu: String?
    let icon: String
    let expansionSet: ExpansionSet
    let ownership: CardOwnership
    let abilities: [CardAbility]
    let faithCost: Int
    let balance: CardBalance?
    let role: CardRole?
    let power: Int?
    let defense: Int?
    let health: Int?
    let realm: Realm?
    let curseType: CurseType?

    /// Конвертация в StandardCardDefinition с локализацией
    func toStandard() -> StandardCardDefinition {
        // Determine language: check Bundle localizations, then Locale.preferredLanguages, then Locale.current
        let isRussian: Bool = {
            // First try Bundle preferred localizations (best for app UI consistency)
            if let bundleLang = Bundle.main.preferredLocalizations.first, bundleLang.hasPrefix("ru") {
                return true
            }
            // Fallback to system preferred languages
            if let systemLang = Locale.preferredLanguages.first, systemLang.hasPrefix("ru") {
                return true
            }
            // Final fallback to current locale
            if Locale.current.language.languageCode?.identifier == "ru" {
                return true
            }
            return false
        }()
        let localizedName = isRussian ? (nameRu ?? name) : name
        let localizedDescription = isRussian ? (descriptionRu ?? description) : description

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

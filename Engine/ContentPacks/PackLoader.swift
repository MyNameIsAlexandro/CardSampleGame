import Foundation

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

    /// Load heroes from path (file or directory)
    private static func loadHeroes(from url: URL) throws -> [String: StandardHeroDefinition] {
        var heroes: [String: StandardHeroDefinition] = [:]

        if isDirectory(url) {
            let files = try jsonFiles(in: url)
            for file in files {
                let fileHeroes = try loadJSONArray(StandardHeroDefinition.self, from: file)
                for hero in fileHeroes {
                    heroes[hero.id] = hero
                }
            }
        } else {
            let fileHeroes = try loadJSONArray(StandardHeroDefinition.self, from: url)
            for hero in fileHeroes {
                heroes[hero.id] = hero
            }
        }

        return heroes
    }

    /// Load cards from path (file or directory)
    private static func loadCards(from url: URL) throws -> [String: StandardCardDefinition] {
        var cards: [String: StandardCardDefinition] = [:]

        if isDirectory(url) {
            let files = try jsonFiles(in: url)
            for file in files {
                let fileCards = try loadJSONArray(StandardCardDefinition.self, from: file)
                for card in fileCards {
                    cards[card.id] = card
                }
            }
        } else {
            let fileCards = try loadJSONArray(StandardCardDefinition.self, from: url)
            for card in fileCards {
                cards[card.id] = card
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
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            // Try array first
            if let array = try? decoder.decode([T].self, from: data) {
                return array
            }

            // Try single object
            let single = try decoder.decode(T.self, from: data)
            return [single]
        } catch {
            throw PackLoadError.contentLoadFailed(file: url.lastPathComponent, underlyingError: error)
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

    // MARK: - Defaults

    static let `default` = BalanceConfiguration(
        resources: .default,
        pressure: .default,
        combat: nil,
        time: .default,
        anchor: .default,
        endConditions: .default
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

    /// Health restored when resting
    let restHealAmount: Int

    static let `default` = ResourceBalanceConfig(
        startingHealth: 20,
        maxHealth: 30,
        startingFaith: 10,
        maxFaith: 20,
        startingSupplies: 5,
        maxSupplies: 10,
        startingGold: 0,
        maxGold: 100,
        restHealAmount: 3
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
    let tensionTickInterval: Int

    /// Pressure thresholds for escalation
    let thresholds: PressureThresholds

    /// Degradation settings
    let degradation: DegradationConfig

    static let `default` = PressureBalanceConfig(
        startingPressure: 0,
        minPressure: 0,
        maxPressure: 100,
        pressurePerTurn: 5,
        tensionTickInterval: 3,
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

    /// Base chance for anchor integrity loss per turn
    let anchorDecayChance: Double

    static let `default` = DegradationConfig(
        warningChance: 0.1,
        criticalChance: 0.25,
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

    static let `default` = CombatBalanceConfig(
        baseDamage: 3,
        powerModifier: 1.0,
        defenseReduction: 0.5
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

    static let `default` = TimeBalanceConfig(
        unitsPerDay: 24,
        startingTime: 8,
        maxDays: nil,
        travelCost: 2,
        exploreCost: 1,
        restCost: 4
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

    static let `default` = EndConditionConfig(
        deathHealth: 0,
        pressureLoss: 100,
        breachLoss: nil,
        victoryQuests: []
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

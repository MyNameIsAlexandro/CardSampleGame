import Foundation

/// Hero registry - centralized storage of all hero definitions
/// Heroes are loaded from Content Pack (JSON) - no hardcoded classes
public final class HeroRegistry {

    // MARK: - Singleton

    public static let shared = HeroRegistry()

    // MARK: - Storage

    /// Зарегистрированные определения героев
    private var definitions: [String: HeroDefinition] = [:]

    /// Порядок отображения героев в UI
    private var displayOrder: [String] = []

    /// Источники данных героев (для модульности)
    private var dataSources: [HeroDataSource] = []

    // MARK: - Init

    private init() {
        registerBuiltInHeroes()
    }

    // MARK: - Registration

    /// Register a hero definition in the registry.
    /// - Parameter definition: The hero definition to register.
    /// - Note: If a hero with the same ID exists, it will be replaced.
    ///         Heroes are added to display order in registration sequence.
    public func register(_ definition: HeroDefinition) {
        definitions[definition.id] = definition
        if !displayOrder.contains(definition.id) {
            displayOrder.append(definition.id)
        }
    }

    /// Register multiple hero definitions at once.
    /// - Parameter definitions: Array of hero definitions to register.
    public func registerAll(_ definitions: [HeroDefinition]) {
        for definition in definitions {
            register(definition)
        }
    }

    /// Remove a hero from the registry.
    /// - Parameter id: The unique identifier of the hero to remove.
    public func unregister(id: String) {
        definitions.removeValue(forKey: id)
        displayOrder.removeAll { $0 == id }
    }

    /// Clear all registered heroes and display order.
    /// - Note: Does not remove data sources; call `reload()` to repopulate.
    public func clear() {
        definitions.removeAll()
        displayOrder.removeAll()
    }

    /// Reload all heroes from registered data sources.
    /// - Note: Clears existing registrations before reloading.
    public func reload() {
        clear()
        registerBuiltInHeroes()
        for source in dataSources {
            registerAll(source.loadHeroes())
        }
    }

    // MARK: - Data Sources

    /// Add a data source and immediately load its heroes.
    /// - Parameter source: The hero data source to add.
    public func addDataSource(_ source: HeroDataSource) {
        dataSources.append(source)
        registerAll(source.loadHeroes())
    }

    /// Remove a data source and unregister all its heroes.
    /// - Parameter source: The hero data source to remove.
    public func removeDataSource(_ source: HeroDataSource) {
        if let index = dataSources.firstIndex(where: { $0.id == source.id }) {
            let source = dataSources.remove(at: index)
            for hero in source.loadHeroes() {
                unregister(id: hero.id)
            }
        }
    }

    // MARK: - Queries

    /// Get a hero definition by its unique identifier.
    /// - Parameter id: The hero's unique identifier.
    /// - Returns: The hero definition, or `nil` if not found.
    public func hero(id: String) -> HeroDefinition? {
        return definitions[id]
    }

    /// All registered heroes in display order.
    public var allHeroes: [HeroDefinition] {
        return displayOrder.compactMap { definitions[$0] }
    }

    /// The first hero in display order (useful for defaults).
    public var firstHero: HeroDefinition? {
        return allHeroes.first
    }

    /// Get heroes available to the player based on unlock status.
    /// - Parameters:
    ///   - unlockedConditions: Set of unlocked condition flags.
    ///   - ownedDLCs: Set of owned DLC pack identifiers.
    /// - Returns: Array of hero definitions the player can select.
    public func availableHeroes(unlockedConditions: Set<String> = [], ownedDLCs: Set<String> = []) -> [HeroDefinition] {
        return allHeroes.filter { hero in
            switch hero.availability {
            case .alwaysAvailable:
                return true
            case .requiresUnlock(let condition):
                return unlockedConditions.contains(condition)
            case .dlc(let packID):
                return ownedDLCs.contains(packID)
            }
        }
    }

    /// Number of registered heroes.
    public var count: Int {
        return definitions.count
    }

    // MARK: - Built-in Heroes

    /// Загрузка героев из JSON файла в бандле (legacy)
    /// NOTE: С переходом на ContentPack систему, герои загружаются через
    /// ContentRegistry.loadPack(), который вызывает HeroRegistry.register() для каждого героя.
    /// Этот метод оставлен для обратной совместимости с Bundle.main структурой.
    private func registerBuiltInHeroes() {
        // Пробуем загрузить из Bundle.main (старая структура)
        // Если не найдено - это OK, герои будут загружены через ContentPack
        if let heroesURL = Bundle.main.url(
            forResource: "heroes",
            withExtension: "json",
            subdirectory: "ContentPacks/TwilightMarches/Characters"
        ) {
            let dataSource = JSONHeroDataSource(
                id: "bundle_heroes",
                name: "Bundle Heroes",
                fileURL: heroesURL
            )
            registerAll(dataSource.loadHeroes())
            return
        }

        if let heroesURL = Bundle.main.url(forResource: "heroes", withExtension: "json") {
            let dataSource = JSONHeroDataSource(
                id: "bundle_heroes",
                name: "Bundle Heroes",
                fileURL: heroesURL
            )
            registerAll(dataSource.loadHeroes())
            return
        }

        // Не найдено в Bundle.main - это нормально при использовании ContentPack системы
        // Герои будут зарегистрированы когда ContentRegistry загрузит пак
        #if DEBUG
        print("HeroRegistry: Heroes will be loaded via ContentPack system")
        #endif
    }
}

// MARK: - Hero Data Source Protocol

/// Protocol for hero data sources
/// Allows loading heroes from different sources (JSON, server, DLC)
public protocol HeroDataSource {
    /// Unique source identifier
    var id: String { get }

    /// Source name (for debugging)
    var name: String { get }

    /// Load heroes from source
    func loadHeroes() -> [HeroDefinition]
}

// MARK: - JSON Data Source

/// Hero loader from JSON file
public struct JSONHeroDataSource: HeroDataSource {
    public let id: String
    public let name: String
    public let fileURL: URL

    public init(id: String, name: String, fileURL: URL) {
        self.id = id
        self.name = name
        self.fileURL = fileURL
    }

    public func loadHeroes() -> [HeroDefinition] {
        guard let data = try? Data(contentsOf: fileURL) else {
            #if DEBUG
            print("HeroRegistry: Failed to load JSON from \(fileURL)")
            #endif
            return []
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let decoded = try decoder.decode([JSONHeroDefinition].self, from: data)
            return decoded.map { $0.toStandard() }
        } catch {
            #if DEBUG
            print("HeroRegistry: Failed to decode heroes: \(error)")
            #endif
            return []
        }
    }
}

/// JSON структура для stats
public struct JSONHeroStats: Codable {
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

/// JSON-совместимое определение героя (data-driven)
public struct JSONHeroDefinition: Codable {
    let id: String
    let name: String
    let nameRu: String?
    let description: String
    let descriptionRu: String?
    let icon: String
    let baseStats: JSONHeroStats
    let abilityId: String
    let startingDeckCardIds: [String]
    let availability: String?

    func toStandard() -> StandardHeroDefinition {
        // Convert legacy name/nameRu to LocalizableText
        let localizedName: LocalizableText
        if name.contains(".") && !name.contains(" ") && name.first?.isLowercase == true {
            // Looks like a StringKey
            localizedName = .key(StringKey(name))
        } else {
            localizedName = .inline(LocalizedString(en: name, ru: nameRu ?? name))
        }

        let localizedDescription: LocalizableText
        if description.contains(".") && !description.contains(" ") && description.first?.isLowercase == true {
            localizedDescription = .key(StringKey(description))
        } else {
            localizedDescription = .inline(LocalizedString(en: description, ru: descriptionRu ?? description))
        }

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

        // Получаем способность по ID
        guard let ability = HeroAbility.forAbilityId(abilityId) else {
            #if DEBUG
            print("HeroRegistry: ERROR - Unknown ability ID '\(abilityId)' for hero '\(id)'")
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

// MARK: - DLC Data Source

/// Hero source from DLC pack
public struct DLCHeroDataSource: HeroDataSource {
    public let id: String
    public let name: String
    public let packID: String
    public let heroes: [HeroDefinition]

    public init(id: String, name: String, packID: String, heroes: [HeroDefinition]) {
        self.id = id
        self.name = name
        self.packID = packID
        self.heroes = heroes
    }

    public func loadHeroes() -> [HeroDefinition] {
        return heroes
    }
}

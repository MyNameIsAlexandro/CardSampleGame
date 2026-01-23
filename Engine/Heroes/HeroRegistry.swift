import Foundation

/// Реестр героев - централизованное хранилище всех определений героев
/// Герои загружаются из Content Pack (JSON) - без хардкода классов
final class HeroRegistry {

    // MARK: - Singleton

    static let shared = HeroRegistry()

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

    /// Зарегистрировать определение героя
    func register(_ definition: HeroDefinition) {
        definitions[definition.id] = definition
        if !displayOrder.contains(definition.id) {
            displayOrder.append(definition.id)
        }
    }

    /// Зарегистрировать несколько героев
    func registerAll(_ definitions: [HeroDefinition]) {
        for definition in definitions {
            register(definition)
        }
    }

    /// Удалить героя из реестра
    func unregister(id: String) {
        definitions.removeValue(forKey: id)
        displayOrder.removeAll { $0 == id }
    }

    /// Очистить реестр
    func clear() {
        definitions.removeAll()
        displayOrder.removeAll()
    }

    /// Перезагрузить реестр из источников данных
    func reload() {
        clear()
        registerBuiltInHeroes()
        for source in dataSources {
            registerAll(source.loadHeroes())
        }
    }

    // MARK: - Data Sources

    /// Добавить источник данных героев
    func addDataSource(_ source: HeroDataSource) {
        dataSources.append(source)
        registerAll(source.loadHeroes())
    }

    /// Удалить источник данных
    func removeDataSource(_ source: HeroDataSource) {
        if let index = dataSources.firstIndex(where: { $0.id == source.id }) {
            let source = dataSources.remove(at: index)
            for hero in source.loadHeroes() {
                unregister(id: hero.id)
            }
        }
    }

    // MARK: - Queries

    /// Получить героя по ID
    func hero(id: String) -> HeroDefinition? {
        return definitions[id]
    }

    /// Все доступные герои
    var allHeroes: [HeroDefinition] {
        return displayOrder.compactMap { definitions[$0] }
    }

    /// Первый доступный герой (для дефолта)
    var firstHero: HeroDefinition? {
        return allHeroes.first
    }

    /// Доступные герои (не заблокированные)
    func availableHeroes(unlockedConditions: Set<String> = [], ownedDLCs: Set<String> = []) -> [HeroDefinition] {
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

    /// Количество зарегистрированных героев
    var count: Int {
        return definitions.count
    }

    // MARK: - Built-in Heroes

    /// Загрузка героев из JSON файла в бандле
    private func registerBuiltInHeroes() {
        // Сначала пробуем загрузить из ContentPacks (новая структура)
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

        // Fallback: старый путь (heroes.json в корне bundle)
        if let heroesURL = Bundle.main.url(forResource: "heroes", withExtension: "json") {
            let dataSource = JSONHeroDataSource(
                id: "bundle_heroes",
                name: "Bundle Heroes",
                fileURL: heroesURL
            )
            registerAll(dataSource.loadHeroes())
            return
        }

        #if DEBUG
        print("HeroRegistry: ERROR - heroes.json not found in bundle!")
        #endif
    }
}

// MARK: - Hero Data Source Protocol

/// Протокол источника данных героев
/// Позволяет загружать героев из разных источников (JSON, сервер, DLC)
protocol HeroDataSource {
    /// Уникальный идентификатор источника
    var id: String { get }

    /// Название источника (для отладки)
    var name: String { get }

    /// Загрузить героев из источника
    func loadHeroes() -> [HeroDefinition]
}

// MARK: - JSON Data Source

/// Загрузчик героев из JSON файла
struct JSONHeroDataSource: HeroDataSource {
    let id: String
    let name: String
    let fileURL: URL

    func loadHeroes() -> [HeroDefinition] {
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
struct JSONHeroStats: Codable {
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
struct JSONHeroDefinition: Codable {
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
        // Локализация
        let isRussian = Locale.current.language.languageCode?.identifier == "ru"
        let localizedName = isRussian ? (nameRu ?? name) : name
        let localizedDescription = isRussian ? (descriptionRu ?? description) : description

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

/// Источник героев из DLC пакета
struct DLCHeroDataSource: HeroDataSource {
    let id: String
    let name: String
    let packID: String
    let heroes: [HeroDefinition]

    func loadHeroes() -> [HeroDefinition] {
        return heroes
    }
}

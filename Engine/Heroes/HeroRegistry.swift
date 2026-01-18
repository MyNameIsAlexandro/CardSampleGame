import Foundation

/// Реестр героев - централизованное хранилище всех определений героев
/// Позволяет легко добавлять, удалять и модифицировать героев
/// без изменения основного кода игры
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

    /// Получить героя по классу
    func hero(forClass heroClass: HeroClass) -> HeroDefinition? {
        return definitions.values.first { $0.heroClass == heroClass }
    }

    /// Все доступные герои
    var allHeroes: [HeroDefinition] {
        return displayOrder.compactMap { definitions[$0] }
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

    /// Герои определённого класса
    func heroes(ofClass heroClass: HeroClass) -> [HeroDefinition] {
        return allHeroes.filter { $0.heroClass == heroClass }
    }

    /// Количество зарегистрированных героев
    var count: Int {
        return definitions.count
    }

    // MARK: - Built-in Heroes

    /// Регистрация встроенных героев
    private func registerBuiltInHeroes() {
        // Воин - Рагнар
        register(StandardHeroDefinition(
            id: "warrior_ragnar",
            name: "Рагнар",
            heroClass: .warrior,
            description: "Бывший командир королевской гвардии. Его ярость в бою легендарна.",
            icon: "⚔️",
            baseStats: HeroClass.warrior.baseStats,
            specialAbility: .warriorRage,
            startingDeckCardIDs: ["strike_basic", "strike_basic", "defend_basic", "rage_strike"],
            availability: .alwaysAvailable
        ))

        // Маг - Эльвира
        register(StandardHeroDefinition(
            id: "mage_elvira",
            name: "Эльвира",
            heroClass: .mage,
            description: "Мастер арканных искусств. Черпает силу из обоих источников.",
            icon: "🔮",
            baseStats: HeroClass.mage.baseStats,
            specialAbility: .mageMeditation,
            startingDeckCardIDs: ["arcane_bolt", "arcane_bolt", "shield_spell", "meditation"],
            availability: .alwaysAvailable
        ))

        // Следопыт - Торин
        register(StandardHeroDefinition(
            id: "ranger_thorin",
            name: "Торин",
            heroClass: .ranger,
            description: "Охотник на чудовищ из северных лесов. Никогда не промахивается.",
            icon: "🏹",
            baseStats: HeroClass.ranger.baseStats,
            specialAbility: .rangerTracking,
            startingDeckCardIDs: ["precise_shot", "precise_shot", "trap", "tracking"],
            availability: .alwaysAvailable
        ))

        // Жрец - Аврелий
        register(StandardHeroDefinition(
            id: "priest_aurelius",
            name: "Аврелий",
            heroClass: .priest,
            description: "Преданный служитель Света. Его благословения защищают союзников.",
            icon: "✝️",
            baseStats: HeroClass.priest.baseStats,
            specialAbility: .priestBlessing,
            startingDeckCardIDs: ["holy_light", "holy_light", "blessing", "smite"],
            availability: .alwaysAvailable
        ))

        // Тень - Умбра
        register(StandardHeroDefinition(
            id: "shadow_umbra",
            name: "Умбра",
            heroClass: .shadow,
            description: "Агент Нави. Наносит удар из тени, когда враг не ожидает.",
            icon: "🗡️",
            baseStats: HeroClass.shadow.baseStats,
            specialAbility: .shadowAmbush,
            startingDeckCardIDs: ["backstab", "backstab", "shadow_step", "poison_blade"],
            availability: .alwaysAvailable
        ))
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
            print("HeroRegistry: Failed to load JSON from \(fileURL)")
            return []
        }

        do {
            let decoded = try JSONDecoder().decode([JSONHeroDefinition].self, from: data)
            return decoded.map { $0.toStandard() }
        } catch {
            print("HeroRegistry: Failed to decode heroes: \(error)")
            return []
        }
    }
}

/// JSON-совместимое определение героя
struct JSONHeroDefinition: Codable {
    let id: String
    let name: String
    let heroClass: HeroClass
    let description: String
    let icon: String
    let startingDeckCardIDs: [String]
    let availability: HeroAvailability?

    func toStandard() -> StandardHeroDefinition {
        return StandardHeroDefinition(
            id: id,
            name: name,
            heroClass: heroClass,
            description: description,
            icon: icon,
            baseStats: heroClass.baseStats,
            specialAbility: .forHeroClass(heroClass),
            startingDeckCardIDs: startingDeckCardIDs,
            availability: availability ?? .alwaysAvailable
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

import Foundation

/// Протокол определения героя (Data Layer)
/// Описывает статические данные героя, которые не меняются во время игры
protocol HeroDefinition {
    /// Уникальный идентификатор
    var id: String { get }

    /// Локализованное имя
    var name: String { get }

    /// Класс героя
    var heroClass: HeroClass { get }

    /// Описание героя для UI
    var description: String { get }

    /// Иконка героя (SF Symbol или emoji)
    var icon: String { get }

    /// Базовые характеристики
    var baseStats: HeroStats { get }

    /// Особая способность героя
    var specialAbility: HeroAbility { get }

    /// Стартовая колода (ID карт)
    var startingDeckCardIDs: [String] { get }

    /// Доступность героя (для DLC/разблокировки)
    var availability: HeroAvailability { get }
}

/// Доступность героя
enum HeroAvailability: Codable, Equatable {
    case alwaysAvailable
    case requiresUnlock(condition: String)
    case dlc(packID: String)
}

/// Дефолтная реализация для базовых героев
struct StandardHeroDefinition: HeroDefinition, Codable {
    let id: String
    let name: String
    let heroClass: HeroClass
    let description: String
    let icon: String
    let baseStats: HeroStats
    let specialAbility: HeroAbility
    let startingDeckCardIDs: [String]
    let availability: HeroAvailability

    init(
        id: String,
        name: String,
        heroClass: HeroClass,
        description: String,
        icon: String,
        baseStats: HeroStats,
        specialAbility: HeroAbility,
        startingDeckCardIDs: [String] = [],
        availability: HeroAvailability = .alwaysAvailable
    ) {
        self.id = id
        self.name = name
        self.heroClass = heroClass
        self.description = description
        self.icon = icon
        self.baseStats = baseStats
        self.specialAbility = specialAbility
        self.startingDeckCardIDs = startingDeckCardIDs
        self.availability = availability
    }
}

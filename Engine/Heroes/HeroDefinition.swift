import Foundation

/// Структура с характеристиками героя
struct HeroStats: Codable, Equatable {
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
}

/// Протокол определения героя (Data Layer)
/// Описывает статические данные героя, которые не меняются во время игры
/// Герои загружаются из Content Pack - без хардкода классов
protocol HeroDefinition {
    /// Уникальный идентификатор (из JSON)
    var id: String { get }

    /// Локализованное имя
    var name: String { get }

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

/// Стандартная реализация определения героя
struct StandardHeroDefinition: HeroDefinition, Codable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let baseStats: HeroStats
    let specialAbility: HeroAbility
    let startingDeckCardIDs: [String]
    let availability: HeroAvailability

    init(
        id: String,
        name: String,
        description: String,
        icon: String,
        baseStats: HeroStats,
        specialAbility: HeroAbility,
        startingDeckCardIDs: [String] = [],
        availability: HeroAvailability = .alwaysAvailable
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.baseStats = baseStats
        self.specialAbility = specialAbility
        self.startingDeckCardIDs = startingDeckCardIDs
        self.availability = availability
    }
}

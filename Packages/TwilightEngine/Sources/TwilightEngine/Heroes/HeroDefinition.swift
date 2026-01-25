import Foundation

/// Structure with hero stats
public struct HeroStats: Codable, Equatable {
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

    public init(
        health: Int,
        maxHealth: Int,
        strength: Int,
        dexterity: Int,
        constitution: Int,
        intelligence: Int,
        wisdom: Int,
        charisma: Int,
        faith: Int,
        maxFaith: Int,
        startingBalance: Int
    ) {
        self.health = health
        self.maxHealth = maxHealth
        self.strength = strength
        self.dexterity = dexterity
        self.constitution = constitution
        self.intelligence = intelligence
        self.wisdom = wisdom
        self.charisma = charisma
        self.faith = faith
        self.maxFaith = maxFaith
        self.startingBalance = startingBalance
    }
}

/// Protocol for hero definition (Data Layer)
/// Describes static hero data that doesn't change during game
/// Heroes are loaded from Content Pack - no hardcoded classes
public protocol HeroDefinition {
    /// Unique identifier (from JSON)
    var id: String { get }

    /// Localized name (supports inline LocalizedString or StringKey)
    var name: LocalizableText { get }

    /// Hero description for UI (supports inline LocalizedString or StringKey)
    var description: LocalizableText { get }

    /// Hero icon (SF Symbol or emoji)
    var icon: String { get }

    /// Base stats
    var baseStats: HeroStats { get }

    /// Special ability
    var specialAbility: HeroAbility { get }

    /// Starting deck (card IDs)
    var startingDeckCardIDs: [String] { get }

    /// Hero availability (for DLC/unlock)
    var availability: HeroAvailability { get }
}

/// Hero availability
public enum HeroAvailability: Codable, Equatable {
    case alwaysAvailable
    case requiresUnlock(condition: String)
    case dlc(packID: String)
}

/// Standard hero definition implementation
public struct StandardHeroDefinition: HeroDefinition, Codable {
    public let id: String
    public let name: LocalizableText
    public let description: LocalizableText
    public let icon: String
    public let baseStats: HeroStats
    public let specialAbility: HeroAbility
    public let startingDeckCardIDs: [String]
    public let availability: HeroAvailability

    public init(
        id: String,
        name: LocalizableText,
        description: LocalizableText,
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

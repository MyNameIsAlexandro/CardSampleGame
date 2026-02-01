import Foundation

/// Hero class archetype — determines playstyle and card restrictions (FR-HRO-003)
public enum HeroClass: String, Codable, CaseIterable, Hashable {
    case warrior
    case mage
    case ranger
    case priest
    case shadow
    case alchemist
    case bard
    case monk
}

/// Structure with hero stats
public struct HeroStats: Codable, Equatable {
    public var health: Int
    public var maxHealth: Int
    public var strength: Int
    public var dexterity: Int
    public var constitution: Int
    public var intelligence: Int
    public var wisdom: Int
    public var charisma: Int
    public var faith: Int
    public var maxFaith: Int
    public var startingBalance: Int

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

    /// Hero class archetype
    var heroClass: HeroClass { get }

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
    public var id: String
    public var heroClass: HeroClass
    public var name: LocalizableText
    public var description: LocalizableText
    public var icon: String
    public var baseStats: HeroStats
    public var specialAbility: HeroAbility
    public var startingDeckCardIDs: [String]
    public var availability: HeroAvailability

    public init(
        id: String,
        heroClass: HeroClass,
        name: LocalizableText,
        description: LocalizableText,
        icon: String,
        baseStats: HeroStats,
        specialAbility: HeroAbility,
        startingDeckCardIDs: [String] = [],
        availability: HeroAvailability = .alwaysAvailable
    ) {
        self.id = id
        self.heroClass = heroClass
        self.name = name
        self.description = description
        self.icon = icon
        self.baseStats = baseStats
        self.specialAbility = specialAbility
        self.startingDeckCardIDs = startingDeckCardIDs
        self.availability = availability
    }

    // Custom Codable: backward-compatible with packs that lack heroClass
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(LocalizableText.self, forKey: .name)
        description = try c.decode(LocalizableText.self, forKey: .description)
        icon = try c.decode(String.self, forKey: .icon)
        baseStats = try c.decode(HeroStats.self, forKey: .baseStats)
        specialAbility = try c.decode(HeroAbility.self, forKey: .specialAbility)
        startingDeckCardIDs = try c.decode([String].self, forKey: .startingDeckCardIDs)
        availability = try c.decode(HeroAvailability.self, forKey: .availability)

        if let decoded = try c.decodeIfPresent(HeroClass.self, forKey: .heroClass) {
            heroClass = decoded
        } else {
            // Infer from ID prefix for legacy packs
            let prefix = id.split(separator: "_").first.map(String.init) ?? ""
            heroClass = HeroClass(rawValue: prefix) ?? .warrior
        }
    }
}

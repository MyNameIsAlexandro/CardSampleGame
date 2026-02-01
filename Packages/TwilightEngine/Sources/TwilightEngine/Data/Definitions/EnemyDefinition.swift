import Foundation

// MARK: - Enemy Definition
// Reference: Docs/ENGINE_ARCHITECTURE.md, Section 4.1
// Data-driven enemy definitions for combat events

/// Immutable definition of an enemy.
/// Used to create monster cards for combat events.
public struct EnemyDefinition: GameDefinition {
    // MARK: - Identity

    /// Unique enemy identifier (defined in content pack)
    public var id: String

    // MARK: - Localized Content

    /// Enemy name (supports inline LocalizedString or StringKey)
    public var name: LocalizableText

    /// Enemy description (supports inline LocalizedString or StringKey)
    public var description: LocalizableText

    // MARK: - Stats

    /// Base health points
    public var health: Int

    /// Base attack power
    public var power: Int

    /// Base defense
    public var defense: Int

    /// Difficulty rating (1-5, affects scaling)
    public var difficulty: Int

    // MARK: - Classification

    /// Enemy type classification
    public var enemyType: EnemyType

    /// Card rarity for loot/display
    public var rarity: CardRarity

    // MARK: - Spirit

    /// Spirit/Resolve stat (optional — not all enemies have Will)
    public var will: Int?

    /// Per-zone stat modifiers keyed by ResonanceZone raw value
    public var resonanceBehavior: [String: EnemyModifier]?

    // MARK: - Abilities

    /// Special abilities this enemy has
    public var abilities: [EnemyAbility]

    // MARK: - Loot & Rewards

    /// Cards that can drop when defeated
    public var lootCardIds: [String]

    /// Faith reward when defeated
    public var faithReward: Int

    /// Balance change when defeated
    public var balanceDelta: Int

    // MARK: - Bestiary Content (Epic 13)

    /// Lore flavor text (Witcher-style scholar quote)
    public var lore: LocalizableText?

    /// Tactical recommendation for Nav faction
    public var tacticsNav: LocalizableText?

    /// Tactical recommendation for Yav faction
    public var tacticsYav: LocalizableText?

    /// Tactical recommendation for Prav faction
    public var tacticsPrav: LocalizableText?

    /// Keyword vulnerabilities (e.g. ["fire", "silver"])
    public var weaknesses: [String]?

    /// Keyword resistances
    public var strengths: [String]?

    /// Repeating behavior pattern. If set, the enemy cycles through these
    /// intents instead of using random generation.
    public var pattern: [EnemyPatternStep]?

    // Note: No explicit CodingKeys needed - JSONDecoder uses .convertFromSnakeCase
    // which automatically converts enemy_type → enemyType, faith_reward → faithReward, etc.

    // MARK: - Initialization

    public init(
        id: String,
        name: LocalizableText,
        description: LocalizableText,
        health: Int,
        power: Int,
        defense: Int,
        difficulty: Int = 1,
        enemyType: EnemyType = .beast,
        rarity: CardRarity = .common,
        will: Int? = nil,
        resonanceBehavior: [String: EnemyModifier]? = nil,
        abilities: [EnemyAbility] = [],
        lootCardIds: [String] = [],
        faithReward: Int = 0,
        balanceDelta: Int = 0,
        lore: LocalizableText? = nil,
        tacticsNav: LocalizableText? = nil,
        tacticsYav: LocalizableText? = nil,
        tacticsPrav: LocalizableText? = nil,
        weaknesses: [String]? = nil,
        strengths: [String]? = nil,
        pattern: [EnemyPatternStep]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.health = health
        self.power = power
        self.defense = defense
        self.difficulty = difficulty
        self.enemyType = enemyType
        self.rarity = rarity
        self.will = will
        self.resonanceBehavior = resonanceBehavior
        self.abilities = abilities
        self.lootCardIds = lootCardIds
        self.faithReward = faithReward
        self.balanceDelta = balanceDelta
        self.lore = lore
        self.tacticsNav = tacticsNav
        self.tacticsYav = tacticsYav
        self.tacticsPrav = tacticsPrav
        self.weaknesses = weaknesses
        self.strengths = strengths
        self.pattern = pattern
    }

    /// Convert to legacy Card (monster type) for UI compatibility
    public func toCard() -> Card {
        return Card(
            id: id,
            name: name.resolved,
            type: .monster,
            rarity: rarity,
            description: description.resolved,
            power: power,
            defense: defense,
            health: health,
            will: will
        )
    }
}

// MARK: - Enemy Modifier (Resonance-based)

/// Stat modifier applied to an enemy based on the current ResonanceZone
public struct EnemyModifier: Codable, Equatable, Hashable {
    public var powerDelta: Int
    public var defenseDelta: Int
    public var healthDelta: Int
    public var willDelta: Int

    public init(powerDelta: Int = 0, defenseDelta: Int = 0, healthDelta: Int = 0, willDelta: Int = 0) {
        self.powerDelta = powerDelta
        self.defenseDelta = defenseDelta
        self.healthDelta = healthDelta
        self.willDelta = willDelta
    }
}

// MARK: - Enemy Type

public enum EnemyType: String, Codable, Hashable {
    case beast       // Wild animals
    case spirit      // Forest spirits, leshy
    case undead      // Risen dead, ghosts
    case demon       // Navi creatures
    case human       // Bandits, cultists
    case boss        // Major enemies
}

// MARK: - Enemy Ability

public struct EnemyAbility: Codable, Hashable, Identifiable {
    public var id: String
    public var name: LocalizableText
    public var description: LocalizableText
    public var effect: EnemyAbilityEffect

    public init(
        id: String,
        name: LocalizableText,
        description: LocalizableText,
        effect: EnemyAbilityEffect
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.effect = effect
    }
}

public enum EnemyAbilityEffect: Codable, Hashable {
    /// Deal extra damage
    case bonusDamage(Int)

    /// Heal each turn
    case regeneration(Int)

    /// Reduce incoming damage
    case armor(Int)

    /// First strike - attacks before player
    case firstStrike

    /// Cannot be targeted by spells
    case spellImmune

    /// Applies curse on hit
    case applyCurse(String)

    /// Custom effect by ID
    case custom(String)

    // MARK: - Custom Codable for JSON compatibility
    // Note: No explicit snake_case mappings - JSONDecoder uses .convertFromSnakeCase
    // which automatically converts bonus_damage → bonusDamage, etc.

    enum CodingKeys: String, CodingKey {
        case bonusDamage
        case regeneration
        case armor
        case firstStrike
        case spellImmune
        case applyCurse
        case custom
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let value = try container.decodeIfPresent(Int.self, forKey: .bonusDamage) {
            self = .bonusDamage(value)
        } else if let value = try container.decodeIfPresent(Int.self, forKey: .regeneration) {
            self = .regeneration(value)
        } else if let value = try container.decodeIfPresent(Int.self, forKey: .armor) {
            self = .armor(value)
        } else if (try? container.decodeIfPresent(Bool.self, forKey: .firstStrike)) == true {
            self = .firstStrike
        } else if (try? container.decodeIfPresent(Bool.self, forKey: .spellImmune)) == true {
            self = .spellImmune
        } else if let value = try container.decodeIfPresent(String.self, forKey: .applyCurse) {
            self = .applyCurse(value)
        } else if let value = try container.decodeIfPresent(String.self, forKey: .custom) {
            self = .custom(value)
        } else {
            // Default to custom with empty string if no recognized key
            self = .custom("unknown")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .bonusDamage(let value):
            try container.encode(value, forKey: .bonusDamage)
        case .regeneration(let value):
            try container.encode(value, forKey: .regeneration)
        case .armor(let value):
            try container.encode(value, forKey: .armor)
        case .firstStrike:
            try container.encode(true, forKey: .firstStrike)
        case .spellImmune:
            try container.encode(true, forKey: .spellImmune)
        case .applyCurse(let value):
            try container.encode(value, forKey: .applyCurse)
        case .custom(let value):
            try container.encode(value, forKey: .custom)
        }
    }
}

// MARK: - Enemy Pattern Step

/// A single step in a repeating enemy behavior pattern.
public struct EnemyPatternStep: Codable, Equatable, Hashable {
    public var type: IntentType
    public var value: Int

    public init(type: IntentType, value: Int = 0) {
        self.type = type
        self.value = value
    }
}


import Foundation

// MARK: - Enemy Definition
// Reference: Docs/ENGINE_ARCHITECTURE.md, Section 4.1
// Data-driven enemy definitions for combat events

/// Immutable definition of an enemy.
/// Used to create monster cards for combat events.
public struct EnemyDefinition: GameDefinition {
    // MARK: - Identity

    /// Unique enemy identifier (e.g., "leshy", "wild_beast")
    public let id: String

    // MARK: - Localized Content

    /// Enemy name (supports inline LocalizedString or StringKey)
    public let name: LocalizableText

    /// Enemy description (supports inline LocalizedString or StringKey)
    public let description: LocalizableText

    // MARK: - Stats

    /// Base health points
    public let health: Int

    /// Base attack power
    public let power: Int

    /// Base defense
    public let defense: Int

    /// Difficulty rating (1-5, affects scaling)
    public let difficulty: Int

    // MARK: - Classification

    /// Enemy type classification
    public let enemyType: EnemyType

    /// Card rarity for loot/display
    public let rarity: CardRarity

    // MARK: - Abilities

    /// Special abilities this enemy has
    public let abilities: [EnemyAbility]

    // MARK: - Loot & Rewards

    /// Cards that can drop when defeated
    public let lootCardIds: [String]

    /// Faith reward when defeated
    public let faithReward: Int

    /// Balance change when defeated
    public let balanceDelta: Int

    // Note: No explicit CodingKeys needed - PackLoader uses .convertFromSnakeCase
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
        abilities: [EnemyAbility] = [],
        lootCardIds: [String] = [],
        faithReward: Int = 0,
        balanceDelta: Int = 0
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
        self.abilities = abilities
        self.lootCardIds = lootCardIds
        self.faithReward = faithReward
        self.balanceDelta = balanceDelta
    }

    /// Convert to legacy Card (monster type) for UI compatibility
    public func toCard() -> Card {
        return Card(
            id: UUID(uuidString: id.md5UUID) ?? UUID(),
            definitionId: id,  // Content Pack ID for tracking
            name: name.resolved,
            type: .monster,
            rarity: rarity,
            description: description.resolved,
            power: power,
            defense: defense,
            health: health
        )
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
    public let id: String
    public let name: LocalizableText
    public let description: LocalizableText
    public let effect: EnemyAbilityEffect

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
    // Note: No explicit snake_case mappings - PackLoader uses .convertFromSnakeCase
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

// MARK: - String UUID Extension (reuse pattern)

private extension String {
    var md5UUID: String {
        var hash: UInt64 = 5381
        for char in self.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(char)
        }
        let hex = String(format: "%016llX", hash)
        let padded = hex.padding(toLength: 32, withPad: "0", startingAt: 0)
        let chars = Array(padded)
        return "\(String(chars[0..<8]))-\(String(chars[8..<12]))-\(String(chars[12..<16]))-\(String(chars[16..<20]))-\(String(chars[20..<32]))"
    }
}

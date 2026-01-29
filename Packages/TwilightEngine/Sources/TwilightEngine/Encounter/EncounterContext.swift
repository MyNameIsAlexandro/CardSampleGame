import Foundation

/// Input context for an encounter — immutable snapshot of world state
public struct EncounterContext: Equatable {
    public let hero: EncounterHero
    public let enemies: [EncounterEnemy]
    public let fateDeckSnapshot: FateDeckState
    public let modifiers: [EncounterModifier]
    public let rules: EncounterRules
    public let rngSeed: UInt64
    public let rngState: UInt64?
    public let worldResonance: Float

    public init(hero: EncounterHero, enemies: [EncounterEnemy], fateDeckSnapshot: FateDeckState, modifiers: [EncounterModifier], rules: EncounterRules, rngSeed: UInt64, rngState: UInt64? = nil, worldResonance: Float = 0) {
        self.hero = hero
        self.enemies = enemies
        self.fateDeckSnapshot = fateDeckSnapshot
        self.modifiers = modifiers
        self.rules = rules
        self.rngSeed = rngSeed
        self.rngState = rngState
        self.worldResonance = worldResonance
    }
}

/// Hero stats snapshot for encounter
public struct EncounterHero: Equatable {
    public let id: String
    public let hp: Int
    public let maxHp: Int
    public let strength: Int
    public let armor: Int
    public let wisdom: Int
    public let willDefense: Int
    public let hand: [String] // card IDs

    public init(id: String, hp: Int, maxHp: Int, strength: Int, armor: Int, wisdom: Int = 0, willDefense: Int = 0, hand: [String] = []) {
        self.id = id
        self.hp = hp
        self.maxHp = maxHp
        self.strength = strength
        self.armor = armor
        self.wisdom = wisdom
        self.willDefense = willDefense
        self.hand = hand
    }
}

/// Enemy snapshot for encounter (dual-track: HP + WP)
public struct EncounterEnemy: Equatable {
    public let id: String
    public let name: String
    public let hp: Int
    public let maxHp: Int
    public let wp: Int?       // nil = no spirit track
    public let maxWp: Int?
    public let power: Int
    public let defense: Int
    public let behaviorId: String?

    public init(id: String, name: String, hp: Int, maxHp: Int, wp: Int? = nil, maxWp: Int? = nil, power: Int = 0, defense: Int = 0, behaviorId: String? = nil) {
        self.id = id
        self.name = name
        self.hp = hp
        self.maxHp = maxHp
        self.wp = wp
        self.maxWp = maxWp
        self.power = power
        self.defense = defense
        self.behaviorId = behaviorId
    }
}

/// Encounter-specific modifiers (environment, curses, etc.)
public struct EncounterModifier: Equatable {
    public let id: String
    public let type: String
    public let value: Double
    public let source: String

    public init(id: String, type: String, value: Double, source: String) {
        self.id = id
        self.type = type
        self.value = value
        self.source = source
    }
}

/// Rules governing the encounter
public struct EncounterRules: Equatable {
    public let maxRounds: Int?
    public let canFlee: Bool
    public let customVictory: String?  // e.g. "survive(5)"

    public init(maxRounds: Int? = nil, canFlee: Bool = true, customVictory: String? = nil) {
        self.maxRounds = maxRounds
        self.canFlee = canFlee
        self.customVictory = customVictory
    }
}

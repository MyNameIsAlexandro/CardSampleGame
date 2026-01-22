import Foundation

// MARK: - Twilight Marches Configuration
// Game-specific configuration for "Сумрачные Пределы" (Twilight Marches)
// This is the "cartridge" that configures the generic engine.

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Resources
// ═══════════════════════════════════════════════════════════════════════════════

/// Resources used in Twilight Marches
enum TwilightResource: String, CaseIterable {
    case health
    case maxHealth
    case faith
    case maxFaith
    case balance  // 0 = Dark, 100 = Light

    var id: String { rawValue }

    /// Default starting values
    var defaultValue: Int {
        switch self {
        case .health: return 10
        case .maxHealth: return 10
        case .faith: return 3
        case .maxFaith: return 10
        case .balance: return 50
        }
    }
}

/// Build initial resources dictionary
func twilightInitialResources() -> [String: Int] {
    var resources: [String: Int] = [:]
    for resource in TwilightResource.allCases {
        resources[resource.id] = resource.defaultValue
    }
    return resources
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Pressure Rules (WorldTension)
// ═══════════════════════════════════════════════════════════════════════════════

/// Twilight Marches pressure (WorldTension) rules
/// SINGLE SOURCE OF TRUTH for tension escalation formula (Audit v1.1 Issue #6)
struct TwilightPressureRules: PressureRuleSet {
    let maxPressure: Int = 100
    let initialPressure: Int = 30
    let escalationInterval: Int = 3  // Every 3 days
    let escalationAmount: Int = 3    // Base +3 tension (increased for balance)

    /// Thresholds and their effects
    var thresholds: [Int: [WorldEffect]] {
        return [
            50: [.regionDegradation(probability: 0.3)],
            75: [.regionDegradation(probability: 0.5), .globalEvent(eventId: "world_shift_warning")],
            90: [.regionDegradation(probability: 0.7), .anchorWeakening(amount: 10)]
        ]
    }

    /// Canonical escalation formula: base + (daysPassed / 10)
    /// - Day 1-9: +3
    /// - Day 10-19: +4
    /// - Day 20-29: +5
    /// Creates increasing urgency as game progresses
    func calculateEscalation(currentPressure: Int, currentTime: Int) -> Int {
        let escalationBonus = currentTime / 10
        return escalationAmount + escalationBonus
    }

    /// Static helper for use outside of PressureEngine context
    /// Both WorldState and TwilightGameEngine should use this
    static func calculateTensionIncrease(daysPassed: Int) -> Int {
        let base = 3  // escalationAmount
        let escalationBonus = daysPassed / 10
        return base + escalationBonus
    }

    func checkThresholds(pressure: Int) -> [WorldEffect] {
        var effects: [WorldEffect] = []

        for (threshold, thresholdEffects) in thresholds {
            if pressure >= threshold {
                effects.append(contentsOf: thresholdEffects)
            }
        }

        return effects
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Region Configuration
// ═══════════════════════════════════════════════════════════════════════════════

/// Region states in Twilight Marches
enum TwilightRegionState: String, Codable, CaseIterable {
    case stable
    case borderland
    case breach

    /// Degradation weight (higher = degrades faster)
    var degradationWeight: Int {
        switch self {
        case .stable: return 0
        case .borderland: return 1
        case .breach: return 2
        }
    }

    /// Can player rest in this state?
    var canRest: Bool {
        self == .stable
    }

    /// Can player trade in this state?
    var canTrade: Bool {
        self == .stable
    }

    /// Combat modifier
    var combatModifier: Int {
        switch self {
        case .stable: return 0
        case .borderland: return 1
        case .breach: return 2
        }
    }

    /// Next degraded state
    var degraded: TwilightRegionState? {
        switch self {
        case .stable: return .borderland
        case .borderland: return .breach
        case .breach: return nil
        }
    }

    /// Previous improved state
    var improved: TwilightRegionState? {
        switch self {
        case .stable: return nil
        case .borderland: return .stable
        case .breach: return .borderland
        }
    }
}

/// Region type
enum TwilightRegionType: String, Codable, CaseIterable {
    case village
    case forest
    case fortress
    case swamp
    case ruins
    case sanctuary
    case cursedLand
}

/// Region definition (static data)
struct TwilightRegionDefinition: Codable {
    let id: String
    let name: String
    let type: TwilightRegionType
    let initialState: TwilightRegionState
    let neighborIds: [String]
    let hasAnchor: Bool
    let anchorName: String?

    /// Initial anchor integrity (if has anchor)
    var initialAnchorIntegrity: Int { hasAnchor ? 100 : 0 }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Curse Configuration
// ═══════════════════════════════════════════════════════════════════════════════

/// Curse types in Twilight Marches
enum TwilightCurseType: String, Codable, CaseIterable {
    case weakness
    case fear
    case exhaustion
    case greed
    case shadowOfNav
    case bloodCurse
    case sealOfNav
}

/// Curse definition (static data)
struct TwilightCurseDefinition {
    let type: TwilightCurseType
    let name: String
    let description: String
    let removalCost: Int
    let damageModifier: Int      // Modifier to damage dealt
    let damageTakenModifier: Int // Modifier to damage received
    let actionModifier: Int      // Modifier to actions per turn
    let specialEffect: String?   // ID of special effect

    static let definitions: [TwilightCurseType: TwilightCurseDefinition] = [
        .weakness: TwilightCurseDefinition(
            type: .weakness,
            name: L10n.curseWeaknessName.localized,
            description: L10n.curseWeaknessDescription.localized,
            removalCost: 2,
            damageModifier: -1,
            damageTakenModifier: 0,
            actionModifier: 0,
            specialEffect: nil
        ),
        .fear: TwilightCurseDefinition(
            type: .fear,
            name: L10n.curseFearName.localized,
            description: L10n.curseFearDescription.localized,
            removalCost: 2,
            damageModifier: 0,
            damageTakenModifier: 1,
            actionModifier: 0,
            specialEffect: nil
        ),
        .exhaustion: TwilightCurseDefinition(
            type: .exhaustion,
            name: L10n.curseExhaustionName.localized,
            description: L10n.curseExhaustionDescription.localized,
            removalCost: 3,
            damageModifier: 0,
            damageTakenModifier: 0,
            actionModifier: -1,
            specialEffect: nil
        ),
        .greed: TwilightCurseDefinition(
            type: .greed,
            name: L10n.curseGreedName.localized,
            description: L10n.curseGreedDescription.localized,
            removalCost: 4,
            damageModifier: 0,
            damageTakenModifier: 0,
            actionModifier: 0,
            specialEffect: "balance_shift_dark"
        ),
        .shadowOfNav: TwilightCurseDefinition(
            type: .shadowOfNav,
            name: L10n.curseShadowOfNavName.localized,
            description: L10n.curseShadowOfNavDescription.localized,
            removalCost: 5,
            damageModifier: 3,
            damageTakenModifier: 0,
            actionModifier: 0,
            specialEffect: "balance_shift_dark_on_combat"
        ),
        .bloodCurse: TwilightCurseDefinition(
            type: .bloodCurse,
            name: L10n.curseBloodCurseName.localized,
            description: L10n.curseBloodCurseDescription.localized,
            removalCost: 6,
            damageModifier: 0,
            damageTakenModifier: 0,
            actionModifier: 0,
            specialEffect: "heal_on_kill_dark"
        ),
        .sealOfNav: TwilightCurseDefinition(
            type: .sealOfNav,
            name: L10n.curseSealOfNavName.localized,
            description: L10n.curseSealOfNavDescription.localized,
            removalCost: 8,
            damageModifier: 0,
            damageTakenModifier: 0,
            actionModifier: 0,
            specialEffect: "block_sustain_cards"
        )
    ]

    static func get(_ type: TwilightCurseType) -> TwilightCurseDefinition? {
        return definitions[type]
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Balance (Light/Dark) Configuration
// ═══════════════════════════════════════════════════════════════════════════════

/// Balance state classification
enum TwilightBalanceState: String {
    case light
    case neutral
    case dark

    static func classify(balance: Int) -> TwilightBalanceState {
        if balance >= 70 { return .light }
        if balance <= 30 { return .dark }
        return .neutral
    }
}

/// Balance thresholds
struct TwilightBalanceConfig {
    static let min = 0
    static let max = 100
    static let initial = 50
    static let lightThreshold = 70
    static let darkThreshold = 30
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Combat Configuration
// ═══════════════════════════════════════════════════════════════════════════════

/// Combat configuration for Twilight Marches
struct TwilightCombatConfig {
    /// Dice type (e.g., d6)
    static let diceMax = 6

    /// Base damage bonus
    static let baseDamageBonus = 2

    /// Actions per combat turn
    static let actionsPerTurn = 3

    /// Cards drawn at turn start
    static let cardsDrawnPerTurn = 5

    /// Maximum hand size
    static let maxHandSize = 7

    /// Calculate damage: playerPower + diceRoll - enemyDefense + bonus
    static func calculateDamage(
        playerPower: Int,
        diceRoll: Int,
        enemyDefense: Int,
        curseModifier: Int,
        regionModifier: Int
    ) -> Int {
        let baseDamage = playerPower + diceRoll - enemyDefense + baseDamageBonus
        let modifiedDamage = baseDamage + curseModifier
        return max(1, modifiedDamage) // Minimum 1 damage
    }

    /// Roll dice (deterministic via WorldRNG)
    static func rollDice() -> Int {
        return WorldRNG.shared.nextInt(in: 1...diceMax)
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Anchor Configuration
// ═══════════════════════════════════════════════════════════════════════════════

/// Anchor integrity thresholds
struct TwilightAnchorConfig {
    static let maxIntegrity = 100
    static let stableThreshold = 70   // Above = region stable
    static let breachThreshold = 30   // Below = region breach

    static let strengthenAmount = 20
    static let degradeAmount = 20

    /// Determine region state based on anchor integrity
    static func regionStateForIntegrity(_ integrity: Int) -> TwilightRegionState {
        if integrity >= stableThreshold { return .stable }
        if integrity > breachThreshold { return .borderland }
        return .breach
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Time Configuration
// ═══════════════════════════════════════════════════════════════════════════════

/// Time-related configuration
struct TwilightTimeConfig {
    /// Days for tension increase
    static let tensionIncreaseInterval = 3

    /// Tension increase amount (increased from 2 to 3 for balance)
    static let tensionIncreaseAmount = 3

    /// Travel costs
    static let neighborTravelCost = 1
    static let distantTravelCost = 2

    /// Action costs
    static let restCost = 1
    static let strengthenAnchorCost = 1
    static let exploreCost = 1
    static let instantCost = 0
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Victory/Defeat Conditions
// ═══════════════════════════════════════════════════════════════════════════════

/// Victory conditions for Twilight Marches
struct TwilightVictoryConfig {
    /// Main quest completion flag
    static let mainQuestCompleteFlag = "act5_completed"

    /// Main quest final stage
    static let mainQuestFinalStage = 5
}

/// Defeat conditions for Twilight Marches
struct TwilightDefeatConfig {
    /// Health defeat threshold
    static let healthDefeatThreshold = 0

    /// Tension defeat threshold
    static let tensionDefeatThreshold = 100

    /// Critical anchor destruction flag
    static let criticalAnchorDestroyedFlag = "critical_anchor_destroyed"
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Factory
// ═══════════════════════════════════════════════════════════════════════════════

/// Factory for creating Twilight Marches game components
enum TwilightMarchesFactory {
    /// Create pressure rules
    static func createPressureRules() -> TwilightPressureRules {
        return TwilightPressureRules()
    }

    /// Create initial player resources
    static func createInitialResources() -> [String: Int] {
        return twilightInitialResources()
    }

    /// Create resource caps
    static func createResourceCaps() -> [String: Int] {
        return [
            TwilightResource.health.id: TwilightResource.maxHealth.defaultValue,
            TwilightResource.faith.id: TwilightResource.maxFaith.defaultValue,
            TwilightResource.balance.id: TwilightBalanceConfig.max
        ]
    }
}

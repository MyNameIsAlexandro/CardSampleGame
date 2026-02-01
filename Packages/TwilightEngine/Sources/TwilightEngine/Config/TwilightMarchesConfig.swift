import Foundation

// MARK: - Twilight Marches Configuration
// Game-specific configuration for "Сумрачные Пределы" (Twilight Marches)
// This is the "cartridge" that configures the generic engine.

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Resources
// ═══════════════════════════════════════════════════════════════════════════════

/// Resources used in Twilight Marches
public enum TwilightResource: String, CaseIterable {
    case health
    case maxHealth
    case faith
    case maxFaith
    case balance  // 0 = Dark, 100 = Light

    public var id: String { rawValue }

    /// Default starting values (synced with balance.json resources)
    public var defaultValue: Int {
        switch self {
        case .health: return 20
        case .maxHealth: return 30
        case .faith: return 8
        case .maxFaith: return 20
        case .balance: return 50
        }
    }
}

/// Build initial resources dictionary
public func twilightInitialResources() -> [String: Int] {
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
/// Reads from BalanceConfiguration (balance.json) as single source of truth
public struct TwilightPressureRules: PressureRuleSet {
    public let maxPressure: Int
    public let initialPressure: Int
    public let escalationInterval: Int
    public let escalationAmount: Int

    private let warningThreshold: Int
    private let criticalThreshold: Int
    private let catastrophicThreshold: Int
    private let warningDegradation: Double
    private let criticalDegradation: Double
    private let catastrophicDegradation: Double

    public init(from config: PressureBalanceConfig? = nil) {
        let c = config ?? .default
        maxPressure = c.maxPressure
        initialPressure = c.startingPressure
        escalationInterval = c.effectiveTickInterval
        escalationAmount = c.pressurePerTurn
        warningThreshold = c.thresholds.warning
        criticalThreshold = c.thresholds.critical
        catastrophicThreshold = c.thresholds.catastrophic
        warningDegradation = c.degradation.warningChance
        criticalDegradation = c.degradation.criticalChance
        catastrophicDegradation = c.degradation.catastrophicChance ?? 0.5
    }

    /// Thresholds and their effects (driven by balance.json)
    public var thresholds: [Int: [WorldEffect]] {
        return [
            warningThreshold: [.regionDegradation(probability: warningDegradation)],
            criticalThreshold: [.regionDegradation(probability: criticalDegradation), .globalEvent(eventId: "world_shift_warning")],
            catastrophicThreshold: [.regionDegradation(probability: catastrophicDegradation), .anchorWeakening(amount: 10)]
        ]
    }

    /// Canonical escalation formula: base + (daysPassed / 10)
    public func calculateEscalation(currentPressure: Int, currentTime: Int) -> Int {
        let escalationBonus = currentTime / 10
        return escalationAmount + escalationBonus
    }

    /// Static helper for use outside of PressureEngine context
    public static func calculateTensionIncrease(daysPassed: Int, base: Int = PressureBalanceConfig.default.pressurePerTurn) -> Int {
        let escalationBonus = daysPassed / 10
        return base + escalationBonus
    }

    public func checkThresholds(pressure: Int) -> [WorldEffect] {
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
public enum TwilightRegionState: String, Codable, CaseIterable {
    case stable
    case borderland
    case breach

    /// Degradation weight (higher = degrades faster)
    public var degradationWeight: Int {
        switch self {
        case .stable: return 0
        case .borderland: return 1
        case .breach: return 2
        }
    }

    /// Can player rest in this state?
    public var canRest: Bool {
        self == .stable
    }

    /// Can player trade in this state?
    public var canTrade: Bool {
        self == .stable
    }

    /// Combat modifier
    public var combatModifier: Int {
        switch self {
        case .stable: return 0
        case .borderland: return 1
        case .breach: return 2
        }
    }

    /// Next degraded state
    public var degraded: TwilightRegionState? {
        switch self {
        case .stable: return .borderland
        case .borderland: return .breach
        case .breach: return nil
        }
    }

    /// Previous improved state
    public var improved: TwilightRegionState? {
        switch self {
        case .stable: return nil
        case .borderland: return .stable
        case .breach: return .borderland
        }
    }
}

/// Region type
public enum TwilightRegionType: String, Codable, CaseIterable {
    case village
    case forest
    case fortress
    case swamp
    case ruins
    case sanctuary
    case cursedLand
}

/// Region definition (static data)
public struct TwilightRegionDefinition: Codable {
    public let id: String
    public let name: String
    public let type: TwilightRegionType
    public let initialState: TwilightRegionState
    public let neighborIds: [String]
    public let hasAnchor: Bool
    public let anchorName: String?

    /// Initial anchor integrity (if has anchor)
    public var initialAnchorIntegrity: Int { hasAnchor ? 100 : 0 }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Curse Configuration
// ═══════════════════════════════════════════════════════════════════════════════

/// Curse types in Twilight Marches
public enum TwilightCurseType: String, Codable, CaseIterable {
    case weakness
    case fear
    case exhaustion
    case greed
    case shadowOfNav
    case bloodCurse
    case sealOfNav
}

/// Curse definition (static data)
public struct TwilightCurseDefinition {
    public let type: TwilightCurseType
    public let name: String
    public let description: String
    public let removalCost: Int
    public let damageModifier: Int      // Modifier to damage dealt
    public let damageTakenModifier: Int // Modifier to damage received
    public let actionModifier: Int      // Modifier to actions per turn
    public let specialEffect: String?   // ID of special effect

    public static let definitions: [TwilightCurseType: TwilightCurseDefinition] = [
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

    public static func get(_ type: TwilightCurseType) -> TwilightCurseDefinition? {
        return definitions[type]
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Balance (Light/Dark) Configuration
// ═══════════════════════════════════════════════════════════════════════════════

/// Balance state classification
public enum TwilightBalanceState: String {
    case light
    case neutral
    case dark

    public static func classify(balance: Int) -> TwilightBalanceState {
        if balance >= 70 { return .light }
        if balance <= 30 { return .dark }
        return .neutral
    }
}

/// Balance thresholds — reads from BalanceConfiguration
public struct TwilightBalanceConfig {
    private static var config: BalanceSystemConfig { ContentRegistry.shared.getBalanceConfig()?.balanceSystem ?? .default }
    public static var min: Int { config.min }
    public static var max: Int { config.max }
    public static var initial: Int { config.initial }
    public static var lightThreshold: Int { config.lightThreshold }
    public static var darkThreshold: Int { config.darkThreshold }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Combat Configuration
// ═══════════════════════════════════════════════════════════════════════════════

/// Combat configuration — reads from BalanceConfiguration
public struct TwilightCombatConfig {
    private static var config: CombatBalanceConfig { ContentRegistry.shared.getBalanceConfig()?.combat ?? .default }
    public static var diceMax: Int { config.diceMax ?? 6 }
    public static var baseDamageBonus: Int { config.baseDamage }
    public static var actionsPerTurn: Int { config.actionsPerTurn ?? 3 }
    public static var cardsDrawnPerTurn: Int { config.cardsDrawnPerTurn ?? 5 }
    public static var maxHandSize: Int { config.maxHandSize ?? 7 }

    /// Calculate damage: playerPower + diceRoll - enemyDefense + bonus
    public static func calculateDamage(
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
    public static func rollDice() -> Int {
        return WorldRNG.shared.nextInt(in: 1...diceMax)
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Anchor Configuration
// ═══════════════════════════════════════════════════════════════════════════════

/// Anchor integrity thresholds — reads from BalanceConfiguration
public struct TwilightAnchorConfig {
    private static var config: AnchorBalanceConfig { ContentRegistry.shared.getBalanceConfig()?.anchor ?? .default }
    public static var maxIntegrity: Int { config.maxIntegrity }
    public static var stableThreshold: Int { config.stableThreshold }
    public static var breachThreshold: Int { config.breachThreshold }
    public static var strengthenAmount: Int { config.strengthenAmount }
    public static var degradeAmount: Int { config.degradationAmount ?? 20 }

    /// Determine region state based on anchor integrity
    public static func regionStateForIntegrity(_ integrity: Int) -> TwilightRegionState {
        if integrity >= stableThreshold { return .stable }
        if integrity > breachThreshold { return .borderland }
        return .breach
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Time Configuration
// ═══════════════════════════════════════════════════════════════════════════════

/// Time-related configuration — reads from BalanceConfiguration
public struct TwilightTimeConfig {
    private static var timeConfig: TimeBalanceConfig { ContentRegistry.shared.getBalanceConfig()?.time ?? .default }
    private static var pressureConfig: PressureBalanceConfig { ContentRegistry.shared.getBalanceConfig()?.pressure ?? .default }

    public static var tensionIncreaseInterval: Int { pressureConfig.effectiveTickInterval }
    public static var tensionIncreaseAmount: Int { pressureConfig.pressurePerTurn }
    public static var neighborTravelCost: Int { timeConfig.travelCost }
    public static var distantTravelCost: Int { timeConfig.travelCost * 2 }
    public static var restCost: Int { timeConfig.restCost }
    public static var strengthenAnchorCost: Int { timeConfig.strengthenAnchorCost ?? 1 }
    public static var exploreCost: Int { timeConfig.exploreCost }
    public static var instantCost: Int { timeConfig.instantCost ?? 0 }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Victory/Defeat Conditions
// ═══════════════════════════════════════════════════════════════════════════════

/// Victory conditions for Twilight Marches
public struct TwilightVictoryConfig {
    /// Main quest completion flag
    public static let mainQuestCompleteFlag = "act5_completed"

    /// Main quest final stage
    public static let mainQuestFinalStage = 5
}

/// Defeat conditions for Twilight Marches
public struct TwilightDefeatConfig {
    /// Health defeat threshold
    public static let healthDefeatThreshold = 0

    /// Tension defeat threshold
    public static let tensionDefeatThreshold = 100

    /// Critical anchor destruction flag
    public static let criticalAnchorDestroyedFlag = "critical_anchor_destroyed"
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Factory
// ═══════════════════════════════════════════════════════════════════════════════

/// Factory for creating Twilight Marches game components
public enum TwilightMarchesFactory {
    /// Create pressure rules
    public static func createPressureRules() -> TwilightPressureRules {
        return TwilightPressureRules()
    }

    /// Create initial player resources
    public static func createInitialResources() -> [String: Int] {
        return twilightInitialResources()
    }

    /// Create resource caps
    public static func createResourceCaps() -> [String: Int] {
        return [
            TwilightResource.health.id: TwilightResource.maxHealth.defaultValue,
            TwilightResource.faith.id: TwilightResource.maxFaith.defaultValue,
            TwilightResource.balance.id: TwilightBalanceConfig.max
        ]
    }
}

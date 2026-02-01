import Foundation

// MARK: - Balance Configuration

/// Configuration for game balance parameters loaded from content packs.
/// Replaces hardcoded balance values with data-driven configuration.
public struct BalanceConfiguration: Codable, Sendable {
    // MARK: - Resources

    /// Resource system configuration (health, faith, supplies, gold).
    public var resources: ResourceBalanceConfig

    // MARK: - Pressure/Tension

    /// Pressure system configuration (tension, escalation).
    public var pressure: PressureBalanceConfig

    // MARK: - Combat

    /// Combat system configuration (optional).
    public var combat: CombatBalanceConfig?

    // MARK: - Time

    /// Time system configuration (day/night cycle, action costs).
    public var time: TimeBalanceConfig

    // MARK: - Anchors

    /// Anchor system configuration (integrity, strengthening).
    public var anchor: AnchorBalanceConfig

    // MARK: - End Conditions

    /// Game end conditions (victory/defeat triggers).
    public var endConditions: EndConditionConfig

    // MARK: - Balance System (optional)

    /// Light/Dark balance system configuration.
    public var balanceSystem: BalanceSystemConfig?

    // MARK: - Defaults

    /// Default balance configuration for testing.
    public static let `default` = BalanceConfiguration(
        resources: .default,
        pressure: .default,
        combat: nil,
        time: .default,
        anchor: .default,
        endConditions: .default,
        balanceSystem: nil
    )
}

// MARK: - Resource Balance

/// Resource balance configuration (health, faith, supplies, gold).
public struct ResourceBalanceConfig: Codable, Sendable {
    /// Starting health value.
    public var startingHealth: Int

    /// Maximum health cap.
    public var maxHealth: Int

    /// Starting faith value.
    public var startingFaith: Int

    /// Maximum faith cap.
    public var maxFaith: Int

    /// Starting supplies value.
    public var startingSupplies: Int

    /// Maximum supplies cap.
    public var maxSupplies: Int

    /// Starting gold value.
    public var startingGold: Int

    /// Maximum gold cap.
    public var maxGold: Int

    /// Health restored when resting (optional, default 3).
    public var restHealAmount: Int?

    /// Starting balance value for Light/Dark system (optional).
    public var startingBalance: Int?

    /// Default resource configuration.
    public static let `default` = ResourceBalanceConfig(
        startingHealth: 20,
        maxHealth: 30,
        startingFaith: 10,
        maxFaith: 20,
        startingSupplies: 5,
        maxSupplies: 10,
        startingGold: 0,
        maxGold: 100,
        restHealAmount: 3,
        startingBalance: 50
    )
}

// MARK: - Pressure Balance

/// Pressure system balance configuration.
public struct PressureBalanceConfig: Codable, Sendable {
    /// Starting pressure level.
    public var startingPressure: Int

    /// Minimum pressure value.
    public var minPressure: Int

    /// Maximum pressure value.
    public var maxPressure: Int

    /// Pressure gain per turn.
    public var pressurePerTurn: Int

    /// Days between tension ticks (when tension increases automatically).
    public var tensionTickInterval: Int?

    /// Escalation interval (alias for tensionTickInterval).
    public var escalationInterval: Int?

    /// Pressure thresholds for escalation levels.
    public var thresholds: PressureThresholds

    /// Degradation settings for regions and anchors.
    public var degradation: DegradationConfig

    /// Get the effective tick interval (tensionTickInterval or escalationInterval).
    public var effectiveTickInterval: Int {
        tensionTickInterval ?? escalationInterval ?? 3
    }

    /// Default pressure configuration.
    public static let `default` = PressureBalanceConfig(
        startingPressure: 15,
        minPressure: 0,
        maxPressure: 100,
        pressurePerTurn: 3,
        tensionTickInterval: 3,
        escalationInterval: nil,
        thresholds: .default,
        degradation: .default
    )
}

/// Pressure thresholds for escalation levels.
public struct PressureThresholds: Codable, Sendable {
    /// Threshold for warning level (increased event danger).
    public var warning: Int

    /// Threshold for critical level.
    public var critical: Int

    /// Threshold for catastrophic level (game loss).
    public var catastrophic: Int

    /// Default thresholds.
    public static let `default` = PressureThresholds(
        warning: 50,
        critical: 75,
        catastrophic: 100
    )
}

/// Degradation configuration for regions and anchors.
public struct DegradationConfig: Codable, Sendable {
    /// Chance for region degradation at warning level.
    public var warningChance: Double

    /// Chance for region degradation at critical level.
    public var criticalChance: Double

    /// Chance for degradation at catastrophic level (optional).
    public var catastrophicChance: Double?

    /// Base chance for anchor integrity loss per turn.
    public var anchorDecayChance: Double

    /// Default degradation configuration.
    public static let `default` = DegradationConfig(
        warningChance: 0.15,
        criticalChance: 0.3,
        catastrophicChance: 0.5,
        anchorDecayChance: 0.05
    )
}

// MARK: - Combat Balance

/// Combat balance configuration.
public struct CombatBalanceConfig: Codable, Sendable, Equatable {
    /// Base damage for attacks.
    public var baseDamage: Int

    /// Damage modifier per power point.
    public var powerModifier: Double

    /// Defense damage reduction factor.
    public var defenseReduction: Double

    /// Maximum dice value (optional).
    public var diceMax: Int?

    /// Actions allowed per turn (optional).
    public var actionsPerTurn: Int?

    /// Cards drawn per turn (optional).
    public var cardsDrawnPerTurn: Int?

    /// Maximum hand size (optional).
    public var maxHandSize: Int?

    // MARK: - Encounter Combat Fields

    /// Resonance shift on escalation (spirit→physical). Default -5.0.
    public var escalationResonanceShift: Float?

    /// Surprise damage bonus on escalation. Default 3.
    public var escalationSurpriseBonus: Int?

    /// Rage shield value on de-escalation (physical→spirit). Default 3.
    public var deEscalationRageShield: Int?

    /// Match multiplier when card suit matches action alignment. Default 1.5.
    public var matchMultiplier: Double?

    /// Known multiplier keys for formula validation.
    public var knownMultiplierKeys: Set<String> {
        ["heavyAttackMultiplier", "lightAttackMultiplier", "healMultiplier",
         "escalationSurpriseBonus", "deEscalationRageShield", "matchMultiplier"]
    }

    /// Default combat configuration.
    public static let `default` = CombatBalanceConfig(
        baseDamage: 3,
        powerModifier: 1.0,
        defenseReduction: 0.5,
        diceMax: 6,
        actionsPerTurn: 3,
        cardsDrawnPerTurn: 5,
        maxHandSize: 7,
        escalationResonanceShift: -5.0,
        escalationSurpriseBonus: 3,
        deEscalationRageShield: 3,
        matchMultiplier: 1.5
    )
}

// MARK: - Time Balance

/// Time system balance configuration.
public struct TimeBalanceConfig: Codable, Sendable {
    /// Starting time of day.
    public var startingTime: Int

    /// Maximum days for campaign (optional).
    public var maxDays: Int?

    /// Time cost for travel action.
    public var travelCost: Int

    /// Time cost for exploration action.
    public var exploreCost: Int

    /// Time cost for rest action.
    public var restCost: Int

    /// Time cost for strengthening anchor (optional).
    public var strengthenAnchorCost: Int?

    /// Time cost for instant actions (optional).
    public var instantCost: Int?

    /// Default time configuration.
    public static let `default` = TimeBalanceConfig(
        startingTime: 8,
        maxDays: nil,
        travelCost: 1,
        exploreCost: 1,
        restCost: 1,
        strengthenAnchorCost: 1,
        instantCost: 0
    )
}

// MARK: - End Conditions

/// End condition configuration for victory and defeat.
public struct EndConditionConfig: Codable, Sendable {
    /// Health threshold for death (game over).
    public var deathHealth: Int

    /// Pressure threshold for loss (optional).
    public var pressureLoss: Int?

    /// Breach count for loss (optional).
    public var breachLoss: Int?

    /// Quest IDs that trigger victory.
    public var victoryQuests: [String]

    /// Flag set when main quest completes (optional).
    public var mainQuestCompleteFlag: String?

    /// Flag set when critical anchor destroyed (optional).
    public var criticalAnchorDestroyedFlag: String?

    /// Default end condition configuration.
    public static let `default` = EndConditionConfig(
        deathHealth: 0,
        pressureLoss: 100,
        breachLoss: nil,
        victoryQuests: [],
        mainQuestCompleteFlag: nil,
        criticalAnchorDestroyedFlag: nil
    )
}

// MARK: - Anchor Balance

/// Anchor system balance configuration.
public struct AnchorBalanceConfig: Codable, Sendable {
    /// Maximum anchor integrity.
    public var maxIntegrity: Int

    /// Amount to strengthen per action.
    public var strengthenAmount: Int

    /// Faith cost to strengthen anchor.
    public var strengthenCost: Int

    /// Integrity threshold for stable status.
    public var stableThreshold: Int

    /// Integrity threshold for breach.
    public var breachThreshold: Int

    /// Base decay rate per turn in threatened regions.
    public var decayPerTurn: Int

    /// Anchor integrity damage per degradation event (optional, default 20).
    public var degradationAmount: Int?

    /// Default anchor configuration.
    public static let `default` = AnchorBalanceConfig(
        maxIntegrity: 100,
        strengthenAmount: 20,
        strengthenCost: 3,
        stableThreshold: 70,
        breachThreshold: 30,
        decayPerTurn: 3,
        degradationAmount: 20
    )
}

// MARK: - Anchor Helpers

extension AnchorBalanceConfig {
    /// Determine region state based on anchor integrity and configured thresholds.
    public func regionStateForIntegrity(_ integrity: Int) -> TwilightRegionState {
        if integrity >= stableThreshold { return .stable }
        if integrity > breachThreshold { return .borderland }
        return .breach
    }

    /// Static convenience using default config.
    public static func regionStateForIntegrity(_ integrity: Int) -> TwilightRegionState {
        AnchorBalanceConfig.default.regionStateForIntegrity(integrity)
    }
}

// MARK: - Balance System

/// Light/Dark balance system configuration.
public struct BalanceSystemConfig: Codable, Sendable {
    /// Minimum balance value.
    public var min: Int

    /// Maximum balance value.
    public var max: Int

    /// Initial balance value.
    public var initial: Int

    /// Threshold for light alignment.
    public var lightThreshold: Int

    /// Threshold for dark alignment.
    public var darkThreshold: Int

    /// Default balance system configuration.
    public static let `default` = BalanceSystemConfig(
        min: 0,
        max: 100,
        initial: 50,
        lightThreshold: 70,
        darkThreshold: 30
    )
}

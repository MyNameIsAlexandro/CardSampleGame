import Foundation

// MARK: - Balance Configuration

/// Configuration for game balance parameters loaded from content packs.
/// Replaces hardcoded balance values with data-driven configuration.
public struct BalanceConfiguration: Codable, Sendable {
    // MARK: - Resources

    /// Resource system configuration (health, faith, supplies, gold).
    public let resources: ResourceBalanceConfig

    // MARK: - Pressure/Tension

    /// Pressure system configuration (tension, escalation).
    public let pressure: PressureBalanceConfig

    // MARK: - Combat

    /// Combat system configuration (optional).
    public let combat: CombatBalanceConfig?

    // MARK: - Time

    /// Time system configuration (day/night cycle, action costs).
    public let time: TimeBalanceConfig

    // MARK: - Anchors

    /// Anchor system configuration (integrity, strengthening).
    public let anchor: AnchorBalanceConfig

    // MARK: - End Conditions

    /// Game end conditions (victory/defeat triggers).
    public let endConditions: EndConditionConfig

    // MARK: - Balance System (optional)

    /// Light/Dark balance system configuration.
    public let balanceSystem: BalanceSystemConfig?

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
    public let startingHealth: Int

    /// Maximum health cap.
    public let maxHealth: Int

    /// Starting faith value.
    public let startingFaith: Int

    /// Maximum faith cap.
    public let maxFaith: Int

    /// Starting supplies value.
    public let startingSupplies: Int

    /// Maximum supplies cap.
    public let maxSupplies: Int

    /// Starting gold value.
    public let startingGold: Int

    /// Maximum gold cap.
    public let maxGold: Int

    /// Health restored when resting (optional, default 3).
    public let restHealAmount: Int?

    /// Starting balance value for Light/Dark system (optional).
    public let startingBalance: Int?

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
    public let startingPressure: Int

    /// Minimum pressure value.
    public let minPressure: Int

    /// Maximum pressure value.
    public let maxPressure: Int

    /// Pressure gain per turn.
    public let pressurePerTurn: Int

    /// Days between tension ticks (when tension increases automatically).
    public let tensionTickInterval: Int?

    /// Escalation interval (alias for tensionTickInterval).
    public let escalationInterval: Int?

    /// Pressure thresholds for escalation levels.
    public let thresholds: PressureThresholds

    /// Degradation settings for regions and anchors.
    public let degradation: DegradationConfig

    /// Get the effective tick interval (tensionTickInterval or escalationInterval).
    public var effectiveTickInterval: Int {
        tensionTickInterval ?? escalationInterval ?? 3
    }

    /// Default pressure configuration.
    public static let `default` = PressureBalanceConfig(
        startingPressure: 0,
        minPressure: 0,
        maxPressure: 100,
        pressurePerTurn: 5,
        tensionTickInterval: 3,
        escalationInterval: nil,
        thresholds: .default,
        degradation: .default
    )
}

/// Pressure thresholds for escalation levels.
public struct PressureThresholds: Codable, Sendable {
    /// Threshold for warning level (increased event danger).
    public let warning: Int

    /// Threshold for critical level.
    public let critical: Int

    /// Threshold for catastrophic level (game loss).
    public let catastrophic: Int

    /// Default thresholds.
    public static let `default` = PressureThresholds(
        warning: 30,
        critical: 60,
        catastrophic: 100
    )
}

/// Degradation configuration for regions and anchors.
public struct DegradationConfig: Codable, Sendable {
    /// Chance for region degradation at warning level.
    public let warningChance: Double

    /// Chance for region degradation at critical level.
    public let criticalChance: Double

    /// Chance for degradation at catastrophic level (optional).
    public let catastrophicChance: Double?

    /// Base chance for anchor integrity loss per turn.
    public let anchorDecayChance: Double

    /// Default degradation configuration.
    public static let `default` = DegradationConfig(
        warningChance: 0.1,
        criticalChance: 0.25,
        catastrophicChance: nil,
        anchorDecayChance: 0.05
    )
}

// MARK: - Combat Balance

/// Combat balance configuration.
public struct CombatBalanceConfig: Codable, Sendable {
    /// Base damage for attacks.
    public let baseDamage: Int

    /// Damage modifier per power point.
    public let powerModifier: Double

    /// Defense damage reduction factor.
    public let defenseReduction: Double

    /// Maximum dice value (optional).
    public let diceMax: Int?

    /// Actions allowed per turn (optional).
    public let actionsPerTurn: Int?

    /// Cards drawn per turn (optional).
    public let cardsDrawnPerTurn: Int?

    /// Maximum hand size (optional).
    public let maxHandSize: Int?

    /// Default combat configuration.
    public static let `default` = CombatBalanceConfig(
        baseDamage: 3,
        powerModifier: 1.0,
        defenseReduction: 0.5,
        diceMax: 6,
        actionsPerTurn: 3,
        cardsDrawnPerTurn: 5,
        maxHandSize: 7
    )
}

// MARK: - Time Balance

/// Time system balance configuration.
public struct TimeBalanceConfig: Codable, Sendable {
    /// Starting time of day.
    public let startingTime: Int

    /// Maximum days for campaign (optional).
    public let maxDays: Int?

    /// Time cost for travel action.
    public let travelCost: Int

    /// Time cost for exploration action.
    public let exploreCost: Int

    /// Time cost for rest action.
    public let restCost: Int

    /// Time cost for strengthening anchor (optional).
    public let strengthenAnchorCost: Int?

    /// Time cost for instant actions (optional).
    public let instantCost: Int?

    /// Default time configuration.
    public static let `default` = TimeBalanceConfig(
        startingTime: 8,
        maxDays: nil,
        travelCost: 2,
        exploreCost: 1,
        restCost: 4,
        strengthenAnchorCost: 1,
        instantCost: 0
    )
}

// MARK: - End Conditions

/// End condition configuration for victory and defeat.
public struct EndConditionConfig: Codable, Sendable {
    /// Health threshold for death (game over).
    public let deathHealth: Int

    /// Pressure threshold for loss (optional).
    public let pressureLoss: Int?

    /// Breach count for loss (optional).
    public let breachLoss: Int?

    /// Quest IDs that trigger victory.
    public let victoryQuests: [String]

    /// Flag set when main quest completes (optional).
    public let mainQuestCompleteFlag: String?

    /// Flag set when critical anchor destroyed (optional).
    public let criticalAnchorDestroyedFlag: String?

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
    public let maxIntegrity: Int

    /// Amount to strengthen per action.
    public let strengthenAmount: Int

    /// Faith cost to strengthen anchor.
    public let strengthenCost: Int

    /// Integrity threshold for stable status.
    public let stableThreshold: Int

    /// Integrity threshold for breach.
    public let breachThreshold: Int

    /// Base decay rate per turn in threatened regions.
    public let decayPerTurn: Int

    /// Default anchor configuration.
    public static let `default` = AnchorBalanceConfig(
        maxIntegrity: 100,
        strengthenAmount: 15,
        strengthenCost: 5,
        stableThreshold: 70,
        breachThreshold: 0,
        decayPerTurn: 5
    )
}

// MARK: - Balance System

/// Light/Dark balance system configuration.
public struct BalanceSystemConfig: Codable, Sendable {
    /// Minimum balance value.
    public let min: Int

    /// Maximum balance value.
    public let max: Int

    /// Initial balance value.
    public let initial: Int

    /// Threshold for light alignment.
    public let lightThreshold: Int

    /// Threshold for dark alignment.
    public let darkThreshold: Int

    /// Default balance system configuration.
    public static let `default` = BalanceSystemConfig(
        min: 0,
        max: 100,
        initial: 50,
        lightThreshold: 70,
        darkThreshold: 30
    )
}

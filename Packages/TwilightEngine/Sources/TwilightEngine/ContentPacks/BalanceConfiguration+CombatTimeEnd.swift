/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/ContentPacks/BalanceConfiguration+CombatTimeEnd.swift
/// Назначение: Содержит реализацию файла BalanceConfiguration+CombatTimeEnd.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

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

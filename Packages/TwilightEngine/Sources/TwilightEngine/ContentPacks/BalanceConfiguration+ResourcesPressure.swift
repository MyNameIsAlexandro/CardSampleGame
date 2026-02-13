/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/ContentPacks/BalanceConfiguration+ResourcesPressure.swift
/// Назначение: Содержит реализацию файла BalanceConfiguration+ResourcesPressure.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

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

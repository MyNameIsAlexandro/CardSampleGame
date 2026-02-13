/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/ContentPacks/BalanceConfiguration+AnchorSystem.swift
/// Назначение: Содержит реализацию файла BalanceConfiguration+AnchorSystem.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

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

    /// HP cost for dark hero to defile anchor (shift alignment to dark). Default 5.
    public var defileCostHP: Int?

    /// HP cost for dark hero to strengthen anchor. Default 3.
    public var darkStrengthenCostHP: Int?

    /// Default anchor configuration.
    public static let `default` = AnchorBalanceConfig(
        maxIntegrity: 100,
        strengthenAmount: 20,
        strengthenCost: 3,
        stableThreshold: 70,
        breachThreshold: 30,
        decayPerTurn: 3,
        degradationAmount: 20,
        defileCostHP: 5,
        darkStrengthenCostHP: 3
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

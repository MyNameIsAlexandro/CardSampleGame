/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Config/TwilightMarchesConfig.swift
/// Назначение: Содержит реализацию файла TwilightMarchesConfig.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Twilight Marches Configuration
// Game-specific configuration for "Сумрачные Пределы" (Twilight Marches)
// Balance values come from BalanceConfiguration (balance.json) — single source of truth.
// This file contains domain types and game-specific logic only.

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

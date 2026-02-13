/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/PressureEngine.swift
/// Назначение: Содержит реализацию файла PressureEngine.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Pressure Engine Implementation
// Generic pressure/tension system that drives game escalation.

/// Default implementation of PressureEngineProtocol
public final class PressureEngine: PressureEngineProtocol {
    // MARK: - Properties

    public private(set) var currentPressure: Int
    public let rules: PressureRuleSet

    /// Track which thresholds have been triggered
    private var triggeredThresholds: Set<Int> = []

    // MARK: - Initialization

    public init(rules: PressureRuleSet) {
        self.rules = rules
        self.currentPressure = rules.initialPressure
    }

    // MARK: - PressureEngineProtocol

    /// Escalate pressure based on rules and current time
    public func escalate(at currentTime: Int) {
        let delta = rules.calculateEscalation(currentPressure: currentPressure, currentTime: currentTime)
        adjust(by: delta)
    }

    /// Manually adjust pressure (can be positive or negative)
    public func adjust(by delta: Int) {
        let newPressure = currentPressure + delta
        currentPressure = min(max(0, newPressure), rules.maxPressure)
    }

    /// Get effects that should trigger at current pressure level
    public func currentEffects() -> [WorldEffect] {
        return rules.checkThresholds(pressure: currentPressure)
    }

    // MARK: - Utility

    /// Reset pressure (for new game)
    public func reset() {
        currentPressure = rules.initialPressure
        triggeredThresholds.removeAll()
    }

    /// Set pressure directly (for save/load)
    public func setPressure(_ value: Int) {
        currentPressure = min(max(0, value), rules.maxPressure)
    }

    // MARK: - Save/Load Support

    /// Get triggered thresholds for save
    public func getTriggeredThresholds() -> Set<Int> {
        return triggeredThresholds
    }

    /// Restore triggered thresholds from save
    /// Call this after loading game to prevent duplicate threshold events
    public func setTriggeredThresholds(_ thresholds: Set<Int>) {
        triggeredThresholds = thresholds
    }

    /// Reconstruct triggered thresholds from current pressure value
    /// Use this when loading a save that doesn't have explicit thresholds saved
    /// All thresholds below or equal to current pressure are marked as triggered
    public func syncTriggeredThresholdsFromPressure() {
        triggeredThresholds.removeAll()
        // Use checkThresholds to find which effects would trigger at current pressure
        // Then mark standard threshold levels (10, 20, 30, etc.) as triggered
        // This is a heuristic - actual threshold levels depend on the rule set
        let standardThresholds = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
        for threshold in standardThresholds where threshold <= currentPressure {
            triggeredThresholds.insert(threshold)
        }
    }

    /// Get pressure as percentage (0.0 - 1.0)
    public var pressurePercentage: Double {
        guard rules.maxPressure > 0 else { return 0 }
        return Double(currentPressure) / Double(rules.maxPressure)
    }

    /// Check if at maximum pressure (game over condition)
    public var isAtMaximum: Bool {
        currentPressure >= rules.maxPressure
    }
}

// MARK: - Standard Pressure Rule Set

/// Basic pressure rules with configurable parameters
public struct StandardPressureRules: PressureRuleSet {
    public let maxPressure: Int
    public let initialPressure: Int
    public let escalationInterval: Int
    public let escalationAmount: Int

    /// Thresholds that trigger effects [pressure: effects]
    public let thresholds: [Int: [WorldEffect]]

    public init(
        maxPressure: Int = 100,
        initialPressure: Int = 30,
        escalationInterval: Int = 3,
        escalationAmount: Int = 2,
        thresholds: [Int: [WorldEffect]] = [:]
    ) {
        self.maxPressure = maxPressure
        self.initialPressure = initialPressure
        self.escalationInterval = escalationInterval
        self.escalationAmount = escalationAmount
        self.thresholds = thresholds
    }

    public func calculateEscalation(currentPressure: Int, currentTime: Int) -> Int {
        // Standard: add escalationAmount every escalationInterval
        return escalationAmount
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

// MARK: - Adaptive Pressure Rules

/// Pressure rules that adapt based on game state
public struct AdaptivePressureRules: PressureRuleSet {
    public let maxPressure: Int
    public let initialPressure: Int
    public let escalationInterval: Int
    public let baseEscalationAmount: Int

    /// Multiplier based on current pressure (higher pressure = faster escalation)
    public let accelerationFactor: Double

    /// Thresholds with effects
    public let thresholds: [Int: [WorldEffect]]

    public var escalationAmount: Int { baseEscalationAmount }

    public init(
        maxPressure: Int = 100,
        initialPressure: Int = 30,
        escalationInterval: Int = 3,
        baseEscalationAmount: Int = 2,
        accelerationFactor: Double = 0.01,
        thresholds: [Int: [WorldEffect]] = [:]
    ) {
        self.maxPressure = maxPressure
        self.initialPressure = initialPressure
        self.escalationInterval = escalationInterval
        self.baseEscalationAmount = baseEscalationAmount
        self.accelerationFactor = accelerationFactor
        self.thresholds = thresholds
    }

    public func calculateEscalation(currentPressure: Int, currentTime: Int) -> Int {
        // Adaptive: base amount + acceleration based on current pressure
        let acceleration = Int(Double(currentPressure) * accelerationFactor)
        return baseEscalationAmount + acceleration
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

// MARK: - Pressure Change Event

/// Event fired when pressure changes significantly
public struct PressureChangeEvent {
    public let oldValue: Int
    public let newValue: Int
    public let delta: Int
    public let thresholdsCrossed: [Int]
    public let effectsTriggered: [WorldEffect]
}

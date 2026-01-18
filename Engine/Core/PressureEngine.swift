import Foundation

// MARK: - Pressure Engine Implementation
// Generic pressure/tension system that drives game escalation.

/// Default implementation of PressureEngineProtocol
final class PressureEngine: PressureEngineProtocol {
    // MARK: - Properties

    private(set) var currentPressure: Int
    let rules: PressureRuleSet

    /// Track which thresholds have been triggered
    private var triggeredThresholds: Set<Int> = []

    // MARK: - Initialization

    init(rules: PressureRuleSet) {
        self.rules = rules
        self.currentPressure = rules.initialPressure
    }

    // MARK: - PressureEngineProtocol

    /// Escalate pressure based on rules and current time
    func escalate(at currentTime: Int) {
        let delta = rules.calculateEscalation(currentPressure: currentPressure, currentTime: currentTime)
        adjust(by: delta)
    }

    /// Manually adjust pressure (can be positive or negative)
    func adjust(by delta: Int) {
        let newPressure = currentPressure + delta
        currentPressure = min(max(0, newPressure), rules.maxPressure)
    }

    /// Get effects that should trigger at current pressure level
    func currentEffects() -> [WorldEffect] {
        return rules.checkThresholds(pressure: currentPressure)
    }

    // MARK: - Utility

    /// Reset pressure (for new game)
    func reset() {
        currentPressure = rules.initialPressure
        triggeredThresholds.removeAll()
    }

    /// Set pressure directly (for save/load)
    func setPressure(_ value: Int) {
        currentPressure = min(max(0, value), rules.maxPressure)
    }

    /// Get pressure as percentage (0.0 - 1.0)
    var pressurePercentage: Double {
        guard rules.maxPressure > 0 else { return 0 }
        return Double(currentPressure) / Double(rules.maxPressure)
    }

    /// Check if at maximum pressure (game over condition)
    var isAtMaximum: Bool {
        currentPressure >= rules.maxPressure
    }
}

// MARK: - Standard Pressure Rule Set

/// Basic pressure rules with configurable parameters
struct StandardPressureRules: PressureRuleSet {
    let maxPressure: Int
    let initialPressure: Int
    let escalationInterval: Int
    let escalationAmount: Int

    /// Thresholds that trigger effects [pressure: effects]
    let thresholds: [Int: [WorldEffect]]

    init(
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

    func calculateEscalation(currentPressure: Int, currentTime: Int) -> Int {
        // Standard: add escalationAmount every escalationInterval
        return escalationAmount
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

// MARK: - Adaptive Pressure Rules

/// Pressure rules that adapt based on game state
struct AdaptivePressureRules: PressureRuleSet {
    let maxPressure: Int
    let initialPressure: Int
    let escalationInterval: Int
    let baseEscalationAmount: Int

    /// Multiplier based on current pressure (higher pressure = faster escalation)
    let accelerationFactor: Double

    /// Thresholds with effects
    let thresholds: [Int: [WorldEffect]]

    var escalationAmount: Int { baseEscalationAmount }

    init(
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

    func calculateEscalation(currentPressure: Int, currentTime: Int) -> Int {
        // Adaptive: base amount + acceleration based on current pressure
        let acceleration = Int(Double(currentPressure) * accelerationFactor)
        return baseEscalationAmount + acceleration
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

// MARK: - Pressure Change Event

/// Event fired when pressure changes significantly
struct PressureChangeEvent {
    let oldValue: Int
    let newValue: Int
    let delta: Int
    let thresholdsCrossed: [Int]
    let effectsTriggered: [WorldEffect]
}

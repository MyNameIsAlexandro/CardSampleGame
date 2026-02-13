/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/EngineProtocols+Pressure.swift
/// Назначение: Содержит реализацию файла EngineProtocols+Pressure.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 2. Pressure System
// ═══════════════════════════════════════════════════════════════════════════════

/// Defines the rules for pressure/tension escalation
public protocol PressureRuleSet {
    var maxPressure: Int { get }
    var initialPressure: Int { get }

    /// Calculate pressure increase based on current state
    func calculateEscalation(currentPressure: Int, currentTime: Int) -> Int

    /// Check what effects trigger at current pressure level
    func checkThresholds(pressure: Int) -> [WorldEffect]

    /// Interval (in time units) for automatic pressure increase
    var escalationInterval: Int { get }

    /// Amount of pressure added per interval
    var escalationAmount: Int { get }
}

/// Effects that can be applied to the world
public enum WorldEffect: Equatable {
    case regionDegradation(probability: Double)
    case globalEvent(eventId: String)
    case phaseChange(newPhase: String)
    case anchorWeakening(amount: Int)
    case custom(id: String, parameters: [String: Any])

    public static func == (lhs: WorldEffect, rhs: WorldEffect) -> Bool {
        switch (lhs, rhs) {
        case (.regionDegradation(let p1), .regionDegradation(let p2)):
            return p1 == p2
        case (.globalEvent(let e1), .globalEvent(let e2)):
            return e1 == e2
        case (.phaseChange(let ph1), .phaseChange(let ph2)):
            return ph1 == ph2
        case (.anchorWeakening(let a1), .anchorWeakening(let a2)):
            return a1 == a2
        case (.custom(let id1, _), .custom(let id2, _)):
            return id1 == id2
        default:
            return false
        }
    }
}

/// Pressure engine protocol
public protocol PressureEngineProtocol {
    var currentPressure: Int { get }
    var rules: PressureRuleSet { get }

    /// Escalate pressure based on rules
    func escalate(at currentTime: Int)

    /// Manually adjust pressure
    func adjust(by delta: Int)

    /// Get current threshold effects
    func currentEffects() -> [WorldEffect]
}

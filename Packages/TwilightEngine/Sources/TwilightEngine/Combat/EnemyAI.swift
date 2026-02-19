/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Combat/EnemyAI.swift
/// Назначение: AI for enemy action selection in disposition combat.
/// Зона ответственности: Select enemy actions based on combat state and enemy mode.
/// Контекст: Epic 19 (normal mode), Epic 21 (mode transitions, hysteresis, all modes).

import Foundation

// MARK: - EnemyMode

/// Enemy mode for AI behavior branching.
public enum EnemyMode: Equatable, Codable, Sendable {
    case normal
    case survival
    case desperation
    case weakened
}

// MARK: - EnemyModeState

/// Enemy mode state with hysteresis tracking (INV-DC-030).
public struct EnemyModeState: Equatable, Codable, Sendable {
    public private(set) var currentMode: EnemyMode = .normal
    /// Turns remaining in hysteresis hold (INV-DC-030).
    public private(set) var hysteresisCounter: Int = 0
    /// Previous disposition for swing detection (INV-DC-031).
    public private(set) var previousDisposition: Int = 0
    /// Whether at least one evaluation has occurred (swing check requires prior state).
    public private(set) var hasEvaluated: Bool = false
    /// Dynamic threshold offsets derived from seed (INV-DC-027..029).
    public let survivalThreshold: Int
    public let desperationThreshold: Int

    public init(seed: UInt64) {
        let hash = Int(truncatingIfNeeded: seed &* 6364136223846793005 &+ 1442695040888963407)
        let offset = abs(hash) % 11 - 5
        self.survivalThreshold = -60 + offset
        self.desperationThreshold = -80 + offset
    }

    /// Evaluate current mode based on disposition and history.
    /// INV-DC-027..029: Dynamic thresholds. INV-DC-030: Hysteresis.
    /// INV-DC-031: Weakened trigger on ±30 swing (requires prior evaluation).
    @discardableResult
    public mutating func evaluateMode(disposition: Int) -> EnemyMode {
        if hasEvaluated {
            let swing = abs(disposition - previousDisposition)
            if swing >= 30 {
                previousDisposition = disposition
                currentMode = .weakened
                hysteresisCounter = 1
                return .weakened
            }
        } else {
            hasEvaluated = true
        }

        if hysteresisCounter > 0 {
            hysteresisCounter -= 1
            previousDisposition = disposition
            return currentMode
        }

        let newMode: EnemyMode
        if disposition <= desperationThreshold {
            newMode = .desperation
        } else if disposition <= survivalThreshold {
            newMode = .survival
        } else {
            newMode = .normal
        }

        if newMode != currentMode {
            hysteresisCounter = 1
        }

        currentMode = newMode
        previousDisposition = disposition
        return newMode
    }
}

// MARK: - EnemyAI

/// AI for enemy action selection in disposition combat.
/// INV-DC-027..034, INV-DC-052..055, INV-DC-060.
public struct EnemyAI {

    // MARK: - Mode Evaluation (convenience static)

    /// Convenience static wrapper for EnemyModeState.evaluateMode.
    @discardableResult
    public static func evaluateMode(
        state: inout EnemyModeState,
        disposition: Int
    ) -> EnemyMode {
        return state.evaluateMode(disposition: disposition)
    }

    // MARK: - Action Selection

    /// Select an enemy action based on combat state.
    /// INV-DC-060: In NORMAL mode, reads momentum (streak >= 3 triggers counter-action).
    /// INV-DC-052: Survival — defensive bias. INV-DC-053..055: Desperation — ATK x2, no defend, provoke +2.
    public static func selectAction(
        mode: EnemyMode,
        simulation: DispositionCombatSimulation,
        rng: WorldRNG,
        baseDamage: Int = 3,
        baseDefend: Int = 3,
        baseProvoke: Int = 3
    ) -> EnemyAction {
        switch mode {
        case .normal:
            if simulation.streakCount >= 3, let streakType = simulation.streakType {
                switch streakType {
                case .strike:
                    return .defend(reduction: baseDefend)
                case .influence:
                    return .provoke(penalty: baseProvoke)
                case .sacrifice:
                    return .adapt
                }
            }
            return .attack(damage: baseDamage)

        case .survival:
            return .attack(damage: baseDamage)

        case .desperation:
            if simulation.streakCount >= 3, simulation.streakType == .influence {
                return .provoke(penalty: baseProvoke + 2)
            }
            return .attack(damage: baseDamage * 2)

        case .weakened:
            return .attack(damage: max(1, baseDamage / 2))
        }
    }
}

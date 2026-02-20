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
        let offset = abs(hash) % 11
        self.survivalThreshold = -(65 + offset)
        self.desperationThreshold = 65 + offset
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
        if disposition >= desperationThreshold {
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
/// Design §7.6: probability-based per mode with streak awareness.
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

    /// Select an enemy action based on combat state (design §7.6).
    /// NORMAL: streak counter + position-based probabilities.
    /// SURVIVAL: Attack(60%) | Rage(30%) | Attack(10%). INV-DC-052.
    /// DESPERATION: ATK x2, no defend, provoke +2. INV-DC-053..055.
    /// WEAKENED: half damage (weakest action). INV-DC-032.
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
            return selectNormalAction(
                simulation: simulation, rng: rng,
                baseDamage: baseDamage, baseDefend: baseDefend, baseProvoke: baseProvoke
            )
        case .survival:
            return selectSurvivalAction(rng: rng, baseDamage: baseDamage)
        case .desperation:
            return selectDesperationAction(
                simulation: simulation, rng: rng,
                baseDamage: baseDamage, baseProvoke: baseProvoke
            )
        case .weakened:
            return .defend(reduction: max(1, baseDefend / 2))
        }
    }

    // MARK: - Normal Mode (design §7.6)

    private static func selectNormalAction(
        simulation: DispositionCombatSimulation,
        rng: WorldRNG,
        baseDamage: Int,
        baseDefend: Int,
        baseProvoke: Int
    ) -> EnemyAction {
        // Streak >= 3: 50% counter, 50% adapt
        if simulation.streakCount >= 3, let streakType = simulation.streakType {
            let roll = rng.nextInt(in: 0...99)
            if roll < 50 {
                switch streakType {
                case .strike: return .defend(reduction: baseDefend)
                case .influence: return .provoke(penalty: baseProvoke)
                case .sacrifice: return .adapt
                }
            }
            return .adapt
        }

        let disp = simulation.disposition
        let roll = rng.nextInt(in: 0...99)

        // Position-based probabilities
        if disp < -50 {
            // Near enemy destruction: Defend(60%) | Attack(40%)
            return roll < 60 ? .defend(reduction: baseDefend) : .attack(damage: baseDamage)
        } else if disp > 30 {
            // Near subjugation: Provoke(50%) | Attack(50%)
            return roll < 50 ? .provoke(penalty: baseProvoke) : .attack(damage: baseDamage)
        } else {
            // Neutral zone: Attack(80%) | random(20%)
            if roll < 80 { return .attack(damage: baseDamage) }
            let sub = rng.nextInt(in: 0...1)
            return sub == 0 ? .defend(reduction: baseDefend) : .provoke(penalty: baseProvoke)
        }
    }

    // MARK: - Survival Mode (design §7.6)

    private static func selectSurvivalAction(
        rng: WorldRNG,
        baseDamage: Int
    ) -> EnemyAction {
        // Attack(60%) | Rage(30%) | Attack(10%)
        let roll = rng.nextInt(in: 0...99)
        if roll < 60 {
            return .attack(damage: baseDamage)
        } else if roll < 90 {
            return .rage(damage: baseDamage * 2)
        } else {
            return .attack(damage: baseDamage)
        }
    }

    // MARK: - Desperation Mode (design §7.6, INV-DC-053..055)

    private static func selectDesperationAction(
        simulation: DispositionCombatSimulation,
        rng: WorldRNG,
        baseDamage: Int,
        baseProvoke: Int
    ) -> EnemyAction {
        // Provoke(40%) | Plea(30%) | Attack(30%)
        let roll = rng.nextInt(in: 0...99)
        if roll < 40 {
            return .provoke(penalty: baseProvoke + 2)
        } else if roll < 70 {
            return .plea(dispositionShift: 10)
        } else {
            return .attack(damage: baseDamage * 2)
        }
    }
}

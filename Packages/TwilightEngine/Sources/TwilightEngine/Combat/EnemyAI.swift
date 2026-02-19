/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Combat/EnemyAI.swift
/// Назначение: AI for enemy action selection in disposition combat.
/// Зона ответственности: Select enemy actions based on combat state and enemy mode.
/// Контекст: Epic 19 — Enemy Action Core. INV-DC-060 (normal mode momentum read). Other modes deferred to Epic 21.

import Foundation

// MARK: - EnemyMode

/// Enemy mode for AI behavior branching.
public enum EnemyMode: Equatable, Codable, Sendable {
    case normal
    case survival
    case desperation
    case weakened
}

// MARK: - EnemyAI

/// AI for enemy action selection in disposition combat.
/// Only NORMAL mode is implemented (Epic 19). Other modes deferred to Epic 21.
public struct EnemyAI {

    /// Select an enemy action based on combat state.
    /// INV-DC-060: In NORMAL mode, reads momentum (streak >= 3 triggers counter-action).
    public static func selectAction(
        mode: EnemyMode,
        simulation: DispositionCombatSimulation,
        rng: WorldRNG,
        baseDamage: Int = 3,
        baseDefend: Int = 3,
        baseProvoke: Int = 3
    ) -> EnemyAction {
        guard mode == .normal else {
            return .attack(damage: baseDamage)
        }

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
    }
}

/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Combat/EnemyActionResolver.swift
/// Назначение: Enemy action types and resolution logic for disposition combat.
/// Зона ответственности: Define EnemyAction enum, apply enemy actions to DispositionCombatSimulation.
/// Контекст: Epic 19 — Enemy Action Core. INV-DC-056..059.

import Foundation

// MARK: - EnemyAction

/// Enemy action types in disposition combat.
public enum EnemyAction: Equatable, Codable, Sendable {
    /// Direct damage to hero HP (INV-DC-056).
    case attack(damage: Int)
    /// Reduce next strike's effective_power (INV-DC-057).
    case defend(reduction: Int)
    /// Penalize next influence (INV-DC-058).
    case provoke(penalty: Int)
    /// Soft-block current streak type (INV-DC-059).
    case adapt
}

// MARK: - EnemyActionResolver

/// Resolves enemy actions against disposition combat state.
public struct EnemyActionResolver {

    /// Apply an enemy action to the simulation.
    /// Returns true if the action was applied, false if combat already has an outcome.
    @discardableResult
    public static func resolve(
        action: EnemyAction,
        simulation: inout DispositionCombatSimulation
    ) -> Bool {
        guard simulation.outcome == nil else { return false }

        switch action {
        case .attack(let damage):
            simulation.applyEnemyAttack(damage: damage)
            return true
        case .defend(let reduction):
            simulation.applyEnemyDefend(value: reduction)
            return true
        case .provoke(let penalty):
            simulation.applyEnemyProvoke(value: penalty)
            return true
        case .adapt:
            let streakBon = DispositionCalculator.streakBonus(streakCount: simulation.streakCount)
            simulation.applyEnemyAdapt(streakBonus: streakBon)
            return true
        }
    }
}

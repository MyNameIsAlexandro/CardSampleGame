/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Combat/EnemyActionResolver.swift
/// Назначение: Enemy action types and resolution logic for disposition combat.
/// Зона ответственности: Define EnemyAction enum, apply enemy actions to DispositionCombatSimulation.
/// Контекст: Epic 19 (INV-DC-056..059), Epic 21 (INV-DC-033..034 rage/plea).

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
    /// Rage: ATK x2, disposition += 5 (INV-DC-033).
    case rage(damage: Int)
    /// Plea: disposition +shift, next strike backlash -5 HP to hero (INV-DC-034).
    case plea(dispositionShift: Int)
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
        case .rage(let damage):
            simulation.applyEnemyAttack(damage: damage)
            simulation.applyDispositionShift(5)
            return true
        case .plea(let shift):
            simulation.applyDispositionShift(shift)
            simulation.applyPleaBacklash(hpLoss: 5)
            return true
        }
    }
}

/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Combat/CombatSimulationRunner.swift
/// Назначение: Runner that executes a full combat simulation using an agent.
/// Зона ответственности: Turn loop, enemy AI integration, result collection.
/// Контекст: Epic 25 — Stress Tests & Simulation.

import Foundation

// MARK: - CombatSimulationRunner

/// Runs a full combat simulation with given agent vs enemy AI.
public struct CombatSimulationRunner {

    /// Maximum turns before forced termination (prevent infinite loops).
    public static let maxTurns = 50

    /// Run a complete combat simulation.
    public static func run(
        agent: CombatSimulationAgent,
        simulation: inout DispositionCombatSimulation,
        enemyMode: EnemyMode = .normal,
        baseDamage: Int = 3,
        seed: UInt64 = 42
    ) -> CombatSimulationResult {
        let rng = WorldRNG(seed: seed &+ 1000)
        var modeState = EnemyModeState(seed: seed)
        var turnsPlayed = 0
        var strikeCount = 0
        var influenceCount = 0
        var sacrificeCount = 0

        while simulation.outcome == nil && turnsPlayed < maxTurns {
            turnsPlayed += 1

            var actionsThisTurn = 0
            var playerTurnDone = false
            while simulation.outcome == nil && !simulation.isAutoTurnEnd
                && !playerTurnDone && actionsThisTurn < 20
            {
                let action = agent.selectAction(simulation: simulation)
                switch action {
                case .strike(let cardId):
                    if simulation.playStrike(cardId: cardId, targetId: "enemy") {
                        strikeCount += 1
                        actionsThisTurn += 1
                    } else {
                        playerTurnDone = true
                    }
                case .influence(let cardId):
                    if simulation.playInfluence(cardId: cardId) {
                        influenceCount += 1
                        actionsThisTurn += 1
                    } else {
                        playerTurnDone = true
                    }
                case .sacrifice(let cardId):
                    if simulation.playCardAsSacrifice(cardId: cardId) {
                        sacrificeCount += 1
                        actionsThisTurn += 1
                    } else {
                        playerTurnDone = true
                    }
                case .endTurn:
                    playerTurnDone = true
                }
            }

            guard simulation.outcome == nil else { break }

            simulation.endPlayerTurn()

            let mode = EnemyAI.evaluateMode(state: &modeState, disposition: simulation.disposition)
            let enemyAction = EnemyAI.selectAction(
                mode: mode, simulation: simulation, rng: rng,
                baseDamage: baseDamage
            )
            EnemyActionResolver.resolve(action: enemyAction, simulation: &simulation)

            simulation.beginPlayerTurn()
        }

        return CombatSimulationResult(
            outcome: simulation.outcome,
            finalDisposition: simulation.disposition,
            turnsPlayed: turnsPlayed,
            heroHPRemaining: simulation.heroHP,
            cardsExhausted: simulation.exhaustPile.count,
            totalStrikeCount: strikeCount,
            totalInfluenceCount: influenceCount,
            totalSacrificeCount: sacrificeCount
        )
    }
}

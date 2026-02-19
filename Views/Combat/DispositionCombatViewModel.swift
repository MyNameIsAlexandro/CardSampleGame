/// Файл: Views/Combat/DispositionCombatViewModel.swift
/// Назначение: ViewModel-обёртка для DispositionCombatSimulation (App-layer adapter).
/// Зона ответственности: Маршрутизация card play команд через simulation API; SwiftUI binding.
/// Контекст: Epic 20 — Card Play App Integration. INV-DC-012..016.

import SwiftUI
import TwilightEngine

// MARK: - DispositionCombatViewModel

/// App-layer ViewModel wrapping `DispositionCombatSimulation`.
/// Scene/View calls ViewModel methods; ViewModel delegates to simulation.
/// No direct `DispositionCombatSimulation` access from Views (INV-DC-039).
final class DispositionCombatViewModel: ObservableObject {

    // MARK: - State

    private(set) var simulation: DispositionCombatSimulation

    // MARK: - Computed Properties (read-through to simulation)

    var disposition: Int { simulation.disposition }
    var outcome: DispositionOutcome? { simulation.outcome }
    var hand: [Card] { simulation.hand }
    var energy: Int { simulation.energy }
    var heroHP: Int { simulation.heroHP }
    var heroMaxHP: Int { simulation.heroMaxHP }
    var streakType: DispositionActionType? { simulation.streakType }
    var streakCount: Int { simulation.streakCount }
    var resonanceZone: TwilightEngine.ResonanceZone { simulation.resonanceZone }
    var enemyType: String { simulation.enemyType }
    var isAutoTurnEnd: Bool { simulation.isAutoTurnEnd }

    // MARK: - Tracking

    private(set) var turnsPlayed: Int = 0
    private(set) var cardsPlayed: Int = 0
    private let initialHeroHP: Int

    // MARK: - Init

    init(simulation: DispositionCombatSimulation) {
        self.simulation = simulation
        self.initialHeroHP = simulation.heroHP
    }

    // MARK: - Player Actions

    /// Play a card as strike. Returns true if accepted.
    @discardableResult
    func playStrike(cardId: String, targetId: String) -> Bool {
        let result = simulation.playStrike(cardId: cardId, targetId: targetId)
        if result {
            cardsPlayed += 1
            objectWillChange.send()
        }
        return result
    }

    /// Play a card as influence. Returns true if accepted.
    @discardableResult
    func playInfluence(cardId: String) -> Bool {
        let result = simulation.playInfluence(cardId: cardId)
        if result {
            cardsPlayed += 1
            objectWillChange.send()
        }
        return result
    }

    /// Play a card as sacrifice. Returns true if accepted.
    @discardableResult
    func playSacrifice(cardId: String) -> Bool {
        let result = simulation.playCardAsSacrifice(cardId: cardId)
        if result {
            cardsPlayed += 1
            objectWillChange.send()
        }
        return result
    }

    // MARK: - Turn Management

    func endTurn() {
        simulation.endPlayerTurn()
        turnsPlayed += 1
        objectWillChange.send()
    }

    func beginTurn() {
        simulation.beginPlayerTurn()
        objectWillChange.send()
    }

    // MARK: - Enemy Resolution

    /// Resolve enemy action against the simulation. Returns the action taken.
    @discardableResult
    func resolveEnemyAction(mode: EnemyMode) -> EnemyAction {
        let action = EnemyAI.selectAction(
            mode: mode,
            simulation: simulation,
            rng: simulation.rng
        )
        EnemyActionResolver.resolve(action: action, simulation: &simulation)
        objectWillChange.send()
        return action
    }

    /// Resolve a pre-computed enemy action (from intent telegraph).
    func resolveStoredAction(_ action: EnemyAction) {
        EnemyActionResolver.resolve(action: action, simulation: &simulation)
        objectWillChange.send()
    }

    // MARK: - Result

    /// Build combat result for bridge submission.
    func makeCombatResult(
        faithDelta: Int = 0,
        resonanceDelta: Float = 0,
        lootCardIds: [String] = []
    ) -> DispositionCombatResult {
        guard let outcome = simulation.outcome else {
            fatalError("Cannot build result before combat ends")
        }
        return DispositionCombatResult(
            outcome: outcome,
            finalDisposition: simulation.disposition,
            hpDelta: simulation.heroHP - initialHeroHP,
            faithDelta: faithDelta,
            resonanceDelta: resonanceDelta,
            lootCardIds: lootCardIds,
            updatedFateDeckState: nil,
            turnsPlayed: turnsPlayed,
            cardsPlayed: cardsPlayed
        )
    }
}

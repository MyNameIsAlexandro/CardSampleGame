/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Encounter/EncounterEngine+Persistence.swift
/// Назначение: Содержит реализацию файла EncounterEngine+Persistence.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

extension EncounterEngine {

    // MARK: - Save/Restore (SAV-03)

    /// Create a serializable snapshot of the current encounter state
    public func createSaveState() -> EncounterSaveState {
        EncounterSaveState(
            currentPhase: currentPhase,
            currentRound: currentRound,
            heroHP: heroHP,
            enemies: enemies,
            currentIntent: currentIntent,
            isFinished: isFinished,
            mulliganDone: mulliganDone,
            lastAttackTrack: lastAttackTrack,
            lastFateDrawResult: lastFateDrawResult,
            hand: hand,
            cardDiscardPile: cardDiscardPile,
            turnAttackBonus: turnAttackBonus,
            turnDefenseBonus: turnDefenseBonus,
            turnInfluenceBonus: turnInfluenceBonus,
            heroFaith: heroFaith,
            pendingFateChoice: pendingFateChoice,
            finishActionUsed: finishActionUsed,
            fleeSucceeded: fleeSucceeded,
            context: context,
            rngState: rng.currentState(),
            fateDeckState: fateDeck.getState(),
            accumulatedResonanceDelta: accumulatedResonanceDelta
        )
    }

    /// Restore an encounter from a saved state
    public static func restore(from state: EncounterSaveState) -> EncounterEngine {
        let engine = EncounterEngine(context: state.context)
        engine.currentPhase = state.currentPhase
        engine.currentRound = state.currentRound
        engine.heroHP = state.heroHP
        engine.enemies = state.enemies
        engine.currentIntent = state.currentIntent
        engine.isFinished = state.isFinished
        engine.mulliganDone = state.mulliganDone
        engine.lastAttackTrack = state.lastAttackTrack
        engine.lastFateDrawResult = state.lastFateDrawResult
        engine.hand = state.hand
        engine.cardDiscardPile = state.cardDiscardPile
        engine.turnAttackBonus = state.turnAttackBonus
        engine.turnDefenseBonus = state.turnDefenseBonus
        engine.turnInfluenceBonus = state.turnInfluenceBonus
        engine.heroFaith = state.heroFaith
        engine.pendingFateChoice = state.pendingFateChoice
        engine.finishActionUsed = state.finishActionUsed
        engine.fleeSucceeded = state.fleeSucceeded
        engine.accumulatedResonanceDelta = state.accumulatedResonanceDelta
        engine.rng.restoreState(state.rngState)
        engine.fateDeck.restoreState(state.fateDeckState)
        return engine
    }
}

/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/TwilightGameEngine+StateSupport.swift
/// Назначение: Содержит реализацию файла TwilightGameEngine+StateSupport.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

extension TwilightGameEngine {
    // MARK: - Combat Helpers (for EngineCombatManager)

    /// Mulligan: return selected cards to deck and draw replacements.
    func performCombatMulligan(cardIds: [String]) {
        deck.performMulligan(cardIds: cardIds)
    }

    /// Initialize combat deck: shuffle all cards and draw opening hand.
    func performCombatInitialize() {
        deck.initializeCombat()
    }

    // MARK: - Resonance Helpers

    /// Adjust resonance by delta, clamped to -100..+100.
    public func adjustResonance(by delta: Float) {
        setWorldResonance(resonanceValue + delta)
    }

    /// Set absolute world resonance with canonical clamping.
    func setWorldResonance(_ value: Float) {
        resonanceValue = max(-100, min(100, value))
    }

    // MARK: - External Combat Commit API

    /// Canonical app-facing entrypoint for committing external combat outcome.
    /// Keeps world-state mutation in action pipeline.
    @discardableResult
    public func commitExternalCombat(
        outcome: CombatEndOutcome,
        transaction: EncounterTransaction,
        updatedFateDeck: FateDeckState?
    ) -> ActionResult {
        performAction(.combatFinish(
            outcome: outcome,
            transaction: transaction,
            updatedFateDeck: updatedFateDeck
        ))
    }

    /// Snapshot current fate-deck ordering without RNG mutation.
    func fateDeckStateSnapshot() -> FateDeckState? {
        fateDeck?.getState()
    }
}

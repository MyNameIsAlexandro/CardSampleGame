/// Файл: Views/Combat/RitualCombatBridge.swift
/// Назначение: Адаптер результата ритуального боя в action-пайплайн TwilightEngine.
/// Зона ответственности: RitualCombatResult → engine.commitExternalCombat().
/// Контекст: Phase 3 Ritual Combat (R9). Паттерн аналогичен EchoCombatBridge.

import Foundation
import TwilightEngine

// MARK: - Ritual Combat Bridge

/// Converts `RitualCombatResult` into a canonical engine commit.
/// Used by Campaign path only — Arena does NOT call this (sandbox rule §1.5).
enum RitualCombatBridge {

    @discardableResult
    static func applyCombatResult(
        _ result: RitualCombatResult,
        to engine: TwilightGameEngine
    ) -> ActionResult {
        let transaction = EncounterTransaction(
            hpDelta: result.hpDelta,
            faithDelta: result.faithDelta,
            resonanceDelta: result.resonanceDelta,
            worldFlags: [:],
            lootCardIds: result.lootCardIds
        )

        let engineOutcome: CombatEndOutcome = result.outcome.isVictory ? .victory : .defeat

        return engine.commitExternalCombat(
            outcome: engineOutcome,
            transaction: transaction,
            updatedFateDeck: result.updatedFateDeckState
        )
    }
}

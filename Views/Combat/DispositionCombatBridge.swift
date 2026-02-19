/// Файл: Views/Combat/DispositionCombatBridge.swift
/// Назначение: Адаптер результата Disposition Combat в action-пайплайн TwilightEngine.
/// Зона ответственности: DispositionCombatResult → engine.commitExternalCombat().
/// Контекст: Epic 20 — Card Play App Integration. Паттерн аналогичен RitualCombatBridge.

import Foundation
import TwilightEngine

// MARK: - Disposition Combat Bridge

/// Converts `DispositionCombatResult` into a canonical engine commit.
/// Used by Campaign path only — Arena does NOT call this (sandbox rule §1.5).
enum DispositionCombatBridge {

    @discardableResult
    static func applyCombatResult(
        _ result: DispositionCombatResult,
        to engine: TwilightGameEngine
    ) -> ActionResult {
        let transaction = EncounterTransaction(
            hpDelta: result.hpDelta,
            faithDelta: result.faithDelta,
            resonanceDelta: result.resonanceDelta,
            worldFlags: [:],
            lootCardIds: result.lootCardIds
        )

        return engine.commitExternalCombat(
            outcome: result.engineOutcome,
            transaction: transaction,
            updatedFateDeck: result.updatedFateDeckState
        )
    }
}

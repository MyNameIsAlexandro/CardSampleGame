/// Файл: Views/Combat/EchoCombatBridge.swift
/// Назначение: Содержит реализацию файла EchoCombatBridge.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import Foundation
import TwilightEngine
import EchoEngine

// MARK: - EchoCombatResult → TwilightGameEngine Bridge

/// Адаптер результата боя EchoEngine в action-пайплайн TwilightEngine.
enum EchoCombatBridge {

    /// Canonical adapter from Echo combat result into engine action pipeline.
    /// Keeps all world-state mutations inside `commitExternalCombat(...)`.
    @discardableResult
    static func applyCombatResult(
        _ result: EchoCombatResult,
        to engine: TwilightGameEngine
    ) -> ActionResult {
        let transaction = EncounterTransaction(
            hpDelta: result.hpDelta,
            faithDelta: result.faithDelta,
            resonanceDelta: Float(result.resonanceDelta),
            worldFlags: [:],
            lootCardIds: result.lootCardIds
        )

        switch result.outcome {
        case .victory:
            return engine.commitExternalCombat(
                outcome: .victory,
                transaction: transaction,
                updatedFateDeck: result.updatedFateDeckState
            )
        case .defeat:
            return engine.commitExternalCombat(
                outcome: .defeat,
                transaction: transaction,
                updatedFateDeck: result.updatedFateDeckState
            )
        }
    }
}

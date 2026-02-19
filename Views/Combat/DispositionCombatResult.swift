/// Файл: Views/Combat/DispositionCombatResult.swift
/// Назначение: DTO результата Disposition Combat для передачи через Bridge.
/// Зона ответственности: Типы исхода и полный результат Disposition Combat боя.
/// Контекст: Epic 20 — Card Play App Integration. Паттерн аналогичен RitualCombatResult.

import TwilightEngine

// MARK: - Disposition Combat Result

/// Full result of a disposition combat for bridge/UI consumption.
struct DispositionCombatResult: Equatable {
    let outcome: DispositionOutcome
    let finalDisposition: Int
    let hpDelta: Int
    let faithDelta: Int
    let resonanceDelta: Float
    let lootCardIds: [String]
    let updatedFateDeckState: FateDeckState?
    let turnsPlayed: Int
    let cardsPlayed: Int

    /// Map disposition outcome to engine combat outcome.
    var engineOutcome: CombatEndOutcome {
        switch outcome {
        case .destroyed: return .victory
        case .subjugated: return .victory
        case .defeated: return .defeat
        }
    }
}

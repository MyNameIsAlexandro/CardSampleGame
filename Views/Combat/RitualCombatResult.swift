/// Файл: Views/Combat/RitualCombatResult.swift
/// Назначение: DTO результата ритуального боя для обратной связи с вызывающим экраном.
/// Зона ответственности: Передача результата из RitualCombatScene в Arena/Campaign bridge.
/// Контекст: Phase 3 Ritual Combat (R9). Не зависит от EchoEngine.

import TwilightEngine

// MARK: - Victory Type

/// Victory sub-type for ritual combat.
enum RitualVictoryType: Equatable {
    case killed
    case pacified
}

// MARK: - Combat Outcome

/// Outcome of a completed ritual combat.
enum RitualCombatOutcome: Equatable {
    case victory(RitualVictoryType)
    case defeat

    var isVictory: Bool {
        if case .victory = self { return true }
        return false
    }
}

// MARK: - Combat Result

/// Full result of a ritual combat for bridge/UI consumption.
struct RitualCombatResult: Equatable {
    let outcome: RitualCombatOutcome
    let hpDelta: Int
    let resonanceDelta: Float
    let faithDelta: Int
    let lootCardIds: [String]
    let updatedFateDeckState: FateDeckState?
    let turnsPlayed: Int
    let totalDamageDealt: Int
    let totalDamageTaken: Int
    let cardsPlayed: Int
}

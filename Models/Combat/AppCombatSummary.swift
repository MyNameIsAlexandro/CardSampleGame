/// Файл: Models/Combat/AppCombatSummary.swift
/// Назначение: Содержит реализацию файла AppCombatSummary.swift.
/// Зона ответственности: Описывает предметные модели и их инварианты.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import Foundation

/// Сводка результата боя на уровне приложения.
/// Используется только UI-слоем (арена/ивенты) и не заменяет engine/scene модели.
enum AppCombatOutcome: Equatable {
    case victory(stats: AppCombatStats)
    case defeat(stats: AppCombatStats)
    case fled

    var isVictory: Bool {
        if case .victory = self { return true }
        return false
    }
}

/// Минимальная статистика боя для экранов итогов и оверлеев.
struct AppCombatStats: Equatable {
    let turnsPlayed: Int
    let totalDamageDealt: Int
    let totalDamageTaken: Int
    let cardsPlayed: Int

    var summary: String {
        L10n.combatTurnsStats.localized(with: turnsPlayed, totalDamageDealt, totalDamageTaken)
    }
}

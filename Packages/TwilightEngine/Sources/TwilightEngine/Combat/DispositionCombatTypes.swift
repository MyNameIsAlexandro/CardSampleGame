/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Combat/DispositionCombatTypes.swift
/// Назначение: Shared value types for Disposition Combat system.
/// Зона ответственности: Enums для outcome, action type — используются DispositionCombatSimulation, DispositionCalculator, EnemyAI.
/// Контекст: Extracted from DispositionCombatSimulation.swift for file-size compliance (CLAUDE.md §5.1).

// MARK: - Disposition Combat Value Types

/// Outcome of a disposition combat encounter.
public enum DispositionOutcome: Equatable, Codable, Sendable {
    /// Enemy is destroyed (disposition reached -100). Player victory by force.
    case destroyed
    /// Enemy is subjugated (disposition reached +100). Player victory by diplomacy.
    case subjugated
    /// Hero HP reached 0. Player defeat.
    case defeated
}

/// Type of player action in disposition combat.
public enum DispositionActionType: Equatable, Codable, Sendable {
    case strike
    case influence
    case sacrifice
}

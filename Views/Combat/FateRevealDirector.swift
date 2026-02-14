/// Файл: Views/Combat/FateRevealDirector.swift
/// Назначение: Режиссёр анимации раскрытия Fate-карты (3D flip, keyword effects).
/// Зона ответственности: Animation state machine, event-driven (без хранения ссылки на Simulation).
/// Контекст: Phase 3 Ritual Combat (R6). Reference: RITUAL_COMBAT_TEST_MODEL.md §3.5

import SpriteKit

// MARK: - Reveal Phase

/// Animation phase of the fate card reveal sequence.
enum FateRevealPhase: Equatable {
    case idle
    case anticipation
    case flip
    case suitMatch
    case keywordEffect
    case complete
}

// MARK: - Fate Reveal Director

/// Directs the fate card reveal animation sequence.
/// Event-driven: receives fate draw results via method calls, not stored simulation reference.
/// This preserves determinism — the director is a pure presentation observer.
final class FateRevealDirector {

    /// Current animation phase
    private(set) var phase: FateRevealPhase = .idle

    /// Total reveal duration (seconds)
    let revealDuration: TimeInterval = 2.5

    /// Callback when reveal sequence completes
    var onRevealComplete: (() -> Void)?

    /// Begin a fate reveal animation for a drawn card.
    /// - Parameters:
    ///   - cardName: Display name of the drawn fate card
    ///   - effectiveValue: Resolved value after resonance rules
    ///   - isSuitMatch: Whether card suit matches action alignment
    ///   - isCritical: Whether this is a critical draw
    func beginReveal(
        cardName: String,
        effectiveValue: Int,
        isSuitMatch: Bool,
        isCritical: Bool
    ) {
        phase = .anticipation
    }

    /// Reset director to idle state.
    func reset() {
        phase = .idle
    }
}

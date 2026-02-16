/// Файл: Views/Combat/RitualThemeConstants.swift
/// Назначение: Центральные константы визуальной темы Ритуального Боя.
/// Зона ответственности: Размеры, углы, тайминги, пороги. Без логики — только значения.
/// Контекст: Phase 3 Ritual Combat. Epic 4 — Card Hand Polish.

import Foundation

/// Centralized theme constants for the Ritual Combat scene.
enum RitualTheme {

    // MARK: - Card Dimensions

    /// Base card size in hand (100×140 per design spec).
    static let cardSize = CGSize(width: 100, height: 140)

    /// Fan angle step per card offset from center (degrees).
    static let fanAngleStep: CGFloat = 8.0

    /// Base overlap spacing between cards in hand.
    static let baseOverlapSpacing: CGFloat = 60

    /// Maximum number of cards before scaling kicks in.
    static let scaleThreshold: Int = 7

    /// Y offset per unit distance from center card.
    static let arcYDropPerUnit: CGFloat = 8

    /// Lift height when card is selected.
    static let selectedLift: CGFloat = 22

    // MARK: - Card Sway

    /// Idle sway amplitude (radians).
    static let swayAmplitude: CGFloat = 0.015

    /// Idle sway full cycle duration (seconds).
    static let swayCycleDuration: TimeInterval = 2.5

    /// Stagger offset per card index (seconds).
    static let swayStagger: TimeInterval = 0.3

    // MARK: - Drag

    /// Scale factor when card is lifted for drag.
    static let dragLiftScale: CGFloat = 1.3

    /// Shadow offset when card is lifted.
    static let dragShadowOffset = CGPoint(x: 4, y: -4)
}

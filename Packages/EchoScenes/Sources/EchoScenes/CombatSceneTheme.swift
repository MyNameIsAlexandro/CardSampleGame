/// Файл: Packages/EchoScenes/Sources/EchoScenes/CombatSceneTheme.swift
/// Назначение: Содержит реализацию файла CombatSceneTheme.swift.
/// Зона ответственности: Реализует визуально-сценовый слой EchoScenes.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import SpriteKit

/// Design system colors for SpriteKit combat scenes.
/// Mirrors AppColors from the main app (which uses SwiftUI Color).
public enum CombatSceneTheme {
    // Backgrounds
    public static let background = SKColor(red: 0.08, green: 0.06, blue: 0.10, alpha: 1)
    public static let backgroundLight = SKColor(red: 0.12, green: 0.10, blue: 0.15, alpha: 1)
    public static let cardBack = SKColor(red: 0.12, green: 0.18, blue: 0.30, alpha: 1)

    // Game state
    public static let health = SKColor(red: 0.90, green: 0.35, blue: 0.35, alpha: 1)
    public static let success = SKColor(red: 0.20, green: 0.62, blue: 0.30, alpha: 1)
    public static let faith = SKColor(red: 0.90, green: 0.75, blue: 0.25, alpha: 1)

    // Accents
    public static let primary = SKColor(red: 0.85, green: 0.65, blue: 0.20, alpha: 1)
    public static let highlight = SKColor(red: 0.90, green: 0.75, blue: 0.30, alpha: 1)
    public static let spirit = SKColor(red: 0.40, green: 0.58, blue: 0.95, alpha: 1)

    // UI
    public static let muted = SKColor(red: 0.65, green: 0.60, blue: 0.65, alpha: 1)
    public static let separator = SKColor(white: 0.25, alpha: 1)
}

/// Файл: Packages/StoryPacks/Season1/TwilightMarchesActI/Sources/TwilightMarchesActIContent/TwilightMarchesActIContent.swift
/// Назначение: Содержит реализацию файла TwilightMarchesActIContent.swift.
/// Зона ответственности: Изолирован своей предметной ответственностью в рамках модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// TwilightMarchesActI story pack
/// Provides Act I campaign content: regions, events, quests, anchors, enemies
public enum TwilightMarchesActIContent {
    /// URL to the TwilightMarchesActI.pack binary file
    public static var packURL: URL? {
        Bundle.module.url(forResource: "TwilightMarchesActI", withExtension: "pack")
    }

    /// Pack identifier
    public static let packId = "twilight-marches-act1"
}

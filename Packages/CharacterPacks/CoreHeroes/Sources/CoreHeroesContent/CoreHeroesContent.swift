/// Файл: Packages/CharacterPacks/CoreHeroes/Sources/CoreHeroesContent/CoreHeroesContent.swift
/// Назначение: Содержит реализацию файла CoreHeroesContent.swift.
/// Зона ответственности: Изолирован своей предметной ответственностью в рамках модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// CoreHeroes content pack
/// Provides base heroes and their class-specific cards
public enum CoreHeroesContent {
    /// URL to the CoreHeroes.pack binary file
    public static var packURL: URL? {
        Bundle.module.url(forResource: "CoreHeroes", withExtension: "pack")
    }

    /// Pack identifier
    public static let packId = "core-heroes"
}

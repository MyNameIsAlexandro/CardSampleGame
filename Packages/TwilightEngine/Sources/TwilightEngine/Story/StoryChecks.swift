/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Story/StoryChecks.swift
/// Назначение: Содержит реализацию файла StoryChecks.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Victory/Defeat Checks

public struct VictoryCheck {
    let isVictory: Bool
    let endingId: String?
    let description: LocalizedString?
}

public struct DefeatCheck {
    let isDefeat: Bool
    let reason: DefeatReason?
    let description: LocalizedString?
}

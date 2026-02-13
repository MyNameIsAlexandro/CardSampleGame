/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/TimeEngine+ExploreAction.swift
/// Назначение: Содержит реализацию файла TimeEngine+ExploreAction.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// Exploration action.
public struct ExploreAction: TimedAction {
    public let isInstant: Bool

    public init(isInstant: Bool) {
        self.isInstant = isInstant
    }

    public var timeCost: Int { isInstant ? 0 : 1 }
}

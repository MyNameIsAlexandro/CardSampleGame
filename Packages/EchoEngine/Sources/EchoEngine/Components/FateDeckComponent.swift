/// Файл: Packages/EchoEngine/Sources/EchoEngine/Components/FateDeckComponent.swift
/// Назначение: Содержит реализацию файла FateDeckComponent.swift.
/// Зона ответственности: Реализует боевой пакет EchoEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import FirebladeECS
import TwilightEngine

public final class FateDeckComponent: Component {
    public var fateDeck: FateDeckManager

    public init(fateDeck: FateDeckManager) {
        self.fateDeck = fateDeck
    }
}

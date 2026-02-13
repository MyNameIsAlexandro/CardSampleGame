/// Файл: Packages/EchoEngine/Sources/EchoEngine/Components/DeckComponent.swift
/// Назначение: Содержит реализацию файла DeckComponent.swift.
/// Зона ответственности: Реализует боевой пакет EchoEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import FirebladeECS
import TwilightEngine

public final class DeckComponent: Component {
    public var drawPile: [Card]
    public var hand: [Card]
    public var discardPile: [Card]
    public var exhaustPile: [Card]

    public init(drawPile: [Card] = [], hand: [Card] = [], discardPile: [Card] = []) {
        self.drawPile = drawPile
        self.hand = hand
        self.discardPile = discardPile
        self.exhaustPile = []
    }
}

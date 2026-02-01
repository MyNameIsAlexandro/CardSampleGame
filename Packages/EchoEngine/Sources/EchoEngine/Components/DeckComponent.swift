import FirebladeECS
import TwilightEngine

public final class DeckComponent: Component {
    public var drawPile: [Card]
    public var hand: [Card]
    public var discardPile: [Card]

    public init(drawPile: [Card] = [], hand: [Card] = [], discardPile: [Card] = []) {
        self.drawPile = drawPile
        self.hand = hand
        self.discardPile = discardPile
    }
}

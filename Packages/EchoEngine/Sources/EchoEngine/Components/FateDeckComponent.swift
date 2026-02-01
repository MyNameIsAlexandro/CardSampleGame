import FirebladeECS
import TwilightEngine

public final class FateDeckComponent: Component {
    public var fateDeck: FateDeckManager

    public init(fateDeck: FateDeckManager) {
        self.fateDeck = fateDeck
    }
}

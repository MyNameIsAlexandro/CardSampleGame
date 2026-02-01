import FirebladeECS
import TwilightEngine

public final class IntentComponent: Component {
    public var intent: EnemyIntent?

    public init(intent: EnemyIntent? = nil) {
        self.intent = intent
    }
}

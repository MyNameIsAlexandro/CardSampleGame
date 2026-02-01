import FirebladeECS
import TwilightEngine

public final class EnemyTagComponent: Component {
    public var definitionId: String
    public var power: Int
    public var defense: Int
    public var pattern: [EnemyPatternStep]?

    public init(definitionId: String, power: Int, defense: Int, pattern: [EnemyPatternStep]? = nil) {
        self.definitionId = definitionId
        self.power = power
        self.defense = defense
        self.pattern = pattern
    }
}

import FirebladeECS
import TwilightEngine

public final class EnemyTagComponent: Component {
    public var definitionId: String
    public var power: Int
    public var defense: Int
    public var pattern: [EnemyPatternStep]?
    public var faithReward: Int
    public var lootCardIds: [String]

    public init(
        definitionId: String,
        power: Int,
        defense: Int,
        pattern: [EnemyPatternStep]? = nil,
        faithReward: Int = 0,
        lootCardIds: [String] = []
    ) {
        self.definitionId = definitionId
        self.power = power
        self.defense = defense
        self.pattern = pattern
        self.faithReward = faithReward
        self.lootCardIds = lootCardIds
    }
}

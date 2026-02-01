import FirebladeECS

public final class EnemyTagComponent: Component {
    public var definitionId: String
    public var power: Int
    public var defense: Int

    public init(definitionId: String, power: Int, defense: Int) {
        self.definitionId = definitionId
        self.power = power
        self.defense = defense
    }
}

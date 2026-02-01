import FirebladeECS

public final class PlayerTagComponent: Component {
    public var name: String
    public var strength: Int

    public init(name: String = "Hero", strength: Int = 5) {
        self.name = name
        self.strength = strength
    }
}

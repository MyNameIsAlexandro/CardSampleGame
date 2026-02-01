import FirebladeECS

public final class EnergyComponent: Component {
    public var current: Int
    public var max: Int

    public init(current: Int = 3, max: Int = 3) {
        self.current = current
        self.max = max
    }
}

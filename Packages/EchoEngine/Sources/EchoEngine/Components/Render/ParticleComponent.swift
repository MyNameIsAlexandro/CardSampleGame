import FirebladeECS

public final class ParticleComponent: Component {
    public var emitterName: String?
    public var isActive: Bool
    public var removeWhenDone: Bool

    public init(emitterName: String? = nil, isActive: Bool = false, removeWhenDone: Bool = true) {
        self.emitterName = emitterName
        self.isActive = isActive
        self.removeWhenDone = removeWhenDone
    }
}

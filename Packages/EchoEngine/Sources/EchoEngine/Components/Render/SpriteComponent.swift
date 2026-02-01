import FirebladeECS
import CoreGraphics

public final class SpriteComponent: Component {
    public var textureName: String
    public var position: CGPoint
    public var scale: CGFloat
    public var zPosition: CGFloat
    public var alpha: CGFloat
    public var isHidden: Bool
    public var isDirty: Bool

    public init(
        textureName: String,
        position: CGPoint = .zero,
        scale: CGFloat = 1.0,
        zPosition: CGFloat = 0,
        alpha: CGFloat = 1.0
    ) {
        self.textureName = textureName
        self.position = position
        self.scale = scale
        self.zPosition = zPosition
        self.alpha = alpha
        self.isHidden = false
        self.isDirty = true
    }
}

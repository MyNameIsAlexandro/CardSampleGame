import Foundation
import FirebladeECS
import CoreGraphics

public final class AnimationComponent: Component {

    public enum AnimationAction {
        case moveTo(CGPoint, duration: TimeInterval)
        case fadeAlpha(CGFloat, duration: TimeInterval)
        case scaleTo(CGFloat, duration: TimeInterval)
        case shake(intensity: CGFloat, duration: TimeInterval)
        case flash(colorName: String, duration: TimeInterval)
        case sequence([AnimationAction])
        case wait(TimeInterval)
    }

    public var queue: [AnimationAction]
    public var isPlaying: Bool

    public init() {
        self.queue = []
        self.isPlaying = false
    }

    public func enqueue(_ action: AnimationAction) {
        queue.append(action)
    }
}

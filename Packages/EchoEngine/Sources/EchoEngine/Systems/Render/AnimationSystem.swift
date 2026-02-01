import SpriteKit
import FirebladeECS

public final class AnimationSystem: EchoSystem {
    public let registry: NodeRegistry

    public init(registry: NodeRegistry) {
        self.registry = registry
    }

    public func update(nexus: Nexus) {
        let family = nexus.family(requires: AnimationComponent.self)
        for entity in family.entities {
            let anim: AnimationComponent = nexus.get(unsafe: entity.identifier)
            guard !anim.queue.isEmpty, !anim.isPlaying else { continue }
            guard let node = registry.node(for: entity.identifier) else { continue }

            anim.isPlaying = true
            let actions = anim.queue.map { skAction(from: $0) }
            anim.queue.removeAll()
            node.run(SKAction.sequence(actions)) {
                anim.isPlaying = false
            }
        }
    }

    private func skAction(from action: AnimationComponent.AnimationAction) -> SKAction {
        switch action {
        case .moveTo(let point, let duration):
            return SKAction.move(to: point, duration: duration)
        case .fadeAlpha(let alpha, let duration):
            return SKAction.fadeAlpha(to: alpha, duration: duration)
        case .scaleTo(let scale, let duration):
            return SKAction.scale(to: scale, duration: duration)
        case .shake(let intensity, let duration):
            return shakeAction(intensity: intensity, duration: duration)
        case .flash(let colorName, let duration):
            return flashAction(colorName: colorName, duration: duration)
        case .sequence(let actions):
            return SKAction.sequence(actions.map { skAction(from: $0) })
        case .wait(let duration):
            return SKAction.wait(forDuration: duration)
        }
    }

    private func shakeAction(intensity: CGFloat, duration: TimeInterval) -> SKAction {
        let count = Int(duration / 0.04)
        var actions: [SKAction] = []
        for _ in 0..<count {
            let dx = CGFloat.random(in: -intensity...intensity)
            let dy = CGFloat.random(in: -intensity...intensity)
            actions.append(SKAction.moveBy(x: dx, y: dy, duration: 0.02))
            actions.append(SKAction.moveBy(x: -dx, y: -dy, duration: 0.02))
        }
        return SKAction.sequence(actions)
    }

    private func flashAction(colorName: String, duration: TimeInterval) -> SKAction {
        let half = duration / 2
        return SKAction.sequence([
            SKAction.colorize(with: .white, colorBlendFactor: 0.8, duration: half),
            SKAction.colorize(withColorBlendFactor: 0.0, duration: half)
        ])
    }
}

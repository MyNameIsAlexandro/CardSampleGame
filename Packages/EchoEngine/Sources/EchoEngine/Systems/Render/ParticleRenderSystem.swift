import SpriteKit
import FirebladeECS

public final class ParticleRenderSystem: EchoSystem {
    public let registry: NodeRegistry

    private static let emitterKey = "echo_particle_emitter"

    public init(registry: NodeRegistry) {
        self.registry = registry
    }

    public func update(nexus: Nexus) {
        let family = nexus.family(requires: ParticleComponent.self)
        for entity in family.entities {
            let particle: ParticleComponent = nexus.get(unsafe: entity.identifier)
            guard let parent = registry.node(for: entity.identifier) else { continue }

            if particle.isActive, let name = particle.emitterName {
                if parent.childNode(withName: Self.emitterKey) == nil {
                    if let emitter = SKEmitterNode(fileNamed: name) {
                        emitter.name = Self.emitterKey
                        parent.addChild(emitter)
                    }
                }
            } else {
                parent.childNode(withName: Self.emitterKey)?.removeFromParent()
            }
        }
    }
}

import SpriteKit
import FirebladeECS

public final class NodeRegistry {
    public let scene: SKScene
    private var nodes: [EntityIdentifier: SKNode] = [:]

    public init(scene: SKScene) {
        self.scene = scene
    }

    public func node(for entityId: EntityIdentifier) -> SKNode? {
        nodes[entityId]
    }

    public func register(_ node: SKNode, for entityId: EntityIdentifier) {
        nodes[entityId]?.removeFromParent()
        nodes[entityId] = node
        scene.addChild(node)
    }

    public func remove(for entityId: EntityIdentifier) {
        nodes[entityId]?.removeFromParent()
        nodes[entityId] = nil
    }

    public var allEntityIds: [EntityIdentifier] {
        Array(nodes.keys)
    }

    public var count: Int { nodes.count }
}

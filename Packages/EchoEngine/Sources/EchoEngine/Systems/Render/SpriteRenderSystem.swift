/// Файл: Packages/EchoEngine/Sources/EchoEngine/Systems/Render/SpriteRenderSystem.swift
/// Назначение: Содержит реализацию файла SpriteRenderSystem.swift.
/// Зона ответственности: Реализует боевой пакет EchoEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import SpriteKit
import FirebladeECS

public final class SpriteRenderSystem: EchoSystem {
    public let registry: NodeRegistry

    public init(registry: NodeRegistry) {
        self.registry = registry
    }

    public func update(nexus: Nexus) {
        let family = nexus.family(requires: SpriteComponent.self)
        for entity in family.entities {
            let sprite: SpriteComponent = nexus.get(unsafe: entity.identifier)

            if let existing = registry.node(for: entity.identifier) as? SKSpriteNode {
                existing.position = sprite.position
                existing.setScale(sprite.scale)
                existing.zPosition = sprite.zPosition
                existing.alpha = sprite.alpha
                existing.isHidden = sprite.isHidden
                sprite.isDirty = false
            } else {
                let node = SKSpriteNode(imageNamed: sprite.textureName)
                node.position = sprite.position
                node.setScale(sprite.scale)
                node.zPosition = sprite.zPosition
                node.alpha = sprite.alpha
                node.isHidden = sprite.isHidden
                registry.register(node, for: entity.identifier)
                sprite.isDirty = false
            }
        }
    }
}

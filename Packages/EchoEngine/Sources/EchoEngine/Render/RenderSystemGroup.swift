/// Файл: Packages/EchoEngine/Sources/EchoEngine/Render/RenderSystemGroup.swift
/// Назначение: Содержит реализацию файла RenderSystemGroup.swift.
/// Зона ответственности: Реализует боевой пакет EchoEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import SpriteKit
import FirebladeECS

public final class RenderSystemGroup {
    public let registry: NodeRegistry
    private let systems: [EchoSystem]

    public init(scene: SKScene) {
        self.registry = NodeRegistry(scene: scene)
        self.systems = [
            SpriteRenderSystem(registry: registry),
            UIRenderSystem(registry: registry),
            AnimationSystem(registry: registry),
            ParticleRenderSystem(registry: registry),
        ]
    }

    public func update(nexus: Nexus) {
        for system in systems {
            system.update(nexus: nexus)
        }
    }

    public func cleanup(nexus: Nexus) {
        for entityId in registry.allEntityIds {
            if !nexus.exists(entity: entityId) {
                registry.remove(for: entityId)
            }
        }
    }
}

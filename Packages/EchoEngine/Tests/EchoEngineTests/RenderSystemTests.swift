/// Файл: Packages/EchoEngine/Tests/EchoEngineTests/RenderSystemTests.swift
/// Назначение: Содержит реализацию файла RenderSystemTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import Testing
import SpriteKit
import FirebladeECS
@testable import EchoEngine

@Suite("Render System Tests")
struct RenderSystemTests {

    // MARK: - NodeRegistry

    @Test("NodeRegistry register and lookup")
    func testNodeRegistry() {
        let scene = SKScene(size: CGSize(width: 300, height: 300))
        let registry = NodeRegistry(scene: scene)
        let entityId = EntityIdentifier(1)

        let node = SKSpriteNode(color: .red, size: CGSize(width: 10, height: 10))
        registry.register(node, for: entityId)

        #expect(registry.node(for: entityId) === node)
        #expect(registry.count == 1)
        #expect(scene.children.contains(node))
    }

    @Test("NodeRegistry remove cleans up")
    func testNodeRegistryRemove() {
        let scene = SKScene(size: CGSize(width: 300, height: 300))
        let registry = NodeRegistry(scene: scene)
        let entityId = EntityIdentifier(1)

        let node = SKSpriteNode(color: .red, size: CGSize(width: 10, height: 10))
        registry.register(node, for: entityId)
        registry.remove(for: entityId)

        #expect(registry.node(for: entityId) == nil)
        #expect(registry.count == 0)
        #expect(node.parent == nil)
    }

    // MARK: - SpriteRenderSystem

    @Test("SpriteRenderSystem creates node from SpriteComponent")
    func testSpriteRenderCreatesNode() {
        let scene = SKScene(size: CGSize(width: 300, height: 300))
        let registry = NodeRegistry(scene: scene)
        let system = SpriteRenderSystem(registry: registry)
        let nexus = Nexus()

        let entity = nexus.createEntity()
        entity.assign(SpriteComponent(
            textureName: "test_sprite",
            position: CGPoint(x: 100, y: 150),
            scale: 2.0,
            zPosition: 5
        ))

        system.update(nexus: nexus)

        let node = registry.node(for: entity.identifier) as? SKSpriteNode
        #expect(node != nil)
        #expect(node?.position == CGPoint(x: 100, y: 150))
        #expect(node?.xScale == 2.0)
        #expect(node?.zPosition == 5)
    }

    @Test("SpriteRenderSystem syncs updated position")
    func testSpriteRenderSyncs() {
        let scene = SKScene(size: CGSize(width: 300, height: 300))
        let registry = NodeRegistry(scene: scene)
        let system = SpriteRenderSystem(registry: registry)
        let nexus = Nexus()

        let entity = nexus.createEntity()
        let sprite = SpriteComponent(textureName: "test", position: CGPoint(x: 10, y: 10))
        entity.assign(sprite)

        system.update(nexus: nexus)

        sprite.position = CGPoint(x: 200, y: 300)
        sprite.alpha = 0.5
        system.update(nexus: nexus)

        let node = registry.node(for: entity.identifier) as? SKSpriteNode
        #expect(node?.position == CGPoint(x: 200, y: 300))
        #expect(node?.alpha == 0.5)
    }

    // MARK: - UIRenderSystem

    @Test("UIRenderSystem creates health bar nodes")
    func testUIRenderHealthBar() {
        let scene = SKScene(size: CGSize(width: 300, height: 300))
        let registry = NodeRegistry(scene: scene)

        let nexus = Nexus()
        let entity = nexus.createEntity()
        entity.assign(SpriteComponent(textureName: "enemy", position: .zero))
        entity.assign(HealthComponent(current: 5, max: 10))
        entity.assign(HealthBarComponent(barWidth: 60, verticalOffset: -40))

        // First create the sprite node
        let spriteSystem = SpriteRenderSystem(registry: registry)
        spriteSystem.update(nexus: nexus)

        // Then render UI
        let uiSystem = UIRenderSystem(registry: registry)
        uiSystem.update(nexus: nexus)

        let parentNode = registry.node(for: entity.identifier)
        let hpBar = parentNode?.childNode(withName: "echo_hp_bar")
        let hpBg = parentNode?.childNode(withName: "echo_hp_bar_bg")

        #expect(hpBar != nil)
        #expect(hpBg != nil)
    }

    @Test("UIRenderSystem creates label nodes")
    func testUIRenderLabel() {
        let scene = SKScene(size: CGSize(width: 300, height: 300))
        let registry = NodeRegistry(scene: scene)

        let nexus = Nexus()
        let entity = nexus.createEntity()
        entity.assign(SpriteComponent(textureName: "enemy", position: .zero))
        entity.assign(LabelComponent(text: "Wolf", colorName: "red", verticalOffset: 30))

        let spriteSystem = SpriteRenderSystem(registry: registry)
        spriteSystem.update(nexus: nexus)

        let uiSystem = UIRenderSystem(registry: registry)
        uiSystem.update(nexus: nexus)

        let parentNode = registry.node(for: entity.identifier)
        let label = parentNode?.childNode(withName: "echo_label") as? SKLabelNode
        #expect(label != nil)
        #expect(label?.text == "Wolf")
    }

    // MARK: - AnimationSystem

    @Test("AnimationSystem dequeues and sets isPlaying")
    func testAnimationDequeues() {
        let scene = SKScene(size: CGSize(width: 300, height: 300))
        let registry = NodeRegistry(scene: scene)
        let nexus = Nexus()

        let entity = nexus.createEntity()
        entity.assign(SpriteComponent(textureName: "test", position: .zero))

        let anim = AnimationComponent()
        anim.enqueue(.moveTo(CGPoint(x: 50, y: 50), duration: 0.1))
        entity.assign(anim)

        // Create sprite node first
        SpriteRenderSystem(registry: registry).update(nexus: nexus)

        let animSystem = AnimationSystem(registry: registry)
        animSystem.update(nexus: nexus)

        #expect(anim.isPlaying == true)
        #expect(anim.queue.isEmpty)
    }

    @Test("AnimationSystem skips when already playing")
    func testAnimationSkipsWhenPlaying() {
        let scene = SKScene(size: CGSize(width: 300, height: 300))
        let registry = NodeRegistry(scene: scene)
        let nexus = Nexus()

        let entity = nexus.createEntity()
        entity.assign(SpriteComponent(textureName: "test", position: .zero))

        let anim = AnimationComponent()
        anim.isPlaying = true
        anim.enqueue(.wait(1.0))
        entity.assign(anim)

        SpriteRenderSystem(registry: registry).update(nexus: nexus)
        AnimationSystem(registry: registry).update(nexus: nexus)

        #expect(anim.queue.count == 1) // not dequeued
    }

    // MARK: - RenderSystemGroup

    @Test("RenderSystemGroup runs all systems")
    func testRenderSystemGroup() {
        let scene = SKScene(size: CGSize(width: 300, height: 300))
        let group = RenderSystemGroup(scene: scene)
        let nexus = Nexus()

        let entity = nexus.createEntity()
        entity.assign(SpriteComponent(textureName: "wolf", position: CGPoint(x: 100, y: 100)))
        entity.assign(HealthComponent(current: 8, max: 10))
        entity.assign(HealthBarComponent())
        entity.assign(LabelComponent(text: "Wolf"))

        group.update(nexus: nexus)

        let node = group.registry.node(for: entity.identifier)
        #expect(node != nil)
        #expect(node?.childNode(withName: "echo_hp_bar") != nil)
        #expect(node?.childNode(withName: "echo_label") != nil)
    }

    @Test("RenderSystemGroup cleanup removes orphan nodes")
    func testCleanup() {
        let scene = SKScene(size: CGSize(width: 300, height: 300))
        let group = RenderSystemGroup(scene: scene)
        let nexus = Nexus()

        let entity = nexus.createEntity()
        entity.assign(SpriteComponent(textureName: "wolf", position: .zero))
        group.update(nexus: nexus)

        #expect(group.registry.count == 1)

        nexus.destroy(entity: entity)
        group.cleanup(nexus: nexus)

        #expect(group.registry.count == 0)
    }
}

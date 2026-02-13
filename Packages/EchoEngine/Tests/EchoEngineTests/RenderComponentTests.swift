/// Файл: Packages/EchoEngine/Tests/EchoEngineTests/RenderComponentTests.swift
/// Назначение: Содержит реализацию файла RenderComponentTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import Testing
import FirebladeECS
import CoreGraphics
@testable import EchoEngine

@Suite("Render Component Tests")
struct RenderComponentTests {

    @Test("SpriteComponent stores position and texture")
    func testSpriteComponent() {
        let nexus = Nexus()
        let entity = nexus.createEntity()
        entity.assign(SpriteComponent(textureName: "enemy_wolf", position: CGPoint(x: 100, y: 200), scale: 1.5))

        let sprite: SpriteComponent = nexus.get(unsafe: entity.identifier)
        #expect(sprite.textureName == "enemy_wolf")
        #expect(sprite.position.x == 100)
        #expect(sprite.position.y == 200)
        #expect(sprite.scale == 1.5)
        #expect(sprite.isDirty == true)
        #expect(sprite.isHidden == false)
    }

    @Test("AnimationComponent enqueues actions")
    func testAnimationComponent() {
        let anim = AnimationComponent()
        #expect(anim.queue.isEmpty)
        #expect(anim.isPlaying == false)

        anim.enqueue(.moveTo(CGPoint(x: 50, y: 50), duration: 0.3))
        anim.enqueue(.shake(intensity: 5, duration: 0.2))
        #expect(anim.queue.count == 2)
    }

    @Test("LabelComponent stores text properties")
    func testLabelComponent() {
        let label = LabelComponent(text: "Wolf", colorName: "red", verticalOffset: 30)
        #expect(label.text == "Wolf")
        #expect(label.fontName == "AvenirNext-Bold")
        #expect(label.fontSize == 14)
        #expect(label.colorName == "red")
        #expect(label.verticalOffset == 30)
    }

    @Test("HealthBarComponent defaults")
    func testHealthBarComponent() {
        let bar = HealthBarComponent()
        #expect(bar.showHP == true)
        #expect(bar.showWill == false)
        #expect(bar.barWidth == 60)
    }

    @Test("ParticleComponent stores emitter info")
    func testParticleComponent() {
        let particle = ParticleComponent(emitterName: "magic_cast", isActive: true)
        #expect(particle.emitterName == "magic_cast")
        #expect(particle.isActive == true)
        #expect(particle.removeWhenDone == true)
    }
}

/// Файл: Packages/EchoScenes/Tests/EchoScenesTests/CombatParticlesTests.swift
/// Назначение: Содержит реализацию файла CombatParticlesTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import Testing
import SpriteKit
@testable import EchoScenes

@Suite("CombatParticles Tests")
struct CombatParticlesTests {

    @Test("attackImpact creates emitter with particles")
    func testAttackImpact() {
        let emitter = CombatParticles.attackImpact()
        #expect(emitter.particleBirthRate > 0)
        #expect(emitter.numParticlesToEmit > 0)
    }

    @Test("criticalHit has more particles than attackImpact")
    func testCriticalHitMoreParticles() {
        let normal = CombatParticles.attackImpact()
        let crit = CombatParticles.criticalHit()
        #expect(crit.numParticlesToEmit > normal.numParticlesToEmit)
        #expect(crit.particleBirthRate > normal.particleBirthRate)
    }

    @Test("healEffect emits upward")
    func testHealEffect() {
        let emitter = CombatParticles.healEffect()
        #expect(emitter.particleBirthRate > 0)
        // Emission angle should be roughly upward (π/2)
        #expect(emitter.emissionAngle > 1.0)
        #expect(emitter.emissionAngle < 2.0)
    }
}

/// Файл: Packages/EchoEngine/Tests/EchoEngineTests/ComponentTests.swift
/// Назначение: Содержит реализацию файла ComponentTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import Testing
import FirebladeECS
@testable import EchoEngine

@Suite("Component Tests")
struct ComponentTests {

    @Test("HealthComponent stores and reads correctly")
    func testHealthComponent() {
        let nexus = Nexus()
        let entity = nexus.createEntity()
        entity.assign(HealthComponent(current: 10, max: 15, will: 5, maxWill: 8))

        let health: HealthComponent = nexus.get(unsafe: entity.identifier)
        #expect(health.current == 10)
        #expect(health.max == 15)
        #expect(health.will == 5)
        #expect(health.maxWill == 8)
        #expect(health.isAlive)
        #expect(!health.willDepleted)
    }

    @Test("HealthComponent isAlive and willDepleted")
    func testHealthFlags() {
        let nexus = Nexus()
        let dead = nexus.createEntity()
        dead.assign(HealthComponent(current: 0, max: 10))

        let health: HealthComponent = nexus.get(unsafe: dead.identifier)
        #expect(!health.isAlive)

        let depleted = nexus.createEntity()
        depleted.assign(HealthComponent(current: 5, max: 10, will: 0, maxWill: 5))

        let h2: HealthComponent = nexus.get(unsafe: depleted.identifier)
        #expect(h2.willDepleted)
    }

    @Test("CombatStateComponent defaults")
    func testCombatStateDefaults() {
        let nexus = Nexus()
        let entity = nexus.createEntity()
        entity.assign(CombatStateComponent())

        let state: CombatStateComponent = nexus.get(unsafe: entity.identifier)
        #expect(state.phase == .setup)
        #expect(state.round == 1)
        #expect(state.isActive)
        #expect(!state.mulliganDone)
    }

    @Test("PlayerTag and EnemyTag coexist in Nexus")
    func testTagComponents() {
        let nexus = Nexus()
        let player = nexus.createEntity()
        player.assign(PlayerTagComponent(name: "Hero", strength: 7))

        let enemy = nexus.createEntity()
        enemy.assign(EnemyTagComponent(definitionId: "wolf", power: 3, defense: 1))

        let playerFamily = nexus.family(requires: PlayerTagComponent.self)
        let enemyFamily = nexus.family(requires: EnemyTagComponent.self)

        #expect(playerFamily.count == 1)
        #expect(enemyFamily.count == 1)
    }

    @Test("ResonanceComponent stores float value")
    func testResonanceComponent() {
        let nexus = Nexus()
        let entity = nexus.createEntity()
        entity.assign(ResonanceComponent(value: -45.5))

        let res: ResonanceComponent = nexus.get(unsafe: entity.identifier)
        #expect(res.value == -45.5)
    }

    @Test("Family query returns entities with matching components")
    func testFamilyQuery() {
        let nexus = Nexus()

        let e1 = nexus.createEntity()
        e1.assign(HealthComponent(current: 10, max: 10))
        e1.assign(EnemyTagComponent(definitionId: "wolf", power: 3, defense: 1))

        let e2 = nexus.createEntity()
        e2.assign(HealthComponent(current: 5, max: 5))
        e2.assign(PlayerTagComponent(name: "Hero", strength: 5))

        let enemies = nexus.family(requiresAll: EnemyTagComponent.self, HealthComponent.self)
        #expect(enemies.count == 1)

        for (tag, health) in enemies {
            #expect(tag.definitionId == "wolf")
            #expect(health.current == 10)
        }
    }
}

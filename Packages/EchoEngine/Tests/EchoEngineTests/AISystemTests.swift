/// Файл: Packages/EchoEngine/Tests/EchoEngineTests/AISystemTests.swift
/// Назначение: Содержит реализацию файла AISystemTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import Testing
import FirebladeECS
import TwilightEngine
@testable import EchoEngine

@Suite("AISystem Tests")
struct AISystemTests {

    @Test("Generate intent for enemy entity")
    func testGenerateIntent() {
        let rng = WorldRNG(seed: 42)
        let nexus = Nexus()

        // Combat state
        let combat = nexus.createEntity()
        combat.assign(CombatStateComponent(round: 1))

        // Enemy
        let enemy = nexus.createEntity()
        enemy.assign(EnemyTagComponent(definitionId: "wolf", power: 4, defense: 2))
        enemy.assign(HealthComponent(current: 8, max: 8))
        enemy.assign(IntentComponent())

        let system = AISystem(rng: rng)
        system.update(nexus: nexus)

        let intent: IntentComponent = nexus.get(unsafe: enemy.identifier)
        #expect(intent.intent != nil)
        #expect(intent.intent!.value > 0)
    }

    @Test("Does not overwrite existing intent")
    func testDoesNotOverwrite() {
        let rng = WorldRNG(seed: 42)
        let nexus = Nexus()

        let combat = nexus.createEntity()
        combat.assign(CombatStateComponent(round: 1))

        let enemy = nexus.createEntity()
        enemy.assign(EnemyTagComponent(definitionId: "wolf", power: 4, defense: 2))
        enemy.assign(HealthComponent(current: 8, max: 8))
        let existingIntent = EnemyIntent.attack(damage: 99)
        enemy.assign(IntentComponent(intent: existingIntent))

        let system = AISystem(rng: rng)
        system.update(nexus: nexus)

        let intent: IntentComponent = nexus.get(unsafe: enemy.identifier)
        #expect(intent.intent?.value == 99) // unchanged
    }

    @Test("Skips dead enemies")
    func testSkipsDeadEnemies() {
        let rng = WorldRNG(seed: 42)
        let nexus = Nexus()

        let combat = nexus.createEntity()
        combat.assign(CombatStateComponent(round: 1))

        let enemy = nexus.createEntity()
        enemy.assign(EnemyTagComponent(definitionId: "wolf", power: 4, defense: 2))
        enemy.assign(HealthComponent(current: 0, max: 8))
        enemy.assign(IntentComponent())

        let system = AISystem(rng: rng)
        system.update(nexus: nexus)

        let intent: IntentComponent = nexus.get(unsafe: enemy.identifier)
        #expect(intent.intent == nil)
    }

    @Test("Enemy with pattern cycles through steps")
    func testPatternCycles() {
        let rng = WorldRNG(seed: 42)
        let nexus = Nexus()

        let combatState = CombatStateComponent(round: 1)
        let combat = nexus.createEntity()
        combat.assign(combatState)

        let pattern: [EnemyPatternStep] = [
            EnemyPatternStep(type: .attack, value: 5),
            EnemyPatternStep(type: .heal, value: 3),
            EnemyPatternStep(type: .ritual, value: -10)
        ]

        let enemy = nexus.createEntity()
        enemy.assign(EnemyTagComponent(definitionId: "boss", power: 4, defense: 2, pattern: pattern))
        enemy.assign(HealthComponent(current: 20, max: 20))
        enemy.assign(IntentComponent())

        let system = AISystem(rng: rng)

        // Round 1 → pattern[0] = attack 5
        system.update(nexus: nexus)
        let intent: IntentComponent = nexus.get(unsafe: enemy.identifier)
        #expect(intent.intent?.type == .attack)
        #expect(intent.intent?.value == 5)

        // Round 2 → pattern[1] = heal 3
        intent.intent = nil
        combatState.round = 2
        system.update(nexus: nexus)
        #expect(intent.intent?.type == .heal)
        #expect(intent.intent?.value == 3)

        // Round 3 → pattern[2] = ritual -10
        intent.intent = nil
        combatState.round = 3
        system.update(nexus: nexus)
        #expect(intent.intent?.type == .ritual)

        // Round 4 → wraps to pattern[0] = attack 5
        intent.intent = nil
        combatState.round = 4
        system.update(nexus: nexus)
        #expect(intent.intent?.type == .attack)
        #expect(intent.intent?.value == 5)
    }
}

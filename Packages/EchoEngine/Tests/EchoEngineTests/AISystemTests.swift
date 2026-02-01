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
}

import Testing
import FirebladeECS
import TwilightEngine
@testable import EchoEngine

@Suite("Integration Tests")
struct IntegrationTests {

    // MARK: - Helpers

    private func makeEnemy(health: Int = 10, will: Int? = nil, faithReward: Int = 2, lootCardIds: [String] = ["loot_sword"]) -> EnemyDefinition {
        EnemyDefinition(
            id: "test_boss",
            name: .key("boss"),
            description: .key("boss_desc"),
            health: health,
            power: 3,
            defense: 1,
            will: will,
            lootCardIds: lootCardIds,
            faithReward: faithReward
        )
    }

    // MARK: - EchoCombatResult Tests

    @Test("EchoCombatResult reports killed victory with Nav resonance delta")
    func testEchoCombatResultKilled() {
        let enemy = makeEnemy(health: 1, faithReward: 3)
        let sim = CombatSimulation.create(
            enemyDefinition: enemy,
            playerStrength: 20,
            seed: 42
        )
        sim.beginCombat()
        sim.playerAttack()
        sim.endTurn()
        sim.resolveEnemyTurn()

        let result = sim.combatResult
        #expect(result != nil)
        #expect(result?.outcome == .victory(.killed))
        #expect(result?.resonanceDelta == -5)
        #expect(result?.faithDelta == 3)
        #expect(result?.lootCardIds == ["loot_sword"])
        #expect(result?.updatedFateDeckState != nil)
    }

    @Test("EchoCombatResult reports pacified victory with Prav resonance delta")
    func testEchoCombatResultPacified() {
        let enemy = makeEnemy(health: 50, will: 1, faithReward: 5)
        let sim = CombatSimulation.create(
            enemyDefinition: enemy,
            playerStrength: 20,
            seed: 42
        )
        sim.beginCombat()
        sim.playerInfluence()
        sim.endTurn()
        sim.resolveEnemyTurn()

        let result = sim.combatResult
        #expect(result != nil)
        #expect(result?.outcome == .victory(.pacified))
        #expect(result?.resonanceDelta == 5)
        #expect(result?.faithDelta == 5)
    }

    @Test("EchoCombatResult is nil before combat ends")
    func testEchoCombatResultNilDuringCombat() {
        let enemy = makeEnemy(health: 50)
        let sim = CombatSimulation.create(
            enemyDefinition: enemy,
            playerStrength: 3,
            seed: 42
        )
        sim.beginCombat()

        #expect(sim.combatResult == nil)
    }

    @Test("EchoCombatResult reports defeat with zero deltas")
    func testEchoCombatResultDefeat() {
        let enemy = makeEnemy(health: 100)
        let sim = CombatSimulation.create(
            enemyDefinition: enemy,
            playerHealth: 1,
            playerMaxHealth: 1,
            playerStrength: 1,
            seed: 42
        )
        sim.beginCombat()

        // Enemy attacks player, should kill with 1 HP
        sim.endTurn()
        sim.resolveEnemyTurn()

        let result = sim.combatResult
        #expect(result != nil)
        #expect(result?.outcome == .defeat)
        #expect(result?.resonanceDelta == 0)
        #expect(result?.faithDelta == 0)
    }

    // MARK: - Full Flow Tests

    @Test("playerInfluence end-to-end: damages will and produces result")
    func testInfluenceEndToEnd() {
        let enemy = makeEnemy(health: 30, will: 5, faithReward: 4)
        let sim = CombatSimulation.create(
            enemyDefinition: enemy,
            playerStrength: 10,
            seed: 42
        )
        sim.beginCombat()

        // Influence should pacify
        let event = sim.playerInfluence()
        if case .playerInfluenced(let willDmg, _, _, _) = event {
            #expect(willDmg > 0)
        } else {
            #expect(Bool(false), "Expected playerInfluenced event")
        }

        #expect(sim.enemyWill == 0)
        #expect(sim.enemyHealth == 30, "HP should be unchanged")

        sim.endTurn()
        sim.resolveEnemyTurn()

        #expect(sim.outcome == .victory(.pacified))
        let result = sim.combatResult!
        #expect(result.resonanceDelta == 5)
        #expect(result.faithDelta == 4)
    }

    @Test("EnemyTagComponent carries faithReward and lootCardIds through builder")
    func testEnemyTagCarriesRewards() {
        let enemy = makeEnemy(faithReward: 7, lootCardIds: ["card_a", "card_b"])
        let sim = CombatSimulation.create(enemyDefinition: enemy, seed: 1)

        guard let enemyEntity = sim.enemyEntity else {
            #expect(Bool(false), "No enemy entity"); return
        }
        let tag: EnemyTagComponent = sim.nexus.get(unsafe: enemyEntity.identifier)
        #expect(tag.faithReward == 7)
        #expect(tag.lootCardIds == ["card_a", "card_b"])
    }
}

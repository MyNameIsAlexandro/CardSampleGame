import Testing
import FirebladeECS
import TwilightEngine
@testable import EchoEngine

@Suite("CombatSystem Tests")
struct CombatSystemTests {

    private func makeBasicCombatNexus(
        playerStrength: Int = 5,
        enemyHealth: Int = 10,
        enemyDefense: Int = 3,
        fateCards: [FateCard] = [],
        seed: UInt64 = 42
    ) -> (Nexus, Entity, Entity, WorldRNG) {
        let rng = WorldRNG(seed: seed)
        let nexus = Nexus()

        let combat = nexus.createEntity()
        combat.assign(CombatStateComponent())
        combat.assign(ResonanceComponent(value: 0))
        let fateDeck = FateDeckManager(cards: fateCards, rng: rng)
        combat.assign(FateDeckComponent(fateDeck: fateDeck))

        let player = nexus.createEntity()
        player.assign(PlayerTagComponent(name: "Hero", strength: playerStrength))
        player.assign(HealthComponent(current: 10, max: 10))

        let enemy = nexus.createEntity()
        enemy.assign(EnemyTagComponent(definitionId: "wolf", power: 4, defense: enemyDefense))
        enemy.assign(HealthComponent(current: enemyHealth, max: enemyHealth))
        enemy.assign(IntentComponent(intent: .attack(damage: 4)))

        return (nexus, player, enemy, rng)
    }

    @Test("Player attack reduces enemy health when totalAttack >= defense")
    func testPlayerAttackHits() {
        // No fate cards = fateValue 0. strength(5) + 0 = 5 >= defense(3) → damage = 5-3+1 = 3
        let (nexus, player, enemy, _) = makeBasicCombatNexus(playerStrength: 5, enemyHealth: 10, enemyDefense: 3)
        let system = CombatSystem()

        let event = system.playerAttack(player: player, enemy: enemy, nexus: nexus)

        let health: HealthComponent = nexus.get(unsafe: enemy.identifier)
        if case .playerAttacked(let damage, _, _) = event {
            #expect(damage == 3)
            #expect(health.current == 7)
        } else {
            #expect(Bool(false), "Expected playerAttacked event")
        }
    }

    @Test("Player attack misses when totalAttack < defense")
    func testPlayerAttackMisses() {
        // strength(1) + 0 = 1 < defense(5) → miss
        let (nexus, player, enemy, _) = makeBasicCombatNexus(playerStrength: 1, enemyHealth: 10, enemyDefense: 5)
        let system = CombatSystem()

        let event = system.playerAttack(player: player, enemy: enemy, nexus: nexus)

        let health: HealthComponent = nexus.get(unsafe: enemy.identifier)
        #expect(health.current == 10) // unchanged
        if case .playerMissed = event {
            // expected
        } else {
            #expect(Bool(false), "Expected playerMissed event")
        }
    }

    @Test("Enemy resolve attack damages player")
    func testEnemyResolveAttack() {
        let (nexus, player, enemy, _) = makeBasicCombatNexus()
        let system = CombatSystem()

        let event = system.resolveEnemyIntent(enemy: enemy, player: player, nexus: nexus)

        let health: HealthComponent = nexus.get(unsafe: player.identifier)
        if case .enemyAttacked(let damage, _, _) = event {
            #expect(damage > 0)
            #expect(health.current < 10)
        } else {
            #expect(Bool(false), "Expected enemyAttacked event")
        }
    }

    @Test("Victory when enemy health reaches 0")
    func testVictoryCheck() {
        let (nexus, _, enemy, _) = makeBasicCombatNexus(enemyHealth: 1, enemyDefense: 0)
        let enemyHealth: HealthComponent = nexus.get(unsafe: enemy.identifier)
        enemyHealth.current = 0

        let system = CombatSystem()
        let outcome = system.checkVictoryOrDefeat(nexus: nexus)

        #expect(outcome == .victory)
    }

    @Test("Defeat when player health reaches 0")
    func testDefeatCheck() {
        let (nexus, player, _, _) = makeBasicCombatNexus()
        let playerHealth: HealthComponent = nexus.get(unsafe: player.identifier)
        playerHealth.current = 0

        let system = CombatSystem()
        let outcome = system.checkVictoryOrDefeat(nexus: nexus)

        #expect(outcome == .defeat)
    }

    @Test("Advance round increments counter and clears intents")
    func testAdvanceRound() {
        let (nexus, _, enemy, _) = makeBasicCombatNexus()
        let system = CombatSystem()

        system.advanceRound(nexus: nexus)

        let state = nexus.family(requires: CombatStateComponent.self)
        for s in state {
            #expect(s.round == 2)
        }

        let intent: IntentComponent = nexus.get(unsafe: enemy.identifier)
        #expect(intent.intent == nil) // cleared
    }

    @Test("Victory when enemy Will depleted even if HP remains")
    func testWillDepletedVictory() {
        let mentalCard = Card(
            id: "mind", name: "Mind Blast", type: .spell,
            description: "Mental damage",
            abilities: [CardAbility(id: "m1", name: "Blast", description: "Mental 10",
                                   effect: .damage(amount: 10, type: .mental))]
        )
        let enemyDef = EnemyDefinition(
            id: "spirit",
            name: .key("spirit"),
            description: .key("spirit_desc"),
            health: 20,
            power: 2,
            defense: 0,
            will: 5
        )
        let sim = CombatSimulation.create(
            enemyDefinition: enemyDef,
            playerDeck: [mentalCard],
            fateCards: (0..<10).map { FateCard(id: "f\($0)", modifier: 0, name: "F\($0)") },
            seed: 42
        )
        sim.beginCombat()

        sim.playCard(cardId: mentalCard.id)
        // Will depleted, HP still full
        #expect(sim.enemyWill == 0)
        #expect(sim.enemyHealth == 20)

        // End turn → checkVictoryOrDefeat triggers
        sim.endTurn()
        sim.resolveEnemyTurn()

        // Should be victory because will is depleted
        #expect(sim.outcome == .victory)
    }
}

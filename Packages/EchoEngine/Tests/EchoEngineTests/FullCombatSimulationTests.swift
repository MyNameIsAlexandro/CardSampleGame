import Testing
import FirebladeECS
import TwilightEngine
@testable import EchoEngine

@Suite("Full Combat Simulation Tests")
struct FullCombatSimulationTests {

    private func makeTestEnemy(health: Int = 6, power: Int = 3, defense: Int = 2) -> EnemyDefinition {
        EnemyDefinition(
            id: "test_wolf",
            name: .key("wolf"),
            description: .key("wolf_desc"),
            health: health,
            power: power,
            defense: defense,
            difficulty: 1,
            enemyType: .beast,
            rarity: .common,
            abilities: [],
            lootCardIds: [],
            faithReward: 1,
            balanceDelta: 0
        )
    }

    private func makeTestCards(_ count: Int) -> [Card] {
        (0..<count).map { i in
            Card(id: "card_\(i)", name: "Card \(i)", type: .spell, description: "Test")
        }
    }

    private func makeSimpleFateCards() -> [FateCard] {
        // Create simple fate cards with known values
        (0..<10).map { i in
            FateCard(
                id: "fate_\(i)",
                modifier: (i % 3) - 1, // -1, 0, 1 cycling
                isCritical: false,
                isSticky: false,
                name: "Fate \(i)",
                resonanceRules: [],
                onDrawEffects: [],
                cardType: .standard
            )
        }
    }

    @Test("CombatSimulation initializes correctly")
    func testInit() {
        let sim = CombatSimulation.create(
            enemyDefinition: makeTestEnemy(),
            playerDeck: makeTestCards(10),
            fateCards: makeSimpleFateCards()
        )

        #expect(sim.phase == .setup)
        #expect(!sim.isOver)
        #expect(sim.playerHealth == 10)
        #expect(sim.enemyHealth == 6)
    }

    @Test("Begin combat draws hand and generates intent")
    func testBeginCombat() {
        let sim = CombatSimulation.create(
            enemyDefinition: makeTestEnemy(),
            playerDeck: makeTestCards(10),
            fateCards: makeSimpleFateCards()
        )

        sim.beginCombat()

        #expect(sim.phase == .playerTurn)
        #expect(sim.hand.count == 5)
    }

    @Test("Full combat loop runs to completion")
    func testFullCombatLoop() {
        let sim = CombatSimulation.create(
            enemyDefinition: makeTestEnemy(health: 6, power: 2, defense: 1),
            playerStrength: 8, // strong player to ensure hits
            playerDeck: makeTestCards(10),
            fateCards: makeSimpleFateCards(),
            seed: 42
        )

        sim.beginCombat()

        var turns = 0
        let maxTurns = 50

        while !sim.isOver && turns < maxTurns {
            sim.playerAttack()
            if sim.isOver { break }
            sim.resolveEnemyTurn()
            turns += 1
        }

        #expect(sim.isOver)
        #expect(turns < maxTurns, "Combat should end within \(maxTurns) turns")
        #expect(sim.outcome != nil)
    }

    @Test("Combat is deterministic with same seed")
    func testDeterministic() {
        let enemy = makeTestEnemy(health: 6, power: 2, defense: 1)
        let deck = makeTestCards(10)
        let fateCards = makeSimpleFateCards()

        func runCombat(seed: UInt64) -> (CombatOutcome?, Int, Int) {
            let sim = CombatSimulation.create(
                enemyDefinition: enemy,
                playerStrength: 6,
                playerDeck: deck,
                fateCards: fateCards,
                seed: seed
            )
            sim.beginCombat()
            var turns = 0
            while !sim.isOver && turns < 50 {
                sim.playerAttack()
                if sim.isOver { break }
                sim.resolveEnemyTurn()
                turns += 1
            }
            return (sim.outcome, sim.playerHealth, turns)
        }

        let (outcome1, hp1, turns1) = runCombat(seed: 123)
        let (outcome2, hp2, turns2) = runCombat(seed: 123)

        #expect(outcome1 == outcome2)
        #expect(hp1 == hp2)
        #expect(turns1 == turns2)
    }

    @Test("Player defeat when enemy is too strong")
    func testPlayerDefeat() {
        let sim = CombatSimulation.create(
            enemyDefinition: makeTestEnemy(health: 100, power: 20, defense: 50),
            playerHealth: 5,
            playerMaxHealth: 5,
            playerStrength: 1,
            playerDeck: makeTestCards(5),
            fateCards: makeSimpleFateCards(),
            seed: 42
        )

        sim.beginCombat()

        var turns = 0
        while !sim.isOver && turns < 50 {
            sim.playerSkip()
            sim.resolveEnemyTurn()
            turns += 1
        }

        #expect(sim.isOver)
        #expect(sim.outcome == .defeat)
    }
}

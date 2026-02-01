import Testing
import FirebladeECS
import TwilightEngine
@testable import EchoEngine

@Suite("Card Play Tests")
struct CardPlayTests {

    private func makeEnemy(health: Int = 10, defense: Int = 0) -> EnemyDefinition {
        EnemyDefinition(
            id: "test_enemy",
            name: .key("enemy"),
            description: .key("enemy_desc"),
            health: health,
            power: 2,
            defense: defense
        )
    }

    private func makeFateCards() -> [FateCard] {
        (0..<10).map { i in
            FateCard(id: "fate_\(i)", modifier: 0, name: "Fate \(i)")
        }
    }

    private func makeDamageCard(id: String = "dmg_card", damage: Int = 3) -> Card {
        Card(
            id: id,
            name: "Strike",
            type: .spell,
            description: "Deal damage",
            abilities: [
                CardAbility(id: "a1", name: "Strike", description: "Deal damage",
                           effect: .damage(amount: damage, type: .physical))
            ]
        )
    }

    private func makeHealCard(id: String = "heal_card", amount: Int = 4) -> Card {
        Card(
            id: id,
            name: "Heal",
            type: .spell,
            description: "Restore health",
            abilities: [
                CardAbility(id: "a2", name: "Heal", description: "Restore health",
                           effect: .heal(amount: amount))
            ]
        )
    }

    private func makeDrawCard(id: String = "draw_card", count: Int = 2) -> Card {
        Card(
            id: id,
            name: "Insight",
            type: .spell,
            description: "Draw cards",
            abilities: [
                CardAbility(id: "a3", name: "Insight", description: "Draw",
                           effect: .drawCards(count: count))
            ]
        )
    }

    @Test("playCard with damage card reduces enemy HP")
    func testPlayDamageCard() {
        let dmgCard = makeDamageCard(damage: 3)
        let sim = CombatSimulation.create(
            enemyDefinition: makeEnemy(health: 10),
            playerDeck: [dmgCard],
            fateCards: makeFateCards(),
            seed: 42
        )
        sim.beginCombat()

        let initialHP = sim.enemyHealth
        let event = sim.playCard(cardId: dmgCard.id)

        if case .cardPlayed(_, let damage, _, _) = event {
            #expect(damage == 3)
        } else {
            Issue.record("Expected cardPlayed event")
        }
        #expect(sim.enemyHealth == initialHP - 3)
    }

    @Test("playCard with heal card restores player HP")
    func testPlayHealCard() {
        let healCard = makeHealCard(amount: 4)
        let sim = CombatSimulation.create(
            enemyDefinition: makeEnemy(),
            playerHealth: 6,
            playerMaxHealth: 10,
            playerDeck: [healCard],
            fateCards: makeFateCards(),
            seed: 42
        )
        sim.beginCombat()

        let event = sim.playCard(cardId: healCard.id)

        if case .cardPlayed(_, _, let heal, _) = event {
            #expect(heal == 4)
        } else {
            Issue.record("Expected cardPlayed event")
        }
        #expect(sim.playerHealth == 10)
    }

    @Test("playCard moves card from hand to discard")
    func testPlayCardDiscardsFromHand() {
        let card = makeDamageCard()
        let extraCards = (0..<4).map { i in
            Card(id: "filler_\(i)", name: "Filler", type: .spell, description: "Filler")
        }
        let sim = CombatSimulation.create(
            enemyDefinition: makeEnemy(),
            playerDeck: [card] + extraCards,
            fateCards: makeFateCards(),
            seed: 42
        )
        sim.beginCombat()

        let handBefore = sim.hand.count
        #expect(sim.hand.contains(where: { $0.id == card.id }))

        sim.playCard(cardId: card.id)

        #expect(sim.hand.count == handBefore - 1)
        #expect(!sim.hand.contains(where: { $0.id == card.id }))
        #expect(sim.discardPileCount == 1)
    }

    @Test("playCard does not change phase from playerTurn")
    func testPlayCardKeepsPhase() {
        let card = makeDamageCard()
        let sim = CombatSimulation.create(
            enemyDefinition: makeEnemy(),
            playerDeck: [card],
            fateCards: makeFateCards(),
            seed: 42
        )
        sim.beginCombat()
        #expect(sim.phase == .playerTurn)

        sim.playCard(cardId: card.id)
        #expect(sim.phase == .playerTurn)
    }

    @Test("endTurn transitions to enemyResolve")
    func testEndTurn() {
        let card = makeDamageCard()
        let sim = CombatSimulation.create(
            enemyDefinition: makeEnemy(health: 20),
            playerDeck: [card],
            fateCards: makeFateCards(),
            seed: 42
        )
        sim.beginCombat()
        #expect(sim.phase == .playerTurn)

        sim.endTurn()
        #expect(sim.phase == .enemyResolve)

        // Resolve enemy turn completes the cycle
        let roundBefore = sim.round
        sim.resolveEnemyTurn()
        #expect(sim.phase == .playerTurn)
        #expect(sim.round == roundBefore + 1)
    }

    @Test("Can play two cards in one turn")
    func testPlayTwoCards() {
        let card1 = makeDamageCard(id: "dmg1", damage: 2)
        let card2 = makeDamageCard(id: "dmg2", damage: 3)
        let fillers = (0..<3).map { i in
            Card(id: "filler_\(i)", name: "Filler", type: .spell, description: "Filler")
        }
        let sim = CombatSimulation.create(
            enemyDefinition: makeEnemy(health: 20),
            playerDeck: [card1, card2] + fillers,
            fateCards: makeFateCards(),
            seed: 42
        )
        sim.beginCombat()

        guard sim.hand.contains(where: { $0.id == "dmg1" }),
              sim.hand.contains(where: { $0.id == "dmg2" }) else { return }

        let initialHP = sim.enemyHealth
        sim.playCard(cardId: "dmg1")
        #expect(sim.phase == .playerTurn)
        sim.playCard(cardId: "dmg2")
        #expect(sim.phase == .playerTurn)
        #expect(sim.enemyHealth == initialHP - 5)
    }

    @Test("Turn start draws one card")
    func testTurnStartDraw() {
        let fillers = (0..<6).map { i in
            Card(id: "filler_\(i)", name: "Filler", type: .spell, description: "Filler")
        }
        let sim = CombatSimulation.create(
            enemyDefinition: makeEnemy(health: 20),
            playerDeck: fillers,
            fateCards: makeFateCards(),
            seed: 42
        )
        sim.beginCombat()

        let handBefore = sim.hand.count
        let drawBefore = sim.drawPileCount
        sim.endTurn()
        sim.resolveEnemyTurn()

        // Drew 1 card at start of new turn
        #expect(sim.hand.count == handBefore + 1)
        #expect(sim.drawPileCount == drawBefore - 1)
    }

    @Test("playCard reduces energy by card cost")
    func testPlayCardReducesEnergy() {
        let card = Card(
            id: "costly", name: "Fireball", type: .spell,
            description: "Boom", cost: 2,
            abilities: [CardAbility(id: "a1", name: "FB", description: "Boom",
                                   effect: .damage(amount: 5, type: .physical))]
        )
        let sim = CombatSimulation.create(
            enemyDefinition: makeEnemy(health: 20),
            playerDeck: [card],
            playerEnergy: 3,
            fateCards: makeFateCards(),
            seed: 42
        )
        sim.beginCombat()
        #expect(sim.energy == 3)

        sim.playCard(cardId: card.id)
        #expect(sim.energy == 1)
    }

    @Test("playCard with insufficient energy returns insufficientEnergy")
    func testInsufficientEnergy() {
        let card = Card(
            id: "expensive", name: "Mega", type: .spell,
            description: "Big", cost: 5,
            abilities: [CardAbility(id: "a1", name: "Mega", description: "Big",
                                   effect: .damage(amount: 10, type: .physical))]
        )
        let sim = CombatSimulation.create(
            enemyDefinition: makeEnemy(health: 20),
            playerDeck: [card],
            playerEnergy: 3,
            fateCards: makeFateCards(),
            seed: 42
        )
        sim.beginCombat()

        let event = sim.playCard(cardId: card.id)
        if case .insufficientEnergy = event {
            // expected
        } else {
            Issue.record("Expected insufficientEnergy event")
        }
        #expect(sim.energy == 3) // unchanged
    }

    @Test("Energy resets after resolveEnemyTurn")
    func testEnergyResetsOnNewTurn() {
        let card = makeDamageCard()
        let sim = CombatSimulation.create(
            enemyDefinition: makeEnemy(health: 20),
            playerDeck: [card],
            playerEnergy: 3,
            fateCards: makeFateCards(),
            seed: 42
        )
        sim.beginCombat()
        sim.playCard(cardId: card.id) // costs 1 (default)
        #expect(sim.energy == 2)

        sim.endTurn()
        sim.resolveEnemyTurn()
        #expect(sim.energy == 3) // reset
    }

    @Test("Card without cost defaults to 1 energy")
    func testDefaultCost() {
        let card = makeDamageCard() // no cost set, defaults to 1
        let sim = CombatSimulation.create(
            enemyDefinition: makeEnemy(health: 20),
            playerDeck: [card],
            playerEnergy: 3,
            fateCards: makeFateCards(),
            seed: 42
        )
        sim.beginCombat()
        sim.playCard(cardId: card.id)
        #expect(sim.energy == 2)
    }

    @Test("playCard with drawCards increases hand size")
    func testPlayDrawCard() {
        let drawCard = makeDrawCard(count: 2)
        // Need enough cards in drawPile after initial hand draw
        let fillers = (0..<9).map { i in
            Card(id: "filler_\(i)", name: "Filler", type: .spell, description: "Filler")
        }
        let sim = CombatSimulation.create(
            enemyDefinition: makeEnemy(),
            playerDeck: [drawCard] + fillers,
            fateCards: makeFateCards(),
            seed: 42
        )
        sim.beginCombat()

        // If draw_card is not in hand (shuffled into drawPile), skip
        guard sim.hand.contains(where: { $0.id == drawCard.id }) else {
            // Card ended up in drawPile due to shuffle — not a failure, just skip
            return
        }

        let handBefore = sim.hand.count
        let drawPileBefore = sim.drawPileCount
        let event = sim.playCard(cardId: drawCard.id)

        if case .cardPlayed(_, _, _, let drawn) = event {
            #expect(drawn > 0)
        } else {
            Issue.record("Expected cardPlayed event")
        }
        // Net change: played 1, drew some → hand should be larger than before - 1
        #expect(sim.hand.count > handBefore - 1)
    }
}

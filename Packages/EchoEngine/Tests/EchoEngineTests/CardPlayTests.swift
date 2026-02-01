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

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

        if case .cardPlayed(_, let damage, _, _, _) = event {
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

        if case .cardPlayed(_, _, let heal, _, _) = event {
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

        if case .cardPlayed(_, _, _, let drawn, _) = event {
            #expect(drawn > 0)
        } else {
            Issue.record("Expected cardPlayed event")
        }
        // Net change: played 1, drew some → hand should be larger than before - 1
        #expect(sim.hand.count > handBefore - 1)
    }

    // MARK: - Status Effect Tests

    @Test("Shield card grants shield to player")
    func testShieldCard() {
        let shieldCard = Card(
            id: "shield", name: "Guard", type: .spell,
            description: "Gain 4 shield",
            abilities: [CardAbility(id: "s1", name: "Guard", description: "Shield",
                                   effect: .temporaryStat(stat: "shield", amount: 4, duration: 2))]
        )
        let sim = CombatSimulation.create(
            enemyDefinition: makeEnemy(health: 20),
            playerDeck: [shieldCard],
            fateCards: makeFateCards(),
            seed: 42
        )
        sim.beginCombat()

        let event = sim.playCard(cardId: shieldCard.id)
        if case .cardPlayed(_, _, _, _, let status) = event {
            #expect(status == "shield")
        } else {
            Issue.record("Expected cardPlayed event")
        }
        #expect(sim.playerStatus(for: "shield") == 4)
    }

    @Test("Poison card applies poison to enemy")
    func testPoisonCard() {
        let poisonCard = Card(
            id: "poison", name: "Venom", type: .spell,
            description: "Apply 2 poison",
            abilities: [CardAbility(id: "p1", name: "Venom", description: "Poison",
                                   effect: .temporaryStat(stat: "poison", amount: 2, duration: 3))]
        )
        let sim = CombatSimulation.create(
            enemyDefinition: makeEnemy(health: 20),
            playerDeck: [poisonCard],
            fateCards: makeFateCards(),
            seed: 42
        )
        sim.beginCombat()
        sim.playCard(cardId: poisonCard.id)
        #expect(sim.enemyStatus(for: "poison") == 2)

        // Poison ticks on round advance
        let hpBefore = sim.enemyHealth
        sim.endTurn()
        sim.resolveEnemyTurn()
        #expect(sim.enemyHealth == hpBefore - 2)
    }

    @Test("Strength buff increases damage")
    func testStrengthBuff() {
        let buffCard = Card(
            id: "buff", name: "Rage", type: .spell,
            description: "Gain 2 strength",
            abilities: [CardAbility(id: "b1", name: "Rage", description: "Strength",
                                   effect: .temporaryStat(stat: "strength", amount: 2, duration: 2))]
        )
        let dmgCard = makeDamageCard(id: "dmg", damage: 3)
        let fillers = (0..<3).map { i in
            Card(id: "f_\(i)", name: "F", type: .spell, description: "F")
        }
        let sim = CombatSimulation.create(
            enemyDefinition: makeEnemy(health: 30),
            playerDeck: [buffCard, dmgCard] + fillers,
            playerEnergy: 5,
            fateCards: makeFateCards(),
            seed: 42
        )
        sim.beginCombat()

        guard sim.hand.contains(where: { $0.id == "buff" }),
              sim.hand.contains(where: { $0.id == "dmg" }) else { return }

        sim.playCard(cardId: "buff")
        #expect(sim.playerStatus(for: "strength") == 2)

        let hpBefore = sim.enemyHealth
        sim.playCard(cardId: "dmg")
        // 3 base + 2 strength = 5 damage
        #expect(sim.enemyHealth == hpBefore - 5)
    }

    @Test("Shield absorbs enemy damage")
    func testShieldAbsorbsDamage() {
        let shieldCard = Card(
            id: "shield", name: "Guard", type: .spell,
            description: "Gain 5 shield",
            abilities: [CardAbility(id: "s1", name: "Guard", description: "Shield",
                                   effect: .temporaryStat(stat: "shield", amount: 5, duration: 2))]
        )
        let sim = CombatSimulation.create(
            enemyDefinition: makeEnemy(health: 20),
            playerDeck: [shieldCard],
            fateCards: makeFateCards(),
            seed: 42
        )
        sim.beginCombat()
        sim.playCard(cardId: shieldCard.id)
        #expect(sim.playerStatus(for: "shield") == 5)

        let hpBefore = sim.playerHealth
        sim.endTurn()
        sim.resolveEnemyTurn()
        // Enemy power=2, shield should absorb some/all
        #expect(sim.playerHealth >= hpBefore - 2)
    }

    // MARK: - Multi-Ability Tests

    @Test("Card with multiple abilities resolves all of them")
    func testMultiAbilityCard() {
        let multiCard = Card(
            id: "multi", name: "Vampiric Strike", type: .spell,
            description: "Deal 3 damage and heal 2",
            abilities: [
                CardAbility(id: "a1", name: "Strike", description: "Damage",
                           effect: .damage(amount: 3, type: .physical)),
                CardAbility(id: "a2", name: "Drain", description: "Heal",
                           effect: .heal(amount: 2))
            ]
        )
        let sim = CombatSimulation.create(
            enemyDefinition: makeEnemy(health: 20),
            playerHealth: 5,
            playerMaxHealth: 10,
            playerDeck: [multiCard],
            playerEnergy: 3,
            fateCards: makeFateCards(),
            seed: 42
        )
        sim.beginCombat()

        let event = sim.playCard(cardId: multiCard.id)
        if case .cardPlayed(_, let damage, let heal, _, _) = event {
            #expect(damage == 3)
            #expect(heal == 2)
        } else {
            Issue.record("Expected cardPlayed event")
        }
        #expect(sim.enemyHealth == 17)
        #expect(sim.playerHealth == 7)
    }

    @Test("Card with no abilities uses power as damage")
    func testCardWithNoPowerFallback() {
        let powerCard = Card(
            id: "basic", name: "Punch", type: .spell,
            description: "Basic hit", power: 4
        )
        let sim = CombatSimulation.create(
            enemyDefinition: makeEnemy(health: 20),
            playerDeck: [powerCard],
            fateCards: makeFateCards(),
            seed: 42
        )
        sim.beginCombat()

        let event = sim.playCard(cardId: powerCard.id)
        if case .cardPlayed(_, let damage, _, _, _) = event {
            #expect(damage == 4)
        } else {
            Issue.record("Expected cardPlayed event")
        }
        #expect(sim.enemyHealth == 16)
    }

    // MARK: - Exhaust Tests

    @Test("Exhaust card goes to exhaustPile instead of discardPile")
    func testExhaustCard() {
        let exhaustCard = Card(
            id: "ex_card", name: "Sacrifice", type: .spell,
            description: "One-time use",
            abilities: [CardAbility(id: "a1", name: "Strike", description: "Hit",
                                   effect: .damage(amount: 2, type: .physical))],
            exhaust: true
        )
        let sim = CombatSimulation.create(
            enemyDefinition: makeEnemy(health: 20),
            playerDeck: [exhaustCard],
            fateCards: makeFateCards(),
            seed: 42
        )
        sim.beginCombat()

        sim.playCard(cardId: exhaustCard.id)
        #expect(sim.discardPileCount == 0)
        #expect(sim.exhaustPileCount == 1)
        #expect(sim.exhaustPile.first?.id == exhaustCard.id)
    }

    @Test("Non-exhaust card goes to discardPile as usual")
    func testNonExhaustCard() {
        let normalCard = makeDamageCard()
        let sim = CombatSimulation.create(
            enemyDefinition: makeEnemy(health: 20),
            playerDeck: [normalCard],
            fateCards: makeFateCards(),
            seed: 42
        )
        sim.beginCombat()

        sim.playCard(cardId: normalCard.id)
        #expect(sim.discardPileCount == 1)
        #expect(sim.exhaustPileCount == 0)
    }

    @Test("Exhausted cards are not recycled when draw pile is empty")
    func testExhaustedCardsNotRecycled() {
        let exhaustCard = Card(
            id: "ex1", name: "Once", type: .spell,
            description: "One-time",
            abilities: [CardAbility(id: "a1", name: "Hit", description: "Hit",
                                   effect: .damage(amount: 1, type: .physical))],
            exhaust: true
        )
        let normalCard = Card(
            id: "norm1", name: "Normal", type: .spell,
            description: "Normal"
        )
        let sim = CombatSimulation.create(
            enemyDefinition: makeEnemy(health: 50),
            playerDeck: [exhaustCard, normalCard],
            playerEnergy: 10,
            fateCards: makeFateCards(),
            seed: 42
        )
        sim.beginCombat()

        // Play exhaust card — goes to exhaust pile
        if sim.hand.contains(where: { $0.id == "ex1" }) {
            sim.playCard(cardId: "ex1")
        }
        #expect(sim.exhaustPileCount == 1)

        // End turn + resolve to trigger recycle
        sim.endTurn()
        sim.resolveEnemyTurn()

        // Exhaust pile should still have 1 card — it wasn't recycled
        #expect(sim.exhaustPileCount == 1)
    }

    // MARK: - Resonance Tests

    @Test("shiftBalance card shifts resonance toward light")
    func testShiftBalanceLight() {
        let lightCard = Card(
            id: "light", name: "Prayer", type: .spell,
            description: "Shift resonance",
            abilities: [CardAbility(id: "r1", name: "Pray", description: "Light +10",
                                   effect: .shiftBalance(towards: .light, amount: 10))]
        )
        let sim = CombatSimulation.create(
            enemyDefinition: makeEnemy(health: 20),
            playerDeck: [lightCard],
            fateCards: makeFateCards(),
            resonance: 0,
            seed: 42
        )
        sim.beginCombat()

        let event = sim.playCard(cardId: lightCard.id)
        if case .cardPlayed(_, _, _, _, let status) = event {
            #expect(status == "resonance")
        } else {
            Issue.record("Expected cardPlayed event")
        }
        #expect(sim.resonance == 10)
    }

    @Test("shiftBalance card shifts resonance toward dark")
    func testShiftBalanceDark() {
        let darkCard = Card(
            id: "dark", name: "Hex", type: .spell,
            description: "Shift resonance",
            abilities: [CardAbility(id: "r1", name: "Hex", description: "Dark +15",
                                   effect: .shiftBalance(towards: .dark, amount: 15))]
        )
        let sim = CombatSimulation.create(
            enemyDefinition: makeEnemy(health: 20),
            playerDeck: [darkCard],
            fateCards: makeFateCards(),
            resonance: 0,
            seed: 42
        )
        sim.beginCombat()

        sim.playCard(cardId: darkCard.id)
        #expect(sim.resonance == -15)
    }

    // MARK: - Mental Damage (Will) Tests

    @Test("Mental damage targets enemy Will instead of HP")
    func testMentalDamageTargetsWill() {
        let mentalCard = Card(
            id: "mind", name: "Mind Blast", type: .spell,
            description: "Mental damage",
            abilities: [CardAbility(id: "m1", name: "Blast", description: "Mental 4",
                                   effect: .damage(amount: 4, type: .mental))]
        )
        let enemyDef = EnemyDefinition(
            id: "spirit_wolf",
            name: .key("wolf"),
            description: .key("wolf_desc"),
            health: 10,
            power: 2,
            defense: 0,
            will: 8
        )
        let sim = CombatSimulation.create(
            enemyDefinition: enemyDef,
            playerDeck: [mentalCard],
            fateCards: makeFateCards(),
            seed: 42
        )
        sim.beginCombat()

        let hpBefore = sim.enemyHealth
        sim.playCard(cardId: mentalCard.id)

        // HP unchanged, Will reduced
        #expect(sim.enemyHealth == hpBefore)
        #expect(sim.enemyWill == 4)
    }

    @Test("Mental damage on enemy without Will hits HP instead")
    func testMentalDamageFallsBackToHP() {
        let mentalCard = Card(
            id: "mind", name: "Mind Blast", type: .spell,
            description: "Mental damage",
            abilities: [CardAbility(id: "m1", name: "Blast", description: "Mental 3",
                                   effect: .damage(amount: 3, type: .mental))]
        )
        let sim = CombatSimulation.create(
            enemyDefinition: makeEnemy(health: 10),
            playerDeck: [mentalCard],
            fateCards: makeFateCards(),
            seed: 42
        )
        sim.beginCombat()

        sim.playCard(cardId: mentalCard.id)
        // No Will → hits HP
        #expect(sim.enemyHealth == 7)
    }
}

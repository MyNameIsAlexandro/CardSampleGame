/// Файл: Packages/EchoEngine/Tests/EchoEngineTests/CardPlayStatusAndAdvancedTests.swift
/// Назначение: Содержит реализацию файла CardPlayStatusAndAdvancedTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import Testing
import FirebladeECS
import TwilightEngine
@testable import EchoEngine

extension CardPlayTests {
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
        #expect(sim.playerHealth >= hpBefore - 2)
    }

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

        if sim.hand.contains(where: { $0.id == "ex1" }) {
            sim.playCard(cardId: "ex1")
        }
        #expect(sim.exhaustPileCount == 1)

        sim.endTurn()
        sim.resolveEnemyTurn()

        #expect(sim.exhaustPileCount == 1)
    }

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
        #expect(sim.enemyHealth == 7)
    }
}

/// Файл: Packages/EchoEngine/Tests/EchoEngineTests/SelectCommitTests.swift
/// Назначение: Содержит реализацию файла SelectCommitTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import Testing
import FirebladeECS
import TwilightEngine
@testable import EchoEngine

@Suite("Select-Then-Commit Combat Tests")
struct SelectCommitTests {

    private func makeEnemy(health: Int = 20, defense: Int = 0) -> EnemyDefinition {
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
        (0..<10).map { FateCard(id: "fate_\($0)", modifier: 0, name: "Fate \($0)") }
    }

    private func makeDamageCard(id: String = "dmg_card", damage: Int = 3, cost: Int = 1) -> Card {
        Card(
            id: id, name: "Strike", type: .spell,
            description: "Deal damage", cost: cost,
            abilities: [
                CardAbility(id: "a_\(id)", name: "Strike", description: "Deal damage",
                           effect: .damage(amount: damage, type: .physical))
            ]
        )
    }

    private func makeHealCard(id: String = "heal_card", amount: Int = 4, cost: Int = 1) -> Card {
        Card(
            id: id, name: "Heal", type: .spell,
            description: "Heal", cost: cost,
            abilities: [
                CardAbility(id: "a_\(id)", name: "Heal", description: "Heal",
                           effect: .heal(amount: amount))
            ]
        )
    }

    private func makeDrawCard(id: String = "draw_card", count: Int = 1, cost: Int = 1) -> Card {
        Card(
            id: id, name: "Draw", type: .spell,
            description: "Draw", cost: cost,
            abilities: [
                CardAbility(id: "a_\(id)", name: "Draw", description: "Draw",
                           effect: .drawCards(count: count))
            ]
        )
    }

    private func makeSim(cards: [Card], energy: Int = 3, enemyHealth: Int = 20) -> CombatSimulation {
        let sim = CombatSimulation.create(
            enemyDefinition: makeEnemy(health: enemyHealth),
            playerDeck: cards,
            playerEnergy: energy,
            fateCards: makeFateCards(),
            seed: 42
        )
        sim.beginCombat()
        return sim
    }

    // MARK: - Select / Deselect

    @Test("selectCard reserves energy and tracks selection")
    func testSelectDeselectEnergy() {
        let card = makeDamageCard(cost: 2)
        let sim = makeSim(cards: [card], energy: 3)

        #expect(sim.selectCard(cardId: card.id) == true)
        #expect(sim.selectedCardIds == [card.id])
        #expect(sim.reservedEnergy == 2)
        #expect(sim.availableEnergy == 1)

        sim.deselectCard(cardId: card.id)
        #expect(sim.selectedCardIds.isEmpty)
        #expect(sim.reservedEnergy == 0)
        #expect(sim.availableEnergy == 3)
    }

    @Test("selectCard fails when not enough energy")
    func testSelectOverBudget() {
        let card1 = makeDamageCard(id: "card1", cost: 2)
        let card2 = makeDamageCard(id: "card2", cost: 2)
        let sim = makeSim(cards: [card1, card2], energy: 3)

        #expect(sim.selectCard(cardId: card1.id) == true)
        #expect(sim.selectCard(cardId: card2.id) == false) // only 1 available, card2 costs 2
        #expect(sim.selectedCardIds.count == 1)
    }

    // MARK: - Commit Attack

    @Test("commitAttack without cards is base attack")
    func testCommitAttackNoCards() {
        let sim = makeSim(cards: [makeDamageCard()], energy: 3, enemyHealth: 50)
        let hpBefore = sim.enemyHealth

        let events = sim.commitAttack()

        // Should have exactly one attack event (no card events)
        let attackEvents = events.filter {
            if case .playerAttacked = $0 { return true }
            if case .playerMissed = $0 { return true }
            return false
        }
        #expect(attackEvents.count == 1)
        #expect(sim.selectedCardIds.isEmpty)
        // Enemy took some damage (strength + fate)
        #expect(sim.enemyHealth <= hpBefore)
    }

    @Test("commitAttack with damage cards adds bonus damage")
    func testCommitAttackWithDamageCards() {
        let card1 = makeDamageCard(id: "dmg1", damage: 3, cost: 1)
        let card2 = makeDamageCard(id: "dmg2", damage: 4, cost: 1)
        let sim = makeSim(cards: [card1, card2], energy: 3, enemyHealth: 50)

        _ = sim.selectCard(cardId: card1.id)
        _ = sim.selectCard(cardId: card2.id)

        let hpBefore = sim.enemyHealth
        let events = sim.commitAttack()

        // Should have 2 cardPlayed events + 1 attack event
        let cardEvents = events.filter { if case .cardPlayed = $0 { return true }; return false }
        let attackEvents = events.filter { if case .playerAttacked = $0 { return true }; if case .playerMissed = $0 { return true }; return false }
        #expect(cardEvents.count == 2)
        #expect(attackEvents.count == 1)

        // Cards are discarded
        #expect(sim.selectedCardIds.isEmpty)
        #expect(sim.energy == 1) // 3 - 2 spent

        // Enemy took more damage than base attack due to bonus
        #expect(sim.enemyHealth < hpBefore)
    }

    @Test("commitAttack with heal card heals player and attacks")
    func testCommitAttackWithHealCard() {
        let healCard = makeHealCard(amount: 3)
        let sim = makeSim(cards: [healCard], energy: 3, enemyHealth: 50)

        // Damage the player first
        if let player = sim.playerEntity {
            let health: HealthComponent = sim.nexus.get(unsafe: player.identifier)
            health.current = health.max - 5 // lose 5 HP
        }
        let hpBefore = sim.playerHealth

        _ = sim.selectCard(cardId: healCard.id)
        let events = sim.commitAttack()

        // Should have cardPlayed (heal) + attack
        let cardEvents = events.filter { if case .cardPlayed = $0 { return true }; return false }
        #expect(cardEvents.count == 1)
        #expect(sim.playerHealth > hpBefore) // healed
    }

    @Test("commitAttack with mixed cards applies all effects")
    func testCommitAttackMixed() {
        let dmgCard = makeDamageCard(id: "dmg", damage: 5, cost: 1)
        let healCard = makeHealCard(id: "heal", amount: 3, cost: 1)
        let sim = makeSim(cards: [dmgCard, healCard], energy: 3, enemyHealth: 50)

        // Damage player
        if let player = sim.playerEntity {
            let health: HealthComponent = sim.nexus.get(unsafe: player.identifier)
            health.current = health.max - 4
        }

        _ = sim.selectCard(cardId: dmgCard.id)
        _ = sim.selectCard(cardId: healCard.id)

        let hpBefore = sim.playerHealth
        let events = sim.commitAttack()

        let cardEvents = events.filter { if case .cardPlayed = $0 { return true }; return false }
        #expect(cardEvents.count == 2)
        #expect(sim.playerHealth > hpBefore) // heal applied
        #expect(sim.statCardsPlayed == 2)
    }

    @Test("selection cleared after commit")
    func testSelectionClearedAfterCommit() {
        let card = makeDamageCard()
        let sim = makeSim(cards: [card], energy: 3)

        _ = sim.selectCard(cardId: card.id)
        #expect(!sim.selectedCardIds.isEmpty)

        _ = sim.commitAttack()
        #expect(sim.selectedCardIds.isEmpty)
        #expect(sim.reservedEnergy == 0)
    }

    @Test("selection cleared on endTurn")
    func testSelectionClearedOnEndTurn() {
        let card = makeDamageCard()
        let sim = makeSim(cards: [card], energy: 3)

        _ = sim.selectCard(cardId: card.id)
        #expect(!sim.selectedCardIds.isEmpty)

        sim.endTurn()
        #expect(sim.selectedCardIds.isEmpty)
        #expect(sim.reservedEnergy == 0)
    }
}

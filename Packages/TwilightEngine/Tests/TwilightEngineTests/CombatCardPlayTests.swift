/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/CombatCardPlayTests.swift
/// Назначение: Содержит реализацию файла CombatCardPlayTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import TwilightEngine

final class CombatCardPlayTests: XCTestCase {

    // MARK: - Helpers

    private func makeCard(
        id: String = "test_card",
        name: String = "Test Card",
        power: Int? = nil,
        defense: Int? = nil,
        abilities: [CardAbility] = []
    ) -> Card {
        Card(
            id: id,
            name: name,
            type: .spell,
            description: "Test",
            power: power,
            defense: defense,
            abilities: abilities
        )
    }

    private func makeAbility(effect: AbilityEffect) -> CardAbility {
        CardAbility(id: "ab_\(UUID().uuidString.prefix(4))", name: "Test", description: "Test", effect: effect)
    }

    private func makeEngine(heroCards: [Card] = [], heroStrength: Int = 5, heroWisdom: Int = 3) -> EncounterEngine {
        let hero = EncounterHero(id: "hero", hp: 20, maxHp: 20, strength: heroStrength, armor: 0, wisdom: heroWisdom)
        let enemy = EncounterEnemy(id: "enemy", name: "Goblin", hp: 30, maxHp: 30, wp: 20, maxWp: 20, power: 3, defense: 2)
        let ctx = EncounterContext(
            hero: hero,
            enemies: [enemy],
            fateDeckSnapshot: FateDeckState(drawPile: [], discardPile: []),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42,
            heroCards: heroCards,
            heroFaith: 100
        )
        let eng = EncounterEngine(context: ctx)
        // Advance to playerAction phase
        _ = eng.advancePhase()
        return eng
    }

    // MARK: - Tests

    func testInitialHandHasUpToThreeCards() {
        let cards = (0..<5).map { makeCard(id: "c\($0)", name: "Card \($0)", power: 1) }
        let eng = makeEngine(heroCards: cards)
        XCTAssertEqual(eng.hand.count, 3)
        XCTAssertEqual(eng.cardDiscardPile.count, 0)
    }

    func testPlayCardIncreasesAttackDamage() {
        let attackCard = makeCard(id: "atk", name: "Slash", abilities: [
            makeAbility(effect: .temporaryStat(stat: "attack", amount: 3, duration: 1))
        ])
        let eng = makeEngine(heroCards: [attackCard], heroStrength: 5)

        // Play the card
        let playResult = eng.performAction(.useCard(cardId: "atk", targetId: "enemy"))
        XCTAssertTrue(playResult.success)
        XCTAssertEqual(eng.turnAttackBonus, 3)

        // Attack should deal hero.strength(5) + bonus(3) - enemy.defense(2) = 6
        let atkResult = eng.performAction(.attack(targetId: "enemy"))
        XCTAssertTrue(atkResult.success)
        let hpChange = atkResult.stateChanges.first(where: {
            if case .enemyHPChanged = $0 { return true }; return false
        })
        if case .enemyHPChanged(_, let delta, _) = hpChange {
            XCTAssertEqual(delta, -6, "Expected 6 damage (5 str + 3 bonus - 2 def)")
        } else {
            XCTFail("Expected enemyHPChanged")
        }
    }

    func testPlayCardIncreasesInfluence() {
        let influenceCard = makeCard(id: "inf", name: "Calm", abilities: [
            makeAbility(effect: .temporaryStat(stat: "influence", amount: 4, duration: 1))
        ])
        let eng = makeEngine(heroCards: [influenceCard], heroWisdom: 3)

        let playResult = eng.performAction(.useCard(cardId: "inf", targetId: "enemy"))
        XCTAssertTrue(playResult.success)
        XCTAssertEqual(eng.turnInfluenceBonus, 4)
    }

    func testPlayCardAddsDefense() {
        let defCard = makeCard(id: "def", name: "Shield", abilities: [
            makeAbility(effect: .temporaryStat(stat: "defense", amount: 3, duration: 1))
        ])
        let eng = makeEngine(heroCards: [defCard])

        let playResult = eng.performAction(.useCard(cardId: "def", targetId: nil))
        XCTAssertTrue(playResult.success)
        XCTAssertEqual(eng.turnDefenseBonus, 3)
    }

    func testCardMovesToDiscardAfterPlay() {
        let card = makeCard(id: "c1", name: "Test")
        let eng = makeEngine(heroCards: [card])

        XCTAssertEqual(eng.hand.count, 1)
        XCTAssertEqual(eng.cardDiscardPile.count, 0)

        _ = eng.performAction(.useCard(cardId: "c1", targetId: nil))

        XCTAssertEqual(eng.hand.count, 0)
        XCTAssertEqual(eng.cardDiscardPile.count, 1)
        XCTAssertEqual(eng.cardDiscardPile.first?.id, "c1")
    }

    func testBonusesResetNextRound() {
        let card = makeCard(id: "atk", name: "Slash", abilities: [
            makeAbility(effect: .temporaryStat(stat: "attack", amount: 3, duration: 1))
        ])
        let eng = makeEngine(heroCards: [card])

        _ = eng.performAction(.useCard(cardId: "atk", targetId: nil))
        XCTAssertEqual(eng.turnAttackBonus, 3)

        // Advance through: playerAction → enemyResolution → roundEnd → intent
        _ = eng.advancePhase() // → enemyResolution
        _ = eng.advancePhase() // → roundEnd (resets bonuses)
        XCTAssertEqual(eng.turnAttackBonus, 0)
        XCTAssertEqual(eng.turnDefenseBonus, 0)
        XCTAssertEqual(eng.turnInfluenceBonus, 0)
    }

    func testCannotPlayCardOutsidePlayerAction() {
        let card = makeCard(id: "c1", name: "Test")
        let hero = EncounterHero(id: "hero", hp: 20, maxHp: 20, strength: 5, armor: 0)
        let enemy = EncounterEnemy(id: "enemy", name: "Goblin", hp: 30, maxHp: 30, power: 3, defense: 2)
        let ctx = EncounterContext(
            hero: hero,
            enemies: [enemy],
            fateDeckSnapshot: FateDeckState(drawPile: [], discardPile: []),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42,
            heroCards: [card]
        )
        let eng = EncounterEngine(context: ctx)
        // Phase is .intent, not .playerAction
        let result = eng.performAction(.useCard(cardId: "c1", targetId: nil))
        XCTAssertFalse(result.success)
    }

    func testPlayCardEmitsCardPlayedChange() {
        let card = makeCard(id: "c1", name: "Slash")
        let eng = makeEngine(heroCards: [card])

        let result = eng.performAction(.useCard(cardId: "c1", targetId: nil))
        let played = result.stateChanges.contains(where: {
            if case .cardPlayed(let id, let name) = $0 { return id == "c1" && name == "Slash" }
            return false
        })
        XCTAssertTrue(played, "Expected .cardPlayed state change")
    }

    func testFallbackPowerAsAttackBonus() {
        // Card with no abilities but power=2 → treated as +2 attack
        let card = makeCard(id: "c1", name: "Sword", power: 2)
        let eng = makeEngine(heroCards: [card])

        _ = eng.performAction(.useCard(cardId: "c1", targetId: nil))
        XCTAssertEqual(eng.turnAttackBonus, 2)
    }

    func testHealCardRestoresHP() {
        let healCard = makeCard(id: "heal", name: "Heal", abilities: [
            makeAbility(effect: .heal(amount: 5))
        ])
        let hero = EncounterHero(id: "hero", hp: 10, maxHp: 20, strength: 5, armor: 0)
        let enemy = EncounterEnemy(id: "enemy", name: "Goblin", hp: 30, maxHp: 30, power: 3, defense: 2)
        let ctx = EncounterContext(
            hero: hero,
            enemies: [enemy],
            fateDeckSnapshot: FateDeckState(drawPile: [], discardPile: []),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42,
            heroCards: [healCard],
            heroFaith: 100
        )
        let eng = EncounterEngine(context: ctx)
        _ = eng.advancePhase() // → playerAction

        let result = eng.performAction(.useCard(cardId: "heal", targetId: nil))
        XCTAssertTrue(result.success)
        XCTAssertEqual(eng.heroHP, 15)
    }
}

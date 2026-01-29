import XCTest
@testable import TwilightEngine

/// Tests for Fate-based attack resolution (calculateAttackWithFate)
/// and the updated .combatAttack(effortCards:bonusDamage:) engine action
final class FateAttackTests: XCTestCase {

    // MARK: - calculateAttackWithFate

    func testFateAttackHit() {
        // Setup: strength 5, fate card +2, defense 5
        // totalAttack = 5 + 0(effort) + 2(fate) + 0(bonus) = 7 >= 5 -> hit
        // damage = max(1, 7 - 5 + 2) = 4
        let cards = [FateCard(id: "f1", modifier: 2, name: "Fortune")]
        let deck = FateDeckManager(cards: cards)
        let context = CombatPlayerContext(
            health: 10, maxHealth: 10, faith: 5, balance: 50, strength: 5,
            activeCurses: [], heroBonusDice: 0, heroDamageBonus: 0
        )

        let result = CombatCalculator.calculateAttackWithFate(
            context: context, fateDeck: deck, worldResonance: 0,
            effortCards: 0, monsterDefense: 5, bonusDamage: 0
        )

        XCTAssertTrue(result.isHit)
        XCTAssertEqual(result.baseStrength, 5)
        XCTAssertEqual(result.totalAttack, 7)  // 5 + 2
        XCTAssertEqual(result.damage, 4)       // max(1, 7-5+2)
        XCTAssertNotNil(result.fateDrawResult)
    }

    func testFateAttackMiss() {
        // strength 3, fate -2, defense 5 -> total = 3 + (-2) = 1 < 5 -> miss
        let cards = [FateCard(id: "f1", modifier: -2, name: "Curse")]
        let deck = FateDeckManager(cards: cards)
        let context = CombatPlayerContext(
            health: 10, maxHealth: 10, faith: 5, balance: 50, strength: 3,
            activeCurses: [], heroBonusDice: 0, heroDamageBonus: 0
        )

        let result = CombatCalculator.calculateAttackWithFate(
            context: context, fateDeck: deck, worldResonance: 0,
            effortCards: 0, monsterDefense: 5, bonusDamage: 0
        )

        XCTAssertFalse(result.isHit)
        XCTAssertEqual(result.damage, 0)
    }

    func testFateAttackWithEffort() {
        // strength 3, fate -1, effort 3, defense 5
        // total = 3 + 3 + (-1) + 0 = 5 >= 5 -> hit
        let cards = [FateCard(id: "f1", modifier: -1, name: "Bad")]
        let deck = FateDeckManager(cards: cards)
        let context = CombatPlayerContext(
            health: 10, maxHealth: 10, faith: 5, balance: 50, strength: 3,
            activeCurses: [], heroBonusDice: 0, heroDamageBonus: 0
        )

        let result = CombatCalculator.calculateAttackWithFate(
            context: context, fateDeck: deck, worldResonance: 0,
            effortCards: 3, monsterDefense: 5, bonusDamage: 0
        )

        XCTAssertEqual(result.effortBonus, 3)
        XCTAssertEqual(result.totalAttack, 5)  // 3 + 3 + (-1)
        XCTAssertTrue(result.isHit)
    }

    func testFateAttackResonanceModifiesFate() {
        // Card has resonance rule: in deepNav zone, modifyValue = -3
        // effectiveValue = 1 + (-3) = -2
        let cards = [FateCard(
            id: "nav_card", modifier: 1, name: "Nav Wind",
            resonanceRules: [FateResonanceRule(zone: .deepNav, modifyValue: -3)]
        )]
        let deck = FateDeckManager(cards: cards)
        let context = CombatPlayerContext(
            health: 10, maxHealth: 10, faith: 5, balance: 50, strength: 5,
            activeCurses: [], heroBonusDice: 0, heroDamageBonus: 0
        )

        // deepNav zone requires resonance <= -61
        let result = CombatCalculator.calculateAttackWithFate(
            context: context, fateDeck: deck, worldResonance: -80,
            effortCards: 0, monsterDefense: 5, bonusDamage: 0
        )

        XCTAssertEqual(result.fateDrawResult?.effectiveValue, -2)
        XCTAssertEqual(result.totalAttack, 3)  // 5 + (-2)
    }

    func testFateAttackReturnsSideEffects() {
        let cards = [FateCard(
            id: "f1", modifier: 1, name: "Shifting",
            onDrawEffects: [FateDrawEffect(type: .shiftResonance, value: -5)]
        )]
        let deck = FateDeckManager(cards: cards)
        let context = CombatPlayerContext(
            health: 10, maxHealth: 10, faith: 5, balance: 50, strength: 5,
            activeCurses: [], heroBonusDice: 0, heroDamageBonus: 0
        )

        let result = CombatCalculator.calculateAttackWithFate(
            context: context, fateDeck: deck, worldResonance: 0,
            effortCards: 0, monsterDefense: 5, bonusDamage: 0
        )

        XCTAssertEqual(result.fateDrawEffects.count, 1)
        XCTAssertEqual(result.fateDrawEffects.first?.type, .shiftResonance)
        XCTAssertEqual(result.fateDrawEffects.first?.value, -5)
    }

    func testFateAttackFallbackWithoutDeck() {
        // No fate deck -> uses random fallback in range -1...2
        let context = CombatPlayerContext(
            health: 10, maxHealth: 10, faith: 5, balance: 50, strength: 5,
            activeCurses: [], heroBonusDice: 0, heroDamageBonus: 0
        )

        let result = CombatCalculator.calculateAttackWithFate(
            context: context, fateDeck: nil, worldResonance: 0,
            effortCards: 0, monsterDefense: 5, bonusDamage: 0
        )

        XCTAssertNil(result.fateDrawResult)
        // totalAttack = 5 + random(-1...2), so 4..7
        XCTAssertTrue(result.totalAttack >= 4 && result.totalAttack <= 7,
            "totalAttack should be in range 4...7, got \(result.totalAttack)")
    }

    // MARK: - Engine Integration

    func testCombatAttackActionUsesFateDeck() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame()

        let fateCards = [FateCard(id: "f1", modifier: 2, name: "Fortune")]
        engine.setupFateDeck(cards: fateCards)

        let enemy = Card(
            id: "test_enemy", name: "Beast", type: .monster, description: "Test",
            defense: 10, health: 20
        )
        engine.setupCombatEnemy(enemy)

        let healthBefore = engine.combatEnemyHealth
        let result = engine.performAction(.combatAttack(effortCards: 0, bonusDamage: 0))

        // Default strength is 5, fate +2 -> totalAttack = 7 < defense 10 -> miss
        let hasDamage = result.stateChanges.contains { change in
            if case .enemyDamaged = change { return true }
            return false
        }
        XCTAssertFalse(hasDamage, "Strength 5 + fate 2 = 7 should miss defense 10")
        XCTAssertEqual(engine.combatEnemyHealth, healthBefore)
    }

    func testCombatAttackEffortDiscardsCards() {
        let engine = TwilightGameEngine()

        let startingDeck = [
            Card(id: "s1", name: "Strike", type: .attack, description: "Attack", power: 3),
            Card(id: "s2", name: "Strike", type: .attack, description: "Attack", power: 3),
            Card(id: "d1", name: "Defend", type: .defense, description: "Defense", defense: 2),
            Card(id: "d2", name: "Defend", type: .defense, description: "Defense", defense: 2),
            Card(id: "h1", name: "Heal", type: .spell, description: "Heal")
        ]
        engine.initializeNewGame(playerName: "Test", heroId: nil, startingDeck: startingDeck)

        let fateCards = [FateCard(id: "f1", modifier: 0, name: "Neutral")]
        engine.setupFateDeck(cards: fateCards)

        let enemy = Card(
            id: "test_enemy", name: "Beast", type: .monster, description: "Test",
            defense: 5, health: 20
        )
        engine.setupCombatEnemy(enemy)
        engine.performAction(.combatInitialize)

        let handBefore = engine.playerHand.count

        _ = engine.performAction(.combatAttack(effortCards: 2, bonusDamage: 0))

        // Should have discarded up to 2 cards from hand
        let expectedDiscard = min(2, handBefore)
        XCTAssertEqual(engine.playerHand.count, handBefore - expectedDiscard,
            "Effort cards should be removed from hand")
    }

    func testCombatAttackAppliesFateDrawEffects() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame()

        let fateCards = [FateCard(
            id: "f1", modifier: 1, name: "Resonance Shifter",
            onDrawEffects: [FateDrawEffect(type: .shiftTension, value: 2)]
        )]
        engine.setupFateDeck(cards: fateCards)

        let enemy = Card(
            id: "test_enemy", name: "Beast", type: .monster, description: "Test",
            defense: 1, health: 20
        )
        engine.setupCombatEnemy(enemy)

        let tensionBefore = engine.worldTension
        let result = engine.performAction(.combatAttack(effortCards: 0, bonusDamage: 0))

        let hasTensionChange = result.stateChanges.contains { change in
            if case .tensionChanged = change { return true }
            return false
        }
        XCTAssertTrue(hasTensionChange, "Fate draw effects should be applied through attack pipeline")
        XCTAssertEqual(engine.worldTension, tensionBefore + 2)
    }
}

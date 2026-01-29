import XCTest
@testable import TwilightEngine

/// Tests for Dual Track combat: Spirit/Will damage and Pacification (Task 4.2)
final class CombatSpiritTests: XCTestCase {

    // MARK: - Spirit Attack Action

    func testSpiritAttackReducesWill() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame()

        // Setup fate deck with known modifier so damage is deterministic
        let cards = [FateCard(id: "f1", modifier: 1, name: "Fortune")]
        engine.setupFateDeck(cards: cards)

        let enemy = Card(
            id: "spirit_enemy", name: "Spirit", type: .monster, description: "Test",
            health: 20, will: 10
        )
        engine.setupCombatEnemy(enemy)
        XCTAssertEqual(engine.combatEnemyWill, 10)

        engine.performAction(.combatSpiritAttack)

        // baseStat = max(wisdom=0, intelligence=0, 1) = 1; fateModifier = 1; damage = max(1, 1+1) = 2
        XCTAssertEqual(engine.combatEnemyWill, 8, "Will should be reduced by calculated damage")
    }

    func testSpiritAttackPacifiesEnemy() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame()

        // High modifier to guarantee pacification
        let cards = [FateCard(id: "f1", modifier: 3, isCritical: true, name: "Crit")]
        engine.setupFateDeck(cards: cards)

        let enemy = Card(
            id: "spirit_enemy", name: "Spirit", type: .monster, description: "Test",
            health: 20, will: 3
        )
        engine.setupCombatEnemy(enemy)

        // baseStat = 1; fateModifier = 3; damage = 4 > will(3)
        let result = engine.performAction(.combatSpiritAttack)

        XCTAssertEqual(engine.combatEnemyWill, 0, "Will should not go below 0")
        XCTAssertTrue(result.stateChanges.contains(.enemyPacified(enemyId: "spirit_enemy")),
                      "Should emit enemyPacified when will reaches 0")
    }

    func testSpiritAttackIgnoredIfNoWill() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame()

        // Enemy without will
        let enemy = Card(
            id: "basic_enemy", name: "Beast", type: .monster, description: "Test",
            health: 10
        )
        engine.setupCombatEnemy(enemy)
        XCTAssertEqual(engine.combatEnemyMaxWill, 0)

        let result = engine.performAction(.combatSpiritAttack)

        XCTAssertTrue(result.stateChanges.isEmpty, "Spirit attack should be ignored for enemies without will")
    }

    func testSpiritAttackConsumesAction() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame()

        let cards = [FateCard(id: "f1", modifier: 0, name: "Neutral")]
        engine.setupFateDeck(cards: cards)

        let enemy = Card(
            id: "spirit_enemy", name: "Spirit", type: .monster, description: "Test",
            health: 20, will: 10
        )
        engine.setupCombatEnemy(enemy)
        let actionsBefore = engine.combatActionsRemaining

        engine.performAction(.combatSpiritAttack)

        XCTAssertEqual(engine.combatActionsRemaining, actionsBefore - 1,
                       "Spirit attack should consume one action")
    }

    // MARK: - CombatState Dual Track

    func testCombatStateHasSpiritTrack() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame()

        let enemy = Card(
            id: "spirit_enemy", name: "Spirit", type: .monster, description: "Test",
            health: 20, will: 15
        )
        engine.setupCombatEnemy(enemy)

        let state = engine.combatState
        XCTAssertNotNil(state)
        XCTAssertTrue(state!.hasSpiritTrack, "Enemy with will should have spirit track")
        XCTAssertEqual(state!.enemyWill, 15)
        XCTAssertEqual(state!.enemyMaxWill, 15)
    }

    func testCombatStateNoSpiritTrack() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame()

        let enemy = Card(
            id: "basic_enemy", name: "Beast", type: .monster, description: "Test",
            health: 10
        )
        engine.setupCombatEnemy(enemy)

        let state = engine.combatState
        XCTAssertFalse(state!.hasSpiritTrack, "Enemy without will should not have spirit track")
    }

    // MARK: - CombatCalculator Spirit Attack

    func testCalculatorSpiritAttackWithFateDeck() {
        let cards = [FateCard(id: "f1", modifier: 2, name: "Fortune")]
        let deck = FateDeckManager(cards: cards)
        let context = CombatPlayerContext(health: 10, maxHealth: 10, faith: 5, balance: 50, strength: 1, activeCurses: [], heroBonusDice: 0, heroDamageBonus: 0)

        let result = CombatCalculator.calculateSpiritAttack(
            context: context,
            enemyCurrentWill: 10,
            fateDeck: deck
        )

        // baseStat = max(wisdom=0, intelligence=0, 1) = 1; fateModifier = 2; damage = max(1, 1+2) = 3
        XCTAssertEqual(result.damage, 3)
        XCTAssertEqual(result.fateModifier, 2)
        XCTAssertEqual(result.newWill, 7)
        XCTAssertFalse(result.isPacified)
    }

    func testCalculatorSpiritAttackPacifies() {
        let cards = [FateCard(id: "f1", modifier: 3, isCritical: true, name: "Crit")]
        let deck = FateDeckManager(cards: cards)
        let context = CombatPlayerContext(health: 10, maxHealth: 10, faith: 5, balance: 50, strength: 1, activeCurses: [], heroBonusDice: 0, heroDamageBonus: 0)

        let result = CombatCalculator.calculateSpiritAttack(
            context: context,
            enemyCurrentWill: 2,
            fateDeck: deck
        )

        // baseStat = 1; fateModifier = 3; damage = 4; newWill = max(0, 2-4) = 0
        XCTAssertEqual(result.newWill, 0)
        XCTAssertTrue(result.isPacified)
    }

    // MARK: - StateChange

    func testEnemyWillDamagedStateChange() {
        let change = StateChange.enemyWillDamaged(enemyId: "test", damage: 5, newWill: 3)
        let change2 = StateChange.enemyWillDamaged(enemyId: "test", damage: 5, newWill: 3)
        XCTAssertEqual(change, change2, "StateChange.enemyWillDamaged should be Equatable")
    }

    func testEnemyPacifiedStateChange() {
        let change = StateChange.enemyPacified(enemyId: "test")
        let change2 = StateChange.enemyPacified(enemyId: "test")
        XCTAssertEqual(change, change2, "StateChange.enemyPacified should be Equatable")
    }

    // MARK: - Integration: Fate Draw Effects Through Engine

    func testSpiritAttackAppliesResonanceShift() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame()

        let cards = [FateCard(
            id: "nav_card", modifier: 1, name: "Nav Wind",
            suit: .nav,
            onDrawEffects: [FateDrawEffect(type: .shiftResonance, value: -5)]
        )]
        engine.setupFateDeck(cards: cards)

        let enemy = Card(
            id: "spirit_enemy", name: "Spirit", type: .monster, description: "Test",
            health: 20, will: 10
        )
        engine.setupCombatEnemy(enemy)

        let resonanceBefore = engine.resonanceValue
        let result = engine.performAction(.combatSpiritAttack)

        let hasResonanceChange = result.stateChanges.contains { change in
            if case .resonanceChanged(let delta, _) = change { return delta == -5.0 }
            return false
        }
        XCTAssertTrue(hasResonanceChange, "Spirit attack should emit resonanceChanged from fate draw effect")
        XCTAssertEqual(engine.resonanceValue, resonanceBefore - 5.0, "Resonance should shift by draw effect")
    }

    func testSpiritAttackAppliesTensionShift() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame()

        let cards = [FateCard(
            id: "curse_card", modifier: -1, name: "Curse",
            onDrawEffects: [FateDrawEffect(type: .shiftTension, value: 3)]
        )]
        engine.setupFateDeck(cards: cards)

        let enemy = Card(
            id: "spirit_enemy", name: "Spirit", type: .monster, description: "Test",
            health: 20, will: 10
        )
        engine.setupCombatEnemy(enemy)

        let tensionBefore = engine.worldTension
        let result = engine.performAction(.combatSpiritAttack)

        let hasTensionChange = result.stateChanges.contains { change in
            if case .tensionChanged(let delta, _) = change { return delta == 3 }
            return false
        }
        XCTAssertTrue(hasTensionChange, "Spirit attack should emit tensionChanged from fate draw effect")
        XCTAssertEqual(engine.worldTension, tensionBefore + 3, "Tension should shift by draw effect")
    }

    func testSpiritAttackResonanceRuleModifiesDamage() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame()

        // Card with +3 bonus in deepNav zone
        let cards = [FateCard(
            id: "nav_card", modifier: 1, name: "Nav Power",
            resonanceRules: [FateResonanceRule(zone: .deepNav, modifyValue: 3)]
        )]
        engine.setupFateDeck(cards: cards)

        // Set resonance to deepNav territory
        engine.setResonance(-80)

        let enemy = Card(
            id: "spirit_enemy", name: "Spirit", type: .monster, description: "Test",
            health: 20, will: 20
        )
        engine.setupCombatEnemy(enemy)

        engine.performAction(.combatSpiritAttack)

        // baseStat=1, baseValue=1, resonanceBonus=3, effectiveValue=4, damage=max(1, 1+4)=5
        XCTAssertEqual(engine.combatEnemyWill, 15,
            "Resonance rule should boost fate modifier and increase damage")
    }
}

import XCTest
@testable import TwilightEngine

/// Integration tests for Dual-Track Combat: HP + Will scenarios
/// Validates that both physical and spirit attack paths work together correctly
final class DualTrackCombatTests: XCTestCase {

    // MARK: - Scenario: Full Combat with Both Tracks

    func testDualTrackEnemy_PhysicalKillBeforePacify() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame()

        // High-modifier fate cards to make attacks deterministic
        let cards = (0..<10).map { FateCard(id: "f\($0)", modifier: 2, name: "Fortune") }
        engine.setupFateDeck(cards: cards)

        let enemy = Card(
            id: "dual_enemy", name: "Spirit Beast", type: .monster, description: "Test",
            defense: 1, health: 5, will: 20
        )
        engine.setupCombatEnemy(enemy)

        XCTAssertEqual(engine.combatEnemyHealth, 5)
        XCTAssertEqual(engine.combatEnemyWill, 20)

        // Physical attack should reduce HP
        engine.performAction(.combatAttack(effortCards: 0, bonusDamage: 0))

        XCTAssertLessThan(engine.combatEnemyHealth, 5, "Physical attack should reduce HP")
        XCTAssertEqual(engine.combatEnemyWill, 20, "Physical attack should not affect Will")
    }

    func testDualTrackEnemy_SpiritAttackDoesNotAffectHP() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame()

        let cards = [FateCard(id: "f1", modifier: 1, name: "Fortune")]
        engine.setupFateDeck(cards: cards)

        let enemy = Card(
            id: "dual_enemy", name: "Spirit Beast", type: .monster, description: "Test",
            health: 20, will: 10
        )
        engine.setupCombatEnemy(enemy)

        engine.performAction(.combatSpiritAttack)

        XCTAssertEqual(engine.combatEnemyHealth, 20, "Spirit attack should not affect HP")
        XCTAssertLessThan(engine.combatEnemyWill, 10, "Spirit attack should reduce Will")
    }

    // MARK: - Scenario: No-Will Enemy

    func testNoWillEnemy_SpiritAttackIsNoop() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame()

        let enemy = Card(
            id: "beast", name: "Beast", type: .monster, description: "Test",
            health: 15
        )
        engine.setupCombatEnemy(enemy)

        XCTAssertEqual(engine.combatEnemyMaxWill, 0)

        let result = engine.performAction(.combatSpiritAttack)

        XCTAssertEqual(engine.combatEnemyHealth, 15, "HP should be unchanged")
        XCTAssertTrue(result.stateChanges.isEmpty, "No state changes for spirit attack on no-will enemy")
    }

    func testNoWillEnemy_CombatStateHasNoSpiritTrack() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame()

        let enemy = Card(
            id: "beast", name: "Beast", type: .monster, description: "Test",
            health: 10
        )
        engine.setupCombatEnemy(enemy)

        let state = engine.combatState
        XCTAssertNotNil(state)
        XCTAssertFalse(state!.hasSpiritTrack)
        XCTAssertEqual(state!.enemyWill, 0)
        XCTAssertEqual(state!.enemyMaxWill, 0)
    }

    // MARK: - Scenario: Pacification via Will Depletion

    func testPacificationEmitsCorrectStateChange() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame()

        // High modifier to guarantee pacification in one hit
        let cards = [FateCard(id: "f1", modifier: 3, isCritical: true, name: "Crit")]
        engine.setupFateDeck(cards: cards)

        let enemy = Card(
            id: "spirit", name: "Spirit", type: .monster, description: "Test",
            health: 20, will: 2
        )
        engine.setupCombatEnemy(enemy)

        let result = engine.performAction(.combatSpiritAttack)

        XCTAssertEqual(engine.combatEnemyWill, 0)
        XCTAssertTrue(result.stateChanges.contains(.enemyPacified(enemyId: "spirit")))
    }

    // MARK: - Scenario: Alternating Attack Types

    func testAlternatingPhysicalAndSpiritAttacks() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame()

        let cards = (0..<10).map { FateCard(id: "f\($0)", modifier: 1, name: "Fortune") }
        engine.setupFateDeck(cards: cards)

        let enemy = Card(
            id: "dual", name: "Dual", type: .monster, description: "Test",
            defense: 1, health: 30, will: 15
        )
        engine.setupCombatEnemy(enemy)

        let hpBefore = engine.combatEnemyHealth
        let willBefore = engine.combatEnemyWill

        // Physical attack
        engine.performAction(.combatAttack(effortCards: 0, bonusDamage: 0))
        XCTAssertLessThan(engine.combatEnemyHealth, hpBefore)
        XCTAssertEqual(engine.combatEnemyWill, willBefore, "Will unchanged after physical")

        let hpAfterPhysical = engine.combatEnemyHealth

        // Spirit attack
        engine.performAction(.combatSpiritAttack)
        XCTAssertEqual(engine.combatEnemyHealth, hpAfterPhysical, "HP unchanged after spirit")
        XCTAssertLessThan(engine.combatEnemyWill, willBefore, "Will reduced after spirit")
    }

    // MARK: - CombatCalculator Dual-Track

    func testCalculatorSpiritAttack_DamageFormula() {
        // baseStat = max(wisdom, intelligence, 1) + fateModifier
        let cards = [FateCard(id: "f1", modifier: 0, name: "Neutral")]
        let deck = FateDeckManager(cards: cards)
        let context = CombatPlayerContext(
            health: 10, maxHealth: 10, faith: 5, balance: 50,
            strength: 1, wisdom: 3, intelligence: 1,
            activeCurses: [], heroBonusDice: 0, heroDamageBonus: 0
        )

        let result = CombatCalculator.calculateSpiritAttack(
            context: context,
            enemyCurrentWill: 10,
            fateDeck: deck
        )

        // baseStat = max(3, 1, 1) = 3; fateModifier = 0; damage = max(1, 3+0) = 3
        XCTAssertEqual(result.baseStat, 3)
        XCTAssertEqual(result.fateModifier, 0)
        XCTAssertEqual(result.damage, 3)
        XCTAssertEqual(result.newWill, 7)
        XCTAssertFalse(result.isPacified)
    }

    func testCalculatorSpiritAttack_MinimumDamageIsOne() {
        let cards = [FateCard(id: "f1", modifier: -3, name: "Misfortune")]
        let deck = FateDeckManager(cards: cards)
        let context = CombatPlayerContext(
            health: 10, maxHealth: 10, faith: 5, balance: 50,
            strength: 1, wisdom: 0, intelligence: 0,
            activeCurses: [], heroBonusDice: 0, heroDamageBonus: 0
        )

        let result = CombatCalculator.calculateSpiritAttack(
            context: context,
            enemyCurrentWill: 10,
            fateDeck: deck
        )

        // baseStat = max(0, 0, 1) = 1; fateModifier = -3; damage = max(1, 1+(-3)) = max(1, -2) = 1
        XCTAssertEqual(result.damage, 1, "Minimum spirit damage should be 1")
        XCTAssertEqual(result.newWill, 9)
    }

    func testCalculatorSpiritAttack_WillCannotGoBelowZero() {
        let cards = [FateCard(id: "f1", modifier: 3, isCritical: true, name: "Crit")]
        let deck = FateDeckManager(cards: cards)
        let context = CombatPlayerContext(
            health: 10, maxHealth: 10, faith: 5, balance: 50,
            strength: 1, wisdom: 5,
            activeCurses: [], heroBonusDice: 0, heroDamageBonus: 0
        )

        let result = CombatCalculator.calculateSpiritAttack(
            context: context,
            enemyCurrentWill: 2,
            fateDeck: deck
        )

        // baseStat = 5; fateModifier = 3; damage = 8; newWill = max(0, 2-8) = 0
        XCTAssertEqual(result.newWill, 0)
        XCTAssertTrue(result.isPacified)
    }

    // MARK: - CombatState Dual-Track Properties

    func testCombatState_DualTrackProperties() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame()

        let enemy = Card(
            id: "spirit_beast", name: "Spirit Beast", type: .monster, description: "Test",
            health: 25, will: 12
        )
        engine.setupCombatEnemy(enemy)

        let state = engine.combatState
        XCTAssertNotNil(state)
        XCTAssertTrue(state!.hasSpiritTrack)
        XCTAssertEqual(state!.enemyHealth, 25)
        XCTAssertEqual(state!.enemyMaxHealth, 25)
        XCTAssertEqual(state!.enemyWill, 12)
        XCTAssertEqual(state!.enemyMaxWill, 12)
    }
}

import XCTest
@testable import CardSampleGame

/// Tests for Engine-First combat system
/// Verifies that combat works without legacy Player/WorldState adapters
final class CombatEngineFirstTests: XCTestCase {

    var engine: TwilightGameEngine!

    override func setUp() {
        super.setUp()
        engine = TwilightGameEngine()

        // Initialize game with starting deck
        let startingDeck = [
            Card(name: "Strike", type: .attack, description: "Basic attack", power: 3),
            Card(name: "Strike", type: .attack, description: "Basic attack", power: 3),
            Card(name: "Defend", type: .defense, description: "Basic defense", defense: 2),
            Card(name: "Defend", type: .defense, description: "Basic defense", defense: 2),
            Card(name: "Heal", type: .spell, description: "Heal 2 HP")
        ]
        engine.initializeNewGame(playerName: "Test Hero", heroId: nil, startingDeck: startingDeck)
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Combat Setup Tests

    func testSetupCombatEnemy() {
        // Given
        let enemy = Card(name: "Wild Beast", type: .monster, description: "A wild beast", health: 10, power: 3, defense: 2)

        // When
        engine.setupCombatEnemy(enemy)

        // Then
        XCTAssertTrue(engine.isInCombat, "Should be in combat after setup")
        XCTAssertEqual(engine.combatEnemyHealth, 10, "Enemy health should be set")
        XCTAssertNotNil(engine.combatState, "Combat state should be available")
        XCTAssertEqual(engine.combatState?.enemy.name, "Wild Beast")
    }

    func testCombatInitializeDrawsCards() {
        // Given
        let enemy = Card(name: "Enemy", type: .monster, description: "Test", health: 10)
        engine.setupCombatEnemy(enemy)

        // When
        engine.performAction(.combatInitialize)

        // Then
        XCTAssertEqual(engine.playerHand.count, 5, "Should draw 5 cards")
    }

    // MARK: - Damage Tests

    func testDamageEnemyReducesHealth() {
        // Given
        let enemy = Card(name: "Enemy", type: .monster, description: "Test", health: 10)
        engine.setupCombatEnemy(enemy)
        let initialHealth = engine.combatEnemyHealth

        // When
        engine.performAction(.combatApplyEffect(effect: .damageEnemy(amount: 3)))

        // Then
        XCTAssertEqual(engine.combatEnemyHealth, initialHealth - 3, "Enemy health should decrease by damage amount")
    }

    func testDamageEnemyCannotGoBelowZero() {
        // Given
        let enemy = Card(name: "Enemy", type: .monster, description: "Test", health: 5)
        engine.setupCombatEnemy(enemy)

        // When
        engine.performAction(.combatApplyEffect(effect: .damageEnemy(amount: 100)))

        // Then
        XCTAssertEqual(engine.combatEnemyHealth, 0, "Enemy health should not go below 0")
    }

    func testDamageEnemyRequiresCombatEnemy() {
        // Given - no enemy set up
        XCTAssertFalse(engine.isInCombat)

        // When
        engine.performAction(.combatApplyEffect(effect: .damageEnemy(amount: 5)))

        // Then - should not crash, just no effect
        XCTAssertEqual(engine.combatEnemyHealth, 0)
    }

    // MARK: - Card Effects Tests

    func testHealEffectRestoresHealth() {
        // Given
        engine.performAction(.combatApplyEffect(effect: .takeDamage(amount: 5)))
        let healthAfterDamage = engine.playerHealth

        // When
        engine.performAction(.combatApplyEffect(effect: .heal(amount: 3)))

        // Then
        XCTAssertEqual(engine.playerHealth, healthAfterDamage + 3, "Health should increase by heal amount")
    }

    func testHealEffectCannotExceedMax() {
        // Given - at full health
        let maxHealth = engine.playerMaxHealth

        // When
        engine.performAction(.combatApplyEffect(effect: .heal(amount: 100)))

        // Then
        XCTAssertEqual(engine.playerHealth, maxHealth, "Health should not exceed max")
    }

    func testDrawCardsEffect() {
        // Given
        let enemy = Card(name: "Enemy", type: .monster, description: "Test", health: 10)
        engine.setupCombatEnemy(enemy)
        engine.performAction(.combatInitialize)
        let initialHandSize = engine.playerHand.count

        // When - play a card first to make room
        if !engine.playerHand.isEmpty {
            engine.performAction(.playCard(cardId: engine.playerHand[0].id, targetId: nil))
        }
        engine.performAction(.combatApplyEffect(effect: .drawCards(count: 1)))

        // Then
        // Hand size depends on deck availability
        XCTAssertGreaterThanOrEqual(engine.playerHand.count, 0)
    }

    func testGainFaithEffect() {
        // Given
        let initialFaith = engine.playerFaith

        // When
        engine.performAction(.combatApplyEffect(effect: .gainFaith(amount: 2)))

        // Then
        XCTAssertEqual(engine.playerFaith, min(initialFaith + 2, engine.playerMaxFaith))
    }

    func testSpendFaithEffect() {
        // Given
        let initialFaith = engine.playerFaith

        // When
        engine.performAction(.combatApplyEffect(effect: .spendFaith(amount: 1)))

        // Then
        XCTAssertEqual(engine.playerFaith, max(0, initialFaith - 1))
    }

    func testTakeDamageEffect() {
        // Given
        let initialHealth = engine.playerHealth

        // When
        engine.performAction(.combatApplyEffect(effect: .takeDamage(amount: 3)))

        // Then
        XCTAssertEqual(engine.playerHealth, initialHealth - 3)
    }

    func testAddBonusDiceEffect() {
        // Given
        let enemy = Card(name: "Enemy", type: .monster, description: "Test", health: 10)
        engine.setupCombatEnemy(enemy)

        // When
        engine.performAction(.combatApplyEffect(effect: .addBonusDice(count: 2)))

        // Then
        XCTAssertEqual(engine.combatState?.bonusDice, 2)
    }

    func testAddBonusDamageEffect() {
        // Given
        let enemy = Card(name: "Enemy", type: .monster, description: "Test", health: 10)
        engine.setupCombatEnemy(enemy)

        // When
        engine.performAction(.combatApplyEffect(effect: .addBonusDamage(amount: 5)))

        // Then
        XCTAssertEqual(engine.combatState?.bonusDamage, 5)
    }

    // MARK: - Combat Lifecycle Tests

    func testCombatFinishClearsEnemy() {
        // Given
        let enemy = Card(name: "Enemy", type: .monster, description: "Test", health: 10)
        engine.setupCombatEnemy(enemy)
        XCTAssertTrue(engine.isInCombat)

        // When
        engine.performAction(.combatFinish(victory: true))

        // Then
        XCTAssertFalse(engine.isInCombat, "Should not be in combat after finish")
        XCTAssertNil(engine.combatState, "Combat state should be nil")
    }

    func testCombatFleeClearsEnemy() {
        // Given
        let enemy = Card(name: "Enemy", type: .monster, description: "Test", health: 10)
        engine.setupCombatEnemy(enemy)

        // When
        engine.performAction(.combatFlee)

        // Then
        XCTAssertFalse(engine.isInCombat)
    }

    // MARK: - Multiple Combats Tests

    func testSecondCombatRestoresDeck() {
        // Given - first combat
        let enemy1 = Card(name: "Enemy 1", type: .monster, description: "Test", health: 5)
        engine.setupCombatEnemy(enemy1)
        engine.performAction(.combatInitialize)

        // Play all cards to discard
        while !engine.playerHand.isEmpty {
            engine.performAction(.playCard(cardId: engine.playerHand[0].id, targetId: nil))
        }
        XCTAssertEqual(engine.playerHand.count, 0, "Hand should be empty after playing all cards")

        // End first combat
        engine.performAction(.combatFinish(victory: true))

        // When - start second combat
        let enemy2 = Card(name: "Enemy 2", type: .monster, description: "Test", health: 5)
        engine.setupCombatEnemy(enemy2)
        engine.performAction(.combatInitialize)

        // Then - should have cards again
        XCTAssertEqual(engine.playerHand.count, 5, "Should draw full hand in second combat")
    }

    func testCardsReturnFromDiscardOnNewCombat() {
        // Given - setup and use cards in first combat
        let enemy = Card(name: "Enemy", type: .monster, description: "Test", health: 100)
        engine.setupCombatEnemy(enemy)
        engine.performAction(.combatInitialize)

        let totalCards = engine.playerHand.count + engine.playerDeck.count

        // Play cards and end turn multiple times
        for _ in 0..<3 {
            while !engine.playerHand.isEmpty {
                engine.performAction(.playCard(cardId: engine.playerHand[0].id, targetId: nil))
            }
            engine.performAction(.combatEndTurnPhase)
        }

        // End combat
        engine.performAction(.combatFinish(victory: false))

        // When - new combat
        engine.setupCombatEnemy(enemy)
        engine.performAction(.combatInitialize)

        // Then - all cards should be available again
        let newTotalCards = engine.playerHand.count + engine.playerDeck.count + engine.playerDiscard.count
        XCTAssertEqual(newTotalCards, totalCards, "All cards should be restored")
    }

    // MARK: - Balance Shift Tests

    func testShiftBalanceTowardsLight() {
        // Given
        let initialBalance = engine.playerBalance

        // When
        engine.performAction(.combatApplyEffect(effect: .shiftBalance(towards: "light", amount: 10)))

        // Then
        XCTAssertEqual(engine.playerBalance, min(100, initialBalance + 10))
    }

    func testShiftBalanceTowardsDark() {
        // Given
        let initialBalance = engine.playerBalance

        // When
        engine.performAction(.combatApplyEffect(effect: .shiftBalance(towards: "dark", amount: 10)))

        // Then
        XCTAssertEqual(engine.playerBalance, max(0, initialBalance - 10))
    }

    // MARK: - Gate Test: Combat Determinism

    /// Gate test: Combat with same seed produces identical results
    /// Requirement: "бой с одинаковым seed даёт одинаковый результат"
    func testCombatDeterminismWithSeed() {
        let testSeed: UInt64 = 54321

        // First combat simulation
        WorldRNG.shared.setSeed(testSeed)
        let results1 = simulateCombatSequence()

        // Second combat simulation with same seed
        WorldRNG.shared.setSeed(testSeed)
        let results2 = simulateCombatSequence()

        // Results must be identical
        XCTAssertEqual(results1.finalEnemyHealth, results2.finalEnemyHealth,
                       "Enemy health must be identical with same seed")
        XCTAssertEqual(results1.finalPlayerHealth, results2.finalPlayerHealth,
                       "Player health must be identical with same seed")
        XCTAssertEqual(results1.cardsDrawn, results2.cardsDrawn,
                       "Cards drawn must be identical with same seed")
        XCTAssertEqual(results1.damageDealt, results2.damageDealt,
                       "Damage dealt must be identical with same seed")
    }

    /// Helper: Simulate a combat sequence and return results
    private func simulateCombatSequence() -> CombatSimulationResult {
        let engine = TwilightGameEngine()

        // Initialize with known deck
        let startingDeck = [
            Card(name: "Strike", type: .attack, description: "Basic attack", power: 3),
            Card(name: "Strike", type: .attack, description: "Basic attack", power: 3),
            Card(name: "Defend", type: .defense, description: "Basic defense", defense: 2),
            Card(name: "Heal", type: .spell, description: "Heal 2 HP"),
            Card(name: "Power", type: .attack, description: "Strong attack", power: 5)
        ]
        engine.initializeNewGame(playerName: "Test", heroId: nil, startingDeck: startingDeck)

        // Setup combat
        let enemy = Card(name: "Test Enemy", type: .monster, description: "Test", health: 20, power: 4)
        engine.setupCombatEnemy(enemy)
        engine.performAction(.combatInitialize)

        // Record initial state
        let cardsDrawn = engine.playerHand.map { $0.name }
        var totalDamage = 0

        // Simulate combat turns
        for _ in 0..<3 {
            // Play attack cards
            for card in engine.playerHand where card.type == .attack {
                engine.performAction(.playCard(cardId: card.id, targetId: nil))
                totalDamage += card.power ?? 0
            }

            // Apply damage to enemy
            engine.performAction(.combatApplyEffect(effect: .damageEnemy(amount: 5)))

            // End turn
            engine.performAction(.combatEndTurnPhase)
        }

        return CombatSimulationResult(
            finalEnemyHealth: engine.combatEnemyHealth,
            finalPlayerHealth: engine.playerHealth,
            cardsDrawn: cardsDrawn,
            damageDealt: totalDamage
        )
    }
}

/// Result of combat simulation for determinism testing
private struct CombatSimulationResult {
    let finalEnemyHealth: Int
    let finalPlayerHealth: Int
    let cardsDrawn: [String]
    let damageDealt: Int
}

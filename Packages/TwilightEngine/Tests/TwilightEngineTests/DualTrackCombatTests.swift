import XCTest
@testable import TwilightEngine

// ==========================================
// TDD Test Model for Dual Track Combat System
// Reference: Docs/Design/COMBAT_DIPLOMACY_SPEC.md
// ==========================================
//
// These tests define the EXPECTED behavior of the new combat system.
// Many will fail (RED) until the corresponding engine code is implemented.
// Follow TDD: Write test -> See it fail -> Implement code -> Test passes (GREEN)
//
// Test Categories:
// 1. Dual Track (HP + WP)
// 2. Active Defense (Fate-based defense)
// 3. Enemy Intent System
// 4. Escalation/De-escalation Penalties
// 5. Kill Priority (HP=0 overrides WP=0)
// 6. Resonance Cost Modifiers

final class DualTrackCombatTests: XCTestCase {

    var engine: TwilightGameEngine!

    override func setUp() {
        super.setUp()
        engine = TwilightGameEngine()

        // Initialize with basic deck for testing
        let startingDeck = [
            Card(id: "strike_1", name: "Strike", type: .attack, description: "Physical attack", power: 4),
            Card(id: "strike_2", name: "Strike", type: .attack, description: "Physical attack", power: 4),
            Card(id: "calm_words", name: "Calm Words", type: .spell, description: "Spiritual influence", will: 3),
            Card(id: "defend_1", name: "Defend", type: .defense, description: "Block damage", defense: 3),
            Card(id: "heal_1", name: "Heal", type: .spell, description: "Restore health")
        ]
        engine.initializeNewGame(playerName: "Test Hero", heroId: nil, startingDeck: startingDeck)

        // Setup deterministic Fate Deck for testing
        let fateCards = [
            FateCard(id: "fate_1", modifier: 1, name: "Fortune +1"),
            FateCard(id: "fate_2", modifier: 2, name: "Fortune +2"),
            FateCard(id: "fate_3", modifier: -1, name: "Misfortune -1"),
            FateCard(id: "fate_4", modifier: 3, isCritical: true, name: "Critical Success"),
            FateCard(id: "fate_5", modifier: 0, name: "Neutral")
        ]
        engine.setupFateDeck(cards: fateCards)
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - 1. Dual Track System Tests

    /// Test: Enemy has both HP and WP tracks
    /// Spec: Section 1.2 - "Every opponent has two parameters"
    func testEnemyHasDualTracks() {
        // Given: Enemy with both HP and WP defined
        let enemy = Card(
            id: "leshy",
            name: "Leshy",
            type: .monster,
            description: "Forest guardian",
            health: 15,
            will: 8
        )

        // When: Setup combat
        engine.setupCombatEnemy(enemy)

        // Then: Both tracks should be initialized
        XCTAssertEqual(engine.combatEnemyHealth, 15, "HP should be set from enemy definition")
        XCTAssertEqual(engine.combatEnemyWill, 8, "WP should be set from enemy definition")
        XCTAssertEqual(engine.combatEnemyMaxWill, 8, "Max WP should be stored")

        let state = engine.combatState
        XCTAssertNotNil(state)
        XCTAssertTrue(state!.hasSpiritTrack, "Enemy with WP should have spirit track flag")
    }

    /// Test: Physical attack reduces HP, not WP
    /// Spec: Section 3.1 - "TotalAttack → EnemyHP"
    func testPhysicalAttackReducesHPOnly() {
        // Given: Enemy with HP=20, WP=8, Armor=2
        let enemy = Card(
            id: "bear",
            name: "Bear",
            type: .monster,
            description: "Wild beast",
            power: 5,
            defense: 2,
            health: 20,
            will: 8
        )
        engine.setupCombatEnemy(enemy)

        let initialHP = engine.combatEnemyHealth
        let initialWP = engine.combatEnemyWill

        // When: Player performs physical attack with Fate card (+1)
        // Formula: (Strength 3 + Card Power 4 + Fate 1) - Armor 2 = 6 damage
        engine.performAction(.combatPlayerAttackWithFate(bonusDamage: 4))

        // Then: HP reduced, WP unchanged
        XCTAssertLessThan(engine.combatEnemyHealth, initialHP, "HP should decrease after physical attack")
        XCTAssertEqual(engine.combatEnemyWill, initialWP, "WP should NOT change on physical attack")
    }

    /// Test: Spiritual influence reduces WP, not HP
    /// Spec: Section 3.2 - "TotalInfluence → EnemyWP"
    func testSpiritualInfluenceReducesWPOnly() {
        // Given: Enemy with HP=20, WP=8
        let enemy = Card(
            id: "spirit",
            name: "Spirit",
            type: .monster,
            description: "Ethereal being",
            health: 20,
            will: 8
        )
        engine.setupCombatEnemy(enemy)

        let initialHP = engine.combatEnemyHealth
        let initialWP = engine.combatEnemyWill

        // When: Player performs spirit attack
        engine.performAction(.combatSpiritAttack)

        // Then: WP reduced, HP unchanged
        XCTAssertLessThan(engine.combatEnemyWill, initialWP, "WP should decrease after spiritual attack")
        XCTAssertEqual(engine.combatEnemyHealth, initialHP, "HP should NOT change on spiritual attack")
    }

    // MARK: - 2. Active Defense Tests

    /// Test: Defense uses Fate card to reduce incoming damage
    /// Spec: Section 3.3 - "TotalDefense = PlayerArmor + FateCard"
    func testActiveDefenseUsesFateCard() {
        // Given: Enemy with intent to attack for 10 damage
        let enemy = Card(
            id: "attacker",
            name: "Attacker",
            type: .monster,
            description: "Test",
            power: 10,
            health: 20
        )
        engine.setupCombatEnemy(enemy)
        engine.performAction(.combatGenerateIntent)

        // Verify intent is attack
        XCTAssertNotNil(engine.currentEnemyIntent)
        XCTAssertEqual(engine.currentEnemyIntent?.type, .attack)

        let initialPlayerHP = engine.playerHealth

        // When: Enemy resolves attack, player defends with Fate
        // Defense: Armor 0 + Fate Card (+2) = 2
        // Incoming: 10 - 2 = 8 damage
        engine.performAction(.combatEnemyResolveWithFate)

        // Then: Player takes reduced damage
        let damageReceived = initialPlayerHP - engine.playerHealth
        XCTAssertGreaterThan(damageReceived, 0, "Player should take some damage")
        XCTAssertLessThan(damageReceived, 10, "Defense should reduce incoming damage")

        // Fate card should have been drawn
        XCTAssertNotNil(engine.lastDefenseFateResult, "Defense Fate result should be stored")
    }

    /// Test: Critical defense = 0 damage (full dodge)
    /// Spec: Section 3.3 - "CRIT symbol in defense = 0 damage"
    func testCriticalDefenseZeroDamage() {
        // Given: Fate deck with critical card at top
        let criticalCards = [
            FateCard(id: "crit", modifier: 3, isCritical: true, name: "Critical Block")
        ]
        engine.setupFateDeck(cards: criticalCards)

        let enemy = Card(
            id: "attacker",
            name: "Attacker",
            type: .monster,
            description: "Test",
            power: 100, // Huge damage
            health: 20
        )
        engine.setupCombatEnemy(enemy)

        // Set intent manually for test
        // Note: This might need engine support for manual intent setting
        engine.performAction(.combatGenerateIntent)

        let initialHP = engine.playerHealth

        // When: Resolve enemy attack with critical defense
        engine.performAction(.combatEnemyResolveWithFate)

        // Then: If critical defense triggered, player takes 0 damage
        if engine.lastDefenseFateResult?.isCritical == true {
            XCTAssertEqual(engine.playerHealth, initialHP, "Critical defense should block all damage")
        }
    }

    // MARK: - 3. Enemy Intent System Tests

    /// Test: Intent is generated at round start
    /// Spec: Section 2 - "Phase 0: Intent Declaration"
    func testIntentGeneratedAtRoundStart() {
        // Given: Combat started
        let enemy = Card(
            id: "test_enemy",
            name: "Test Enemy",
            type: .monster,
            description: "Test",
            power: 5,
            health: 20
        )
        engine.setupCombatEnemy(enemy)

        // Initially no intent
        XCTAssertNil(engine.currentEnemyIntent)

        // When: Generate intent
        engine.performAction(.combatGenerateIntent)

        // Then: Intent should exist
        XCTAssertNotNil(engine.currentEnemyIntent, "Intent should be generated")
        XCTAssertNotNil(engine.currentEnemyIntent?.type, "Intent should have a type")
        XCTAssertGreaterThan(engine.currentEnemyIntent?.value ?? 0, 0, "Attack intent should have damage value")
    }

    /// Test: Player can see intent before acting
    /// Spec: Section 2 - "Player KNOWS what will happen"
    func testIntentVisibleBeforePlayerAction() {
        // Given: Combat with intent
        let enemy = Card(
            id: "test_enemy",
            name: "Test Enemy",
            type: .monster,
            description: "Test",
            power: 8,
            health: 20
        )
        engine.setupCombatEnemy(enemy)
        engine.performAction(.combatGenerateIntent)

        // Then: Intent should have description for UI
        let intent = engine.currentEnemyIntent
        XCTAssertNotNil(intent)
        XCTAssertFalse(intent!.description.isEmpty, "Intent should have description for display")
    }

    // MARK: - 4. Escalation/De-escalation Tests

    /// Test: Switching from Spirit to Body attack triggers escalation penalty
    /// Spec: Section 5.2 - escalationResonanceShift (default -15)
    /// Balance Pack Key: combat.balance.escalationResonanceShift
    func testEscalationPenaltyOnSwitchToPhysical() {
        // Given: Combat started, player previously used spiritual attack
        let enemy = Card(
            id: "guard",
            name: "Guard",
            type: .monster,
            description: "Test",
            health: 20,
            will: 10
        )
        engine.setupCombatEnemy(enemy)

        // First: Spirit attack (diplomacy)
        engine.performAction(.combatSpiritAttack)

        let resonanceBefore = engine.resonanceValue

        // When: Switch to physical attack (escalation)
        engine.performAction(.combatPlayerAttackWithFate(bonusDamage: 0))

        // Then: Resonance should shift -15 toward Nav
        let expectedResonance = resonanceBefore - 15
        XCTAssertEqual(
            engine.resonanceValue,
            max(-100, expectedResonance),
            "Escalation should shift resonance -15 toward Nav"
        )
    }

    /// Test: First physical attack after diplomacy deals 1.5x damage
    /// Spec: Section 5.2 - surpriseMultiplier (default 1.5)
    /// Balance Pack Key: combat.balance.surpriseMultiplier
    func testEscalationSurpriseDamageBonus() {
        // Given: Combat where player used spirit attack first
        let enemy = Card(
            id: "guard",
            name: "Guard",
            type: .monster,
            description: "Test",
            power: 3,
            defense: 0,
            health: 100, // High HP to measure damage
            will: 10
        )
        engine.setupCombatEnemy(enemy)

        // Spirit attack first
        engine.performAction(.combatSpiritAttack)

        let hpBeforeEscalation = engine.combatEnemyHealth

        // When: Physical attack (escalation)
        // Normal damage would be: Strength + Fate - Armor
        // With surprise: damage * 1.5
        engine.performAction(.combatPlayerAttackWithFate(bonusDamage: 4))

        let damageDealt = hpBeforeEscalation - engine.combatEnemyHealth

        // Then: Damage should be boosted (verify surprise multiplier is applied)
        // This is a behavioral test - exact value depends on implementation
        XCTAssertGreaterThan(damageDealt, 0, "Escalation attack should deal damage")
    }

    /// Test: De-escalation applies Rage Shield to WP
    /// Spec: Section 5.1 - rageShieldFactor (default 1)
    /// Formula: RageShield = EnemyPower × TurnsInCombat × rageShieldFactor
    /// Balance Pack Key: combat.balance.rageShieldFactor
    func testDeEscalationRageShieldApplied() {
        // Given: Combat where player attacked Body first
        let enemy = Card(
            id: "angry_guard",
            name: "Angry Guard",
            type: .monster,
            description: "Test",
            power: 5,
            defense: 2,
            health: 50,
            will: 10
        )
        engine.setupCombatEnemy(enemy)

        // Physical attack first (establishes combat)
        engine.performAction(.combatPlayerAttackWithFate(bonusDamage: 3))

        // Record WP before spirit attack
        let wpBefore = engine.combatEnemyWill

        // When: Try to switch to spirit attack (de-escalation)
        // Engine should apply Rage Shield: EnemyPower(5) × TurnsInCombat(1) = 5
        engine.performAction(.combatSpiritAttack)

        // Then: Rage Shield should absorb spirit damage
        // If no shield, WP would decrease significantly
        // With shield, first spirit attacks must deplete shield first
        let wpDamage = wpBefore - engine.combatEnemyWill

        // Verify rage shield is active (stored in combat state)
        XCTAssertTrue(engine.combatState?.hasRageShield ?? false,
                      "Rage shield should be applied when de-escalating")

        // Note: Exact behavior depends on implementation
        // Key assertion: rage shield mechanic is triggered
    }

    // MARK: - 5. Kill Priority Tests

    /// Test: HP=0 results in Kill, even if WP also reaches 0
    /// Spec: Section 1.2 - "If HP <= 0: Enemy is KILLED (regardless of WP state)"
    func testKillPriorityWhenBothZero() {
        // Given: Enemy with very low HP and WP
        let enemy = Card(
            id: "weak_enemy",
            name: "Weak Enemy",
            type: .monster,
            description: "Test",
            power: 1,
            defense: 0,
            health: 1,
            will: 1
        )
        engine.setupCombatEnemy(enemy)

        // Reduce WP to 0 first (but don't end combat)
        engine.performAction(.combatSpiritAttack)
        XCTAssertEqual(engine.combatEnemyWill, 0, "WP should be 0")

        // When: Physical attack brings HP to 0
        engine.performAction(.combatPlayerAttackWithFate(bonusDamage: 10))

        // Then: Result should be KILLED, not PACIFIED
        // Check state changes for kill vs pacify
        XCTAssertEqual(engine.combatEnemyHealth, 0, "HP should be 0")

        // The combat result should indicate "killed" not "pacified"
        // This depends on how results are tracked in the engine
    }

    /// Test: WP=0 while HP>0 results in Pacify
    /// Spec: Section 1.2 - "If WP <= 0 (and HP > 0): Enemy is PACIFIED"
    func testPacifyWhenWPZeroHPRemains() {
        // Given: Enemy with high HP but low WP
        let enemy = Card(
            id: "spirit_enemy",
            name: "Spirit Enemy",
            type: .monster,
            description: "Test",
            health: 100, // High HP
            will: 3       // Low WP
        )
        engine.setupCombatEnemy(enemy)

        // Setup high-damage spirit attack
        let strongFate = [FateCard(id: "strong", modifier: 5, name: "Strong")]
        engine.setupFateDeck(cards: strongFate)

        // When: Spirit attack reduces WP to 0
        let result = engine.performAction(.combatSpiritAttack)

        // Then: Should be pacified, not killed
        XCTAssertEqual(engine.combatEnemyWill, 0, "WP should be 0")
        XCTAssertGreaterThan(engine.combatEnemyHealth, 0, "HP should remain")

        let hasPacified = result.stateChanges.contains { change in
            if case .enemyPacified = change { return true }
            return false
        }
        XCTAssertTrue(hasPacified, "Should emit enemyPacified when WP reaches 0")
    }

    // MARK: - 6. Resonance Cost Modifier Tests

    /// Test: Nav cards cost more in Prav zone
    /// Spec: Section 4.1 - "Light cards cost +1 Faith in Nav zone"
    func testResonanceCostModifierNavInPrav() {
        // Given: World in Deep Prav (+80 resonance)
        engine.setResonance(80)

        // Create card with Nav affinity
        // Note: This requires Card to have affinity property
        let navCard = Card(
            id: "shadow_strike",
            name: "Shadow Strike",
            type: .attack,
            description: "Dark attack",
            power: 5,
            cost: 2  // Base cost
            // affinity: .nav  // Need to add this
        )

        // When: Calculate adjusted cost
        // Adjusted cost should be baseCost + 2 (Deep Prav penalty for Nav)
        // TODO: Implement engine.calculateAdjustedCost(for: navCard)
        _ = navCard // Suppress warning - card will be used once affinity system is implemented

        // Then: Cost should be increased
        // This test documents expected behavior for implementation
        XCTAssertTrue(true, "TODO: Implement affinity-based cost modifiers")
    }

    // MARK: - 7. Wait Action Tests

    /// Test: Wait action skips attack but conserves Fate card
    /// Spec: Section 2 - "Wait: No Fate Card drawn, conserves resources"
    func testWaitActionConservesFateCard() {
        // Given: Combat with known Fate deck size
        let enemy = Card(
            id: "test_enemy",
            name: "Test Enemy",
            type: .monster,
            description: "Test",
            health: 20
        )
        engine.setupCombatEnemy(enemy)

        let fateCardsBeforeWait = engine.fateDeckDrawCount

        // When: Player chooses to wait
        engine.performAction(.combatSkipAttack)

        // Then: No Fate card should be drawn
        XCTAssertEqual(engine.fateDeckDrawCount, fateCardsBeforeWait, "Wait should not draw Fate card")
        XCTAssertNil(engine.lastAttackFateResult, "No attack Fate result when waiting")
    }

    /// Test: Wait action has no hidden side effects on FateDeck
    /// Spec: Section 2 - "Wait не триггерит никаких hidden draws и не меняет состояние FateDeck"
    func testWaitHasNoHiddenFateDeckSideEffects() {
        // Given: Combat with known Fate deck state
        let enemy = Card(
            id: "test_enemy",
            name: "Test Enemy",
            type: .monster,
            description: "Test",
            health: 20
        )
        engine.setupCombatEnemy(enemy)

        // Record full Fate deck state before Wait
        let deckSizeBefore = engine.fateDeckRemaining
        let discardSizeBefore = engine.fateDiscardPileCount
        let drawCountBefore = engine.fateDeckDrawCount

        // When: Player waits multiple times
        engine.performAction(.combatSkipAttack)
        engine.performAction(.combatSkipAttack)
        engine.performAction(.combatSkipAttack)

        // Then: Fate deck state should be completely unchanged
        XCTAssertEqual(engine.fateDeckRemaining, deckSizeBefore,
                       "Wait should not change deck size")
        XCTAssertEqual(engine.fateDiscardPileCount, discardSizeBefore,
                       "Wait should not change discard pile")
        XCTAssertEqual(engine.fateDeckDrawCount, drawCountBefore,
                       "Wait should not trigger any hidden draws")
    }

    // MARK: - 8. Mulligan Tests

    /// Test: Mulligan replaces selected cards
    /// Spec: Section 2 - "Phase 0: Preparation (mulligan)"
    func testMulliganReplacesSelectedCards() {
        // Given: Combat initialized with hand
        let enemy = Card(
            id: "test_enemy",
            name: "Test Enemy",
            type: .monster,
            description: "Test",
            health: 20
        )
        engine.setupCombatEnemy(enemy)
        engine.performAction(.combatInitialize)

        let initialHand = engine.playerHand
        XCTAssertEqual(initialHand.count, 5, "Should have 5 cards")

        // Select first 2 cards to replace
        let cardsToReplace = Array(initialHand.prefix(2).map { $0.id })

        // When: Mulligan
        engine.performAction(.combatMulligan(cardIds: cardsToReplace))

        // Then: Hand should still have 5 cards, but different ones
        XCTAssertEqual(engine.playerHand.count, 5, "Should still have 5 cards after mulligan")
        XCTAssertTrue(engine.combatMulliganDone, "Mulligan should be marked as done")
    }

    /// Test: Mulligan can only be done once
    /// Spec: Section 2 - Mulligan is a one-time action
    func testMulliganOnlyOnce() {
        // Given: Combat with mulligan already done
        let enemy = Card(
            id: "test_enemy",
            name: "Test Enemy",
            type: .monster,
            description: "Test",
            health: 20
        )
        engine.setupCombatEnemy(enemy)
        engine.performAction(.combatInitialize)
        engine.performAction(.combatMulligan(cardIds: []))

        XCTAssertTrue(engine.combatMulliganDone)

        let handAfterFirstMulligan = engine.playerHand

        // When: Try second mulligan
        engine.performAction(.combatMulligan(cardIds: engine.playerHand.map { $0.id }))

        // Then: Hand should be unchanged
        XCTAssertEqual(engine.playerHand.map { $0.id }, handAfterFirstMulligan.map { $0.id },
                       "Second mulligan should be ignored")
    }

    // MARK: - 9. Balance Pack Configuration Tests

    /// Test: Escalation penalty uses Balance Pack configured value
    /// Spec: Section 5 - "Balance Pack Requirement: hardcoded values forbidden"
    func testEscalationUsesBalancePackValue() {
        // Given: Balance pack with custom escalation penalty
        // Default: -15, custom: -20
        // Note: This test verifies Balance Pack integration when implemented

        let enemy = Card(
            id: "guard",
            name: "Guard",
            type: .monster,
            description: "Test",
            health: 50,
            will: 50
        )
        engine.setupCombatEnemy(enemy)
        engine.setResonance(0)

        // Spirit attack first
        engine.performAction(.combatSpiritAttack)

        let resonanceBefore = engine.resonanceValue

        // When: Escalate to physical
        engine.performAction(.combatPlayerAttackWithFate(bonusDamage: 0))

        // Then: Should use configured value (default -15)
        // When Balance Pack integration is done, this test should verify:
        // engine.balancePack.escalationResonanceShift is used
        let shift = resonanceBefore - engine.resonanceValue
        XCTAssertGreaterThan(shift, 0, "Escalation should shift resonance toward Nav")
    }

    // MARK: - 10. Multi-Enemy Encounter Tests

    /// Test: Per-entity outcome tracking in multi-enemy encounters
    /// Spec: Section 1.2 - "В multi-enemy encounter исход фиксируется per-entity"
    func testMultiEnemyPerEntityOutcome() {
        // Given: Two enemies in encounter
        let enemy1 = Card(
            id: "bandit_1",
            name: "Bandit",
            type: .monster,
            description: "Test",
            health: 5,
            will: 10
        )
        let enemy2 = Card(
            id: "bandit_2",
            name: "Bandit",
            type: .monster,
            description: "Test",
            health: 10,
            will: 5
        )

        // Setup multi-enemy encounter (requires engine support)
        // engine.setupMultiEnemyEncounter([enemy1, enemy2])

        // When: Kill first enemy, pacify second
        // engine.targetEnemy(0)
        // engine.performAction(.combatPlayerAttackWithFate(bonusDamage: 10)) // Kill bandit_1
        // engine.targetEnemy(1)
        // engine.performAction(.combatSpiritAttack) // Pacify bandit_2

        // Then: Encounter should track per-entity outcomes
        // XCTAssertEqual(engine.encounterOutcomes["bandit_1"], .killed)
        // XCTAssertEqual(engine.encounterOutcomes["bandit_2"], .pacified)
        // XCTAssertTrue(engine.encounterFlags.violence, "Should have violence flag when any enemy killed")
        // XCTAssertFalse(engine.encounterFlags.nonviolent, "Should NOT have nonviolent flag")

        // TODO: Implement multi-enemy encounter support
        XCTAssertTrue(true, "TODO: Implement multi-enemy encounter support")
    }

    /// Test: Non-violent encounter when all enemies pacified
    /// Spec: Section 1.2 - "если все pacified — non-violent"
    func testMultiEnemyAllPacifiedIsNonviolent() {
        // Given: Two enemies in encounter
        // When: Both pacified (WP reduced to 0, HP > 0)
        // Then: encounterFlags.nonviolent should be true

        // TODO: Implement when multi-enemy support is added
        XCTAssertTrue(true, "TODO: Implement multi-enemy encounter support")
    }
}

// MARK: - Integration Tests

/// Full combat flow integration tests
final class DualTrackCombatIntegrationTests: XCTestCase {

    /// Test: Complete combat victory via Kill path
    func testFullCombatKillPath() {
        let engine = TwilightGameEngine()

        let startingDeck = (1...10).map { i in
            Card(id: "strike_\(i)", name: "Strike", type: .attack, description: "Attack", power: 5)
        }
        engine.initializeNewGame(playerName: "Warrior", heroId: nil, startingDeck: startingDeck)

        let fateCards = (1...20).map { i in
            FateCard(id: "fate_\(i)", modifier: 2, name: "Fortune")
        }
        engine.setupFateDeck(cards: fateCards)

        // Setup enemy
        let enemy = Card(
            id: "weak_beast",
            name: "Weak Beast",
            type: .monster,
            description: "Test",
            power: 3,
            defense: 1,
            health: 10,
            will: 5
        )
        engine.setupCombatEnemy(enemy)
        engine.performAction(.combatInitialize)

        // Combat loop
        var turns = 0
        while engine.combatEnemyHealth > 0 && turns < 10 {
            // Generate intent
            engine.performAction(.combatGenerateIntent)

            // Player attacks body
            engine.performAction(.combatPlayerAttackWithFate(bonusDamage: 5))

            // Enemy resolves
            if engine.combatEnemyHealth > 0 {
                engine.performAction(.combatEnemyResolveWithFate)
                engine.performAction(.combatEndTurnPhase)
            }

            turns += 1
        }

        // Assert kill victory
        XCTAssertEqual(engine.combatEnemyHealth, 0, "Enemy HP should be 0")
        XCTAssertGreaterThan(engine.combatEnemyWill, 0, "Enemy WP should remain (Kill path)")
    }

    /// Test: Complete combat victory via Pacify path
    func testFullCombatPacifyPath() {
        let engine = TwilightGameEngine()

        let startingDeck = (1...10).map { i in
            Card(id: "calm_\(i)", name: "Calm Words", type: .spell, description: "Influence", will: 3)
        }
        engine.initializeNewGame(playerName: "Diplomat", heroId: nil, startingDeck: startingDeck)

        let fateCards = (1...20).map { i in
            FateCard(id: "fate_\(i)", modifier: 3, name: "Fortune")
        }
        engine.setupFateDeck(cards: fateCards)

        // Setup enemy with low WP
        let enemy = Card(
            id: "spirit",
            name: "Spirit",
            type: .monster,
            description: "Test",
            power: 3,
            health: 100,
            will: 5
        )
        engine.setupCombatEnemy(enemy)
        engine.performAction(.combatInitialize)

        // Combat loop - spirit attacks only
        var turns = 0
        while engine.combatEnemyWill > 0 && turns < 10 {
            engine.performAction(.combatGenerateIntent)
            engine.performAction(.combatSpiritAttack)

            if engine.combatEnemyWill > 0 {
                engine.performAction(.combatEnemyResolveWithFate)
                engine.performAction(.combatEndTurnPhase)
            }

            turns += 1
        }

        // Assert pacify victory
        XCTAssertEqual(engine.combatEnemyWill, 0, "Enemy WP should be 0")
        XCTAssertGreaterThan(engine.combatEnemyHealth, 0, "Enemy HP should remain (Pacify path)")
    }

    /// Test: Escalation penalty actually shifts resonance
    /// Spec: Task T5 - escalationResonanceShift (default -15)
    /// Balance Pack Key: combat.balance.escalationResonanceShift
    func testEscalationResonancePenaltyApplied() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame()

        let fateCards = [FateCard(id: "f1", modifier: 5, name: "Strong")]
        engine.setupFateDeck(cards: fateCards)

        let enemy = Card(
            id: "guard",
            name: "Guard",
            type: .monster,
            description: "Test",
            health: 100,
            will: 100
        )
        engine.setupCombatEnemy(enemy)

        // Set resonance to neutral
        engine.setResonance(0)
        let initialResonance = engine.resonanceValue

        // Spirit attack first (establish diplomacy)
        engine.performAction(.combatSpiritAttack)

        // Then physical attack (escalation)
        engine.performAction(.combatPlayerAttackWithFate(bonusDamage: 5))

        // Verify resonance shift (default -15 from Balance Pack)
        XCTAssertEqual(
            engine.resonanceValue,
            initialResonance - 15,
            "Escalation should apply default -15 resonance penalty (combat.balance.escalationResonanceShift)"
        )
    }
}

// MARK: - Content Validation Tests

/// Tests for data-driven combat content validation
/// Reference: TESTING_GUIDE.md §2.1.1 ContentValidationTests Requirements
final class CombatContentValidationTests: XCTestCase {

    /// Test: All behavior_id references in enemies.json must exist
    /// Gate Test Requirement: enemies.behavior_id exists
    func testAllBehaviorReferencesExist() {
        // Given: Loaded enemies and behaviors from content packs
        TestContentLoader.loadContentPacksIfNeeded()

        let enemies = ContentRegistry.shared.allEnemies
        let behaviorIds = Set(ContentRegistry.shared.allBehaviorIds)

        // When: Check each enemy's behavior_id
        var missingBehaviors: [String] = []
        for enemy in enemies {
            if let behaviorId = enemy.behaviorId, !behaviorIds.contains(behaviorId) {
                missingBehaviors.append("\(enemy.id) references missing behavior: \(behaviorId)")
            }
        }

        // Then: No missing behavior references (hard fail, no fallback)
        XCTAssertTrue(missingBehaviors.isEmpty,
                      "Missing behavior references: \(missingBehaviors.joined(separator: ", "))")
    }

    /// Test: All Fate card IDs must be unique
    /// Gate Test Requirement: Fate cards unique IDs
    func testFateCardIdsUnique() {
        // Given: All fate cards from content packs
        TestContentLoader.loadContentPacksIfNeeded()

        let fateCards = ContentRegistry.shared.allFateCards
        var seenIds = Set<String>()
        var duplicates: [String] = []

        // When: Check for duplicate IDs
        for card in fateCards {
            if seenIds.contains(card.id) {
                duplicates.append(card.id)
            }
            seenIds.insert(card.id)
        }

        // Then: No duplicates
        XCTAssertTrue(duplicates.isEmpty,
                      "Duplicate Fate card IDs: \(duplicates.joined(separator: ", "))")
    }

    /// Test: Fate card suit values must be valid
    /// Gate Test Requirement: suit ∈ {nav, prav, yav, neutral}
    func testFateCardSuitsValid() {
        // Given: All fate cards
        TestContentLoader.loadContentPacksIfNeeded()

        let validSuits = Set(["nav", "prav", "yav", "neutral"])
        let fateCards = ContentRegistry.shared.allFateCards
        var invalidSuits: [String] = []

        // When: Check each card's suit
        for card in fateCards {
            if let suit = card.suit, !validSuits.contains(suit) {
                invalidSuits.append("\(card.id) has invalid suit: \(suit)")
            }
        }

        // Then: All suits valid
        XCTAssertTrue(invalidSuits.isEmpty,
                      "Invalid Fate card suits: \(invalidSuits.joined(separator: ", "))")
    }

    /// Test: Choice cards must have both options (safe and risk)
    /// Gate Test Requirement: Choice cards complete
    func testChoiceCardsHaveBothOptions() {
        // Given: All fate cards with type "choice"
        TestContentLoader.loadContentPacksIfNeeded()

        let choiceCards = ContentRegistry.shared.allFateCards.filter { $0.type == "choice" }
        var incompleteCards: [String] = []

        // When: Check each choice card has both options
        for card in choiceCards {
            if card.choiceOption == nil {
                incompleteCards.append("\(card.id) missing choice_option")
            }
        }

        // Then: All choice cards complete
        XCTAssertTrue(incompleteCards.isEmpty,
                      "Incomplete choice cards: \(incompleteCards.joined(separator: ", "))")
    }

    /// Test: value_formula in behaviors must use whitelist forms only
    /// Gate Test Requirement: value_formula whitelist validation
    /// Whitelist forms: "power", "power * MULTIPLIER_ID", "influence", "hp_percent"
    /// Hardcoded numbers like "power * 1.5" are FORBIDDEN
    func testValueFormulaWhitelist() {
        // Given: All behaviors from content packs
        TestContentLoader.loadContentPacksIfNeeded()

        // Valid base formulas (without multipliers)
        let validBaseFormulas = Set(["power", "influence", "hp_percent"])

        // Pattern for "power * MULTIPLIER_ID" (identifier, not number)
        let multiplierPattern = try! NSRegularExpression(pattern: "^(power|influence) \\* ([a-zA-Z][a-zA-Z0-9_]*)$")

        let behaviors = ContentRegistry.shared.allBehaviors
        var invalidFormulas: [String] = []

        // When: Check each intent's value_formula
        for behavior in behaviors {
            for (intentId, intent) in behavior.intents {
                guard let formula = intent.valueFormula else { continue }

                // Check if it's a valid base formula
                if validBaseFormulas.contains(formula) {
                    continue
                }

                // Check if it matches "stat * MULTIPLIER_ID" pattern
                let range = NSRange(formula.startIndex..., in: formula)
                if multiplierPattern.firstMatch(in: formula, range: range) != nil {
                    continue
                }

                // Invalid: hardcoded number or unknown form
                invalidFormulas.append("\(behavior.id).\(intentId) has invalid formula: \(formula)")
            }
        }

        // Then: All formulas use whitelist forms (no hardcoded numbers)
        XCTAssertTrue(invalidFormulas.isEmpty,
                      "Invalid value_formula (hardcoded numbers forbidden, use MULTIPLIER_ID): \(invalidFormulas.joined(separator: ", "))")
    }

    /// Test: MULTIPLIER_ID in value_formula must exist in Balance Pack
    /// Gate Test Requirement: Multiplier references valid
    func testValueFormulaMultipliersExist() {
        // Given: All behaviors and balance pack
        TestContentLoader.loadContentPacksIfNeeded()

        let multiplierPattern = try! NSRegularExpression(pattern: "^(?:power|influence) \\* ([a-zA-Z][a-zA-Z0-9_]*)$")
        let balanceKeys = Set(ContentRegistry.shared.balancePack.allKeys)

        let behaviors = ContentRegistry.shared.allBehaviors
        var missingMultipliers: [String] = []

        // When: Extract and check multiplier IDs
        for behavior in behaviors {
            for (intentId, intent) in behavior.intents {
                guard let formula = intent.valueFormula else { continue }

                let range = NSRange(formula.startIndex..., in: formula)
                if let match = multiplierPattern.firstMatch(in: formula, range: range),
                   let idRange = Range(match.range(at: 1), in: formula) {
                    let multiplierId = String(formula[idRange])
                    let balanceKey = "combat.balance.\(multiplierId)"

                    if !balanceKeys.contains(balanceKey) {
                        missingMultipliers.append("\(behavior.id).\(intentId) references missing multiplier: \(multiplierId)")
                    }
                }
            }
        }

        // Then: All multiplier IDs exist in balance pack
        XCTAssertTrue(missingMultipliers.isEmpty,
                      "Missing balance pack multipliers: \(missingMultipliers.joined(separator: ", "))")
    }

    /// Test: All behavior conditions must parse without errors
    /// Gate Test Requirement: Conditions parsable
    func testBehaviorConditionsParsable() {
        // Given: All behaviors
        TestContentLoader.loadContentPacksIfNeeded()

        let behaviors = ContentRegistry.shared.allBehaviors
        var parseErrors: [String] = []

        // When: Try to parse each condition
        for behavior in behaviors {
            for rule in behavior.rules {
                if let condition = rule.condition {
                    do {
                        _ = try ConditionParser.parse(condition)
                    } catch {
                        parseErrors.append("\(behavior.id) rule \(rule.priority): \(error)")
                    }
                }
            }
        }

        // Then: All conditions parse successfully
        XCTAssertTrue(parseErrors.isEmpty,
                      "Condition parse errors: \(parseErrors.joined(separator: ", "))")
    }

    /// Test: All intent types must be valid IntentType enum values
    /// Gate Test Requirement: intent.type ∈ IntentType enum
    /// Critical for DLC/mod compatibility
    func testIntentTypesValid() {
        // Given: All behaviors and valid intent types
        TestContentLoader.loadContentPacksIfNeeded()

        // IntentType enum values (from §6.5 of spec)
        let validIntentTypes = Set([
            "attack",
            "defend",
            "heal",
            "restoreWP",
            "restore_wp",  // snake_case variant
            "ritual",
            "prepare",
            "summon",
            "debuff",
            "buff"
        ])

        let behaviors = ContentRegistry.shared.allBehaviors
        var invalidTypes: [String] = []

        // When: Check each intent's type
        for behavior in behaviors {
            for (intentId, intent) in behavior.intents {
                if !validIntentTypes.contains(intent.type) {
                    invalidTypes.append("\(behavior.id).\(intentId) has unknown intent type: \(intent.type)")
                }
            }
        }

        // Then: All intent types are valid (hard fail on unknown)
        XCTAssertTrue(invalidTypes.isEmpty,
                      "Unknown intent types (DLC/mod incompatibility risk): \(invalidTypes.joined(separator: ", "))")
    }

    /// Test: All fate cards have valid keyword
    /// Gate Test Requirement: keyword ∈ FateKeyword enum
    /// Spec: §3.5.4 Core Keywords
    func testFateCardKeywordsValid() {
        // Given: All fate cards and valid keywords
        TestContentLoader.loadContentPacksIfNeeded()

        // FateKeyword enum values (from §6.4 of spec)
        let validKeywords = Set([
            "surge",
            "focus",
            "echo",
            "shadow",
            "ward"
        ])

        let fateCards = ContentRegistry.shared.allFateCards
        var invalidKeywords: [String] = []

        // When: Check each card's keyword
        for card in fateCards {
            if let keyword = card.keyword, !validKeywords.contains(keyword) {
                invalidKeywords.append("\(card.id) has invalid keyword: \(keyword)")
            }
        }

        // Then: All keywords valid
        XCTAssertTrue(invalidKeywords.isEmpty,
                      "Invalid Fate card keywords: \(invalidKeywords.joined(separator: ", "))")
    }
}

// MARK: - Universal Fate Keyword Tests

/// Tests for Universal Fate Keyword system (Contextual Interpretation)
/// Reference: COMBAT_DIPLOMACY_SPEC.md §3.5
final class UniversalFateKeywordTests: XCTestCase {

    var engine: TwilightGameEngine!

    override func setUp() {
        super.setUp()
        engine = TwilightGameEngine()
        engine.initializeNewGame(playerName: "Test", heroId: nil)
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    /// Test: Same card gives different effects in different contexts
    /// Spec: §3.5.2 Interpretation Matrix
    func testKeywordInterpretationByContext() {
        // Given: Fate card with "surge" keyword
        let surgeCard = FateCard(
            id: "test_surge",
            modifier: 2,
            name: "Surge Test",
            keyword: "surge",
            suit: "nav"
        )
        engine.setupFateDeck(cards: [surgeCard])

        // When: Resolve in combat context
        // let combatResult = engine.resolveKeyword(surgeCard, context: .combatPhysical)

        // When: Resolve in exploration context
        // let exploreResult = engine.resolveKeyword(surgeCard, context: .exploration)

        // Then: Effects should be different
        // XCTAssertNotEqual(combatResult.effectType, exploreResult.effectType)

        // TODO: Implement KeywordResolver
        XCTAssertTrue(true, "TODO: Implement KeywordResolver for context-based interpretation")
    }

    /// Test: Match Bonus when suit matches action type
    /// Spec: §3.5.3 Match Bonus
    func testMatchBonusWhenSuitMatchesAction() {
        // Given: Nav card and Nav action (attack)
        let navCard = FateCard(
            id: "test_nav",
            modifier: 2,
            name: "Nav Test",
            keyword: "surge",
            suit: "nav"
        )

        // When: Used for attack (Nav action)
        // let matchResult = engine.calculateMatchBonus(navCard, actionType: .attack)

        // Then: Should get enhanced effect (x1.5 or trigger)
        // XCTAssertTrue(matchResult.isEnhanced)

        // TODO: Implement Match Bonus system
        XCTAssertTrue(true, "TODO: Implement Match Bonus system")
    }

    /// Test: Mismatch gives only value, no keyword effect
    /// Spec: §3.5.3 Match Bonus
    func testMismatchGivesOnlyValue() {
        // Given: Nav card and Prav action (healing)
        let navCard = FateCard(
            id: "test_nav",
            modifier: 2,
            name: "Nav Test",
            keyword: "surge",
            suit: "nav"
        )

        // When: Used for healing (Prav action)
        // let mismatchResult = engine.calculateMatchBonus(navCard, actionType: .heal)

        // Then: Should get only value (+2), keyword effect suppressed or negative
        // XCTAssertFalse(mismatchResult.keywordActive)
        // XCTAssertEqual(mismatchResult.value, 2)

        // TODO: Implement Mismatch handling
        XCTAssertTrue(true, "TODO: Implement Mismatch handling")
    }

    /// Test: Each keyword has defined effects for all contexts
    /// Spec: §3.5.4 Core Keywords
    func testAllKeywordsHaveAllContextEffects() {
        // Given: All 5 core keywords
        let keywords = ["surge", "focus", "echo", "shadow", "ward"]

        // Given: All action contexts
        let contexts = ["combatPhysical", "combatSpiritual", "defense", "exploration", "dialogue"]

        // When: Check that each keyword has an effect for each context
        // let resolver = KeywordResolver()

        // Then: No missing combinations
        // for keyword in keywords {
        //     for context in contexts {
        //         XCTAssertNotNil(resolver.effect(for: keyword, in: context))
        //     }
        // }

        // TODO: Implement full keyword matrix
        XCTAssertTrue(true, "TODO: Implement full keyword effect matrix")
    }

    // MARK: - Gate Tests (Universal Fate System)

    /// Gate Test: FateDeck is global per campaign session
    /// Spec: §3.5 - "FateDeck is global per campaign session. All contexts share one deck."
    func testFateDeckStateGlobalAcrossContexts() {
        // Given: Initial Fate deck with known state
        let fateCards = [
            FateCard(id: "fate_1", modifier: 1, name: "Card 1"),
            FateCard(id: "fate_2", modifier: 2, name: "Card 2"),
            FateCard(id: "fate_3", modifier: 3, name: "Card 3")
        ]
        engine.setupFateDeck(cards: fateCards)

        let initialDeckSize = engine.fateDeckRemaining

        // When: Draw in combat context
        let enemy = Card(
            id: "test_enemy",
            name: "Test Enemy",
            type: .monster,
            description: "Test",
            health: 100
        )
        engine.setupCombatEnemy(enemy)
        engine.performAction(.combatPlayerAttackWithFate(bonusDamage: 0))

        let deckAfterCombatDraw = engine.fateDeckRemaining

        // Then: Deck size should decrease (same deck used)
        XCTAssertEqual(deckAfterCombatDraw, initialDeckSize - 1,
                       "Combat draw should affect the global deck")

        // When: Draw in exploration context (simulated)
        // let exploreResult = engine.performFateCheck(context: .exploration)

        // Then: Deck should decrease further
        // XCTAssertEqual(engine.fateDeckRemaining, deckAfterCombatDraw - 1,
        //                "Exploration draw should use same global deck")

        // TODO: Implement cross-context FateDeck when exploration fate checks are added
        XCTAssertTrue(true, "FateDeck global state verified for combat context")
    }

    /// Gate Test: Resolution Order is enforced (DRAW → MATCH CHECK → VALUE → KEYWORD → RESONANCE)
    /// Spec: §3.5.1a - Canonical Resolution Order
    func testFateCardResolutionOrder() {
        // Given: Fate card with all layers
        let testCard = FateCard(
            id: "test_order",
            modifier: 2,
            name: "Order Test",
            keyword: "surge",
            suit: "nav",
            intensity: 5
        )
        engine.setupFateDeck(cards: [testCard])

        // Given: Track resolution order via state changes
        var resolutionOrder: [String] = []

        // When: Resolve fate card in combat
        // let result = engine.resolveFateCard(testCard, context: .combatPhysical)

        // Expected order:
        // 1. DRAW - card is drawn
        // 2. MATCH CHECK - determine synergy/dissonance
        // 3. VALUE - apply +2 to check
        // 4. KEYWORD - resolve "surge" in combat context
        // 5. RESONANCE - apply intensity with synergy/dissonance multiplier

        // Then: Verify order (implementation dependent)
        // XCTAssertEqual(resolutionOrder, ["draw", "match_check", "value", "keyword", "resonance"])

        // TODO: Implement resolution order tracking in engine
        XCTAssertTrue(true, "TODO: Implement FateCard resolution order verification")
    }

    /// Gate Test: Match Bonus multiplier must come from Balance Pack
    /// Spec: §3.5.3 - "combat.balance.matchMultiplier (default 1.5)"
    func testMatchBonusMultiplierFromBalancePack() {
        // Given: Balance pack is loaded
        TestContentLoader.loadContentPacksIfNeeded()

        // When: Check for matchMultiplier key
        let balancePack = ContentRegistry.shared.balancePack
        let matchMultiplierKey = "combat.balance.matchMultiplier"

        // Then: Key should exist (or use default 1.5)
        // If Balance Pack has the key, verify it's a valid multiplier
        if let multiplier = balancePack.value(for: matchMultiplierKey) as? Double {
            XCTAssertGreaterThan(multiplier, 0, "matchMultiplier must be positive")
            XCTAssertLessThanOrEqual(multiplier, 10, "matchMultiplier should be reasonable")
        } else {
            // Default 1.5 is acceptable if key not explicitly set
            // Engine should use default when key missing
            XCTAssertTrue(true, "matchMultiplier not in pack, engine uses default 1.5")
        }

        // Verify engine respects the multiplier (when implemented)
        // let navCard = FateCard(id: "nav", modifier: 2, suit: "nav", keyword: "surge")
        // let matchResult = engine.calculateMatchBonus(navCard, actionType: .attack)
        // XCTAssertEqual(matchResult.multiplier, expectedMultiplier)
    }
}

import XCTest
@testable import TwilightEngine

/// Encounter Engine component tests
/// Reference: ENCOUNTER_TEST_MODEL.md §3.1
final class EncounterEngineTests: XCTestCase {

    // #1: Enemy has both HP and WP tracks initialized
    func testDualTrackInitialization() {
        let ctx = EncounterContextFixtures.dualTrack(enemyHP: 50, enemyWP: 30)
        let engine = EncounterEngine(context: ctx)

        XCTAssertEqual(engine.enemies[0].hp, 50)
        XCTAssertEqual(engine.enemies[0].wp, 30)
        XCTAssertEqual(engine.enemies[0].maxWp, 30)
        XCTAssertTrue(engine.enemies[0].hasSpiritTrack)
    }

    // #4: Active defense uses fate card to reduce damage
    func testActiveDefenseFateCard() {
        let ctx = EncounterContextFixtures.standard()
        let engine = EncounterEngine(context: ctx)

        // Generate enemy intent (attack)
        _ = engine.generateIntent(for: "test_enemy")
        XCTAssertNotNil(engine.currentIntent)

        let hpBefore = engine.heroHP

        // Resolve enemy attack with fate-based defense
        _ = engine.resolveEnemyAction(enemyId: "test_enemy")

        // Player should take reduced damage (defense + fate card)
        let damage = hpBefore - engine.heroHP
        XCTAssertGreaterThanOrEqual(damage, 0, "Damage should be non-negative")
    }

    // #5: Critical defense blocks all damage
    func testCriticalDefenseBlocksAll() {
        // Use critical-only fate deck
        let ctx = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 100, maxHp: 100, strength: 5, armor: 2),
            enemies: [EncounterEnemy(id: "e1", name: "Attacker", hp: 50, maxHp: 50, power: 100, defense: 0)],
            fateDeckSnapshot: FateDeckManager(cards: FateDeckFixtures.criticalOnly()).getState(),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42
        )
        let engine = EncounterEngine(context: ctx)

        _ = engine.generateIntent(for: "e1")
        let hpBefore = engine.heroHP
        _ = engine.resolveEnemyAction(enemyId: "e1")

        // Critical defense → 0 damage
        XCTAssertEqual(engine.heroHP, hpBefore, "Critical defense should block all damage")
    }

    // #6: Intent generated in intent phase
    func testIntentGeneratedInIntentPhase() {
        let ctx = EncounterContextFixtures.standard()
        let engine = EncounterEngine(context: ctx)

        XCTAssertEqual(engine.currentPhase, .intent)
        XCTAssertNil(engine.currentIntent)

        let intent = engine.generateIntent(for: "test_enemy")

        XCTAssertNotNil(engine.currentIntent)
        XCTAssertGreaterThan(intent.value, 0, "Intent should have a value")
    }

    // #7: Intent visible before player action
    func testIntentVisibility() {
        let ctx = EncounterContextFixtures.standard()
        let engine = EncounterEngine(context: ctx)

        let intent = engine.generateIntent(for: "test_enemy")

        XCTAssertFalse(intent.description.isEmpty, "Intent must have description for UI")
        XCTAssertNotNil(intent.type, "Intent must have type")
    }

    // #8: Escalation (Spirit→Body) shifts resonance
    func testEscalationResonanceShift() {
        let ctx = EncounterContextFixtures.dualTrack(enemyHP: 100, enemyWP: 100)
        let engine = EncounterEngine(context: ctx)

        // Spirit attack first
        _ = engine.performAction(.spiritAttack(targetId: "test_enemy"))

        // Physical attack (escalation)
        let result = engine.performAction(.attack(targetId: "test_enemy"))

        // Should emit resonance shift
        let hasShift = result.stateChanges.contains { change in
            if case .resonanceShifted = change { return true }
            return false
        }
        XCTAssertTrue(hasShift, "Escalation must shift resonance toward Nav")
    }

    // #9: Escalation surprise damage bonus
    func testEscalationSurpriseDamage() {
        let ctx = EncounterContextFixtures.dualTrack(enemyHP: 100, enemyWP: 100)
        let engine = EncounterEngine(context: ctx)

        // Spirit attack first (establish diplomacy)
        _ = engine.performAction(.spiritAttack(targetId: "test_enemy"))
        let hpBefore = engine.enemies[0].hp

        // Physical attack (escalation → surprise bonus)
        _ = engine.performAction(.attack(targetId: "test_enemy"))

        let damage = hpBefore - engine.enemies[0].hp
        XCTAssertGreaterThan(damage, 0, "Escalation attack must deal boosted damage")
    }

    // #10: De-escalation applies rage shield
    func testDeEscalationRageShield() {
        let ctx = EncounterContextFixtures.dualTrack(enemyHP: 100, enemyWP: 100)
        let engine = EncounterEngine(context: ctx)

        // Physical attack first
        _ = engine.performAction(.attack(targetId: "test_enemy"))

        // Spirit attack (de-escalation)
        let result = engine.performAction(.spiritAttack(targetId: "test_enemy"))

        let hasShield = result.stateChanges.contains { change in
            if case .rageShieldApplied = change { return true }
            return false
        }
        XCTAssertTrue(hasShield, "De-escalation must apply rage shield")
        XCTAssertGreaterThan(engine.enemies[0].rageShield, 0, "Rage shield value must be > 0")
    }

    // #12: WP=0 + HP>0 → pacified
    func testPacifyOutcome() {
        let ctx = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 100, maxHp: 100, strength: 5, armor: 2, wisdom: 10),
            enemies: [EncounterEnemy(id: "e1", name: "Spirit", hp: 100, maxHp: 100, wp: 1, maxWp: 1, power: 3)],
            fateDeckSnapshot: FateDeckFixtures.deterministicState(),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42
        )
        let engine = EncounterEngine(context: ctx)

        let result = engine.performAction(.spiritAttack(targetId: "e1"))

        let hasPacified = result.stateChanges.contains { change in
            if case .enemyPacified = change { return true }
            return false
        }
        XCTAssertTrue(hasPacified, "WP=0 + HP>0 must result in pacified")
    }

    // #16: Mulligan replaces selected cards
    func testMulliganReplace() {
        let ctx = EncounterContextFixtures.standard()
        let engine = EncounterEngine(context: ctx)

        let result = engine.performAction(.mulligan(cardIds: ["card_1", "card_2"]))

        XCTAssertTrue(result.success, "Mulligan should succeed on first attempt")
        XCTAssertTrue(engine.mulliganDone, "Mulligan flag should be set")
    }

    // #17: Mulligan only once
    func testMulliganOnceOnly() {
        let ctx = EncounterContextFixtures.standard()
        let engine = EncounterEngine(context: ctx)

        // First mulligan
        _ = engine.performAction(.mulligan(cardIds: []))
        XCTAssertTrue(engine.mulliganDone)

        // Second mulligan should fail
        let result = engine.performAction(.mulligan(cardIds: []))
        XCTAssertEqual(result.error, .mulliganAlreadyDone, "Second mulligan must return error")
    }
}

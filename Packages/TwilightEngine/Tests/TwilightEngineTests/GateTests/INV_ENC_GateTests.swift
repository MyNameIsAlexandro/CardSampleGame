import XCTest
@testable import TwilightEngine

/// Encounter Engine Invariants — Gate Tests
/// Reference: ENCOUNTER_TEST_MODEL.md §2.1
/// Rule: < 2 seconds, deterministic, no system RNG
final class INV_ENC_GateTests: XCTestCase {

    // INV-ENC-002: Physical attack affects only HP, not WP
    func test_INV_ENC_002_PhysicalAttackHPOnly() {
        // Arrange
        let ctx = EncounterContextFixtures.dualTrack(enemyHP: 50, enemyWP: 30)
        let engine = EncounterEngine(context: ctx)

        let initialHP = engine.enemies[0].hp
        let initialWP = engine.enemies[0].wp

        // Act: physical attack
        _ = engine.performAction(.attack(targetId: "test_enemy"))

        // Assert: HP changed, WP unchanged
        XCTAssertLessThan(engine.enemies[0].hp, initialHP, "HP must decrease after physical attack")
        XCTAssertEqual(engine.enemies[0].wp, initialWP, "WP must NOT change on physical attack")
    }

    // INV-ENC-002 (split): Spiritual attack affects only WP, not HP
    func test_INV_ENC_002_SpiritualAttackWPOnly() {
        // Arrange
        let ctx = EncounterContextFixtures.dualTrack(enemyHP: 50, enemyWP: 30)
        let engine = EncounterEngine(context: ctx)

        let initialHP = engine.enemies[0].hp
        let initialWP = engine.enemies[0].wp!

        // Act: spirit attack
        _ = engine.performAction(.spiritAttack(targetId: "test_enemy"))

        // Assert: WP changed, HP unchanged
        XCTAssertLessThan(engine.enemies[0].wp!, initialWP, "WP must decrease after spiritual attack")
        XCTAssertEqual(engine.enemies[0].hp, initialHP, "HP must NOT change on spiritual attack")
    }

    // INV-ENC-003: HP=0 → killed, regardless of WP state
    func test_INV_ENC_003_KillPriorityWhenBothZero() {
        // Arrange: weak enemy (1 HP, 1 WP)
        let ctx = EncounterContextFixtures.weakEnemy()
        let engine = EncounterEngine(context: ctx)

        // Act: spirit attack to reduce WP to 0
        _ = engine.performAction(.spiritAttack(targetId: "weak_enemy"))

        // Act: physical attack to reduce HP to 0
        let result = engine.performAction(.attack(targetId: "weak_enemy"))

        // Assert: outcome is killed (not pacified)
        let hasKilled = result.stateChanges.contains { change in
            if case .enemyKilled = change { return true }
            return false
        }
        XCTAssertTrue(hasKilled, "When HP=0, outcome must be .killed regardless of WP")
    }
}

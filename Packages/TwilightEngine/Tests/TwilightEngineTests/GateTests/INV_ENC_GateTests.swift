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
        _ = engine.advancePhase() // intent → playerAction
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
        _ = engine.advancePhase() // intent → playerAction
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

        // Round 1: spirit attack to reduce WP to 0
        _ = engine.advancePhase() // intent → playerAction
        _ = engine.performAction(.spiritAttack(targetId: "weak_enemy"))
        _ = engine.advancePhase() // → enemyResolution
        _ = engine.resolveEnemyAction(enemyId: "weak_enemy")
        _ = engine.advancePhase() // → roundEnd
        _ = engine.advancePhase() // → intent (round 2)
        _ = engine.generateIntent(for: "weak_enemy")

        // Round 2: physical attack to reduce HP to 0
        _ = engine.advancePhase() // → playerAction
        let result = engine.performAction(.attack(targetId: "weak_enemy"))

        // Assert: outcome is killed (not pacified)
        let hasKilled = result.stateChanges.contains { change in
            if case .enemyKilled = change { return true }
            return false
        }
        XCTAssertTrue(hasKilled, "When HP=0, outcome must be .killed regardless of WP")
    }

    // INV-ENC-004: Transaction Atomicity — input context is never mutated
    func test_INV_ENC_004_TransactionAtomicity() {
        let ctx = EncounterContextFixtures.standard()
        let engine = EncounterEngine(context: ctx)

        // Act: partial combat — attack enemy + resolve enemy action (takes damage)
        _ = engine.generateIntent(for: "test_enemy")
        _ = engine.advancePhase() // → playerAction
        _ = engine.performAction(.attack(targetId: "test_enemy"))
        _ = engine.advancePhase() // → enemyResolution
        _ = engine.resolveEnemyAction(enemyId: "test_enemy")

        let result = engine.finishEncounter()

        // Assert: input context is immutable (EncounterContext is a struct)
        XCTAssertEqual(ctx.hero.hp, 100, "Input context hero HP must be unchanged")
        XCTAssertEqual(ctx.enemies[0].hp, 50, "Input context enemy HP must be unchanged")

        // Engine internal state DID change
        XCTAssertLessThan(engine.enemies[0].hp, 50, "Engine enemy HP must have decreased")
        // Transaction captures the delta
        XCTAssertLessThanOrEqual(result.transaction.hpDelta, 0, "Transaction must record HP loss")
    }

    // INV-ENC-005: Determinism — same context + seed = same observable state
    func test_INV_ENC_005_Determinism() {
        // Create a single fixed snapshot to guarantee identical input
        let fateDeckState = FateDeckState(
            drawPile: FateDeckFixtures.deterministic(),
            discardPile: []
        )

        var enemyHPs: [Int] = []
        var heroHPs: [Int] = []

        for _ in 0..<10 {
            let ctx = EncounterContext(
                hero: EncounterHero(id: "test_hero", hp: 100, maxHp: 100, strength: 5, armor: 2, wisdom: 3, willDefense: 1),
                enemies: [EncounterEnemy(id: "test_enemy", name: "Test Enemy", hp: 50, maxHp: 50, wp: 30, maxWp: 30, power: 5, defense: 2)],
                fateDeckSnapshot: fateDeckState,
                modifiers: [],
                rules: EncounterRules(),
                rngSeed: 42
            )
            let engine = EncounterEngine(context: ctx)

            _ = engine.generateIntent(for: "test_enemy")
            _ = engine.advancePhase() // → playerAction
            _ = engine.performAction(.attack(targetId: "test_enemy"))
            _ = engine.advancePhase() // → enemyResolution
            _ = engine.resolveEnemyAction(enemyId: "test_enemy")

            enemyHPs.append(engine.enemies[0].hp)
            heroHPs.append(engine.heroHP)
        }

        // All 10 runs must produce identical HP values
        let firstEnemyHP = enemyHPs[0]
        let firstHeroHP = heroHPs[0]
        for i in 1..<10 {
            XCTAssertEqual(enemyHPs[i], firstEnemyHP, "Enemy HP diverged on run \(i)")
            XCTAssertEqual(heroHPs[i], firstHeroHP, "Hero HP diverged on run \(i)")
        }
    }

    // INV-ENC-007: Second finish action in same round → .actionNotAllowed
    func test_INV_ENC_007_OneFinishActionPerRound() {
        let ctx = EncounterContextFixtures.standard()
        let engine = EncounterEngine(context: ctx)

        _ = engine.advancePhase() // intent → playerAction
        let first = engine.performAction(.attack(targetId: "test_enemy"))
        XCTAssertTrue(first.success, "First action must succeed")

        // Second attack in same playerAction phase → blocked
        let second = engine.performAction(.attack(targetId: "test_enemy"))
        XCTAssertFalse(second.success, "Second finish action must be rejected")
        XCTAssertEqual(second.error, .actionNotAllowed, "Error must be .actionNotAllowed")
    }
}

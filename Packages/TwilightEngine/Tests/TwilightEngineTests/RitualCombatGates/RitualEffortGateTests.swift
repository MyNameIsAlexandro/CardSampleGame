/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/RitualCombatGates/RitualEffortGateTests.swift
/// Назначение: Gate-тесты Effort mechanic для Phase 3 Ritual Combat (R1).
/// Зона ответственности: Проверяет инварианты Effort: burn, undo, limits, determinism, save/load и phase path.
/// Контекст: TDD RED — CombatSimulation ещё не реализован. Reference: RITUAL_COMBAT_TEST_MODEL.md §3.2

import XCTest
@testable import TwilightEngine

// MARK: - Effort Gate Test Protocol (R1 Contract)
// CombatSimulation must conform to this contract when implemented.
// These tests will not compile until CombatSimulation is created (TDD RED).

/// Ritual Effort Invariants — Phase 3 Gate Tests (R1)
/// Reference: RITUAL_COMBAT_TEST_MODEL.md §3.2
/// Rule: < 2 seconds per test, deterministic, no system RNG
///
/// NOTE: These tests reference CombatSimulation which does not exist yet.
/// This file will produce compile errors until R1 implementation creates the type.
/// This IS the intended TDD RED state — the tests define the contract.
final class RitualEffortGateTests: XCTestCase {

    // MARK: - Fixture

    /// Standard fixture: hero (str=5, maxEffort=2), 5 cards, 1 enemy (hp=10, wp=8), seed=42
    private func makeSimulation(seed: UInt64 = 42) -> CombatSimulation {
        CombatSimulation.makeStandard(seed: seed)
    }

    private func makeMultiEnemySimulation(seed: UInt64 = 42) -> CombatSimulation {
        let base = CombatSimulation.makeStandard(seed: seed)
        let enemyA = EncounterEnemy(id: "enemy_a", name: "Enemy A", hp: 12, maxHp: 12, wp: 7, maxWp: 7, defense: 0)
        let enemyB = EncounterEnemy(id: "enemy_b", name: "Enemy B", hp: 11, maxHp: 11, wp: 6, maxWp: 6, defense: 0)
        return CombatSimulation(
            hand: base.hand,
            heroHP: base.heroHP,
            heroStrength: base.heroStrength,
            heroWisdom: base.heroWisdom,
            heroArmor: base.heroArmor,
            enemies: [enemyA, enemyB],
            fateDeckState: base.snapshot().fateDeckState,
            rngSeed: seed
        )
    }

    // MARK: - INV-EFF-001: Burn moves card to discard (not exhaust)

    func testEffortBurnMovesToDiscard() {
        let sim = makeSimulation()
        let cardA = sim.hand[0]
        let cardB = sim.hand[1]

        sim.selectCard(cardB.id)
        let result = sim.burnForEffort(cardA.id)

        XCTAssertTrue(result, "burnForEffort must succeed for eligible card")
        XCTAssertTrue(sim.discardPile.contains { $0.id == cardA.id },
            "Burned card must be in discardPile")
        XCTAssertFalse(sim.hand.contains { $0.id == cardA.id },
            "Burned card must not be in hand")
        XCTAssertFalse(sim.exhaustPile.contains { $0.id == cardA.id },
            "Burned card must NOT go to exhaustPile")
    }

    // MARK: - INV-EFF-002: Burn does NOT spend energy

    func testEffortDoesNotSpendEnergy() {
        let sim = makeSimulation()
        let energyBefore = sim.energy
        let reservedBefore = sim.reservedEnergy

        sim.selectCard(sim.hand[1].id)
        _ = sim.burnForEffort(sim.hand[0].id)

        XCTAssertEqual(sim.energy, energyBefore,
            "Energy must not change after burn")
        XCTAssertEqual(sim.reservedEnergy, reservedBefore,
            "Reserved energy must not change after burn")
    }

    // MARK: - INV-EFF-003: Burn does NOT affect Fate Deck

    func testEffortDoesNotAffectFateDeck() {
        let sim = makeSimulation()
        let deckCountBefore = sim.fateDeckCount
        let discardCountBefore = sim.fateDiscardCount

        sim.selectCard(sim.hand[1].id)
        _ = sim.burnForEffort(sim.hand[0].id)

        XCTAssertEqual(sim.fateDeckCount, deckCountBefore,
            "Fate deck draw pile must not change after effort burn")
        XCTAssertEqual(sim.fateDiscardCount, discardCountBefore,
            "Fate deck discard pile must not change after effort burn")
    }

    // MARK: - INV-EFF-004: Effort bonus passed to Fate resolve

    func testEffortBonusPassedToFateResolve() {
        let sim = makeSimulation()
        let cardA = sim.hand[0]
        let cardB = sim.hand[1]
        let cardC = sim.hand[2]

        sim.selectCard(cardC.id)
        _ = sim.burnForEffort(cardA.id)
        _ = sim.burnForEffort(cardB.id)

        XCTAssertEqual(sim.effortBonus, 2, "Two burns must give effortBonus = 2")

        let result = sim.commitAttack(targetId: "enemy")
        XCTAssertEqual(result.effortBonus, 2,
            "FateAttackResult must contain effortBonus = 2")
        // Formula: totalAttack = baseStrength + effortBonus + fateValue + bonusDamage
        // With effortBonus=2, total must be >= baseStrength + 2
        XCTAssertGreaterThanOrEqual(result.totalAttack, sim.heroStrength + 2,
            "totalAttack must include effortBonus")
    }

    // MARK: - INV-EFF-005: Undo returns card to hand

    func testEffortUndoReturnsCardToHand() {
        let sim = makeSimulation()
        let cardA = sim.hand[0]

        sim.selectCard(sim.hand[1].id)
        _ = sim.burnForEffort(cardA.id)
        XCTAssertEqual(sim.effortBonus, 1)

        let undone = sim.undoBurnForEffort(cardA.id)
        XCTAssertTrue(undone, "Undo must succeed for burned card")
        XCTAssertTrue(sim.hand.contains { $0.id == cardA.id },
            "Undone card must return to hand")
        XCTAssertFalse(sim.discardPile.contains { $0.id == cardA.id },
            "Undone card must not be in discardPile")
        XCTAssertEqual(sim.effortBonus, 0,
            "effortBonus must decrement after undo")
        XCTAssertTrue(sim.effortCardIds.isEmpty,
            "effortCardIds must be empty after undo")
    }

    // MARK: - INV-EFF-006: Cannot burn selected card (NEGATIVE)

    func testCannotBurnSelectedCard() {
        let sim = makeSimulation()
        let cardA = sim.hand[0]

        sim.selectCard(cardA.id)
        let result = sim.burnForEffort(cardA.id)

        XCTAssertFalse(result, "Must not burn the selected card")
        XCTAssertEqual(sim.effortBonus, 0,
            "effortBonus must remain 0 after rejected burn")
        XCTAssertTrue(sim.hand.contains { $0.id == cardA.id },
            "Selected card must still be in hand (not moved)")
    }

    // MARK: - INV-EFF-007: Effort limit respected (NEGATIVE)

    func testEffortLimitRespected() {
        let sim = makeSimulation() // maxEffort = 2
        let cardA = sim.hand[0]
        let cardB = sim.hand[1]
        let cardC = sim.hand[2]

        sim.selectCard(sim.hand[3].id) // select card_d
        _ = sim.burnForEffort(cardA.id) // burn 1
        _ = sim.burnForEffort(cardB.id) // burn 2

        let result = sim.burnForEffort(cardC.id) // burn 3 → should fail

        XCTAssertFalse(result, "Must not exceed maxEffort limit")
        XCTAssertEqual(sim.effortBonus, 2,
            "effortBonus must stay at max (2), not 3")
        XCTAssertTrue(sim.hand.contains { $0.id == cardC.id },
            "Rejected card must remain in hand")
    }

    // MARK: - INV-EFF-008: Default zero effort

    func testEffortDefaultZero() {
        let sim = makeSimulation()
        sim.selectCard(sim.hand[0].id)

        // Commit without burning any cards
        let result = sim.commitAttack(targetId: "enemy")

        XCTAssertEqual(result.effortBonus, 0,
            "Without burns, effortBonus must be 0")
        // totalAttack = strength + 0 + fateValue (no effort)
        XCTAssertEqual(result.totalAttack, sim.heroStrength + result.fateDrawResult!.effectiveValue,
            "totalAttack without effort must be strength + fateValue only")
    }

    // MARK: - INV-EFF-009: Effort determinism (Equatable comparison)

    func testEffortDeterminism() {
        // Run 1
        let sim1 = makeSimulation(seed: 42)
        sim1.selectCard(sim1.hand[2].id)
        _ = sim1.burnForEffort(sim1.hand[0].id)
        _ = sim1.burnForEffort(sim1.hand[1].id)
        let result1 = sim1.commitAttack(targetId: "enemy")

        // Run 2 — identical
        let sim2 = makeSimulation(seed: 42)
        sim2.selectCard(sim2.hand[2].id)
        _ = sim2.burnForEffort(sim2.hand[0].id)
        _ = sim2.burnForEffort(sim2.hand[1].id)
        let result2 = sim2.commitAttack(targetId: "enemy")

        // Semantic comparison (Equatable, not bitwise — dictionary ordering not guaranteed)
        XCTAssertEqual(result1.totalAttack, result2.totalAttack,
            "Same seed + same actions must produce identical totalAttack")
        XCTAssertEqual(result1.effortBonus, result2.effortBonus,
            "Same seed + same actions must produce identical effortBonus")
        XCTAssertEqual(result1.isHit, result2.isHit,
            "Same seed + same actions must produce identical hit result")
        XCTAssertEqual(result1.damage, result2.damage,
            "Same seed + same actions must produce identical damage")
    }

    // MARK: - INV-EFF-010: Mid-combat save/load

    func testEffortMidCombatSaveLoad() {
        let sim = makeSimulation()
        let cardA = sim.hand[0]
        let cardB = sim.hand[1]

        sim.selectCard(cardB.id)
        _ = sim.burnForEffort(cardA.id)

        // Save
        let snapshot = sim.snapshot()

        // Restore into new simulation
        let sim2 = CombatSimulation.restore(from: snapshot)

        XCTAssertEqual(sim2.effortBonus, 1,
            "Restored effortBonus must match saved state")
        XCTAssertEqual(sim2.effortCardIds, [cardA.id],
            "Restored effortCardIds must match saved state")
        XCTAssertTrue(sim2.selectedCardIds.contains(cardB.id),
            "Restored selectedCardIds must contain cardB")
        XCTAssertFalse(sim2.hand.contains { $0.id == cardA.id },
            "Burned card must not be in hand after restore")
    }

    // MARK: - INV-EFF-011: Snapshot contains effort fields

    func testSnapshotContainsEffortFields() {
        let sim = makeSimulation()
        _ = sim.burnForEffort(sim.hand[0].id)

        let snapshot = sim.snapshot()

        XCTAssertNotNil(snapshot.effortBonus,
            "Snapshot must contain effortBonus field")
        XCTAssertNotNil(snapshot.effortCardIds,
            "Snapshot must contain effortCardIds field")
        XCTAssertNotNil(snapshot.selectedCardIds,
            "Snapshot must contain selectedCardIds field")
        XCTAssertNotNil(snapshot.phase,
            "Snapshot must contain phase field")
    }

    // MARK: - INV-EFF-012: Undo non-existent card (NEGATIVE)

    func testUndoNonExistentCardReturnsFalse() {
        let sim = makeSimulation()

        let result = sim.undoBurnForEffort("missing_card")

        XCTAssertFalse(result, "Undo must fail for card that was never burned")
        XCTAssertEqual(sim.effortBonus, 0, "Undo failure must not change effortBonus")
        XCTAssertTrue(sim.effortCardIds.isEmpty, "Undo failure must not change effortCardIds")
    }

    // MARK: - INV-EFF-013: Double undo is rejected (NEGATIVE)

    func testUndoAlreadyReturnedCardReturnsFalse() {
        let sim = makeSimulation()
        let selectedId = sim.hand[1].id
        let burnedId = sim.hand[0].id

        sim.selectCard(selectedId)
        XCTAssertTrue(sim.burnForEffort(burnedId), "Initial burn should succeed")
        XCTAssertTrue(sim.undoBurnForEffort(burnedId), "First undo should succeed")

        let secondUndo = sim.undoBurnForEffort(burnedId)
        XCTAssertFalse(secondUndo, "Second undo must fail for already returned card")
        XCTAssertEqual(sim.effortBonus, 0, "Second undo must not change effortBonus")
    }

    // MARK: - INV-EFF-014: Effort state resets after commit

    func testEffortResetAfterCommit() {
        let sim = makeSimulation()
        let selectedId = sim.hand[2].id
        let burnedId = sim.hand[0].id

        sim.selectCard(selectedId)
        XCTAssertTrue(sim.burnForEffort(burnedId))
        XCTAssertEqual(sim.effortBonus, 1)
        XCTAssertEqual(sim.effortCardIds, [burnedId])

        _ = sim.commitAttack(targetId: "enemy")

        XCTAssertEqual(sim.effortBonus, 0, "Commit must clear effort bonus")
        XCTAssertTrue(sim.effortCardIds.isEmpty, "Commit must clear effort card ids")
        XCTAssertTrue(sim.selectedCardIds.isEmpty, "Commit must clear selected card ids")
    }

    // MARK: - INV-EFF-015: Skip path does not consume effort

    func testEffortResetAfterSkip() {
        let sim = makeSimulation()
        let selectedId = sim.hand[1].id
        let burnedId = sim.hand[0].id

        sim.selectCard(selectedId)
        XCTAssertTrue(sim.burnForEffort(burnedId))
        let effortBefore = sim.effortBonus
        let effortCardsBefore = sim.effortCardIds
        let fateDeckBefore = sim.fateDeckCount
        let fateDiscardBefore = sim.fateDiscardCount

        sim.setPhase(.resolution)
        _ = sim.resolveEnemyTurn()

        XCTAssertEqual(sim.effortBonus, effortBefore, "Skip path must not consume effort bonus")
        XCTAssertEqual(sim.effortCardIds, effortCardsBefore, "Skip path must not clear effort cards")
        XCTAssertEqual(sim.fateDeckCount, fateDeckBefore, "Skip path must not draw Fate card")
        XCTAssertEqual(sim.fateDiscardCount, fateDiscardBefore, "Skip path must not discard Fate card")
    }

    // MARK: - INV-EFF-016: Effort bonus applies to influence

    func testEffortBonusInInfluence() {
        let withEffort = makeSimulation(seed: 123)
        let withoutEffort = makeSimulation(seed: 123)

        withEffort.selectCard(withEffort.hand[1].id)
        withoutEffort.selectCard(withoutEffort.hand[1].id)
        XCTAssertTrue(withEffort.burnForEffort(withEffort.hand[0].id))

        let withEffortResult = withEffort.commitInfluence(targetId: "enemy")
        let withoutEffortResult = withoutEffort.commitInfluence(targetId: "enemy")

        XCTAssertEqual(
            withEffortResult.damage,
            withoutEffortResult.damage + 1,
            "Single effort burn must add +1 influence damage with identical seed/actions"
        )
    }

    // MARK: - INV-EFF-017: Burn outside playerAction is rejected (NEGATIVE)

    func testBurnDuringWrongPhase() {
        let sim = makeSimulation()
        let burnCandidate = sim.hand[0].id
        sim.setPhase(.resolution)

        let result = sim.burnForEffort(burnCandidate)

        XCTAssertFalse(result, "Burn must be rejected outside playerAction phase")
        XCTAssertEqual(sim.effortBonus, 0, "Rejected burn must not change effort bonus")
        XCTAssertTrue(sim.hand.contains(where: { $0.id == burnCandidate }),
            "Rejected burn must leave card in hand")
    }

    // MARK: - INV-EFF-018: Effort applies only to chosen target in multi-enemy combat

    func testEffortWithMultiEnemy() {
        let sim = makeMultiEnemySimulation(seed: 42)
        sim.selectCard(sim.hand[2].id)
        XCTAssertTrue(sim.burnForEffort(sim.hand[0].id))

        let hpA = sim.enemies[0].hp
        let hpB = sim.enemies[1].hp
        _ = sim.commitAttack(targetId: "enemy_a")

        XCTAssertLessThan(sim.enemies[0].hp, hpA, "Targeted enemy must take damage")
        XCTAssertEqual(sim.enemies[1].hp, hpB, "Non-target enemy must remain unchanged")
    }

    // MARK: - INV-EFF-019: Mid-combat save/restore supports deterministic resume

    func testMidCombatSaveRestoreResume() {
        let sim = makeSimulation(seed: 424242)
        sim.selectCard(sim.hand[1].id)
        XCTAssertTrue(sim.burnForEffort(sim.hand[0].id))

        let snapshot = sim.snapshot()
        let resumedA = CombatSimulation.restore(from: snapshot)
        let resumedB = CombatSimulation.restore(from: snapshot)

        _ = resumedA.commitAttack(targetId: "enemy")
        resumedA.setPhase(.resolution)
        _ = resumedA.resolveEnemyTurn()

        _ = resumedB.commitAttack(targetId: "enemy")
        resumedB.setPhase(.resolution)
        _ = resumedB.resolveEnemyTurn()

        XCTAssertEqual(resumedA.snapshot(), resumedB.snapshot(),
            "Resume from identical snapshot must remain deterministic after continuing combat")
        XCTAssertEqual(resumedA.round, 2, "Resolved round must advance after resume path")
        XCTAssertEqual(resumedA.phase, .playerAction, "Combat should return to playerAction after enemy turn")
    }

    // MARK: - INV-EFF-020: Wait path does not draw Fate

    func testWaitPathNoFateDraw() {
        let sim = makeSimulation(seed: 2026)
        let drawBefore = sim.fateDeckCount
        let discardBefore = sim.fateDiscardCount

        sim.setPhase(.resolution)
        _ = sim.resolveEnemyTurn()

        XCTAssertEqual(sim.fateDeckCount, drawBefore, "Wait path must not consume Fate draw pile")
        XCTAssertEqual(sim.fateDiscardCount, discardBefore, "Wait path must not change Fate discard pile")
    }
}

/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/RitualCombatGates/RitualEffortGateTests.swift
/// Назначение: Gate-тесты Effort mechanic для Phase 3 Ritual Combat (R1).
/// Зона ответственности: Проверяет 11 инвариантов Effort: burn, undo, limits, determinism, save/load.
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
}

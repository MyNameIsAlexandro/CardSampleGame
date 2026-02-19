/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/DispositionSnapshotGateTests.swift
/// Назначение: Gate-тесты CombatSnapshot save/restore для Phase 3 Disposition Combat (Epic 23).
/// Зона ответственности: Проверяет snapshot round-trip, field completeness, resume determinism.
/// Контекст: Reference: RITUAL_COMBAT_TEST_MODEL.md §3.10

import XCTest
@testable import TwilightEngine

/// Disposition Snapshot Invariants — Phase 3 Gate Tests (Epic 23)
/// Reference: RITUAL_COMBAT_TEST_MODEL.md §3.10
/// Rule: < 2 seconds per test, deterministic (fixed seed), no system RNG
final class DispositionSnapshotGateTests: XCTestCase {

    // MARK: - Fixture

    /// Standard test cards (15 cards, cost=1, power=5).
    private static let testCards: [Card] = (0..<15).map { i in
        Card(id: "card_\(i)", name: "Test Card \(i)", type: .item, description: "Test card", power: 5, cost: 1)
    }

    private func makeSimulation(
        disposition: Int = 0,
        seed: UInt64 = 42,
        startingEnergy: Int = 5,
        resonanceZone: ResonanceZone = .yav
    ) -> DispositionCombatSimulation {
        DispositionCombatSimulation(
            disposition: disposition,
            energy: startingEnergy,
            startingEnergy: startingEnergy,
            hand: Self.testCards,
            heroHP: 100,
            heroMaxHP: 100,
            resonanceZone: resonanceZone,
            enemyType: "bandit",
            rng: WorldRNG(seed: seed),
            seed: seed
        )
    }

    // MARK: - testSnapshotContainsAllRequiredFields

    /// Create a simulation, play several actions to set various state
    /// (strike, influence, sacrifice, enemy defend, etc.), capture snapshot,
    /// verify all key fields are non-default.
    func testSnapshotContainsAllRequiredFields() {
        var sim = makeSimulation(disposition: 10, startingEnergy: 10)

        // Play strike to set momentum and move disposition
        sim.playStrike(cardId: "card_0", targetId: "enemy")
        // Play another strike to build streak
        sim.playStrike(cardId: "card_1", targetId: "enemy")
        // Play influence to switch action type and trigger threat bonus tracking
        sim.playInfluence(cardId: "card_2")
        // Play sacrifice to set sacrifice state
        sim.playCardAsSacrifice(cardId: "card_3")
        // Apply enemy effects
        sim.applyEnemyDefend(value: 4)
        sim.applyEnemyProvoke(value: 3)
        sim.applyEnemyAdapt(streakBonus: 2)
        sim.applyPleaBacklash(hpLoss: 5)
        sim.applyEnemyAttack(damage: 10)

        let snapshot = DispositionCombatSnapshot.capture(from: sim)

        // Disposition track
        XCTAssertNotEqual(snapshot.disposition, 0, "Disposition must be non-default after actions")
        XCTAssertNil(snapshot.outcome, "Outcome must be nil mid-combat")

        // Momentum
        XCTAssertNotNil(snapshot.streakType, "Streak type must be set after actions")
        XCTAssertGreaterThan(snapshot.streakCount, 0, "Streak count must be > 0")
        XCTAssertNotNil(snapshot.lastActionType, "Last action type must be set")

        // Energy
        XCTAssertNotEqual(snapshot.energy, 10, "Energy must change after playing cards")
        XCTAssertEqual(snapshot.startingEnergy, 10, "Starting energy must be preserved")

        // Sacrifice
        XCTAssertTrue(snapshot.sacrificeUsedThisTurn, "Sacrifice used flag must be set")
        XCTAssertGreaterThan(snapshot.enemySacrificeBuff, 0, "Enemy sacrifice buff must increase")

        // Card zones — cards moved from hand to discard/exhaust
        XCTAssertLessThan(snapshot.hand.count, Self.testCards.count, "Hand must have fewer cards")
        XCTAssertFalse(snapshot.discardPile.isEmpty, "Discard pile must not be empty")
        XCTAssertFalse(snapshot.exhaustPile.isEmpty, "Exhaust pile must not be empty (sacrifice)")

        // Hero
        XCTAssertLessThan(snapshot.heroHP, 100, "Hero HP must decrease from enemy attack")
        XCTAssertEqual(snapshot.heroMaxHP, 100, "Hero max HP must be preserved")

        // Combat context
        XCTAssertEqual(snapshot.resonanceZone, .yav)
        XCTAssertEqual(snapshot.enemyType, "bandit")

        // Enemy effects
        XCTAssertGreaterThan(snapshot.defendReduction, 0, "Defend reduction must be set")
        XCTAssertGreaterThan(snapshot.provokePenalty, 0, "Provoke penalty must be set")
        XCTAssertGreaterThan(snapshot.adaptPenalty, 0, "Adapt penalty must be set")
        XCTAssertGreaterThan(snapshot.pleaBacklash, 0, "Plea backlash must be set")

        // Echo state
        XCTAssertNotNil(snapshot.lastPlayedCardId, "Last played card ID must be set")
        XCTAssertNotNil(snapshot.lastPlayedAction, "Last played action must be set")

        // Determinism
        XCTAssertEqual(snapshot.seed, 42, "Seed must match original")
        // RNG state is captured from WorldRNG; it equals seed if no RNG calls occurred
        // (sacrifice in yav does not call RNG), so just verify it is present
        XCTAssertTrue(snapshot.rngState > 0, "RNG state must be captured")
    }

    // MARK: - testSnapshotRoundTrip_encode_decode

    /// Capture snapshot, encode to JSON, decode back, verify equality with original snapshot.
    func testSnapshotRoundTrip_encode_decode() {
        var sim = makeSimulation(disposition: -20, startingEnergy: 10)

        // Build diverse state
        sim.playStrike(cardId: "card_0", targetId: "enemy")
        sim.playStrike(cardId: "card_1", targetId: "enemy")
        sim.playInfluence(cardId: "card_2")
        sim.playCardAsSacrifice(cardId: "card_3")
        sim.applyEnemyDefend(value: 5)
        sim.applyEnemyAttack(damage: 8)

        let original = DispositionCombatSnapshot.capture(from: sim)

        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data: Data
        do {
            data = try encoder.encode(original)
        } catch {
            XCTFail("Snapshot encoding failed: \(error)")
            return
        }

        // Decode from JSON
        let decoder = JSONDecoder()
        let decoded: DispositionCombatSnapshot
        do {
            decoded = try decoder.decode(DispositionCombatSnapshot.self, from: data)
        } catch {
            XCTFail("Snapshot decoding failed: \(error)")
            return
        }

        // Verify full equality
        XCTAssertEqual(original, decoded, "Decoded snapshot must equal original")

        // Verify individual fields for diagnostic clarity
        XCTAssertEqual(original.disposition, decoded.disposition)
        XCTAssertEqual(original.outcome, decoded.outcome)
        XCTAssertEqual(original.streakType, decoded.streakType)
        XCTAssertEqual(original.streakCount, decoded.streakCount)
        XCTAssertEqual(original.lastActionType, decoded.lastActionType)
        XCTAssertEqual(original.energy, decoded.energy)
        XCTAssertEqual(original.startingEnergy, decoded.startingEnergy)
        XCTAssertEqual(original.sacrificeUsedThisTurn, decoded.sacrificeUsedThisTurn)
        XCTAssertEqual(original.enemySacrificeBuff, decoded.enemySacrificeBuff)
        XCTAssertEqual(original.hand, decoded.hand)
        XCTAssertEqual(original.discardPile, decoded.discardPile)
        XCTAssertEqual(original.exhaustPile, decoded.exhaustPile)
        XCTAssertEqual(original.heroHP, decoded.heroHP)
        XCTAssertEqual(original.heroMaxHP, decoded.heroMaxHP)
        XCTAssertEqual(original.resonanceZone, decoded.resonanceZone)
        XCTAssertEqual(original.enemyType, decoded.enemyType)
        XCTAssertEqual(original.defendReduction, decoded.defendReduction)
        XCTAssertEqual(original.provokePenalty, decoded.provokePenalty)
        XCTAssertEqual(original.adaptPenalty, decoded.adaptPenalty)
        XCTAssertEqual(original.pleaBacklash, decoded.pleaBacklash)
        XCTAssertEqual(original.lastPlayedCardId, decoded.lastPlayedCardId)
        XCTAssertEqual(original.lastPlayedAction, decoded.lastPlayedAction)
        XCTAssertEqual(original.lastPlayedBasePower, decoded.lastPlayedBasePower)
        XCTAssertEqual(original.lastFateModifier, decoded.lastFateModifier)
        XCTAssertEqual(original.echoUsedThisAction, decoded.echoUsedThisAction)
        XCTAssertEqual(original.seed, decoded.seed)
        XCTAssertEqual(original.rngState, decoded.rngState)
    }

    // MARK: - testSnapshotRoundTrip_resume_deterministic

    /// Capture snapshot mid-combat, restore to new simulation, play identical action
    /// sequence on both original and restored — verify identical results.
    func testSnapshotRoundTrip_resume_deterministic() {
        var sim = makeSimulation(disposition: 5, startingEnergy: 10)

        // Play initial actions to reach a mid-combat state
        sim.playStrike(cardId: "card_0", targetId: "enemy")
        sim.playInfluence(cardId: "card_1")
        sim.playStrike(cardId: "card_2", targetId: "enemy")

        // Capture snapshot at mid-point
        let snapshot = DispositionCombatSnapshot.capture(from: sim)

        // Encode and decode to simulate actual save/load
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        guard let data = try? encoder.encode(snapshot),
              let decodedSnapshot = try? decoder.decode(DispositionCombatSnapshot.self, from: data) else {
            XCTFail("Snapshot encode/decode failed")
            return
        }

        // Restore from decoded snapshot
        var restored = decodedSnapshot.restore()

        // Play identical actions on both original and restored
        let actions: [(inout DispositionCombatSimulation) -> Void] = [
            { $0.playStrike(cardId: "card_3", targetId: "enemy") },
            { $0.playInfluence(cardId: "card_4") },
            { $0.playCardAsSacrifice(cardId: "card_5") },
            { $0.playStrike(cardId: "card_6", targetId: "enemy") }
        ]

        for action in actions {
            action(&sim)
            action(&restored)
        }

        // Verify identical final state
        XCTAssertEqual(sim.disposition, restored.disposition,
            "Disposition must match after identical actions on original and restored")
        XCTAssertEqual(sim.outcome, restored.outcome)
        XCTAssertEqual(sim.streakType, restored.streakType)
        XCTAssertEqual(sim.streakCount, restored.streakCount)
        XCTAssertEqual(sim.lastActionType, restored.lastActionType)
        XCTAssertEqual(sim.energy, restored.energy)
        XCTAssertEqual(sim.sacrificeUsedThisTurn, restored.sacrificeUsedThisTurn)
        XCTAssertEqual(sim.enemySacrificeBuff, restored.enemySacrificeBuff)
        XCTAssertEqual(sim.hand.map(\.id), restored.hand.map(\.id))
        XCTAssertEqual(sim.discardPile.map(\.id), restored.discardPile.map(\.id))
        XCTAssertEqual(sim.exhaustPile.map(\.id), restored.exhaustPile.map(\.id))
        XCTAssertEqual(sim.heroHP, restored.heroHP)
        XCTAssertEqual(sim.defendReduction, restored.defendReduction)
        XCTAssertEqual(sim.provokePenalty, restored.provokePenalty)
        XCTAssertEqual(sim.adaptPenalty, restored.adaptPenalty)
        XCTAssertEqual(sim.pleaBacklash, restored.pleaBacklash)
        XCTAssertEqual(sim.lastPlayedCardId, restored.lastPlayedCardId)
        XCTAssertEqual(sim.lastPlayedAction, restored.lastPlayedAction)
        XCTAssertEqual(sim.lastPlayedBasePower, restored.lastPlayedBasePower)
        XCTAssertEqual(sim.lastFateModifier, restored.lastFateModifier)
        XCTAssertEqual(sim.echoUsedThisAction, restored.echoUsedThisAction)

        // RNG state must also be in sync
        XCTAssertEqual(sim.rng.currentState(), restored.rng.currentState(),
            "RNG state must be identical after identical action sequences")
    }
}

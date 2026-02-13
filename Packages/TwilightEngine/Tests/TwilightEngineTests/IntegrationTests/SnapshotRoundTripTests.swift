/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/IntegrationTests/SnapshotRoundTripTests.swift
/// Назначение: Содержит реализацию файла SnapshotRoundTripTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import TwilightEngine

/// Snapshot round-trip tests — verify state isolation and persistence
/// Reference: ENCOUNTER_TEST_MODEL.md §4.2
final class SnapshotRoundTripTests: XCTestCase {

    // FateDeck snapshot → encounter → updatedFateDeck → apply → consistent state
    func testFateDeckSnapshotRoundTrip() {
        // Create a real FateDeckManager
        let cards = FateDeckFixtures.deterministic()
        let manager = TestFateDeck.makeManager(cards: cards, seed: 42)
        let originalState = manager.getState()
        let originalDrawCount = originalState.drawPile.count

        // Run an encounter that draws fate cards
        let ctx = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 100, maxHp: 100, strength: 10, armor: 2),
            enemies: [EncounterEnemy(id: "e1", name: "Enemy", hp: 10, maxHp: 10, power: 3, defense: 1)],
            fateDeckSnapshot: originalState,
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42
        )
        let engine = EncounterEngine(context: ctx)

        // Attack draws a fate card
        _ = engine.advancePhase() // → playerAction
        _ = engine.performAction(.attack(targetId: "e1"))

        let result = engine.finishEncounter()

        // Apply updated state back to manager
        manager.restoreState(result.updatedFateDeck)
        let restoredState = manager.getState()

        // Total cards must be conserved
        let originalTotal = originalState.drawPile.count + originalState.discardPile.count
        let restoredTotal = restoredState.drawPile.count + restoredState.discardPile.count
        XCTAssertEqual(originalTotal, restoredTotal,
            "Total fate cards must be conserved through round-trip")

        // Draw pile should have shrunk (cards were drawn)
        XCTAssertLessThanOrEqual(restoredState.drawPile.count, originalDrawCount,
            "Draw pile should not grow after draws")
    }

    // Snapshot isolation: changes in encounter don't affect original manager
    func testSnapshotAfterAbort() {
        let cards = FateDeckFixtures.deterministic()
        let manager = TestFateDeck.makeManager(cards: cards, seed: 42)
        let snapshot = manager.getState()
        let drawCountBefore = snapshot.drawPile.count

        // Run encounter (simulate partial combat, don't apply result)
        let ctx = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 100, maxHp: 100, strength: 10, armor: 2),
            enemies: [EncounterEnemy(id: "e1", name: "Enemy", hp: 100, maxHp: 100, power: 3, defense: 1)],
            fateDeckSnapshot: snapshot,
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42
        )
        let engine = EncounterEngine(context: ctx)
        _ = engine.advancePhase()
        _ = engine.performAction(.attack(targetId: "e1"))
        // Result NOT applied to manager

        // Original manager must be unchanged
        let currentState = manager.getState()
        XCTAssertEqual(currentState.drawPile.count, drawCountBefore,
            "Original manager must be unchanged after aborted encounter")
    }

    // Snapshot with sticky cards (via state restoration)
    func testSnapshotPreservesAllCards() {
        let cards = FateDeckFixtures.deterministic()
        let manager = TestFateDeck.makeManager(cards: cards, seed: 42)

        // Draw some cards to populate discard
        _ = manager.drawAndResolve(worldResonance: 0)
        _ = manager.drawAndResolve(worldResonance: 0)

        let state = manager.getState()
        let total = state.drawPile.count + state.discardPile.count

        // Create new manager from state
        let manager2 = TestFateDeck.makeManager(cards: [], seed: 42)
        manager2.restoreState(state)
        let state2 = manager2.getState()
        let total2 = state2.drawPile.count + state2.discardPile.count

        XCTAssertEqual(total, total2, "Total cards must be preserved through snapshot restore")
    }

    // RNG state round-trip: encounter returns updated RNG state
    func testRngStateRoundTrip() {
        let ctx = EncounterContextFixtures.standard(seed: 42)
        let engine = EncounterEngine(context: ctx)

        _ = engine.advancePhase()
        _ = engine.performAction(.attack(targetId: "test_enemy"))

        let result = engine.finishEncounter()

        // rngState must be returned (non-zero for seeded RNG after use)
        XCTAssertNotEqual(result.rngState, 0, "RNG state must be updated after encounter")
    }
}

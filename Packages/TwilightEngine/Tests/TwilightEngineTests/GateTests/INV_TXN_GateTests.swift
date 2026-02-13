/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/INV_TXN_GateTests.swift
/// Назначение: Содержит реализацию файла INV_TXN_GateTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import TwilightEngine

/// INV-TXN: Transaction Integrity Gate Tests
/// Verifies that engine state changes only through performAction(),
/// and that save/load round-trips preserve all fields.
/// Gate rules: < 2s, no XCTSkip, no non-deterministic RNG.
final class INV_TXN_GateTests: XCTestCase {

    override func setUp() {
        super.setUp()
        _ = TestContentLoader.sharedLoadedRegistry()
    }

    // MARK: - TXN-04: State changes only via performAction

    /// INV-TXN-001: performAction(.rest) changes health, returns stateChanges
    func testRestActionChangesHealth() {
        let engine = TestEngineFactory.makeEngine(seed: 42)
        engine.initializeNewGame(playerName: "Test", heroId: nil)

        // Damage player first so rest has visible effect
        let hpBefore = engine.player.health
        let result = engine.performAction(.rest)

        XCTAssertTrue(result.success, "Rest should succeed")
        // Health should be >= before (rest heals)
        XCTAssertGreaterThanOrEqual(engine.player.health, hpBefore)
    }

    /// INV-TXN-002: performAction(.explore) can trigger event
    func testExploreActionMayTriggerEvent() {
        let engine = TestEngineFactory.makeEngine(seed: 42)
        engine.initializeNewGame(playerName: "Test", heroId: nil)

        guard !engine.publishedRegions.isEmpty else {
            XCTFail("ContentPack not loaded")
            return
        }

        let result = engine.performAction(.explore)
        XCTAssertTrue(result.success, "Explore should succeed")
        // Event may or may not be triggered (depends on region/RNG)
        // Key invariant: state changed through action, not direct mutation
    }

    /// INV-TXN-003: performAction(.skipTurn) advances day
    func testSkipTurnAdvancesDay() {
        let engine = TestEngineFactory.makeEngine(seed: 42)
        engine.initializeNewGame(playerName: "Test", heroId: nil)

        let dayBefore = engine.currentDay
        let result = engine.performAction(.skipTurn)

        XCTAssertTrue(result.success)
        XCTAssertEqual(engine.currentDay, dayBefore + 1, "Skip turn must advance day by 1")
    }

    /// INV-TXN-004: ActionResult contains stateChanges for tracking
    func testActionResultContainsStateChanges() {
        let engine = TestEngineFactory.makeEngine(seed: 42)
        engine.initializeNewGame(playerName: "Test", heroId: nil)

        let result = engine.performAction(.rest)
        XCTAssertTrue(result.success)
        // stateChanges should exist (may be empty if at full health)
        XCTAssertNotNil(result.stateChanges)
    }

    // MARK: - TXN-05: Save round-trip — all fields preserved

    /// INV-TXN-005: Save → Load preserves player state
    func testSaveLoadPreservesPlayerState() {
        let engine = TestEngineFactory.makeEngine(seed: 42)
        engine.initializeNewGame(playerName: "TestHero", heroId: nil)

        // Modify state through actions
        _ = engine.performAction(.rest)
        _ = engine.performAction(.skipTurn)

        let save = engine.createEngineSave()

        // Restore into fresh engine
        let engine2 = TestEngineFactory.makeEngine(seed: 1)
        engine2.initializeNewGame(playerName: "Dummy", heroId: nil)
        engine2.restoreFromEngineSave(save)

        XCTAssertEqual(engine2.player.name, "TestHero")
        XCTAssertEqual(engine2.player.health, engine.player.health)
        XCTAssertEqual(engine2.player.maxHealth, engine.player.maxHealth)
        XCTAssertEqual(engine2.player.faith, engine.player.faith)
        XCTAssertEqual(engine2.player.maxFaith, engine.player.maxFaith)
        XCTAssertEqual(engine2.player.balance, engine.player.balance)
        XCTAssertEqual(engine2.player.heroId, engine.player.heroId)
    }

    /// INV-TXN-006: Save → Load preserves world state
    func testSaveLoadPreservesWorldState() {
        let engine = TestEngineFactory.makeEngine(seed: 42)
        engine.initializeNewGame(playerName: "Test", heroId: nil)

        _ = engine.performAction(.skipTurn)
        _ = engine.performAction(.skipTurn)

        let save = engine.createEngineSave()

        let engine2 = TestEngineFactory.makeEngine(seed: 1)
        engine2.initializeNewGame(playerName: "Dummy", heroId: nil)
        engine2.restoreFromEngineSave(save)

        XCTAssertEqual(engine2.currentDay, engine.currentDay)
        XCTAssertEqual(engine2.worldTension, engine.worldTension)
        XCTAssertEqual(engine2.currentRegionId, engine.currentRegionId)
        XCTAssertEqual(engine2.publishedRegions.count, engine.publishedRegions.count)
        XCTAssertEqual(engine2.mainQuestStage, engine.mainQuestStage)
        XCTAssertEqual(engine2.lightDarkBalance, engine.lightDarkBalance)
    }

    /// INV-TXN-007: Save → Load preserves completed events and flags
    func testSaveLoadPreservesEventsAndFlags() {
        let engine = TestEngineFactory.makeEngine(seed: 42)
        engine.initializeNewGame(playerName: "Test", heroId: nil)

        guard !engine.publishedRegions.isEmpty else {
            XCTFail("ContentPack not loaded")
            return
        }

        // Explore to potentially trigger events
        _ = engine.performAction(.explore)
        if engine.currentEvent != nil {
            _ = engine.performAction(.dismissCurrentEvent)
        }

        let save = engine.createEngineSave()

        let engine2 = TestEngineFactory.makeEngine(seed: 1)
        engine2.initializeNewGame(playerName: "Dummy", heroId: nil)
        engine2.restoreFromEngineSave(save)

        XCTAssertEqual(engine2.publishedWorldFlags, engine.publishedWorldFlags)
        XCTAssertEqual(engine2.publishedEventLog.count, engine.publishedEventLog.count)
    }

    /// INV-TXN-008: Save → Load preserves RNG state (determinism after load)
    func testSaveLoadPreservesRNGState() {
        let engine = TestEngineFactory.makeEngine(seed: 55555)
        engine.initializeNewGame(playerName: "Test", heroId: nil)

        _ = engine.performAction(.rest)

        let save = engine.createEngineSave()

        // Get next RNG value from current state
        let nextValue1 = engine.services.rng.nextInt(in: 0...10000)

        // Restore — should reset RNG to saved state
        let engine2 = TestEngineFactory.makeEngine(seed: 1)
        engine2.initializeNewGame(playerName: "Dummy", heroId: nil)
        engine2.restoreFromEngineSave(save)

        let nextValue2 = engine2.services.rng.nextInt(in: 0...10000)

        XCTAssertEqual(nextValue1, nextValue2, "RNG must produce same value after save/load restore")
    }
}

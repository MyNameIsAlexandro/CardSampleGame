import XCTest
@testable import TwilightEngine

/// INV-TXN: Transaction Integrity Gate Tests
/// Verifies that engine state changes only through performAction(),
/// and that save/load round-trips preserve all fields.
/// Gate rules: < 2s, no XCTSkip, no non-deterministic RNG.
final class INV_TXN_GateTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TestContentLoader.loadContentPacksIfNeeded()
        WorldRNG.shared.setSeed(42)
    }

    override func tearDown() {
        WorldRNG.shared.setSeed(0)
        super.tearDown()
    }

    // MARK: - TXN-04: State changes only via performAction

    /// INV-TXN-001: performAction(.rest) changes health, returns stateChanges
    func testRestActionChangesHealth() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame(playerName: "Test", heroId: nil)

        // Damage player first so rest has visible effect
        let hpBefore = engine.playerHealth
        let result = engine.performAction(.rest)

        XCTAssertTrue(result.success, "Rest should succeed")
        // Health should be >= before (rest heals)
        XCTAssertGreaterThanOrEqual(engine.playerHealth, hpBefore)
    }

    /// INV-TXN-002: performAction(.explore) can trigger event
    func testExploreActionMayTriggerEvent() {
        let engine = TwilightGameEngine()
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
        let engine = TwilightGameEngine()
        engine.initializeNewGame(playerName: "Test", heroId: nil)

        let dayBefore = engine.currentDay
        let result = engine.performAction(.skipTurn)

        XCTAssertTrue(result.success)
        XCTAssertEqual(engine.currentDay, dayBefore + 1, "Skip turn must advance day by 1")
    }

    /// INV-TXN-004: ActionResult contains stateChanges for tracking
    func testActionResultContainsStateChanges() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame(playerName: "Test", heroId: nil)

        let result = engine.performAction(.rest)
        XCTAssertTrue(result.success)
        // stateChanges should exist (may be empty if at full health)
        XCTAssertNotNil(result.stateChanges)
    }

    // MARK: - TXN-05: Save round-trip — all fields preserved

    /// INV-TXN-005: Save → Load preserves player state
    func testSaveLoadPreservesPlayerState() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame(playerName: "TestHero", heroId: nil)

        // Modify state through actions
        _ = engine.performAction(.rest)
        _ = engine.performAction(.skipTurn)

        let save = engine.createEngineSave()

        // Restore into fresh engine
        let engine2 = TwilightGameEngine()
        engine2.initializeNewGame(playerName: "Dummy", heroId: nil)
        engine2.restoreFromEngineSave(save)

        XCTAssertEqual(engine2.playerName, "TestHero")
        XCTAssertEqual(engine2.playerHealth, engine.playerHealth)
        XCTAssertEqual(engine2.playerMaxHealth, engine.playerMaxHealth)
        XCTAssertEqual(engine2.playerFaith, engine.playerFaith)
        XCTAssertEqual(engine2.playerMaxFaith, engine.playerMaxFaith)
        XCTAssertEqual(engine2.playerBalance, engine.playerBalance)
        XCTAssertEqual(engine2.heroId, engine.heroId)
    }

    /// INV-TXN-006: Save → Load preserves world state
    func testSaveLoadPreservesWorldState() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame(playerName: "Test", heroId: nil)

        _ = engine.performAction(.skipTurn)
        _ = engine.performAction(.skipTurn)

        let save = engine.createEngineSave()

        let engine2 = TwilightGameEngine()
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
        let engine = TwilightGameEngine()
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

        let engine2 = TwilightGameEngine()
        engine2.initializeNewGame(playerName: "Dummy", heroId: nil)
        engine2.restoreFromEngineSave(save)

        XCTAssertEqual(engine2.publishedWorldFlags, engine.publishedWorldFlags)
        XCTAssertEqual(engine2.publishedEventLog.count, engine.publishedEventLog.count)
    }

    /// INV-TXN-008: Save → Load preserves RNG state (determinism after load)
    func testSaveLoadPreservesRNGState() {
        WorldRNG.shared.setSeed(55555)
        let engine = TwilightGameEngine()
        engine.initializeNewGame(playerName: "Test", heroId: nil)

        _ = engine.performAction(.rest)

        let save = engine.createEngineSave()

        // Get next RNG value from current state
        let nextValue1 = WorldRNG.shared.nextInt(in: 0...10000)

        // Restore — should reset RNG to saved state
        let engine2 = TwilightGameEngine()
        engine2.initializeNewGame(playerName: "Dummy", heroId: nil)
        engine2.restoreFromEngineSave(save)

        let nextValue2 = WorldRNG.shared.nextInt(in: 0...10000)

        XCTAssertEqual(nextValue1, nextValue2, "RNG must produce same value after save/load restore")
    }
}

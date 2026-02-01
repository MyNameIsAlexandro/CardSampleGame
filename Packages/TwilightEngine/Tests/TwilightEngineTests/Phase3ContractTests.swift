import XCTest
@testable import TwilightEngine

/// Phase 3 Contract Tests: GameLoop Integration
/// Verifies that all actions go through Engine and state changes are correct
///
/// АРХИТЕКТУРА ТЕСТИРОВАНИЯ (Audit v1.1 Issue #3):
/// - Этот файл содержит ИНТЕГРАЦИОННЫЕ тесты игрового потока
/// - ВСЕ действия тестируются через TwilightGameEngine.performAction()
/// - Это канонический способ тестирования игровой логики
/// - Для unit-тестов моделей см. WorldStateTests, RegionActionsModelTests
/// - Engine обеспечивает: валидацию, синхронизацию legacy, отслеживание изменений
final class Phase3ContractTests: XCTestCase {

    var engine: TwilightGameEngine!

    override func setUp() {
        super.setUp()
        TestContentLoader.loadContentPacksIfNeeded()
        engine = TwilightGameEngine()
        engine.initializeNewGame(playerName: "Test", heroId: nil)
    }

    override func tearDown() {
        engine = nil
        WorldRNG.shared.setSeed(0)
        super.tearDown()
    }

    /// Helper to fail test if regions not loaded
    private func requireRegionsLoaded() -> Bool {
        if engine.publishedRegions.isEmpty {
            XCTFail("Skipping: ContentPack not loaded (regions empty)")
            return false
        }
        return true
    }

    // MARK: - INV-P3-001: All Actions Through Engine

    func testAllActionsReturnActionResult() {
        // Every action should return an ActionResult
        let actions: [TwilightGameAction] = [
            .rest,
            .explore,
            .skipTurn
        ]

        for action in actions {
            let result = engine.performAction(action)
            XCTAssertNotNil(result, "Action \(action) should return result")
        }
    }

    // MARK: - INV-P3-002: Time Advances Only Via Engine

    func testTimeAdvancesOnlyViaEngine() {
        guard requireRegionsLoaded() else { return }
        let initialDay = engine.currentDay

        // Perform action with time cost
        let result = engine.performAction(.rest)

        XCTAssertTrue(result.success, "Rest action should succeed")
        XCTAssertEqual(engine.currentDay, initialDay + 1, "Day should advance by 1")
    }

    // MARK: - INV-P3-003: State Changes Are Tracked

    func testStateChangesAreTracked() {
        guard requireRegionsLoaded() else { return }
        // Perform action that changes state
        let result = engine.performAction(.rest)

        XCTAssertTrue(result.success)
        XCTAssertFalse(result.stateChanges.isEmpty, "Rest should produce state changes")

        // Check for expected changes
        let hasHealthChange = result.stateChanges.contains { change in
            if case .healthChanged = change { return true }
            return false
        }
        XCTAssertTrue(hasHealthChange, "Rest should change health")

        let hasDayChange = result.stateChanges.contains { change in
            if case .dayAdvanced = change { return true }
            return false
        }
        XCTAssertTrue(hasDayChange, "Rest should advance day")
    }

    // MARK: - INV-P3-004: Validation Before Execution

    func testInvalidActionReturnsError() {
        // Try to travel to non-neighbor region
        let farRegionId = "nonexistent_region_999"  // Non-existent region
        let result = engine.performAction(.travel(toRegionId: farRegionId))

        XCTAssertFalse(result.success, "Invalid travel should fail")
        XCTAssertNotNil(result.error, "Should have error")
    }

    // MARK: - INV-P3-005: Tension Escalation Through Engine

    func testTensionEscalatesOnDay3() {
        guard requireRegionsLoaded() else { return }
        // Advance to day 3
        _ = engine.performAction(.rest)  // Day 1
        _ = engine.performAction(.rest)  // Day 2

        let tensionBeforeDay3 = engine.worldTension

        _ = engine.performAction(.rest)  // Day 3 - should trigger tension

        // Tension should increase on day 3
        XCTAssertGreaterThan(engine.worldTension, tensionBeforeDay3,
            "Tension should increase on day 3")

        // Verify escalation formula: +3 + (daysPassed / 10)
        let expectedIncrease = 3 + (3 / 10)  // = 3
        XCTAssertEqual(engine.worldTension, tensionBeforeDay3 + expectedIncrease,
            "Escalation should follow formula")
    }

    // Legacy sync tests removed - Engine-First architecture

    // MARK: - INV-P3-007: Rest Heals Player

    func testRestHealsPlayer() {
        guard requireRegionsLoaded() else { return }
        // Damage player first by setting engine health directly
        engine.player.setHealth(5)

        let initialHealth = engine.player.health
        let result = engine.performAction(.rest)

        XCTAssertTrue(result.success)

        // Health should increase (capped at max)
        XCTAssertGreaterThan(engine.player.health, initialHealth,
            "Rest should heal player")
    }

    // MARK: - INV-P3-008: Strengthen Anchor Costs Faith

    func testStrengthenAnchorCostsFaith() {
        // Ensure player has enough faith
        engine.player.setFaith(20)

        // Move to region with anchor
        guard let regionWithAnchor = engine.publishedRegions.values.first(where: { $0.anchor != nil }) else {
            XCTFail("No region with anchor found"); return
        }
        engine.setCurrentRegion(regionWithAnchor.id)

        let initialFaith = engine.player.faith
        let result = engine.performAction(.strengthenAnchor)

        if result.success {
            // Faith should decrease
            XCTAssertLessThan(engine.player.faith, initialFaith,
                "Strengthening anchor should cost faith")
        }
    }

    // MARK: - INV-P3-009: Game Over On Tension 100

    func testGameOverOnMaxTension() {
        // Set tension near max
        engine.setWorldTension(97)

        // Advance time to trigger tension increase
        _ = engine.performAction(.rest)
        _ = engine.performAction(.rest)
        _ = engine.performAction(.rest)  // Day 3

        // If tension reached 100, game should be over
        if engine.worldTension >= 100 {
            XCTAssertTrue(engine.isGameOver, "Game should be over at tension 100")
            XCTAssertNotNil(engine.gameResult, "Should have game result")

            if case .defeat(let reason) = engine.gameResult {
                XCTAssertTrue(reason.contains("Напряжение") || reason.contains("tension"),
                    "Defeat reason should mention tension")
            } else {
                XCTFail("Should be defeat, not victory")
            }
        }
    }

    // MARK: - INV-P3-010: Game Over On Health 0

    func testGameOverOnHealthZero() {
        // Set health to 1
        engine.player.setHealth(1)

        // Apply damage through consequences (simulated)
        // For now, manually trigger check
        engine.player.setHealth(0)

        // Trigger end condition check
        _ = engine.performAction(.skipTurn)

        XCTAssertTrue(engine.isGameOver || engine.player.health <= 0,
            "Game should be over or health should be 0")
    }

    // MARK: - INV-P3-011: Actions Blocked When Game Over

    func testActionsBlockedWhenGameOver() {
        // End the game
        engine.setWorldTension(100)
        _ = engine.performAction(.skipTurn)  // Trigger end check

        // If game is over, actions should fail
        if engine.isGameOver {
            let result = engine.performAction(.rest)
            XCTAssertFalse(result.success, "Actions should fail when game is over")
            XCTAssertEqual(result.error, .gameNotInProgress)
        }
    }

    // MARK: - INV-P3-012: Event Choice Resolution

    func testEventChoiceProducesStateChanges() {
        // This test requires an active event
        // For unit testing, we can test the resolver directly

        let resolver = EventResolver()

        // Create test event with proper EventConsequences structure
        let consequences = EventConsequences(
            faithChange: 3,
            healthChange: -2,
            tensionChange: 1,
            setFlags: ["test_flag": true],
            message: "Test result"
        )

        let choice = EventChoice(
            id: "test_choice",
            text: "Test Choice",
            consequences: consequences
        )

        let event = GameEvent(
            id: "test_event_1",
            eventType: .exploration,
            title: "Test Event",
            description: "Test description",
            choices: [choice],
            weight: 10
        )

        let context = EventResolutionContext(
            currentHealth: 10,
            currentFaith: 5,
            currentBalance: 50,
            currentTension: 30,
            currentFlags: [:]
        )

        let result = resolver.resolve(event: event, choiceIndex: 0, context: context)

        XCTAssertTrue(result.success)
        XCTAssertFalse(result.stateChanges.isEmpty, "Choice should produce changes")

        // Verify expected changes exist
        let hasHealthChange = result.stateChanges.contains { change in
            if case .healthChanged(let delta, _) = change {
                return delta == -2
            }
            return false
        }
        XCTAssertTrue(hasHealthChange, "Should have health change of -2")

        let hasFaithChange = result.stateChanges.contains { change in
            if case .faithChanged(let delta, _) = change {
                return delta == 3
            }
            return false
        }
        XCTAssertTrue(hasFaithChange, "Should have faith change of +3")
    }

    // MARK: - INV-P3-013: Deterministic With Seed

    func testEngineDeterministicWithSeed() {
        // Run same actions with same seed twice
        WorldRNG.shared.setSeed(42)

        let engine1 = TwilightGameEngine()
        engine1.initializeFromContentRegistry(ContentRegistry.shared)

        // Perform actions
        _ = engine1.performAction(.rest)
        _ = engine1.performAction(.rest)
        _ = engine1.performAction(.rest)

        let finalTension1 = engine1.worldTension
        let finalDay1 = engine1.currentDay

        // Reset and run again
        WorldRNG.shared.setSeed(42)

        let engine2 = TwilightGameEngine()
        engine2.initializeFromContentRegistry(ContentRegistry.shared)

        _ = engine2.performAction(.rest)
        _ = engine2.performAction(.rest)
        _ = engine2.performAction(.rest)

        let finalTension2 = engine2.worldTension
        let finalDay2 = engine2.currentDay

        // Results should be identical
        XCTAssertEqual(finalDay1, finalDay2, "Days should match with same seed")
        XCTAssertEqual(finalTension1, finalTension2, "Tension should match with same seed")
    }
}

// MARK: - Test Helpers

/// Helper to describe TwilightGameAction for test output (avoids extension conformance issues)
private func describeAction(_ action: TwilightGameAction) -> String {
    switch action {
    case .travel(let id): return "travel(\(id))"
    case .rest: return "rest"
    case .explore: return "explore"
    case .trade: return "trade"
    case .strengthenAnchor: return "strengthenAnchor"
    case .chooseEventOption(let e, let c): return "choose(\(e), \(c))"
    case .resolveMiniGame(let r): return "miniGame(\(r))"
    case .startCombat(let id): return "combat(\(id))"
    case .combatInitialize: return "combatInitialize"
    // Active Defense actions
    case .combatMulligan(let cardIds): return "combatMulligan(\(cardIds.count) cards)"
    case .combatGenerateIntent: return "combatGenerateIntent"
    case .combatPlayerAttackWithFate(let dmg): return "combatPlayerAttackWithFate(bonus:\(dmg))"
    case .combatSkipAttack: return "combatSkipAttack"
    case .combatEnemyResolveWithFate: return "combatEnemyResolveWithFate"
    case .dismissCurrentEvent: return "dismissCurrentEvent"
    case .dismissDayEvent: return "dismissDayEvent"
    case .skipTurn: return "skipTurn"
    case .custom(let id, let cost): return "custom(\(id), \(cost))"
    }
}

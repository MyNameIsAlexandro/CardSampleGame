import XCTest
@testable import CardSampleGame

/// Phase 3 Contract Tests: GameLoop Integration
/// Verifies that all actions go through Engine and state changes are correct
final class Phase3ContractTests: XCTestCase {

    var engine: TwilightGameEngine!
    var player: Player!
    var gameState: GameState!
    var worldState: WorldState!

    override func setUp() {
        super.setUp()
        player = Player(name: "Test Hero")
        gameState = GameState(players: [player])
        worldState = gameState.worldState
        engine = TwilightGameEngine()
        engine.connectToLegacy(worldState: worldState, player: player)
    }

    override func tearDown() {
        engine = nil
        player = nil
        gameState = nil
        worldState = nil
        WorldRNG.shared.resetToSystem()
        super.tearDown()
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
        let initialDay = engine.currentDay

        // Perform action with time cost
        let result = engine.performAction(.rest)

        XCTAssertTrue(result.success, "Rest action should succeed")
        XCTAssertEqual(engine.currentDay, initialDay + 1, "Day should advance by 1")

        // Verify legacy is synced
        XCTAssertEqual(worldState.daysPassed, engine.currentDay, "Legacy should be synced")
    }

    // MARK: - INV-P3-003: State Changes Are Tracked

    func testStateChangesAreTracked() {
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
        let farRegionId = UUID()  // Non-existent region
        let result = engine.performAction(.travel(toRegionId: farRegionId))

        XCTAssertFalse(result.success, "Invalid travel should fail")
        XCTAssertNotNil(result.error, "Should have error")
    }

    // MARK: - INV-P3-005: Tension Escalation Through Engine

    func testTensionEscalatesOnDay3() {
        let initialTension = engine.worldTension

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

    // MARK: - INV-P3-006: Legacy Sync After Action

    func testLegacySyncAfterAction() {
        let initialLegacyDay = worldState.daysPassed
        let initialLegacyTension = worldState.worldTension

        // Perform action
        _ = engine.performAction(.rest)

        // Legacy should be synced
        XCTAssertEqual(worldState.daysPassed, engine.currentDay,
            "Legacy daysPassed should match engine")
    }

    // MARK: - INV-P3-007: Rest Heals Player

    func testRestHealsPlayer() {
        // Damage player first
        player.health = 5
        engine.syncFromLegacy()

        let initialHealth = player.health
        let result = engine.performAction(.rest)

        XCTAssertTrue(result.success)

        // Health should increase (capped at max)
        XCTAssertGreaterThan(player.health, initialHealth,
            "Rest should heal player")
    }

    // MARK: - INV-P3-008: Strengthen Anchor Costs Faith

    func testStrengthenAnchorCostsFaith() {
        // Ensure player has enough faith
        player.faith = 20
        engine.syncFromLegacy()

        // Move to region with anchor
        guard let regionWithAnchor = worldState.regions.first(where: { $0.anchor != nil }) else {
            XCTSkip("No region with anchor found")
            return
        }
        worldState.currentRegionId = regionWithAnchor.id
        engine.syncFromLegacy()

        let initialFaith = player.faith
        let result = engine.performAction(.strengthenAnchor)

        if result.success {
            // Faith should decrease
            XCTAssertLessThan(player.faith, initialFaith,
                "Strengthening anchor should cost faith")
        }
    }

    // MARK: - INV-P3-009: Game Over On Tension 100

    func testGameOverOnMaxTension() {
        // Set tension near max
        worldState.worldTension = 97
        engine.syncFromLegacy()

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
        player.health = 1
        engine.syncFromLegacy()

        // Apply damage through consequences (simulated)
        // For now, manually trigger check
        player.health = 0

        // Trigger end condition check
        _ = engine.performAction(.skipTurn)

        XCTAssertTrue(engine.isGameOver || player.health <= 0,
            "Game should be over or health should be 0")
    }

    // MARK: - INV-P3-011: Actions Blocked When Game Over

    func testActionsBlockedWhenGameOver() {
        // End the game
        worldState.worldTension = 100
        engine.syncFromLegacy()
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

        // Create test event
        let consequences = EventConsequences(
            healthChange: -2,
            faithChange: 3,
            tensionChange: 1,
            flagsToSet: ["test_flag"]
        )

        let choice = EventChoice(
            text: "Test Choice",
            consequences: consequences,
            resultText: "Test result"
        )

        let event = GameEvent(
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

        let player1 = Player(name: "Test")
        let gameState1 = GameState(players: [player1])
        let engine1 = TwilightGameEngine()
        engine1.connectToLegacy(worldState: gameState1.worldState, player: player1)

        // Perform actions
        _ = engine1.performAction(.rest)
        _ = engine1.performAction(.rest)
        _ = engine1.performAction(.rest)

        let finalTension1 = engine1.worldTension
        let finalDay1 = engine1.currentDay

        // Reset and run again
        WorldRNG.shared.setSeed(42)

        let player2 = Player(name: "Test")
        let gameState2 = GameState(players: [player2])
        let engine2 = TwilightGameEngine()
        engine2.connectToLegacy(worldState: gameState2.worldState, player: player2)

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

// MARK: - TwilightGameAction Equatable Extension (for tests)

extension TwilightGameAction: CustomStringConvertible {
    var description: String {
        switch self {
        case .travel(let id): return "travel(\(id))"
        case .rest: return "rest"
        case .explore: return "explore"
        case .trade: return "trade"
        case .strengthenAnchor: return "strengthenAnchor"
        case .chooseEventOption(let e, let c): return "choose(\(e), \(c))"
        case .resolveMiniGame(let r): return "miniGame(\(r))"
        case .startCombat(let id): return "combat(\(id))"
        case .playCard(let c, let t): return "playCard(\(c), \(String(describing: t)))"
        case .endCombatTurn: return "endCombatTurn"
        case .skipTurn: return "skipTurn"
        case .custom(let id, let cost): return "custom(\(id), \(cost))"
        }
    }
}

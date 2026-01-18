import XCTest
@testable import CardSampleGame

/// Engine Contract Tests
/// Verify that engine-level invariants are maintained.
/// Reference: Docs/ENGINE_ARCHITECTURE.md
final class EngineContractsTests: XCTestCase {

    // MARK: - Test Fixtures

    var gameLoop: GameLoopBase!
    var testPressureRules: TestPressureRules!

    override func setUp() {
        super.setUp()
        testPressureRules = TestPressureRules()
        gameLoop = TestGameLoop(pressureRules: testPressureRules)
        gameLoop.startGame()
    }

    override func tearDown() {
        gameLoop = nil
        testPressureRules = nil
        super.tearDown()
    }

    // MARK: - INV-001: Single Entry Point

    /// UI should not mutate state directly - all changes through performAction
    /// Reference: ENGINE_ARCHITECTURE.md, Section 2 (Core Loop)
    func testPerformActionIsOnlyStateChangeEntry() async {
        // Given: Initial state
        let initialTime = gameLoop.timeEngine.currentTime
        let initialPressure = gameLoop.pressureEngine.currentPressure

        // When: Perform a timed action
        let action = StandardAction.rest
        await gameLoop.performAction(action)

        // Then: State changed through engine, not directly
        XCTAssertGreaterThan(
            gameLoop.timeEngine.currentTime,
            initialTime,
            "Time should advance through performAction"
        )

        // Verify time engine is the canonical time source
        XCTAssertEqual(
            gameLoop.timeEngine.currentTime,
            initialTime + action.timeCost,
            "Time should advance by action cost"
        )
    }

    // MARK: - INV-002: Time Advances Only Via TimeEngine

    /// All time changes must go through TimeEngine.advance()
    /// Reference: ENGINE_ARCHITECTURE.md, Section 3.1 (TimeEngine)
    func testTimeAdvancesOnlyViaTimeEngine() async {
        // Given: Track time changes
        let timeTracker = TimeTracker()
        gameLoop.timeDelegate = timeTracker

        // When: Perform action
        await gameLoop.performAction(StandardAction.travel(from: "A", to: "B", isNeighbor: true))

        // Then: Time advanced through delegate
        XCTAssertGreaterThan(
            timeTracker.tickCount,
            0,
            "Time ticks should be recorded via delegate"
        )
        XCTAssertEqual(
            timeTracker.totalTimeAdvanced,
            1,
            "Travel to neighbor should cost 1 time unit"
        )
    }

    func testInstantActionsDoNotAdvanceTime() async {
        // Given: Initial time
        let initialTime = gameLoop.timeEngine.currentTime

        // When: Instant action (cost = 0)
        await gameLoop.performAction(StandardAction.explore(instant: true))

        // Then: Time unchanged
        XCTAssertEqual(
            gameLoop.timeEngine.currentTime,
            initialTime,
            "Instant actions should not advance time"
        )
    }

    // MARK: - INV-003: World Tick Triggered by Time Thresholds

    /// World effects should trigger when time thresholds are crossed
    /// Reference: ENGINE_ARCHITECTURE.md, Section 3.2 (PressureEngine)
    func testWorldTickTriggeredByTimeThresholds() async {
        // Given: Pressure rules with interval = 3
        XCTAssertEqual(testPressureRules.escalationInterval, 3)
        let initialPressure = gameLoop.pressureEngine.currentPressure

        // When: Advance time to threshold (3 days)
        for _ in 0..<3 {
            await gameLoop.performAction(StandardAction.rest) // 1 day each
        }

        // Then: Pressure escalated
        XCTAssertGreaterThan(
            gameLoop.pressureEngine.currentPressure,
            initialPressure,
            "Pressure should escalate at time threshold"
        )
    }

    func testPressureDoesNotEscalateBeforeThreshold() async {
        // Given: Initial pressure
        let initialPressure = gameLoop.pressureEngine.currentPressure

        // When: Advance time but not to threshold
        await gameLoop.performAction(StandardAction.rest) // 1 day
        await gameLoop.performAction(StandardAction.rest) // 2 days

        // Then: Pressure unchanged (threshold is 3)
        XCTAssertEqual(
            gameLoop.pressureEngine.currentPressure,
            initialPressure,
            "Pressure should not escalate before threshold"
        )
    }

    // MARK: - INV-004: Economy Transactions

    /// Resource changes should go through EconomyManager
    /// Reference: ENGINE_ARCHITECTURE.md, Section 3.4 (EconomyManager)
    func testEconomyTransactionsAreAtomic() {
        // Given: Player with limited resources
        gameLoop.setResource("faith", value: 5)
        gameLoop.setResource("health", value: 10)

        // When: Transaction that costs more than available
        let expensiveTransaction = Transaction(
            costs: ["faith": 10], // More than available
            gains: ["health": 5],
            description: "Expensive action"
        )
        let result = gameLoop.processTransaction(expensiveTransaction)

        // Then: Transaction fails, resources unchanged
        XCTAssertFalse(result, "Transaction should fail if unaffordable")
        XCTAssertEqual(gameLoop.getResource("faith"), 5, "Faith should be unchanged")
        XCTAssertEqual(gameLoop.getResource("health"), 10, "Health should be unchanged")
    }

    func testSuccessfulTransactionAppliesBothCostsAndGains() {
        // Given: Sufficient resources
        gameLoop.setResource("faith", value: 10)
        gameLoop.setResource("health", value: 10)

        // When: Affordable transaction
        let transaction = Transaction(
            costs: ["faith": 3],
            gains: ["health": 5],
            description: "Heal"
        )
        let result = gameLoop.processTransaction(transaction)

        // Then: Both applied
        XCTAssertTrue(result)
        XCTAssertEqual(gameLoop.getResource("faith"), 7, "Faith should decrease by cost")
        XCTAssertEqual(gameLoop.getResource("health"), 15, "Health should increase by gain")
    }

    // MARK: - INV-005: Pressure Maximum Triggers Game Over

    /// When pressure reaches maximum, game should end
    /// Reference: ENGINE_ARCHITECTURE.md, Section 6 (End Conditions)
    func testPressureMaximumTriggersDefeat() async {
        // Given: Pressure near maximum
        let maxPressure = testPressureRules.maxPressure
        gameLoop.pressureEngine.adjust(by: maxPressure - 1)

        // When: Trigger escalation that pushes over max
        // Force threshold check
        for _ in 0..<testPressureRules.escalationInterval {
            await gameLoop.performAction(StandardAction.rest)
        }

        // Then: Game should end in defeat
        XCTAssertTrue(gameLoop.isGameOver, "Game should be over")
        if case .defeat(let reason) = gameLoop.endResult {
            XCTAssertEqual(reason, "pressure_maximum")
        } else {
            XCTFail("End result should be defeat due to pressure")
        }
    }

    // MARK: - INV-006: Flags Persistence

    /// Flags set should persist and be queryable
    func testFlagsPersistAcrossActions() async {
        // Given: Set a flag
        gameLoop.setFlag("test_flag", value: true)

        // When: Perform actions
        await gameLoop.performAction(StandardAction.rest)
        await gameLoop.performAction(StandardAction.rest)

        // Then: Flag still set
        XCTAssertTrue(gameLoop.hasFlag("test_flag"), "Flag should persist")
    }

    // MARK: - INV-007: Event Completion Tracking

    func testCompletedEventsPersist() async {
        // Given: Mark event as completed
        gameLoop.markEventCompleted("test_event_001")

        // When: Check completion
        let isCompleted = gameLoop.isEventCompleted("test_event_001")
        let isNotCompleted = gameLoop.isEventCompleted("other_event")

        // Then: Correctly tracked
        XCTAssertTrue(isCompleted, "Completed event should be tracked")
        XCTAssertFalse(isNotCompleted, "Other events should not be marked")
    }
}

// MARK: - Test Helpers

/// Test implementation of PressureRuleSet
class TestPressureRules: PressureRuleSet {
    var maxPressure: Int = 100
    var initialPressure: Int = 0
    var escalationInterval: Int = 3
    var escalationAmount: Int = 5

    func calculateEscalation(currentPressure: Int, currentTime: Int) -> Int {
        return escalationAmount
    }

    func checkThresholds(pressure: Int) -> [WorldEffect] {
        if pressure >= 80 {
            return [.regionDegradation(probability: 0.5)]
        }
        return []
    }
}

/// Test implementation of GameLoopBase
class TestGameLoop: GameLoopBase {
    override func setupInitialState() {
        playerResources["health"] = 20
        playerResources["faith"] = 10
    }
}

/// Time tracking delegate for tests
class TimeTracker: TimeSystemDelegate {
    var tickCount: Int = 0
    var totalTimeAdvanced: Int = 0
    var thresholdsCrossed: [Int] = []

    func onTimeTick(currentTime: Int, delta: Int) {
        tickCount += 1
        totalTimeAdvanced += delta
    }

    func onTimeThreshold(currentTime: Int, threshold: Int) {
        thresholdsCrossed.append(threshold)
    }
}

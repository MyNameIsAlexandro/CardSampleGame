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
        WorldRNG.shared.resetToSystem()
        super.tearDown()
    }

    // MARK: - INV-001: Single Entry Point

    /// UI should not mutate state directly - all changes through performAction
    /// Reference: ENGINE_ARCHITECTURE.md, Section 2 (Core Loop)
    func testPerformActionIsOnlyStateChangeEntry() async {
        // Given: Initial state
        let initialTime = gameLoop.timeEngine.currentTime
        _ = gameLoop.pressureEngine.currentPressure // Captured for potential future assertions

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

    // MARK: - INV-008: WorldRNG Determinism

    /// WorldRNG with same seed should produce identical sequences
    func testWorldRNGDeterministicWithSeed() {
        // Given: Set seed
        WorldRNG.shared.setSeed(42)
        let seq1 = (0..<20).map { _ in WorldRNG.shared.nextInt(in: 0..<1000) }

        // When: Reset with same seed
        WorldRNG.shared.setSeed(42)
        let seq2 = (0..<20).map { _ in WorldRNG.shared.nextInt(in: 0..<1000) }

        // Then: Sequences identical
        XCTAssertEqual(seq1, seq2, "Same seed should produce identical sequence")

        // Cleanup
        WorldRNG.shared.resetToSystem()
    }

    // MARK: - INV-009: DegradationRules Used

    /// Degradation should use DegradationRules for resistance probability
    func testDegradationResistanceUsesRuleSet() {
        let rules = DegradationRules.current

        // Verify rules are used (not hardcoded values)
        // Resistance probability should be integrity/100, not a threshold
        XCTAssertEqual(rules.resistanceProbability(anchorIntegrity: 100), 1.0, accuracy: 0.001)
        XCTAssertEqual(rules.resistanceProbability(anchorIntegrity: 75), 0.75, accuracy: 0.001)
        XCTAssertEqual(rules.resistanceProbability(anchorIntegrity: 50), 0.5, accuracy: 0.001)
        XCTAssertEqual(rules.resistanceProbability(anchorIntegrity: 25), 0.25, accuracy: 0.001)
        XCTAssertEqual(rules.resistanceProbability(anchorIntegrity: 0), 0.0, accuracy: 0.001)

        // Verify degradation amount matches config
        XCTAssertEqual(rules.degradationAmount, 20, "Degradation should use configured amount")
    }

    // MARK: - INV-010: RequirementsEvaluator

    /// Requirements evaluation should work through RequirementsEvaluator
    func testRequirementsEvaluatorWorks() {
        let requirements = ChoiceRequirements(
            minResources: ["faith": 5],
            requiredFlags: ["quest_started"],
            forbiddenFlags: ["quest_failed"],
            minBalance: nil,
            maxBalance: nil
        )

        // Test with evaluator
        let canMeet1 = Requirements.evaluator.canMeet(
            requirements: requirements,
            resources: ["faith": 10],
            flags: ["quest_started"],
            balance: 50
        )
        XCTAssertTrue(canMeet1, "Should meet requirements")

        let canMeet2 = Requirements.evaluator.canMeet(
            requirements: requirements,
            resources: ["faith": 2],  // Not enough
            flags: ["quest_started"],
            balance: 50
        )
        XCTAssertFalse(canMeet2, "Should not meet requirements - insufficient faith")

        let canMeet3 = Requirements.evaluator.canMeet(
            requirements: requirements,
            resources: ["faith": 10],
            flags: ["quest_failed"],  // Forbidden flag
            balance: 50
        )
        XCTAssertFalse(canMeet3, "Should not meet requirements - forbidden flag")
    }

    // MARK: - INV-010: PressureEngine Save/Load

    /// Triggered thresholds must be preserved across save/load
    /// Reference: Audit.rtf - Save/Load state loss bug
    func testPressureEngineTriggeredThresholdsSaveLoad() {
        // Given: Pressure engine with some triggered thresholds
        let pressureEngine = gameLoop.pressureEngine

        // Trigger some thresholds by advancing pressure
        pressureEngine.adjust(by: 25)  // Trigger 10, 20
        pressureEngine.adjust(by: 30)  // Trigger 30, 40, 50

        let originalThresholds = pressureEngine.getTriggeredThresholds()
        let originalPressure = pressureEngine.currentPressure

        // When: Save and restore thresholds
        let savedThresholds = pressureEngine.getTriggeredThresholds()

        // Simulate reload by creating new engine and restoring
        let newPressureEngine = PressureEngine(rules: testPressureRules)
        newPressureEngine.setPressure(originalPressure)
        newPressureEngine.setTriggeredThresholds(savedThresholds)

        // Then: Thresholds should match
        XCTAssertEqual(
            newPressureEngine.getTriggeredThresholds(),
            originalThresholds,
            "Triggered thresholds should be preserved after save/load"
        )
        XCTAssertEqual(
            newPressureEngine.currentPressure,
            originalPressure,
            "Pressure should be preserved after save/load"
        )
    }

    /// syncTriggeredThresholdsFromPressure should reconstruct state from pressure value
    /// Reference: Audit.rtf - Save/Load state loss fix
    func testPressureEngineSyncTriggeredThresholdsFromPressure() {
        // Given: Pressure engine with pressure at 55
        let pressureEngine = PressureEngine(rules: testPressureRules)
        pressureEngine.setPressure(55)

        // When: Sync triggered thresholds from pressure
        pressureEngine.syncTriggeredThresholdsFromPressure()

        // Then: All thresholds <= 55 should be marked as triggered
        let triggered = pressureEngine.getTriggeredThresholds()
        XCTAssertTrue(triggered.contains(10), "Threshold 10 should be triggered")
        XCTAssertTrue(triggered.contains(20), "Threshold 20 should be triggered")
        XCTAssertTrue(triggered.contains(30), "Threshold 30 should be triggered")
        XCTAssertTrue(triggered.contains(40), "Threshold 40 should be triggered")
        XCTAssertTrue(triggered.contains(50), "Threshold 50 should be triggered")
        XCTAssertFalse(triggered.contains(60), "Threshold 60 should NOT be triggered")
        XCTAssertFalse(triggered.contains(70), "Threshold 70 should NOT be triggered")
    }

    /// After sync from pressure, triggered thresholds should prevent duplicates
    /// Reference: Audit.rtf - Duplicate events after load
    func testPressureEngineTriggeredThresholdsPreventDuplicates() {
        // Given: Pressure engine that synced from pressure 50
        let pressureEngine = PressureEngine(rules: testPressureRules)
        pressureEngine.setPressure(50)
        pressureEngine.syncTriggeredThresholdsFromPressure()

        // When: Get triggered thresholds
        let triggeredBefore = pressureEngine.getTriggeredThresholds()

        // Advance slightly
        pressureEngine.adjust(by: 5) // Now at 55
        let triggeredAfter = pressureEngine.getTriggeredThresholds()

        // Then: Previously triggered thresholds should still be marked
        // All thresholds <= 50 should be in both sets
        for threshold in [10, 20, 30, 40, 50] {
            XCTAssertTrue(triggeredBefore.contains(threshold), "Threshold \(threshold) should be triggered before")
            XCTAssertTrue(triggeredAfter.contains(threshold), "Threshold \(threshold) should still be triggered after")
        }
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

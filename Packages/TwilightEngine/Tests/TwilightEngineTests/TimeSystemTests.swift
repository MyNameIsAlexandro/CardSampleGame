import XCTest
@testable import TwilightEngine

/// Time System Invariant Tests
/// Ensures the time system follows critical rules:
/// - Each day must be processed individually (no skipping)
/// - Time cannot be rolled back
/// - Escalation happens at correct intervals
final class TimeSystemTests: XCTestCase {

    var engine: TwilightGameEngine!

    override func setUp() {
        super.setUp()
        engine = TwilightGameEngine()
        // Initialize with minimal setup
        TestContentLoader.loadContentPacksIfNeeded()
        engine.initializeNewGame(playerName: "Test", heroId: nil)
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Day Processing Invariants

    /// INVARIANT: Each day must be processed individually, not skipped
    /// When advancing multiple days, tension should increase for EACH eligible day
    func testEachDayProcessedIndividually() {
        // Given: Engine at day 0 with initial tension
        let initialDay = engine.currentDay
        let initialTension = engine.worldTension

        // When: Advance by 9 days (should trigger 3 tension ticks at days 3, 6, 9)
        // Using performAction to simulate real gameplay
        for _ in 0..<9 {
            // Rest action costs 1 day
            _ = engine.performAction(.rest)
        }

        // Then: Should be at day 9
        XCTAssertEqual(engine.currentDay, initialDay + 9, "Should have advanced 9 days")

        // And: Tension should have increased 3 times (at days 3, 6, 9)
        // Each tick increases tension by at least 3 (base amount)
        XCTAssertGreaterThanOrEqual(
            engine.worldTension,
            initialTension + 9, // 3 ticks * 3 base minimum
            "Tension should increase at each interval"
        )
    }

    /// INVARIANT: Time cannot be rolled back
    /// currentDay should only increase, never decrease
    func testTimeCannotBeRolledBack() {
        // Given: Engine at some day
        let dayBeforeAction = engine.currentDay

        // When: Perform any action
        _ = engine.performAction(.rest)

        // Then: Day should not have decreased
        XCTAssertGreaterThanOrEqual(
            engine.currentDay,
            dayBeforeAction,
            "Time should never go backwards"
        )
    }

    /// INVARIANT: No day can be skipped when advancing time
    /// If we go from day 1 to day 10, days 2-9 must all be processed
    func testNoDaySkipping() {
        // This test verifies the implementation correctness
        // by checking that tension ticks happen at the expected intervals

        // Given: Engine at day 0
        XCTAssertEqual(engine.currentDay, 0, "Should start at day 0")

        // Record tension before starting
        let tensionAtDay0 = engine.worldTension

        // Advance to day 3 (first tension tick)
        for _ in 0..<3 {
            _ = engine.performAction(.rest)
        }
        let tensionAtDay3 = engine.worldTension
        XCTAssertGreaterThan(tensionAtDay3, tensionAtDay0, "Tension should increase at day 3")

        // Advance to day 6 (second tension tick)
        for _ in 0..<3 {
            _ = engine.performAction(.rest)
        }
        let tensionAtDay6 = engine.worldTension
        XCTAssertGreaterThan(tensionAtDay6, tensionAtDay3, "Tension should increase at day 6")

        // Advance to day 9 (third tension tick)
        for _ in 0..<3 {
            _ = engine.performAction(.rest)
        }
        let tensionAtDay9 = engine.worldTension
        XCTAssertGreaterThan(tensionAtDay9, tensionAtDay6, "Tension should increase at day 9")
    }

    // MARK: - Escalation Invariants

    /// INVARIANT: Escalation must increase with time
    /// The tension increase per tick should grow as days progress
    func testEscalationIncreasesWithTime() {
        // The formula is: base + (daysPassed / 10)
        // Day 1-9: +3
        // Day 10-19: +4
        // Day 20-29: +5

        let earlyIncrease = TwilightPressureRules.calculateTensionIncrease(daysPassed: 5)
        let midIncrease = TwilightPressureRules.calculateTensionIncrease(daysPassed: 15)
        let lateIncrease = TwilightPressureRules.calculateTensionIncrease(daysPassed: 25)

        XCTAssertEqual(earlyIncrease, 3, "Early game (day 5): base tension increase")
        XCTAssertEqual(midIncrease, 4, "Mid game (day 15): +1 escalation")
        XCTAssertEqual(lateIncrease, 5, "Late game (day 25): +2 escalation")

        XCTAssertLessThan(earlyIncrease, midIncrease, "Tension increase should grow over time")
        XCTAssertLessThan(midIncrease, lateIncrease, "Tension increase should continue growing")
    }

    /// INVARIANT: Tension tick interval is respected
    /// Tension should only increase every N days (default 3)
    func testTensionTickIntervalRespected() {
        // Record initial tension
        let initialTension = engine.worldTension

        // Day 1: No tick
        _ = engine.performAction(.rest)
        XCTAssertEqual(engine.worldTension, initialTension, "No tension increase on day 1")

        // Day 2: No tick
        _ = engine.performAction(.rest)
        XCTAssertEqual(engine.worldTension, initialTension, "No tension increase on day 2")

        // Day 3: Tick!
        _ = engine.performAction(.rest)
        XCTAssertGreaterThan(engine.worldTension, initialTension, "Tension should increase on day 3")
    }

    // MARK: - Free Action Invariants

    /// INVARIANT: Most actions cost time (no free actions except instant ones)
    func testMostActionsCostTime() {
        let dayBefore = engine.currentDay

        // Rest should cost time
        _ = engine.performAction(.rest)
        XCTAssertGreaterThan(engine.currentDay, dayBefore, "Rest should advance time")
    }

    // MARK: - State Consistency

    /// INVARIANT: Engine state remains consistent after time advancement
    func testStateConsistencyAfterTimeAdvancement() {
        // Advance several days
        for _ in 0..<10 {
            _ = engine.performAction(.rest)
        }

        // State should be consistent
        XCTAssertGreaterThanOrEqual(engine.playerHealth, 0, "Health should not be negative")
        XCTAssertGreaterThanOrEqual(engine.playerFaith, 0, "Faith should not be negative")
        XCTAssertGreaterThanOrEqual(engine.worldTension, 0, "Tension should not be negative")
        XCTAssertLessThanOrEqual(engine.worldTension, 100, "Tension should not exceed 100")
    }

    // MARK: - Regression Tests

    /// Regression test: Ensure advancing by N days doesn't skip day processing
    /// This guards against the bug: `daysPassed += N` instead of proper iteration
    func testAdvanceMultipleDaysProcessesEach() {
        // Setup: Start at day 0, tension tick every 3 days
        let initialTension = engine.worldTension

        // If we advance by 6 days, we should see exactly 2 tension ticks
        // (at day 3 and day 6)

        // Simulate advancing 6 days
        for _ in 0..<6 {
            _ = engine.performAction(.rest)
        }

        // We should be at day 6
        XCTAssertEqual(engine.currentDay, 6)

        // Tension should have increased twice
        // Minimum increase: 2 * 3 (base) = 6
        XCTAssertGreaterThanOrEqual(
            engine.worldTension - initialTension,
            6,
            "Two tension ticks should have occurred"
        )
    }
}

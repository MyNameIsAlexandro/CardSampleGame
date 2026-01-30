import XCTest
@testable import TwilightEngine

/// INV-WLD: World Consistency Gate Tests
/// Verifies degradation rules, tension game-over, anchor resistance,
/// and region state transitions are consistent and deterministic.
/// Gate rules: < 2s, no XCTSkip, no non-deterministic RNG.
final class INV_WLD_GateTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TestContentLoader.loadContentPacksIfNeeded()
        WorldRNG.shared.setSeed(42)
        DegradationRules.reset()
    }

    override func tearDown() {
        WorldRNG.shared.setSeed(0)
        DegradationRules.reset()
        super.tearDown()
    }

    // MARK: - WLD-01: Degradation algorithm in one place

    /// DegradationRules is the single source of truth for selection weights
    func testDegradationRules_stableWeightIsZero() {
        let weight = DegradationRules.current.selectionWeight(for: .stable)
        XCTAssertEqual(weight, 0, "Stable regions should have 0 weight (never selected)")
    }

    /// Borderland weight = 1, Breach weight = 2
    func testDegradationRules_weightOrdering() {
        let borderland = DegradationRules.current.selectionWeight(for: .borderland)
        let breach = DegradationRules.current.selectionWeight(for: .breach)
        XCTAssertEqual(borderland, 1)
        XCTAssertEqual(breach, 2)
        XCTAssertGreaterThan(breach, borderland, "Breach should have higher weight than borderland")
    }

    /// Resistance probability is integrity / 100
    func testDegradationRules_resistanceProbability() {
        XCTAssertEqual(DegradationRules.current.resistanceProbability(anchorIntegrity: 100), 1.0)
        XCTAssertEqual(DegradationRules.current.resistanceProbability(anchorIntegrity: 50), 0.5)
        XCTAssertEqual(DegradationRules.current.resistanceProbability(anchorIntegrity: 0), 0.0)
    }

    // MARK: - WLD-02: Stable → Borderland single rule

    /// RegionStateType.degraded follows strict chain: stable→borderland→breach→nil
    func testRegionState_degradationChain() {
        XCTAssertEqual(RegionStateType.stable.degraded, .borderland)
        XCTAssertEqual(RegionStateType.borderland.degraded, .breach)
        XCTAssertNil(RegionStateType.breach.degraded, "Breach cannot degrade further")
    }

    /// RegionStateType.restored follows reverse chain: breach→borderland→stable→nil
    func testRegionState_restorationChain() {
        XCTAssertEqual(RegionStateType.breach.restored, .borderland)
        XCTAssertEqual(RegionStateType.borderland.restored, .stable)
        XCTAssertNil(RegionStateType.stable.restored, "Stable cannot restore further")
    }

    /// Anchor integrity thresholds map correctly to region states
    func testAnchorConfig_integrityThresholds() {
        XCTAssertEqual(TwilightAnchorConfig.regionStateForIntegrity(100), .stable)
        XCTAssertEqual(TwilightAnchorConfig.regionStateForIntegrity(70), .stable)
        XCTAssertEqual(TwilightAnchorConfig.regionStateForIntegrity(69), .borderland)
        XCTAssertEqual(TwilightAnchorConfig.regionStateForIntegrity(31), .borderland)
        XCTAssertEqual(TwilightAnchorConfig.regionStateForIntegrity(30), .breach)
        XCTAssertEqual(TwilightAnchorConfig.regionStateForIntegrity(0), .breach)
    }

    // MARK: - WLD-03: Tension 100% → Game Over

    /// Engine triggers game over when tension reaches 100
    func testTension100_gameOver() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame(playerName: "Test", heroId: nil)

        guard !engine.publishedRegions.isEmpty else {
            XCTFail("ContentPack not loaded"); return
        }

        engine.setWorldTension(97)

        // Advance 3 days to trigger tension escalation (+3 minimum)
        _ = engine.performAction(.rest)
        _ = engine.performAction(.rest)
        _ = engine.performAction(.rest) // day 3 → tension increase

        if engine.worldTension >= 100 {
            XCTAssertTrue(engine.isGameOver, "Game should end at tension >= 100")
            if case .defeat = engine.gameResult {
                // Expected
            } else {
                XCTFail("Should be defeat result")
            }
        }
    }

    /// Tension below 100 does not trigger game over
    func testTensionBelow100_noGameOver() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame(playerName: "Test", heroId: nil)
        engine.setWorldTension(50)
        _ = engine.performAction(.rest)
        XCTAssertFalse(engine.isGameOver, "Game should not end at tension 50")
    }

    // MARK: - WLD-04: Tension escalation formula

    /// Tension escalation follows formula: 3 + (daysPassed / 10)
    func testTensionEscalation_formula() {
        // Day 1-9: +3
        XCTAssertEqual(TwilightPressureRules.calculateTensionIncrease(daysPassed: 1), 3)
        XCTAssertEqual(TwilightPressureRules.calculateTensionIncrease(daysPassed: 9), 3)
        // Day 10-19: +4
        XCTAssertEqual(TwilightPressureRules.calculateTensionIncrease(daysPassed: 10), 4)
        XCTAssertEqual(TwilightPressureRules.calculateTensionIncrease(daysPassed: 19), 4)
        // Day 20-29: +5
        XCTAssertEqual(TwilightPressureRules.calculateTensionIncrease(daysPassed: 20), 5)
    }

    /// Tension escalation interval is 3 days
    func testTensionEscalation_intervalIs3Days() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame(playerName: "Test", heroId: nil)

        guard !engine.publishedRegions.isEmpty else {
            XCTFail("ContentPack not loaded"); return
        }

        let initial = engine.worldTension
        _ = engine.performAction(.rest) // day 1
        _ = engine.performAction(.rest) // day 2
        XCTAssertEqual(engine.worldTension, initial, "Tension should not change before day 3")

        _ = engine.performAction(.rest) // day 3 → escalation
        XCTAssertGreaterThan(engine.worldTension, initial, "Tension should increase on day 3")
    }

    // MARK: - WLD-05: 30-day simulation

    /// 30-day deterministic simulation: tension rises, no crash
    func testSimulation_30days_deterministic() {
        WorldRNG.shared.setSeed(12345)
        let engine = TwilightGameEngine()
        engine.initializeNewGame(playerName: "Sim", heroId: nil)

        guard !engine.publishedRegions.isEmpty else {
            XCTFail("ContentPack not loaded"); return
        }

        var tensions: [Int] = [engine.worldTension]

        for day in 1...30 {
            if engine.isGameOver { break }
            _ = engine.performAction(.rest)
            if engine.currentEvent != nil {
                _ = engine.performAction(.dismissCurrentEvent)
            }
            tensions.append(engine.worldTension)
            _ = day // suppress unused warning
        }

        // Tension should be non-decreasing (it only goes up via escalation)
        for i in 1..<tensions.count {
            XCTAssertGreaterThanOrEqual(tensions[i], tensions[i - 1],
                "Tension must be non-decreasing (day \(i))")
        }

        // Should have progressed beyond initial
        XCTAssertGreaterThan(tensions.last!, tensions.first!,
            "Tension should have increased over 30 days")
    }

    /// Same seed produces identical 30-day simulation
    func testSimulation_30days_sameResult() {
        func runSimulation(seed: UInt64) -> [Int] {
            WorldRNG.shared.setSeed(seed)
            let engine = TwilightGameEngine()
            engine.initializeNewGame(playerName: "Sim", heroId: nil)
            var tensions: [Int] = []
            for _ in 1...30 {
                if engine.isGameOver { break }
                _ = engine.performAction(.rest)
                if engine.currentEvent != nil {
                    _ = engine.performAction(.dismissCurrentEvent)
                }
                tensions.append(engine.worldTension)
            }
            return tensions
        }

        let run1 = runSimulation(seed: 99999)
        let run2 = runSimulation(seed: 99999)
        XCTAssertEqual(run1, run2, "Same seed must produce identical 30-day simulation")
    }
}

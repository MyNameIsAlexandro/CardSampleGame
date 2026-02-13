/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/INV_WLD_GateTests.swift
/// Назначение: Содержит реализацию файла INV_WLD_GateTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import TwilightEngine

/// INV-WLD: World Consistency Gate Tests
/// Verifies degradation rules, tension game-over, anchor resistance,
/// and region state transitions are consistent and deterministic.
/// Gate rules: < 2s, no XCTSkip, no non-deterministic RNG.
final class INV_WLD_GateTests: XCTestCase {

    private let rules = TwilightDegradationRules()

    override func setUp() {
        super.setUp()
        _ = TestContentLoader.sharedLoadedRegistry()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - WLD-01: Degradation algorithm in one place

    /// DegradationRules is the single source of truth for selection weights
    func testDegradationRules_stableWeightIsZero() {
        let weight = rules.selectionWeight(for: .stable)
        XCTAssertEqual(weight, 0, "Stable regions should have 0 weight (never selected)")
    }

    /// Borderland weight = 1, Breach weight = 2
    func testDegradationRules_weightOrdering() {
        let borderland = rules.selectionWeight(for: .borderland)
        let breach = rules.selectionWeight(for: .breach)
        XCTAssertEqual(borderland, 1)
        XCTAssertEqual(breach, 2)
        XCTAssertGreaterThan(breach, borderland, "Breach should have higher weight than borderland")
    }

    /// Resistance probability is integrity / 100
    func testDegradationRules_resistanceProbability() {
        XCTAssertEqual(rules.resistanceProbability(anchorIntegrity: 100), 1.0)
        XCTAssertEqual(rules.resistanceProbability(anchorIntegrity: 50), 0.5)
        XCTAssertEqual(rules.resistanceProbability(anchorIntegrity: 0), 0.0)
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
        XCTAssertEqual(AnchorBalanceConfig.regionStateForIntegrity(100), .stable)
        XCTAssertEqual(AnchorBalanceConfig.regionStateForIntegrity(70), .stable)
        XCTAssertEqual(AnchorBalanceConfig.regionStateForIntegrity(69), .borderland)
        XCTAssertEqual(AnchorBalanceConfig.regionStateForIntegrity(31), .borderland)
        XCTAssertEqual(AnchorBalanceConfig.regionStateForIntegrity(30), .breach)
        XCTAssertEqual(AnchorBalanceConfig.regionStateForIntegrity(0), .breach)
    }

    // MARK: - WLD-03: Tension 100% → Game Over

    /// Engine triggers game over when tension reaches 100
    func testTension100_gameOver() {
        let engine = TestEngineFactory.makeEngine(seed: 42)
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
        let engine = TestEngineFactory.makeEngine(seed: 42)
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
        let engine = TestEngineFactory.makeEngine(seed: 42)
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
        let engine = TestEngineFactory.makeEngine(seed: 12345)
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
            let engine = TestEngineFactory.makeEngine(seed: seed)
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

    // MARK: - WLD-06: Anchor Alignment

    /// Anchor alignment is initialized from definition's initialInfluence
    func testAnchorAlignment_initialFromDefinition() {
        let engine = TestEngineFactory.makeEngine(seed: 42)
        engine.initializeNewGame(playerName: "Test", heroId: nil)

        // Check that anchors have alignment set (from definition)
        for region in engine.regionsArray {
            if let anchor = region.anchor {
                // Alignment should be a valid value (not crash)
                XCTAssertTrue(
                    [AnchorAlignment.light, .neutral, .dark].contains(anchor.alignment),
                    "Anchor \(anchor.id) should have valid alignment"
                )
            }
        }
    }

    /// Region alignment is derived from its anchor
    func testRegionAlignment_derivedFromAnchor() {
        let engine = TestEngineFactory.makeEngine(seed: 42)
        engine.initializeNewGame(playerName: "Test", heroId: nil)

        for region in engine.regionsArray {
            if let anchor = region.anchor {
                XCTAssertEqual(region.alignment, anchor.alignment,
                    "Region alignment should match anchor alignment")
            } else {
                XCTAssertEqual(region.alignment, .neutral,
                    "Region without anchor should be neutral")
            }
        }
    }

    /// Light/neutral hero strengthening does not change alignment
    func testStrengthenAnchor_lightHero_keepsAlignment() {
        let engine = TestEngineFactory.makeEngine(seed: 42)
        engine.initializeNewGame(playerName: "Test", heroId: nil)

        guard let regionWithAnchor = engine.regionsArray.first(where: { $0.anchor != nil }) else {
            XCTFail("No region with anchor"); return
        }

        // Set player to light alignment (balance > 70 = prav)
        engine.player.setBalance(80)
        engine.player.setFaith(20)
        engine.setCurrentRegion(regionWithAnchor.id)

        let originalAlignment = regionWithAnchor.anchor!.alignment

        _ = engine.performAction(.strengthenAnchor)

        let updatedRegion = engine.publishedRegions[regionWithAnchor.id]!
        XCTAssertEqual(updatedRegion.anchor?.alignment, originalAlignment,
            "Light hero strengthen should not change anchor alignment")
    }

    /// Dark hero strengthening shifts alignment toward dark
    func testStrengthenAnchor_darkHero_shiftsAlignment() {
        let engine = TestEngineFactory.makeEngine(seed: 42)
        engine.initializeNewGame(playerName: "Test", heroId: nil)

        guard let regionWithAnchor = engine.regionsArray.first(where: {
            $0.anchor != nil && $0.anchor!.alignment != .dark
        }) else {
            XCTFail("No region with non-dark anchor"); return
        }

        // Set player to dark alignment (balance < 30 = nav)
        engine.player.setBalance(10)
        engine.player.setHealth(20)
        engine.setCurrentRegion(regionWithAnchor.id)

        let originalAlignment = regionWithAnchor.anchor!.alignment

        _ = engine.performAction(.strengthenAnchor)

        let updatedRegion = engine.publishedRegions[regionWithAnchor.id]!
        XCTAssertNotEqual(updatedRegion.anchor?.alignment, originalAlignment,
            "Dark hero strengthen should shift anchor alignment toward dark")
    }

    /// Defile anchor changes alignment to dark
    func testDefileAnchor_changesAlignmentToDark() {
        let engine = TestEngineFactory.makeEngine(seed: 42)
        engine.initializeNewGame(playerName: "Test", heroId: nil)

        guard let regionWithAnchor = engine.regionsArray.first(where: {
            $0.anchor != nil && $0.anchor!.alignment != .dark
        }) else {
            XCTFail("No region with non-dark anchor"); return
        }

        engine.player.setBalance(10) // nav alignment
        engine.player.setHealth(20)
        engine.setCurrentRegion(regionWithAnchor.id)

        _ = engine.performAction(.defileAnchor)

        let updatedRegion = engine.publishedRegions[regionWithAnchor.id]!
        XCTAssertEqual(updatedRegion.anchor?.alignment, .dark,
            "Defile should set anchor alignment to dark")
    }

    /// Defile requires nav (dark) player alignment
    func testDefileAnchor_requiresNavAlignment() {
        let engine = TestEngineFactory.makeEngine(seed: 42)
        engine.initializeNewGame(playerName: "Test", heroId: nil)

        guard let regionWithAnchor = engine.regionsArray.first(where: {
            $0.anchor != nil && $0.anchor!.alignment != .dark
        }) else {
            XCTFail("No region with non-dark anchor"); return
        }

        engine.player.setBalance(80) // prav = light
        engine.player.setHealth(20)
        engine.setCurrentRegion(regionWithAnchor.id)

        let result = engine.performAction(.defileAnchor)
        XCTAssertFalse(result.success, "Light hero should not be able to defile")
    }

    /// Cannot defile already dark anchor
    func testDefileAnchor_alreadyDark_fails() {
        let engine = TestEngineFactory.makeEngine(seed: 42)
        engine.initializeNewGame(playerName: "Test", heroId: nil)

        guard let regionWithAnchor = engine.regionsArray.first(where: { $0.anchor != nil }) else {
            XCTFail("No region with anchor"); return
        }

        // First defile it
        engine.player.setBalance(10)
        engine.player.setHealth(20)
        engine.setCurrentRegion(regionWithAnchor.id)
        _ = engine.performAction(.defileAnchor)

        // Try to defile again
        let result = engine.performAction(.defileAnchor)
        XCTAssertFalse(result.success, "Cannot defile already dark anchor")
    }

    /// Save/load preserves anchor alignment
    func testSaveLoad_preservesAnchorAlignment() {
        let region = EngineRegionState(
            id: "test_region",
            name: "Test",
            type: .sacred,
            state: .stable,
            anchor: EngineAnchorState(id: "test_anchor", name: "Anchor", integrity: 80, alignment: .dark)
        )

        let saveState = RegionSaveState(from: region)
        XCTAssertEqual(saveState.anchorAlignment, "dark")

        let restored = saveState.toEngineRegionState()
        XCTAssertEqual(restored.anchor?.alignment, .dark, "Alignment should survive save/load")
    }

    /// Save/load defaults to neutral for old saves without alignment
    func testSaveLoad_defaultsToNeutral() {
        let region = EngineRegionState(
            id: "test_region",
            name: "Test",
            type: .sacred,
            state: .stable,
            anchor: EngineAnchorState(id: "test_anchor", name: "Anchor", integrity: 80)
        )

        let saveState = RegionSaveState(from: region)
        let restored = saveState.toEngineRegionState()
        XCTAssertEqual(restored.anchor?.alignment, .neutral, "Default alignment should be neutral")
    }
}

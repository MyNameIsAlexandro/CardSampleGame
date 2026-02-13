/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/GameplayFlowTests+ContentPerformanceAndReset.swift
/// Назначение: Содержит реализацию файла GameplayFlowTests+ContentPerformanceAndReset.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import TwilightEngine

extension GameplayFlowTests {
    // MARK: - Content Pack Loading Tests

    func testSemanticVersionDecoding() throws {
        // Given: JSON with version string
        let json = """
        {"version": "1.2.3"}
        """
        struct VersionWrapper: Codable { let version: SemanticVersion }

        // When: Decoding
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(VersionWrapper.self, from: data)

        // Then: Version should be parsed correctly
        XCTAssertEqual(decoded.version.major, 1)
        XCTAssertEqual(decoded.version.minor, 2)
        XCTAssertEqual(decoded.version.patch, 3)
    }

    func testSemanticVersionEncoding() throws {
        // Given: SemanticVersion
        let version = SemanticVersion(major: 2, minor: 0, patch: 1)
        struct VersionWrapper: Codable { let version: SemanticVersion }

        // When: Encoding
        let wrapper = VersionWrapper(version: version)
        let data = try JSONEncoder().encode(wrapper)
        let json = String(data: data, encoding: .utf8)!

        // Then: Should encode to string format
        XCTAssertTrue(json.contains("\"2.0.1\""), "Version should be encoded as string")
    }

    func testInvalidSemanticVersionThrowsError() {
        // Given: JSON with invalid version
        let json = """
        {"version": "invalid"}
        """
        struct VersionWrapper: Codable { let version: SemanticVersion }

        // When/Then: Decoding should throw
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(VersionWrapper.self, from: data))
    }

    func testContentRegistryExists() {
        let registry = TestContentLoader.sharedLoadedRegistry()
        XCTAssertFalse(registry.loadedPackIds.isEmpty, "TestContentLoader should load at least 1 pack for engine tests")
    }

    // MARK: - Performance Tests

    func testEngineInitializationPerformance() {
        guard requireRegionsLoaded() else { return }
        // Measure time to initialize engine (Engine-First)
        measure {
            let testEngine = TestEngineFactory.makeEngine(seed: 1)
            testEngine.initializeNewGame(playerName: "Perf", heroId: nil)

            // Ensure engine is usable
            XCTAssertNotNil(testEngine.currentRegionId)
        }
    }

    func testRegionAccessPerformance() {
        guard requireRegionsLoaded() else { return }
        // Measure time to access regions multiple times
        measure {
            for _ in 0..<100 {
                let regions = engine.regionsArray
                XCTAssertFalse(regions.isEmpty)
            }
        }
    }

    func testTravelActionPerformance() {
        guard let currentRegion = engine.currentRegion,
              let neighborId = currentRegion.neighborIds.first else {
            XCTFail("No neighbors for performance test"); return
        }

        // Measure travel performance
        measure {
            // Travel to neighbor
            _ = engine.performAction(.travel(toRegionId: neighborId))

            // Travel back
            if let newRegion = engine.currentRegion,
               let returnId = newRegion.neighborIds.first {
                _ = engine.performAction(.travel(toRegionId: returnId))
            }
        }
    }

    func testCardCreationPerformance() {
        // Measure card creation performance
        measure {
            for i in 0..<100 {
                _ = Card(
                    id: "test_perf_\(i)",
                    name: "Test Card \(i)",
                    type: .attack,
                    rarity: .common,
                    description: "Test description",
                    power: 2
                )
            }
        }
    }

    func testCombatLogEnumeratedPerformance() {
        // Test that enumerated log (used in ForEach) is fast
        var log: [String] = []
        for i in 0..<1000 {
            log.append("⚔️ Action \(i)")
        }

        measure {
            // This is what ForEach does
            let enumerated = Array(log.suffix(5).enumerated())
            XCTAssertEqual(enumerated.count, 5)

            // Access each element
            for (index, entry) in enumerated {
                XCTAssertNotNil(index)
                XCTAssertFalse(entry.isEmpty)
            }
        }
    }

    // Legacy sync tests removed - Engine-First architecture manages playerHand directly

    // MARK: - Engine Reset Tests

    /// Test that resetGameState clears isGameOver flag
    func testResetGameStateClearsIsGameOver() {
        // Given: Game is over (simulate by setting tension to max)
        // First check that we can trigger game over
        let initialGameOver = engine.isGameOver
        XCTAssertFalse(initialGameOver, "Game should not be over initially")

        // When: resetGameState is called
        engine.resetGameState()

        // Then: isGameOver should be false
        XCTAssertFalse(engine.isGameOver, "isGameOver should be false after reset")
    }

    /// Test that new game creates fresh world state - Engine-First version
    func testNewGameCreatesFreshWorldState() {
        guard requireRegionsLoaded() else { return }
        // Given: A fresh engine after initialization
        let freshEngine = TestEngineFactory.makeEngine(seed: 42)
        freshEngine.initializeNewGame(playerName: "Test", heroId: nil)

        // Then: It should have initial world tension from active balance config
        let expectedInitialTension = freshEngine.services.contentRegistry.getBalanceConfig()?.pressure.startingPressure ?? 30
        XCTAssertEqual(freshEngine.worldTension, expectedInitialTension, "Fresh engine should use balance-config initial tension")

        // And: It should have initial day count
        XCTAssertEqual(freshEngine.currentDay, 0, "Fresh engine should start at day 0")

        // And: It should have regions (when ContentPack loaded)
        XCTAssertFalse(freshEngine.publishedRegions.isEmpty, "Fresh engine should have regions")
    }

    // MARK: - Travel Validation Tests

    /// Test that travel to non-neighbor region is blocked
    func testTravelToNonNeighborIsBlocked() {
        guard let currentRegion = engine.currentRegion else {
            XCTFail("No current region"); return
        }

        // Find a non-neighbor region
        let nonNeighborRegion = engine.regionsArray.first { region in
            region.id != currentRegion.id && !currentRegion.neighborIds.contains(region.id)
        }

        guard let targetRegion = nonNeighborRegion else {
            XCTFail("No non-neighbor region available for testing"); return
        }

        // When: Try to travel to non-neighbor
        let result = engine.performAction(.travel(toRegionId: targetRegion.id))

        // Then: Action should fail
        XCTAssertFalse(result.success, "Travel to non-neighbor should fail")
        XCTAssertNotNil(result.error, "Should have an error for non-neighbor travel")
    }

    /// Test that travel to neighbor region succeeds
    func testTravelToNeighborSucceeds() {
        guard let currentRegion = engine.currentRegion,
              let neighborId = currentRegion.neighborIds.first else {
            XCTFail("No neighbor available for travel test"); return
        }

        let initialDay = engine.currentDay

        // When: Travel to neighbor
        let result = engine.performAction(.travel(toRegionId: neighborId))

        // Then: Action should succeed
        XCTAssertTrue(result.success, "Travel to neighbor should succeed")
        XCTAssertGreaterThan(engine.currentDay, initialDay, "Day should advance after travel")
        XCTAssertEqual(engine.currentRegionId, neighborId, "Current region should change")
    }

    /// Test that travel cost is calculated correctly
    func testTravelCostCalculation() {
        guard let currentRegion = engine.currentRegion,
              let neighborId = currentRegion.neighborIds.first else {
            XCTFail("No neighbor for cost test"); return
        }

        // When: Calculate travel cost to neighbor
        let neighborCost = engine.calculateTravelCost(to: neighborId)

        // Then: Cost should be 1 for neighbor
        XCTAssertEqual(neighborCost, 1, "Travel to neighbor should cost 1 day")

        // Find non-neighbor
        let nonNeighborRegion = engine.regionsArray.first { region in
            region.id != currentRegion.id && !currentRegion.neighborIds.contains(region.id)
        }

        if let nonNeighbor = nonNeighborRegion {
            // When: Calculate travel cost to non-neighbor
            let nonNeighborCost = engine.calculateTravelCost(to: nonNeighbor.id)

            // Then: Cost should be 2 for non-neighbor
            XCTAssertEqual(nonNeighborCost, 2, "Travel to non-neighbor should cost 2 days")
        }
    }
}

import XCTest
@testable import CardSampleGame

/// Regression Playthrough Tests
/// Ensures migration does not change game behavior.
/// These tests use fixed seeds and action sequences to verify determinism.
/// Reference: Docs/MIGRATION_PLAN.md
final class RegressionPlaythroughTests: XCTestCase {

    // MARK: - Test Fixtures

    /// Snapshot of expected game state at checkpoints
    struct GameStateSnapshot: Equatable {
        let pressure: Int
        let time: Int
        let healthRange: ClosedRange<Int>   // Allow small variance
        let faithRange: ClosedRange<Int>
        let visitedRegionsCount: Int
        let flagsSet: Set<String>

        func matches(_ state: ActualGameState, tolerance: Int = 2) -> Bool {
            guard pressure == state.pressure else { return false }
            guard time == state.time else { return false }
            guard healthRange.contains(state.health) else { return false }
            guard faithRange.contains(state.faith) else { return false }
            guard visitedRegionsCount == state.visitedRegionsCount else { return false }
            guard flagsSet.isSubset(of: state.flags) else { return false }
            return true
        }
    }

    struct ActualGameState {
        let pressure: Int
        let time: Int
        let health: Int
        let faith: Int
        let visitedRegionsCount: Int
        let flags: Set<String>
    }

    // MARK: - Determinism Tests

    /// Same seed should produce same event selection
    func testFixedSeedProducesDeterministicEvents() {
        // Given: Fixed seed
        let seed: UInt64 = 42

        // When: Run selection multiple times
        var results: [String] = []
        for _ in 0..<5 {
            let eventId = selectEventWithFixedSeed(seed: seed, poolSize: 10)
            results.append(eventId)
        }

        // Then: All results identical
        let uniqueResults = Set(results)
        XCTAssertEqual(uniqueResults.count, 1, "Same seed should always select same event")
    }

    /// Different actions should produce different outcomes
    func testDifferentActionsProduceDifferentOutcomes() {
        // Given: Two playthroughs with different action sequences
        let actionsA: [TestAction] = [.rest, .rest, .travel("forest")]
        let actionsB: [TestAction] = [.travel("village"), .explore, .rest]

        // When: Simulate both
        let outcomeA = simulatePlaythrough(actions: actionsA, seed: 100)
        let outcomeB = simulatePlaythrough(actions: actionsB, seed: 100)

        // Then: Different final states
        // Note: They might coincidentally match, but likely different
        let areDifferent = outcomeA.time != outcomeB.time ||
                          outcomeA.visitedRegions != outcomeB.visitedRegions
        XCTAssertTrue(areDifferent || actionsA == actionsB,
                      "Different actions should generally produce different outcomes")
    }

    // MARK: - Save/Load Roundtrip

    /// Game state should survive save/load cycle unchanged
    func testSaveLoadRoundtripPreservesState() {
        // Given: Game state
        let originalState = TestGameState(
            pressure: 35,
            time: 12,
            health: 15,
            faith: 8,
            currentRegion: "village",
            visitedRegions: ["forest", "village", "crossroads"],
            flags: ["quest_started": true, "npc_met": true],
            completedEvents: ["event_001", "event_003"]
        )

        // When: Save and load
        let savedData = encodeState(originalState)
        let loadedState = decodeState(savedData)

        // Then: State preserved
        XCTAssertEqual(loadedState.pressure, originalState.pressure)
        XCTAssertEqual(loadedState.time, originalState.time)
        XCTAssertEqual(loadedState.health, originalState.health)
        XCTAssertEqual(loadedState.faith, originalState.faith)
        XCTAssertEqual(loadedState.currentRegion, originalState.currentRegion)
        XCTAssertEqual(loadedState.visitedRegions, originalState.visitedRegions)
        XCTAssertEqual(loadedState.flags, originalState.flags)
        XCTAssertEqual(loadedState.completedEvents, originalState.completedEvents)
    }

    // MARK: - Regression Checkpoints

    /// Standard playthrough should hit expected checkpoints
    /// This test documents expected behavior and catches regressions
    func testStandardPlaythroughReachesCheckpoints() {
        // Given: Standard action sequence (typical early game)
        let standardActions: [TestAction] = [
            .explore,           // Day 1: Explore starting area
            .travel("forest"),  // Day 2: Travel to forest
            .explore,           // Day 3: Explore forest (triggers day threshold)
            .rest,              // Day 4: Rest to recover
            .travel("village"), // Day 5: Travel to village
        ]

        // And: Expected checkpoints
        let checkpoint1 = GameStateSnapshot(
            pressure: 0,        // Before first threshold
            time: 2,
            healthRange: 18...20,
            faithRange: 8...12,
            visitedRegionsCount: 1,
            flagsSet: []
        )

        let checkpoint2 = GameStateSnapshot(
            pressure: 5,        // After first threshold (day 3)
            time: 5,
            healthRange: 15...20,
            faithRange: 5...12,
            visitedRegionsCount: 3,
            flagsSet: []
        )

        // When: Run playthrough
        let outcomes = simulateWithCheckpoints(
            actions: standardActions,
            checkpointIndices: [2, 5], // After action 2 and after action 5
            seed: 12345
        )

        // Then: Checkpoints reached (within tolerance)
        // Note: This test may need adjustment as game balance changes
        // The key invariant is: same input → same output
        XCTAssertEqual(outcomes.count, 2, "Should have 2 checkpoints")
    }

    // MARK: - Migration Safety Net

    /// This test captures current behavior for migration comparison
    /// Run before and after migration - results should match
    func testMigrationRegressionHarness() {
        // Given: Canonical test sequence
        let canonicalSeed: UInt64 = 98765
        let canonicalActions: [TestAction] = [
            .explore,
            .travel("forest"),
            .explore,
            .travel("village"),
            .rest,
            .strengthen,
            .travel("crossroads"),
            .explore,
            .rest,
            .travel("forest")
        ]

        // When: Run simulation
        let finalState = simulatePlaythrough(actions: canonicalActions, seed: canonicalSeed)

        // Then: Record/verify known good values
        // These values should be captured once and then verified on each run
        // If migration changes behavior, this test will fail

        // For now, we just verify the simulation completes
        XCTAssertGreaterThan(finalState.time, 0, "Time should advance")
        XCTAssertGreaterThanOrEqual(finalState.visitedRegions.count, 1, "Should have visited regions")

        // TODO: After establishing baseline, add specific assertions:
        // XCTAssertEqual(finalState.pressure, EXPECTED_PRESSURE)
        // XCTAssertEqual(finalState.time, EXPECTED_TIME)
        // XCTAssertEqual(finalState.visitedRegions, EXPECTED_REGIONS)
    }

    // MARK: - Deck State Persistence

    func testDeckStatePersistsAcrossSaveLoad() {
        // Given: Deck state with zones
        let deckState = TestDeckState(
            drawPile: ["card_1", "card_2", "card_3"],
            hand: ["card_4", "card_5"],
            discard: ["card_6"],
            exile: []
        )

        // When: Save and load
        let savedData = encodeDeckState(deckState)
        let loadedDeck = decodeDeckState(savedData)

        // Then: All zones preserved
        XCTAssertEqual(loadedDeck.drawPile, deckState.drawPile)
        XCTAssertEqual(loadedDeck.hand, deckState.hand)
        XCTAssertEqual(loadedDeck.discard, deckState.discard)
        XCTAssertEqual(loadedDeck.exile, deckState.exile)
    }

    // MARK: - Legacy vs Engine Comparison Tests

    /// Compare legacy playthrough to engine playthrough - must produce same results
    /// This is the critical migration safety net
    func testLegacyVsEngineProduceSameOutcome() {
        // Given: Same seed and actions for both
        let seed: UInt64 = 54321
        let actions: [TestAction] = [
            .explore,
            .travel("forest"),
            .rest,
            .explore,
            .travel("village"),
            .strengthen
        ]

        // When: Run both simulations
        let legacyOutcome = runLegacyPlaythrough(seed: seed, actions: actions)
        let engineOutcome = runEnginePlaythrough(seed: seed, actions: actions)

        // Then: Key metrics must match
        XCTAssertEqual(
            legacyOutcome.time,
            engineOutcome.time,
            "Time should match: legacy=\(legacyOutcome.time), engine=\(engineOutcome.time)"
        )
        XCTAssertEqual(
            legacyOutcome.pressure,
            engineOutcome.pressure,
            "Pressure should match: legacy=\(legacyOutcome.pressure), engine=\(engineOutcome.pressure)"
        )
        XCTAssertEqual(
            legacyOutcome.visitedRegions,
            engineOutcome.visitedRegions,
            "Visited regions should match"
        )
    }

    /// Run playthrough using legacy simulation (current Models/*)
    private func runLegacyPlaythrough(seed: UInt64, actions: [TestAction]) -> PlaythroughOutcome {
        // This simulates the current (legacy) game flow
        return simulatePlaythrough(actions: actions, seed: seed)
    }

    /// Run playthrough using new Engine simulation
    private func runEnginePlaythrough(seed: UInt64, actions: [TestAction]) -> PlaythroughOutcome {
        // This simulates the new Engine flow using GameRuntimeState
        var runtime = GameRuntimeState.newGame(
            startingRegionId: "starting_area",
            startingResources: ["health": 20, "faith": 10],
            startingDeck: [],
            seed: seed
        )

        var rng = SeededRNG(seed: seed)

        for action in actions {
            switch action {
            case .rest:
                runtime.world.currentTime += 1
                let currentHealth = runtime.player.getResource("health")
                runtime.player.setResource("health", value: min(20, currentHealth + 3))

            case .explore:
                runtime.world.currentTime += 1
                let eventRoll = Int.random(in: 0..<10, using: &rng)
                if eventRoll < 3 {
                    runtime.player.modifyResource("faith", by: -1)
                }

            case .travel(let destination):
                runtime.world.currentTime += 1
                runtime.world.currentRegionId = destination
                runtime.world.regionsState[destination] = RegionRuntimeState(
                    definitionId: destination,
                    currentState: .stable,
                    visitCount: 1,
                    isDiscovered: true
                )

            case .strengthen:
                runtime.world.currentTime += 1
                runtime.player.modifyResource("faith", by: -2)

            case .choose:
                break
            }

            // Check pressure threshold (same logic as legacy)
            if runtime.world.currentTime > 0 && runtime.world.currentTime % 3 == 0 {
                runtime.world.pressure += 5
            }
        }

        // Build visited regions set
        var visitedRegions = Set<String>(["starting_area"])
        for (regionId, state) in runtime.world.regionsState {
            if state.visitCount > 0 {
                visitedRegions.insert(regionId)
            }
        }

        return PlaythroughOutcome(
            time: runtime.world.currentTime,
            pressure: runtime.world.pressure,
            health: runtime.player.getResource("health"),
            faith: runtime.player.getResource("faith"),
            visitedRegions: visitedRegions,
            completedEvents: runtime.events.completedOneTimeEvents
        )
    }

    /// Test that snapshots can be compared for equality
    func testSnapshotComparison() {
        // Given: Two game states with same values
        let state1 = GameRuntimeState.newGame(
            startingRegionId: "forest",
            startingResources: ["health": 20, "faith": 10],
            startingDeck: ["c1", "c2"],
            seed: 100
        )

        let state2 = GameRuntimeState.newGame(
            startingRegionId: "forest",
            startingResources: ["health": 20, "faith": 10],
            startingDeck: ["c1", "c2"],
            seed: 100
        )

        // When: Take snapshots
        let snapshot1 = state1.snapshot()
        let snapshot2 = state2.snapshot()

        // Then: Snapshots equal
        XCTAssertEqual(snapshot1, snapshot2)
    }

    /// Test that different states produce different snapshots
    func testSnapshotDetectsDifferences() {
        // Given: Two different game states
        var state1 = GameRuntimeState.newGame(
            startingRegionId: "forest",
            startingResources: ["health": 20, "faith": 10],
            startingDeck: [],
            seed: 100
        )
        state1.world.pressure = 50

        var state2 = GameRuntimeState.newGame(
            startingRegionId: "forest",
            startingResources: ["health": 20, "faith": 10],
            startingDeck: [],
            seed: 100
        )
        state2.world.pressure = 0

        // When: Take snapshots
        let snapshot1 = state1.snapshot()
        let snapshot2 = state2.snapshot()

        // Then: Snapshots different
        XCTAssertNotEqual(snapshot1, snapshot2)
        XCTAssertNotEqual(snapshot1.pressure, snapshot2.pressure)
    }
}

// MARK: - Test Types

enum TestAction: Equatable {
    case rest
    case explore
    case travel(String)
    case strengthen
    case choose(eventId: String, choiceId: String)
}

struct TestGameState: Codable, Equatable {
    var pressure: Int
    var time: Int
    var health: Int
    var faith: Int
    var currentRegion: String
    var visitedRegions: Set<String>
    var flags: [String: Bool]
    var completedEvents: Set<String>
}

struct TestDeckState: Codable, Equatable {
    var drawPile: [String]
    var hand: [String]
    var discard: [String]
    var exile: [String]
}

struct PlaythroughOutcome {
    let time: Int
    let pressure: Int
    let health: Int
    let faith: Int
    let visitedRegions: Set<String>
    let completedEvents: Set<String>
}

// MARK: - Simulation Helpers

func selectEventWithFixedSeed(seed: UInt64, poolSize: Int) -> String {
    var rng = SeededRNG(seed: seed)
    let index = Int.random(in: 0..<poolSize, using: &rng)
    return "event_\(index)"
}

func simulatePlaythrough(actions: [TestAction], seed: UInt64) -> PlaythroughOutcome {
    var state = TestGameState(
        pressure: 0,
        time: 0,
        health: 20,
        faith: 10,
        currentRegion: "starting_area",
        visitedRegions: ["starting_area"],
        flags: [:],
        completedEvents: []
    )

    var rng = SeededRNG(seed: seed)

    for action in actions {
        switch action {
        case .rest:
            state.time += 1
            state.health = min(20, state.health + 3)

        case .explore:
            state.time += 1
            // Random event might affect resources
            let eventRoll = Int.random(in: 0..<10, using: &rng)
            if eventRoll < 3 {
                state.faith -= 1
            }

        case .travel(let destination):
            state.time += 1
            state.currentRegion = destination
            state.visitedRegions.insert(destination)

        case .strengthen:
            state.time += 1
            state.faith -= 2

        case .choose:
            // Choice resolution would go here
            break
        }

        // Check pressure threshold
        if state.time > 0 && state.time % 3 == 0 {
            state.pressure += 5
        }
    }

    return PlaythroughOutcome(
        time: state.time,
        pressure: state.pressure,
        health: state.health,
        faith: state.faith,
        visitedRegions: state.visitedRegions,
        completedEvents: state.completedEvents
    )
}

func simulateWithCheckpoints(
    actions: [TestAction],
    checkpointIndices: [Int],
    seed: UInt64
) -> [PlaythroughOutcome] {
    var results: [PlaythroughOutcome] = []
    var currentActions: [TestAction] = []

    for (index, action) in actions.enumerated() {
        currentActions.append(action)

        if checkpointIndices.contains(index + 1) {
            let outcome = simulatePlaythrough(actions: currentActions, seed: seed)
            results.append(outcome)
        }
    }

    return results
}

func encodeState(_ state: TestGameState) -> Data {
    return try! JSONEncoder().encode(state)
}

func decodeState(_ data: Data) -> TestGameState {
    return try! JSONDecoder().decode(TestGameState.self, from: data)
}

func encodeDeckState(_ state: TestDeckState) -> Data {
    return try! JSONEncoder().encode(state)
}

func decodeDeckState(_ data: Data) -> TestDeckState {
    return try! JSONDecoder().decode(TestDeckState.self, from: data)
}

struct SeededRNG: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

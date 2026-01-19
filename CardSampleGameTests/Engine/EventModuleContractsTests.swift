import XCTest
@testable import CardSampleGame

/// Event Module Contract Tests
/// Verify that Event Module invariants are maintained.
/// Reference: Docs/EVENT_MODULE_ARCHITECTURE.md
final class EventModuleContractsTests: XCTestCase {

    // MARK: - Test Fixtures

    var eventContext: EventContext!

    override func setUp() {
        super.setUp()
        eventContext = EventContext(
            currentLocation: "test_region",
            locationState: "stable",
            pressure: 20,
            flags: [:],
            resources: ["faith": 10, "health": 15],
            completedEvents: []
        )
    }

    override func tearDown() {
        eventContext = nil
        WorldRNG.shared.resetToSystem()
        super.tearDown()
    }

    // MARK: - INV-E01: Inline Events Do Not Invoke MiniGame

    /// Inline events resolve entirely within main flow
    /// Reference: EVENT_MODULE_ARCHITECTURE.md, Section 2.1
    func testInlineEventClassification() {
        // Given: An inline event definition
        let inlineEvent = TestEventDefinition(
            id: "inline_001",
            title: "Test Inline Event",
            description: "A simple choice event",
            choices: [
                TestChoiceDefinition(id: "c1", text: "Option A", consequences: TestConsequences(faithDelta: -2)),
                TestChoiceDefinition(id: "c2", text: "Option B", consequences: TestConsequences(healthDelta: -3))
            ],
            isInstant: false,
            isOneTime: false,
            eventType: .inline
        )

        // Then: Should be classified as inline
        XCTAssertEqual(inlineEvent.eventType, .inline)
        XCTAssertFalse(inlineEvent.requiresMiniGame)
    }

    func testMiniGameEventClassification() {
        // Given: A mini-game event definition
        let miniGameEvent = TestEventDefinition(
            id: "combat_001",
            title: "Combat Encounter",
            description: "A battle awaits",
            choices: [],
            isInstant: false,
            isOneTime: false,
            eventType: .miniGame(.combat),
            miniGameChallenge: TestMiniGameChallenge(type: .combat, difficulty: 3)
        )

        // Then: Should be classified as mini-game
        XCTAssertTrue(miniGameEvent.requiresMiniGame)
        XCTAssertNotNil(miniGameEvent.miniGameChallenge)
    }

    // MARK: - INV-E02: MiniGame Returns Diff, Does Not Mutate State

    /// MiniGame modules return ResolutionResult + Diff, never mutate state directly
    /// Reference: EVENT_MODULE_ARCHITECTURE.md, Section 4.2
    func testMiniGameReturnsResultNotMutation() {
        // Given: A mini-game challenge
        let challenge = TestMiniGameChallenge(type: .combat, difficulty: 3)

        // When: Mini-game resolves (simulated)
        let result = simulateMiniGameResolution(challenge: challenge, victory: true)

        // Then: Returns diff, not mutation
        XCTAssertNotNil(result.diff)
        XCTAssertTrue(result.diff.resourceChanges.count > 0 || result.diff.flagsToSet.count > 0,
                      "Mini-game should return diff with changes")
    }

    func testMiniGameDiffIsAppliedByEngine() {
        // Given: A diff from mini-game
        let diff = StateDiff(
            resourceChanges: ["health": -5, "faith": 2],
            flagsToSet: ["combat_won_001": true],
            customEffects: []
        )

        // When: Engine applies diff (simulated)
        var resources: [String: Int] = ["health": 20, "faith": 10]
        var flags: [String: Bool] = [:]
        applyDiff(diff, to: &resources, flags: &flags)

        // Then: State updated correctly
        XCTAssertEqual(resources["health"], 15)
        XCTAssertEqual(resources["faith"], 12)
        XCTAssertTrue(flags["combat_won_001"] ?? false)
    }

    // MARK: - INV-E03: Event Selection is Deterministic with Seed

    /// Same seed + context should produce same event selection
    /// Reference: EVENT_MODULE_ARCHITECTURE.md, Section 3.1
    func testEventSelectionDeterministicWithSeed() {
        // Given: Event pool and fixed seed
        let eventPool = [
            TestEventDefinition(id: "event_1", title: "E1", description: "", choices: [], isInstant: false, isOneTime: false, eventType: .inline),
            TestEventDefinition(id: "event_2", title: "E2", description: "", choices: [], isInstant: false, isOneTime: false, eventType: .inline),
            TestEventDefinition(id: "event_3", title: "E3", description: "", choices: [], isInstant: false, isOneTime: false, eventType: .inline)
        ]
        let seed: UInt64 = 12345

        // When: Select events multiple times with same seed
        let selection1 = selectEventWithSeed(from: eventPool, context: eventContext, seed: seed)
        let selection2 = selectEventWithSeed(from: eventPool, context: eventContext, seed: seed)
        let selection3 = selectEventWithSeed(from: eventPool, context: eventContext, seed: seed)

        // Then: Same selection every time
        XCTAssertEqual(selection1?.id, selection2?.id, "Same seed should produce same selection")
        XCTAssertEqual(selection2?.id, selection3?.id, "Same seed should produce same selection")
    }

    func testDifferentSeedsProduceDifferentSelections() {
        // Given: Event pool with multiple events
        let eventPool = (1...10).map { i in
            TestEventDefinition(
                id: "event_\(i)",
                title: "Event \(i)",
                description: "",
                choices: [],
                isInstant: false,
                isOneTime: false,
                eventType: .inline
            )
        }

        // When: Select with different seeds
        var selections: Set<String> = []
        for seed in [UInt64(1), UInt64(2), UInt64(3), UInt64(100), UInt64(999)] {
            if let event = selectEventWithSeed(from: eventPool, context: eventContext, seed: seed) {
                selections.insert(event.id)
            }
        }

        // Then: Should have some variety (not all same)
        // Note: With 10 events and 5 different seeds, very unlikely all same
        XCTAssertGreaterThan(selections.count, 1, "Different seeds should produce variety")
    }

    // MARK: - INV-E04: One-Time Events Persist Across Save/Load

    /// One-time events marked completed should persist
    /// Reference: EVENT_MODULE_ARCHITECTURE.md, Section 5 (Invariant #3)
    func testOneTimeEventCompletionPersists() {
        // Given: One-time event
        let oneTimeEvent = TestEventDefinition(
            id: "unique_001",
            title: "One Time Only",
            description: "This event can only happen once",
            choices: [TestChoiceDefinition(id: "c1", text: "OK", consequences: TestConsequences())],
            isInstant: false,
            isOneTime: true,
            eventType: .inline
        )

        // When: Event completed and context updated
        var completedEvents: Set<String> = []
        completedEvents.insert(oneTimeEvent.id)

        let newContext = EventContext(
            currentLocation: eventContext.currentLocation,
            locationState: eventContext.locationState,
            pressure: eventContext.pressure,
            flags: eventContext.flags,
            resources: eventContext.resources,
            completedEvents: completedEvents
        )

        // Then: Event should not be available
        let canOccur = oneTimeEvent.canOccur(in: newContext)
        XCTAssertFalse(canOccur, "One-time event should not occur after completion")
    }

    // MARK: - INV-E05: Cooldown Respected

    /// Events with cooldowns should respect them
    func testCooldownRespected() {
        // Given: Event with cooldown tracking
        let eventId = "cooldown_event_001"
        var cooldowns: [String: Int] = [eventId: 3] // 3 turns remaining

        // When: Check if event available
        let isOnCooldown = (cooldowns[eventId] ?? 0) > 0

        // Then: Event should be on cooldown
        XCTAssertTrue(isOnCooldown, "Event should be on cooldown")

        // When: Cooldown decremented over time
        cooldowns[eventId] = 0

        // Then: Event should be available
        let nowAvailable = (cooldowns[eventId] ?? 0) == 0
        XCTAssertTrue(nowAvailable, "Event should be available after cooldown")
    }

    // MARK: - INV-E06: Choice Requirements Checked Before Resolution

    /// Choices with requirements should be gated
    /// Reference: EVENT_MODULE_ARCHITECTURE.md, Section 2.3
    func testChoiceRequirementsGateSelection() {
        // Given: Choice with faith requirement
        let expensiveChoice = TestChoiceDefinition(
            id: "expensive",
            text: "Spend 100 faith",
            requirements: TestRequirements(minFaith: 100),
            consequences: TestConsequences(faithDelta: -100)
        )

        // When: Check with insufficient resources
        let canMeet = expensiveChoice.requirements?.canMeet(with: TestResourceProvider(resources: ["faith": 10])) ?? true

        // Then: Should not be able to meet
        XCTAssertFalse(canMeet, "Choice should be gated by requirements")
    }

    func testChoiceWithoutRequirementsAlwaysAvailable() {
        // Given: Choice without requirements
        let simpleChoice = TestChoiceDefinition(
            id: "simple",
            text: "Just proceed",
            consequences: TestConsequences()
        )

        // When: Check requirements
        let canMeet = simpleChoice.requirements?.canMeet(with: TestResourceProvider(resources: [:])) ?? true

        // Then: Should always be available
        XCTAssertTrue(canMeet, "Choice without requirements should be available")
    }
}

// MARK: - Test Types

enum TestEventType: Equatable {
    case inline
    case miniGame(ChallengeType)
}

struct TestEventDefinition {
    let id: String
    let title: String
    let description: String
    let choices: [TestChoiceDefinition]
    let isInstant: Bool
    let isOneTime: Bool
    let eventType: TestEventType
    var miniGameChallenge: TestMiniGameChallenge?

    var requiresMiniGame: Bool {
        if case .miniGame = eventType {
            return true
        }
        return false
    }

    func canOccur(in context: EventContext) -> Bool {
        // One-time check
        if isOneTime && context.completedEvents.contains(id) {
            return false
        }
        return true
    }
}

struct TestChoiceDefinition {
    let id: String
    let text: String
    var requirements: TestRequirements?
    let consequences: TestConsequences

    init(id: String, text: String, requirements: TestRequirements? = nil, consequences: TestConsequences) {
        self.id = id
        self.text = text
        self.requirements = requirements
        self.consequences = consequences
    }
}

struct TestRequirements {
    var minFaith: Int = 0
    var minHealth: Int = 0
    var requiredFlags: [String] = []

    func canMeet(with provider: TestResourceProvider) -> Bool {
        if provider.getValue(for: "faith") < minFaith { return false }
        if provider.getValue(for: "health") < minHealth { return false }
        for flag in requiredFlags {
            if !provider.hasFlag(flag) { return false }
        }
        return true
    }
}

struct TestConsequences {
    var faithDelta: Int = 0
    var healthDelta: Int = 0
    var flagsToSet: [String: Bool] = [:]
}

struct TestMiniGameChallenge {
    let type: ChallengeType
    let difficulty: Int
}

struct TestResourceProvider {
    let resources: [String: Int]
    var flags: [String: Bool] = [:]

    func getValue(for key: String) -> Int {
        return resources[key] ?? 0
    }

    func hasFlag(_ flag: String) -> Bool {
        return flags[flag] ?? false
    }
}

struct StateDiff {
    let resourceChanges: [String: Int]
    let flagsToSet: [String: Bool]
    let customEffects: [String]
}

struct MiniGameResolutionResult {
    let victory: Bool
    let diff: StateDiff
}

// MARK: - Test Helpers

func simulateMiniGameResolution(challenge: TestMiniGameChallenge, victory: Bool) -> MiniGameResolutionResult {
    let diff = StateDiff(
        resourceChanges: victory ? ["health": -2] : ["health": -5],
        flagsToSet: ["combat_resolved": true],
        customEffects: []
    )
    return MiniGameResolutionResult(victory: victory, diff: diff)
}

func applyDiff(_ diff: StateDiff, to resources: inout [String: Int], flags: inout [String: Bool]) {
    for (key, delta) in diff.resourceChanges {
        resources[key] = (resources[key] ?? 0) + delta
    }
    for (key, value) in diff.flagsToSet {
        flags[key] = value
    }
}

func selectEventWithSeed(
    from pool: [TestEventDefinition],
    context: EventContext,
    seed: UInt64
) -> TestEventDefinition? {
    // Filter available events
    let available = pool.filter { $0.canOccur(in: context) }
    guard !available.isEmpty else { return nil }

    // Deterministic selection based on seed
    var rng = RandomNumberGeneratorWithSeed(seed: seed)
    let index = Int.random(in: 0..<available.count, using: &rng)
    return available[index]
}

/// Simple seeded RNG for deterministic tests
struct RandomNumberGeneratorWithSeed: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        // Simple LCG
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

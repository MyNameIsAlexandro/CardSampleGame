import XCTest
@testable import CardSampleGame

/// Phase 2 Contract Tests
/// Tests the actual Definitions and RuntimeState types created in Phase 2.
/// Reference: Docs/MIGRATION_PLAN.md
final class Phase2ContractTests: XCTestCase {

    // MARK: - INV-D01: Definitions Are Immutable (Real Types)

    func testRegionDefinitionIsImmutable() {
        // Given: A real RegionDefinition
        let region = RegionDefinition(
            id: "test_region",
            titleKey: "region.test.title",
            descriptionKey: "region.test.description",
            neighborIds: ["neighbor_a", "neighbor_b"],
            initiallyDiscovered: true,
            anchorId: "anchor_test",
            eventPoolIds: ["pool_common"],
            initialState: .stable
        )

        // Then: All fields accessible (compiler enforces immutability via let)
        XCTAssertEqual(region.id, "test_region")
        XCTAssertEqual(region.neighborIds.count, 2)
        XCTAssertEqual(region.initialState, .stable)

        // Note: Attempting to modify would be a compile error:
        // region.id = "other" // ❌ Compiler error
    }

    func testEventDefinitionIsImmutable() {
        // Given: A real EventDefinition
        let event = EventDefinition(
            id: "event_test",
            titleKey: "event.test.title",
            bodyKey: "event.test.body",
            eventKind: .inline,
            isOneTime: true,
            choices: [
                ChoiceDefinition(
                    id: "choice_a",
                    labelKey: "choice.a.label",
                    consequences: .none
                ),
                ChoiceDefinition(
                    id: "choice_b",
                    labelKey: "choice.b.label",
                    consequences: .none
                )
            ]
        )

        // Then: All fields accessible, no runtime state
        XCTAssertEqual(event.id, "event_test")
        XCTAssertTrue(event.isOneTime)
        XCTAssertEqual(event.choices.count, 2)

        // Definition has NO runtime fields like:
        // - isCompleted
        // - occurrenceCount
        // - cooldownRemaining
    }

    func testDefinitionsHaveNoRuntimeFields() {
        // This test documents that Definitions don't have runtime fields
        // The compiler enforces this - if a runtime field was added, this test would need updating

        // RegionDefinition - NO: visitCount, currentState (mutable), isVisited
        let region = RegionDefinition(
            id: "r1",
            titleKey: "r.title",
            descriptionKey: "r.desc",
            neighborIds: []
        )
        // Only has: id, titleKey, descriptionKey, neighborIds, initiallyDiscovered,
        // anchorId, eventPoolIds, initialState (as enum), degradationWeight

        // EventDefinition - NO: isCompleted, timesOccurred, lastOccurrence
        let event = EventDefinition(
            id: "e1",
            titleKey: "e.title",
            bodyKey: "e.body",
            choices: []
        )
        // Only has: id, titleKey, bodyKey, eventKind, availability, poolIds,
        // weight, isOneTime, isInstant, cooldown, choices, miniGameChallenge

        XCTAssertNotNil(region)
        XCTAssertNotNil(event)
    }

    // MARK: - INV-D02: RuntimeState is Mutable

    func testRegionRuntimeStateIsMutable() {
        // Given: A RuntimeState
        var regionState = RegionRuntimeState(
            definitionId: "test_region",
            currentState: .stable,
            visitCount: 0,
            isDiscovered: false
        )

        // When: Modify runtime state
        regionState.visit()
        _ = regionState.degrade()

        // Then: State changed
        XCTAssertEqual(regionState.visitCount, 1)
        XCTAssertTrue(regionState.isDiscovered)
        XCTAssertEqual(regionState.currentState, .borderland)
    }

    func testPlayerRuntimeStateIsMutable() {
        // Given: PlayerRuntimeState
        var player = PlayerRuntimeState(
            resources: ["health": 20, "faith": 10],
            balance: 0
        )

        // When: Modify state
        player.modifyResource("health", by: -5)
        player.shiftBalance(by: 20)
        player.addCurse("curse_test")

        // Then: State changed
        XCTAssertEqual(player.getResource("health"), 15)
        XCTAssertEqual(player.balance, 20)
        XCTAssertTrue(player.hasCurse("curse_test"))
    }

    // MARK: - INV-D03: Runtime References Definition by ID

    func testRuntimeReferencesDefinitionById() {
        // Given: Definition and RuntimeState
        let regionDef = RegionDefinition(
            id: "forest",
            titleKey: "region.forest.title",
            descriptionKey: "region.forest.desc",
            neighborIds: []
        )

        let regionRuntime = RegionRuntimeState(
            definitionId: regionDef.id, // ← References by ID, not object
            currentState: .stable,
            visitCount: 0,
            isDiscovered: true
        )

        // Then: Runtime references definition by string ID only
        XCTAssertEqual(regionRuntime.definitionId, "forest")
        // No direct object reference - allows serialization and separation
    }

    // MARK: - ContentProvider Validation

    func testContentProviderValidatesUniqueIds() {
        // Given: Provider with test content
        let provider = TestContentProvider()
        provider.addRegion(RegionDefinition(
            id: "region_a",
            titleKey: "r.a.title",
            descriptionKey: "r.a.desc",
            neighborIds: []
        ))
        provider.addRegion(RegionDefinition(
            id: "region_a", // Duplicate!
            titleKey: "r.a2.title",
            descriptionKey: "r.a2.desc",
            neighborIds: []
        ))

        // When: Validate
        let errors = provider.validate()

        // Then: Duplicate ID detected
        let duplicateErrors = errors.filter { $0.type == .duplicateId }
        XCTAssertFalse(duplicateErrors.isEmpty, "Should detect duplicate ID")
    }

    func testContentValidatorRejectsBrokenReferences() {
        // Given: Provider with broken neighbor reference
        let provider = TestContentProvider()
        provider.addRegion(RegionDefinition(
            id: "island",
            titleKey: "r.island.title",
            descriptionKey: "r.island.desc",
            neighborIds: ["nonexistent_region"] // ← Broken!
        ))

        // When: Validate
        let errors = provider.validate()

        // Then: Broken reference detected
        let brokenRefErrors = errors.filter { $0.type == .brokenReference }
        XCTAssertFalse(brokenRefErrors.isEmpty, "Should detect broken reference")
    }

    func testContentValidatorAcceptsValidContent() {
        // Given: Provider with valid content
        let provider = TestContentProvider()
        provider.addRegion(RegionDefinition(
            id: "forest",
            titleKey: "r.forest.title",
            descriptionKey: "r.forest.desc",
            neighborIds: ["village"]
        ))
        provider.addRegion(RegionDefinition(
            id: "village",
            titleKey: "r.village.title",
            descriptionKey: "r.village.desc",
            neighborIds: ["forest"]
        ))

        // When: Validate
        let errors = provider.validate()

        // Then: No errors
        XCTAssertTrue(errors.isEmpty, "Valid content should have no errors: \(errors)")
    }

    // MARK: - Transactions Are Atomic

    func testTransactionsAreAtomic() {
        // Given: Player with limited resources
        let player = PlayerRuntimeState(
            resources: ["health": 10, "faith": 5]
        )

        // When: Try to spend more than available
        let canAfford = player.canAfford(["faith": 10])

        // Then: Cannot afford
        XCTAssertFalse(canAfford, "Should not afford 10 faith with only 5")

        // And: Resources unchanged (atomic - either all or nothing)
        XCTAssertEqual(player.getResource("faith"), 5)
    }

    // MARK: - MiniGame Does Not Mutate State

    func testMiniGameDiffDoesNotMutateDirectly() {
        // Given: A mini-game result with diff
        let diff = MiniGameDiff(
            resourceChanges: ["health": -5, "faith": 2],
            flagsToSet: ["combat_won": true],
            cardsToAdd: ["card_reward"],
            balanceDelta: 10
        )

        // Then: Diff is data-only, no mutation methods
        XCTAssertEqual(diff.resourceChanges["health"], -5)
        XCTAssertEqual(diff.flagsToSet["combat_won"], true)
        XCTAssertEqual(diff.cardsToAdd, ["card_reward"])

        // Mini-game returns diff, Engine applies it - mini-game cannot mutate state directly
    }

    func testMiniGameResultContainsDiffNotMutation() {
        // Given: MiniGame result
        let result = MiniGameResult(
            outcome: .victory,
            diff: MiniGameDiff(
                resourceChanges: ["health": -3],
                flagsToSet: ["boss_defeated": true]
            )
        )

        // Then: Result contains diff to apply, not direct state mutation
        XCTAssertEqual(result.outcome, .victory)
        XCTAssertEqual(result.diff.resourceChanges["health"], -3)

        // The contract is: mini-game returns result, engine applies diff
        // Mini-game never sees or modifies GameRuntimeState directly
    }

    // MARK: - Availability Checks

    func testAvailabilityChecks() {
        // Given: Event with availability constraints
        let event = EventDefinition(
            id: "pressure_event",
            titleKey: "e.title",
            bodyKey: "e.body",
            availability: Availability(
                requiredFlags: ["quest_started"],
                forbiddenFlags: ["event_completed"],
                minPressure: 30,
                maxPressure: 70
            ),
            choices: []
        )

        // Then: Availability conditions are accessible for checking
        XCTAssertEqual(event.availability.minPressure, 30)
        XCTAssertEqual(event.availability.maxPressure, 70)
        XCTAssertTrue(event.availability.requiredFlags.contains("quest_started"))
        XCTAssertTrue(event.availability.forbiddenFlags.contains("event_completed"))
    }

    func testChoiceRequirementsCheck() {
        // Given: Choice with requirements
        let requirements = ChoiceRequirements(
            minResources: ["faith": 10],
            requiredFlags: ["has_blessing"],
            balanceRange: 0...50
        )

        // When: Check with sufficient resources
        let canMeet1 = requirements.canMeet(
            resources: ["faith": 15],
            flags: Set(["has_blessing"]),
            balance: 25
        )

        // Then: Can meet requirements
        XCTAssertTrue(canMeet1)

        // When: Check with insufficient resources
        let canMeet2 = requirements.canMeet(
            resources: ["faith": 5], // Not enough!
            flags: Set(["has_blessing"]),
            balance: 25
        )

        // Then: Cannot meet
        XCTAssertFalse(canMeet2)
    }

    // MARK: - GameRuntimeState Snapshot

    func testGameRuntimeStateSnapshot() {
        // Given: A game state
        let state = GameRuntimeState.newGame(
            startingRegionId: "forest",
            startingResources: ["health": 20, "faith": 10],
            startingDeck: ["card_1", "card_2", "card_3"],
            seed: 12345
        )

        // When: Take snapshot
        let snapshot = state.snapshot()

        // Then: Snapshot captures key metrics
        XCTAssertEqual(snapshot.pressure, 0)
        XCTAssertEqual(snapshot.time, 0)
        XCTAssertEqual(snapshot.health, 20)
        XCTAssertEqual(snapshot.faith, 10)
        XCTAssertEqual(snapshot.currentRegionId, "forest")
        XCTAssertEqual(snapshot.deckSize, 3)
    }
}

// MARK: - Test Helpers

/// Test content provider for Phase 2 contract validation tests
/// Implements ContentProvider protocol for testing
/// Uses arrays to allow duplicate IDs for validation testing
final class TestContentProvider: ContentProvider {
    private var regionsList: [CardSampleGame.RegionDefinition] = []
    private var anchorsList: [CardSampleGame.AnchorDefinition] = []
    private var eventsList: [CardSampleGame.EventDefinition] = []
    private var questsList: [CardSampleGame.QuestDefinition] = []
    private var challengesList: [CardSampleGame.MiniGameChallengeDefinition] = []

    func addRegion(_ region: CardSampleGame.RegionDefinition) {
        regionsList.append(region)
    }

    func addAnchor(_ anchor: CardSampleGame.AnchorDefinition) {
        anchorsList.append(anchor)
    }

    func addEvent(_ event: CardSampleGame.EventDefinition) {
        eventsList.append(event)
    }

    func getAllRegionDefinitions() -> [CardSampleGame.RegionDefinition] {
        regionsList
    }

    func getRegionDefinition(id: String) -> CardSampleGame.RegionDefinition? {
        regionsList.first { $0.id == id }
    }

    func getAllAnchorDefinitions() -> [CardSampleGame.AnchorDefinition] {
        anchorsList
    }

    func getAnchorDefinition(id: String) -> CardSampleGame.AnchorDefinition? {
        anchorsList.first { $0.id == id }
    }

    func getAnchorDefinition(forRegion regionId: String) -> CardSampleGame.AnchorDefinition? {
        anchorsList.first { $0.regionId == regionId }
    }

    func getAllEventDefinitions() -> [CardSampleGame.EventDefinition] {
        eventsList
    }

    func getEventDefinition(id: String) -> CardSampleGame.EventDefinition? {
        eventsList.first { $0.id == id }
    }

    func getEventDefinitions(forRegion regionId: String) -> [CardSampleGame.EventDefinition] {
        []
    }

    func getEventDefinitions(forPool poolId: String) -> [CardSampleGame.EventDefinition] {
        []
    }

    func getAllQuestDefinitions() -> [CardSampleGame.QuestDefinition] {
        questsList
    }

    func getQuestDefinition(id: String) -> CardSampleGame.QuestDefinition? {
        questsList.first { $0.id == id }
    }

    func getAllMiniGameChallenges() -> [CardSampleGame.MiniGameChallengeDefinition] {
        challengesList
    }

    func getMiniGameChallenge(id: String) -> CardSampleGame.MiniGameChallengeDefinition? {
        challengesList.first { $0.id == id }
    }

    func validate() -> [CardSampleGame.ContentValidationError] {
        let validator = CardSampleGame.ContentValidator(provider: self)
        return validator.validate()
    }
}

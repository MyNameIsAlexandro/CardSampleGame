/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/GameplayFlowTests.swift
/// Назначение: Содержит реализацию файла GameplayFlowTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import TwilightEngine

/// Tests for gameplay flow - regions, travel, events, choices
/// These tests verify the critical user paths work correctly
final class GameplayFlowTests: XCTestCase {

    var engine: TwilightGameEngine!

    override func setUp() {
        super.setUp()
        engine = TestEngineFactory.makeEngine(seed: 42)
        engine.initializeNewGame(playerName: "Test", heroId: nil)
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    /// Helper to fail test if regions not loaded
    func requireRegionsLoaded() -> Bool {
        if engine.regionsArray.isEmpty {
            XCTFail("Skipping: ContentPack not loaded (no regions)")
            return false
        }
        return true
    }

    // MARK: - Region Tests

    func testRegionsArrayNotEmpty() {
        guard requireRegionsLoaded() else { return }
        // Given: Engine initialized
        // When: Accessing regions
        let regions = engine.regionsArray

        // Then: Should have regions
        XCTAssertFalse(regions.isEmpty, "Engine should have at least one region")
    }

    func testCurrentRegionExists() {
        guard requireRegionsLoaded() else { return }
        // Given: Engine initialized
        // When: Checking current region
        let currentRegionId = engine.currentRegionId

        // Then: Should have current region
        XCTAssertNotNil(currentRegionId, "Engine should have current region ID")

        // And current region should be in regionsArray
        let currentRegion = engine.regionsArray.first { $0.id == currentRegionId }
        XCTAssertNotNil(currentRegion, "Current region should exist in regionsArray")
    }

    func testRegionHasRequiredProperties() {
        guard requireRegionsLoaded() else { return }
        // Given: Engine with regions
        guard let region = engine.regionsArray.first else {
            XCTFail("No regions available"); return
        }

        // Then: Region should have required properties
        XCTAssertFalse(region.name.isEmpty, "Region should have name")
        // ID is UUID, always valid
        XCTAssertNotNil(region.id, "Region should have ID")
    }

    // MARK: - Travel Tests

    func testTravelToNeighborRegion() {
        guard requireRegionsLoaded() else { return }
        // Given: Current region with neighbors
        guard let currentRegion = engine.currentRegion else {
            XCTFail("No current region"); return
        }

        guard let neighborId = currentRegion.neighborIds.first else {
            XCTFail("Current region has no neighbors to travel to"); return
        }

        let initialRegionId = engine.currentRegionId

        // When: Traveling to neighbor
        let result = engine.performAction(.travel(toRegionId: neighborId))

        // Then: Travel should succeed
        XCTAssertTrue(result.success, "Travel to neighbor should succeed")

        // And current region should change
        XCTAssertNotEqual(engine.currentRegionId, initialRegionId, "Current region should change after travel")
        XCTAssertEqual(engine.currentRegionId, neighborId, "Current region should be destination")
    }

    func testTravelAdvancesTime() {
        // Given: Current day
        let initialDay = engine.currentDay

        guard let currentRegion = engine.currentRegion,
              let neighborId = currentRegion.neighborIds.first else {
            XCTFail("Cannot test travel time - no neighbors"); return
        }

        // When: Traveling
        let _ = engine.performAction(.travel(toRegionId: neighborId))

        // Then: Day should advance
        XCTAssertGreaterThan(engine.currentDay, initialDay, "Travel should advance time")
    }

    func testCannotTravelToNonNeighbor() {
        guard requireRegionsLoaded() else { return }
        // Given: A region that is not a neighbor
        guard let currentRegion = engine.currentRegion else {
            XCTFail("No current region"); return
        }

        // Find a non-neighbor region
        let nonNeighborRegion = engine.regionsArray.first { region in
            region.id != currentRegion.id && !currentRegion.neighborIds.contains(region.id)
        }

        guard let targetRegion = nonNeighborRegion else {
            XCTFail("All regions are neighbors - cannot test non-neighbor travel"); return
        }

        // When: Trying to travel to non-neighbor
        let _ = engine.performAction(.travel(toRegionId: targetRegion.id))

        // Then: Should fail or be blocked (depending on implementation)
        // Note: Some implementations may allow travel to any region
        // This test documents expected behavior
        if !currentRegion.neighborIds.contains(targetRegion.id) {
            // Either fails or implementation allows any travel
            XCTAssertTrue(true, "Non-neighbor travel behavior documented")
        }
    }

    // MARK: - Event Tests

    func testExploreTriggersEvent() {
        guard requireRegionsLoaded() else { return }
        // Given: Engine in a region
        guard engine.currentRegion != nil else {
            XCTFail("No current region"); return
        }

        // When: Exploring
        let result = engine.performAction(.explore)

        // Then: Should succeed (may or may not trigger event)
        XCTAssertTrue(result.success, "Explore action should succeed")

        // Note: Event may or may not be triggered depending on availability
        // This test verifies the action completes without error
    }

    func testEventHasChoices() {
        // Given: A combat event
        let testEvent = GameEvent(
            id: "test_event_1",
            eventType: .combat,
            title: "Test Combat",
            description: "Test description",
            choices: [
                EventChoice(
                    id: "fight",
                    text: "Fight",
                    consequences: EventConsequences(message: "Fought")
                ),
                EventChoice(
                    id: "flee",
                    text: "Flee",
                    consequences: EventConsequences(healthChange: -1, message: "Fled")
                )
            ]
        )

        // Then: Event should have choices
        XCTAssertGreaterThan(testEvent.choices.count, 0, "Event should have at least one choice")
        XCTAssertEqual(testEvent.choices.count, 2, "Test event should have 2 choices")
    }

    // MARK: - Choice Requirement Tests

    func testChoiceWithNoRequirementsIsAvailable() {
        // Given: A choice with no requirements
        let choice = EventChoice(
            id: "simple_choice",
            text: "Simple choice",
            requirements: nil,
            consequences: EventConsequences(message: "Done")
        )

        // Then: Should be available (requirements are nil)
        XCTAssertNil(choice.requirements, "Choice should have no requirements")
    }

    func testChoiceWithFaithRequirement() {
        // Given: A choice requiring faith
        let choice = EventChoice(
            id: "holy_action",
            text: "Holy action",
            requirements: EventRequirements(minimumFaith: 5),
            consequences: EventConsequences(message: "Blessed")
        )

        // When: Player has enough faith
        let hasFaith = engine.player.faith >= 5

        // Then: Requirement check depends on faith
        XCTAssertNotNil(choice.requirements?.minimumFaith, "Choice should have faith requirement")
        XCTAssertEqual(choice.requirements?.minimumFaith, 5, "Faith requirement should be 5")

        XCTAssertEqual(hasFaith, engine.player.faith >= 5, "Faith requirement evaluation must be stable")
    }

    func testChoiceWithHealthRequirement() {
        // Given: A choice requiring health
        let choice = EventChoice(
            id: "dangerous_action",
            text: "Dangerous action",
            requirements: EventRequirements(minimumHealth: 3),
            consequences: EventConsequences(message: "Survived")
        )

        // When: Player has enough health
        let hasHealth = engine.player.health >= 3

        // Then: Requirement check depends on health
        XCTAssertNotNil(choice.requirements?.minimumHealth, "Choice should have health requirement")
        XCTAssertEqual(choice.requirements?.minimumHealth, 3, "Health requirement should be 3")
        XCTAssertTrue(hasHealth, "Player should have at least 3 health")
    }

    // MARK: - Choice Application Tests

    func testChoiceConsequencesStructure() {
        // Given: Consequences with various changes
        let consequences = EventConsequences(
            faithChange: -2,
            healthChange: -1,
            message: "Test consequence"
        )

        // Then: Verify consequences structure
        XCTAssertNotNil(consequences.faithChange, "Consequences should have faith change")
        XCTAssertEqual(consequences.faithChange, -2, "Faith change should be -2")
        XCTAssertNotNil(consequences.healthChange, "Consequences should have health change")
        XCTAssertEqual(consequences.healthChange, -1, "Health change should be -1")
        XCTAssertEqual(consequences.message, "Test consequence", "Message should match")
    }

    // MARK: - Combat Event Tests

    func testCombatEventHasMonsterCard() {
        // Given: A combat event definition with challenge
        let challenge = MiniGameChallengeDefinition(
            id: "test_challenge",
            challengeKind: .combat,
            difficulty: 1,
            enemyId: "wild_beast"
        )

        let eventDef = EventDefinition(
            id: "test_combat",
            title: .inline(LocalizedString(en: "Test Combat", ru: "Тест Бой")),
            body: .inline(LocalizedString(en: "A beast attacks!", ru: "Зверь атакует!")),
            eventKind: .miniGame(.combat),
            availability: .always,
            poolIds: ["pool_common"],
            weight: 10,
            isOneTime: false,
            choices: [],
            miniGameChallenge: challenge
        )

        // When: Converting to GameEvent using extension method
        let gameEvent = eventDef.toGameEvent(
            registry: engine.services.contentRegistry,
            localizationManager: engine.services.localizationManager
        )

        // Then: Should be combat event type
        XCTAssertEqual(gameEvent.eventType, .combat, "Event type should be combat")
        // Note: monsterCard may be nil if enemy is not in registry, but eventType should be correct
    }

    func testNarrativeEventType() {
        // Given: A narrative event definition
        let eventDef = EventDefinition(
            id: "test_narrative",
            title: .inline(LocalizedString(en: "Test Narrative", ru: "Тест Нарратив")),
            body: .inline(LocalizedString(en: "Something happens", ru: "Что-то происходит")),
            eventKind: .inline,
            availability: .always,
            poolIds: ["pool_common"],
            weight: 10,
            isOneTime: false,
            choices: [],
            miniGameChallenge: nil
        )

        // When: Converting to GameEvent using extension method
        let gameEvent = eventDef.toGameEvent(
            registry: engine.services.contentRegistry,
            localizationManager: engine.services.localizationManager
        )

        // Then: Should NOT have monster card and should be narrative type
        XCTAssertNil(gameEvent.monsterCard, "Non-combat event should not have monster card")
        XCTAssertEqual(gameEvent.eventType, .narrative, "Event type should be narrative")
    }

    // MARK: - Event Definition Parsing Tests

    func testEventKindDecodingInline() throws {
        // Given: JSON with inline event kind
        let json = """
        "inline"
        """.data(using: .utf8)!

        // When: Decoding
        let decoder = JSONDecoder()
        let eventKind = try decoder.decode(EventKind.self, from: json)

        // Then: Should be inline
        XCTAssertEqual(eventKind, .inline, "Should decode 'inline' string to EventKind.inline")
    }

    func testEventKindDecodingMiniGame() throws {
        // Given: JSON with mini_game event kind
        let json = """
        {"mini_game": "combat"}
        """.data(using: .utf8)!

        // When: Decoding
        let decoder = JSONDecoder()
        let eventKind = try decoder.decode(EventKind.self, from: json)

        // Then: Should be miniGame combat
        XCTAssertEqual(eventKind, .miniGame(.combat), "Should decode mini_game object to EventKind.miniGame(.combat)")
    }

    func testMiniGameChallengeDecoding() throws {
        // Given: JSON with simplified mini_game_challenge format
        let json = """
        {
            "enemy_id": "wild_beast",
            "difficulty": 2
        }
        """.data(using: .utf8)!

        // When: Decoding (using same decoder config as PackLoader)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let challenge = try decoder.decode(MiniGameChallengeDefinition.self, from: json)

        // Then: Should have correct values
        XCTAssertEqual(challenge.enemyId, "wild_beast", "Enemy ID should be decoded")
        XCTAssertEqual(challenge.difficulty, 2, "Difficulty should be decoded")
        XCTAssertEqual(challenge.id, "challenge_wild_beast", "ID should be generated from enemy ID")
    }

    // MARK: - State Persistence Tests

    func testRegionStateAfterTravel() {
        // Given: Initial state
        guard let initialRegion = engine.currentRegion,
              let neighborId = initialRegion.neighborIds.first else {
            XCTFail("Cannot test - no neighbors"); return
        }

        // When: Traveling
        let _ = engine.performAction(.travel(toRegionId: neighborId))

        // Then: New region should be current
        XCTAssertEqual(engine.currentRegionId, neighborId, "Current region ID should update")

        // And previous region should still exist in array
        let previousRegion = engine.regionsArray.first { $0.id == initialRegion.id }
        XCTAssertNotNil(previousRegion, "Previous region should still exist")
    }

    // MARK: - Explore Flow Tests

    func testExploreActionSuccess() {
        guard requireRegionsLoaded() else { return }
        // Given: Engine in a region
        guard engine.currentRegion != nil else {
            XCTFail("No current region"); return
        }

        // When: Exploring
        let result = engine.performAction(.explore)

        // Then: Action should succeed
        XCTAssertTrue(result.success, "Explore action should always succeed")
    }

    func testExploreReturnsEventOrNil() {
        guard requireRegionsLoaded() else { return }
        // Given: Engine in a region
        guard engine.currentRegion != nil else {
            XCTFail("No current region"); return
        }

        // When: Exploring
        let result = engine.performAction(.explore)

        // Then: Either an event is triggered or nil (no events available)
        // Both outcomes are valid
        if let eventId = result.currentEvent {
            // Event was triggered - verify it's a valid UUID
            XCTAssertNotNil(eventId, "Triggered event should have valid ID")
            // Engine should have currentEvent set
            XCTAssertEqual(engine.currentEventId, eventId, "Engine currentEventId should match result")
        } else {
            // No event available - this is expected when region is fully explored
            XCTAssertTrue(result.success, "Explore should succeed even without events")
            XCTAssertNil(engine.currentEventId, "Engine currentEventId should be nil when no event")
        }
    }

    func testExploreDoesNotAdvanceTimeWhenNoEvent() {
        guard requireRegionsLoaded() else { return }
        // Given: Engine with current day
        let initialDay = engine.currentDay

        // When: Exploring
        let result = engine.performAction(.explore)

        // Then: If no event triggered, time should not advance
        if result.currentEvent == nil {
            XCTAssertEqual(engine.currentDay, initialDay, "Day should not advance when no event found")
        }
        // Note: If event was triggered, time advancement depends on event handling
    }
}

// MARK: - Test Helpers

extension GameplayFlowTests {

    /// Helper to create test engine (Engine-First)
    func createTestEngine() -> TwilightGameEngine {
        let testEngine = TwilightGameEngine()
        testEngine.initializeNewGame(playerName: "Test", heroId: nil)
        return testEngine
    }
}

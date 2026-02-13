/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/StoryDirectorTests.swift
/// Назначение: Содержит реализацию файла StoryDirectorTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import TwilightEngine

final class StoryDirectorTests: XCTestCase {

    private var director: BaseStoryDirector!
    private var contentRegistry: ContentRegistry!

    override func setUp() {
        super.setUp()
        contentRegistry = ContentRegistry()
        director = BaseStoryDirector(contentRegistry: contentRegistry)
    }

    override func tearDown() {
        director = nil
        contentRegistry = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeContext(
        currentRegionId: String = "region_1",
        regionStates: [String: RegionStateType] = ["region_1": .stable],
        worldTension: Int = 30,
        currentDay: Int = 1,
        playerHealth: Int = 100,
        playerFaith: Int = 50,
        playerBalance: Int = 0,
        activeQuestIds: Set<String> = [],
        completedQuestIds: Set<String> = [],
        questObjectiveStates: [String: Set<String>] = [:],
        worldFlags: [String: Bool] = [:],
        completedEventIds: Set<String> = [],
        visitedRegionIds: Set<String> = ["region_1"],
        campaignId: String = "campaign_test",
        actNumber: Int = 1
    ) -> StoryContext {
        StoryContext(
            currentRegionId: currentRegionId,
            regionStates: regionStates,
            worldTension: worldTension,
            currentDay: currentDay,
            playerHealth: playerHealth,
            playerFaith: playerFaith,
            playerBalance: playerBalance,
            activeQuestIds: activeQuestIds,
            completedQuestIds: completedQuestIds,
            questObjectiveStates: questObjectiveStates,
            worldFlags: worldFlags,
            completedEventIds: completedEventIds,
            visitedRegionIds: visitedRegionIds,
            campaignId: campaignId,
            actNumber: actNumber
        )
    }

    private func makeEvent(
        id: String = "test_event",
        availability: Availability = .always,
        weight: Int = 10,
        isOneTime: Bool = false
    ) -> EventDefinition {
        EventDefinition(
            id: id,
            title: .text("Test Event"),
            body: .text("Test body"),
            availability: availability,
            weight: weight,
            isOneTime: isOneTime
        )
    }

    // MARK: - isEventAvailable: One-Time Events

    func testOneTimeEventAlreadyCompleted_isUnavailable() {
        let event = makeEvent(id: "evt_once", isOneTime: true)
        let context = makeContext(completedEventIds: ["evt_once"])

        XCTAssertFalse(director.isEventAvailable(event, context: context))
    }

    func testOneTimeEventNotCompleted_isAvailable() {
        let event = makeEvent(id: "evt_once", isOneTime: true)
        let context = makeContext(completedEventIds: [])

        XCTAssertTrue(director.isEventAvailable(event, context: context))
    }

    func testRepeatableEventAlreadyCompleted_isStillAvailable() {
        let event = makeEvent(id: "evt_repeat", isOneTime: false)
        let context = makeContext(completedEventIds: ["evt_repeat"])

        XCTAssertTrue(director.isEventAvailable(event, context: context))
    }

    // MARK: - isEventAvailable: Required Flags

    func testRequiredFlagMissing_isUnavailable() {
        let avail = Availability(requiredFlags: ["has_key"])
        let event = makeEvent(availability: avail)
        let context = makeContext(worldFlags: [:])

        XCTAssertFalse(director.isEventAvailable(event, context: context))
    }

    func testRequiredFlagPresent_isAvailable() {
        let avail = Availability(requiredFlags: ["has_key"])
        let event = makeEvent(availability: avail)
        let context = makeContext(worldFlags: ["has_key": true])

        XCTAssertTrue(director.isEventAvailable(event, context: context))
    }

    func testRequiredFlagSetToFalse_isUnavailable() {
        let avail = Availability(requiredFlags: ["has_key"])
        let event = makeEvent(availability: avail)
        let context = makeContext(worldFlags: ["has_key": false])

        XCTAssertFalse(director.isEventAvailable(event, context: context))
    }

    // MARK: - isEventAvailable: Forbidden Flags

    func testForbiddenFlagPresent_isUnavailable() {
        let avail = Availability(forbiddenFlags: ["cursed"])
        let event = makeEvent(availability: avail)
        let context = makeContext(worldFlags: ["cursed": true])

        XCTAssertFalse(director.isEventAvailable(event, context: context))
    }

    func testForbiddenFlagAbsent_isAvailable() {
        let avail = Availability(forbiddenFlags: ["cursed"])
        let event = makeEvent(availability: avail)
        let context = makeContext(worldFlags: [:])

        XCTAssertTrue(director.isEventAvailable(event, context: context))
    }

    // MARK: - isEventAvailable: Tension Range

    func testTensionBelowMinPressure_isUnavailable() {
        let avail = Availability(minPressure: 50)
        let event = makeEvent(availability: avail)
        let context = makeContext(worldTension: 30)

        XCTAssertFalse(director.isEventAvailable(event, context: context))
    }

    func testTensionAboveMaxPressure_isUnavailable() {
        let avail = Availability(maxPressure: 50)
        let event = makeEvent(availability: avail)
        let context = makeContext(worldTension: 60)

        XCTAssertFalse(director.isEventAvailable(event, context: context))
    }

    func testTensionWithinRange_isAvailable() {
        let avail = Availability(minPressure: 20, maxPressure: 80)
        let event = makeEvent(availability: avail)
        let context = makeContext(worldTension: 50)

        XCTAssertTrue(director.isEventAvailable(event, context: context))
    }

    // MARK: - isEventAvailable: Region State

    func testRegionStateMismatch_isUnavailable() {
        let avail = Availability(regionStates: ["breach"])
        let event = makeEvent(availability: avail)
        let context = makeContext(
            currentRegionId: "region_1",
            regionStates: ["region_1": .stable]
        )

        XCTAssertFalse(director.isEventAvailable(event, context: context))
    }

    func testRegionStateMatch_isAvailable() {
        let avail = Availability(regionStates: ["breach"])
        let event = makeEvent(availability: avail)
        let context = makeContext(
            currentRegionId: "region_1",
            regionStates: ["region_1": .breach]
        )

        XCTAssertTrue(director.isEventAvailable(event, context: context))
    }

    // MARK: - isEventAvailable: All Conditions Met

    func testAllConditionsMet_isAvailable() {
        let avail = Availability(
            requiredFlags: ["flag_a"],
            forbiddenFlags: ["flag_b"],
            minPressure: 10,
            maxPressure: 90,
            regionStates: ["borderland"]
        )
        let event = makeEvent(availability: avail)
        let context = makeContext(
            currentRegionId: "region_1",
            regionStates: ["region_1": .borderland],
            worldTension: 50,
            worldFlags: ["flag_a": true]
        )

        XCTAssertTrue(director.isEventAvailable(event, context: context))
    }

    // MARK: - selectEvent

    func testSelectEvent_returnsNilWhenNoEventsAvailable() {
        let context = makeContext(
            currentRegionId: "nonexistent_region_xyz",
            worldFlags: ["impossible_flag_xyz_123": true]
        )
        var rng = WorldRNG(seed: 42 as UInt64)

        let result = director.selectEvent(forRegion: "nonexistent_region_xyz", context: context, using: &rng)

        XCTAssertNil(result)
    }

    // MARK: - checkVictoryConditions

    func testVictory_whenActCompletedFlagIsSet() {
        let context = makeContext(
            worldFlags: ["act1_completed": true],
            actNumber: 1
        )

        let check = director.checkVictoryConditions(context: context)

        XCTAssertTrue(check.isVictory)
        XCTAssertEqual(check.endingId, "act1_standard")
    }

    func testVictory_act2CompletedFlag() {
        let context = makeContext(
            worldFlags: ["act2_completed": true],
            actNumber: 2
        )

        let check = director.checkVictoryConditions(context: context)

        XCTAssertTrue(check.isVictory)
        XCTAssertEqual(check.endingId, "act2_standard")
    }

    func testNoVictory_whenFlagNotSet() {
        let context = makeContext(worldFlags: [:], actNumber: 1)

        let check = director.checkVictoryConditions(context: context)

        XCTAssertFalse(check.isVictory)
        XCTAssertNil(check.endingId)
    }

    func testNoVictory_whenWrongActFlagSet() {
        let context = makeContext(
            worldFlags: ["act2_completed": true],
            actNumber: 1
        )

        let check = director.checkVictoryConditions(context: context)

        XCTAssertFalse(check.isVictory)
    }

    // MARK: - checkDefeatConditions

    func testDefeat_healthZero() {
        let context = makeContext(playerHealth: 0)

        let check = director.checkDefeatConditions(context: context)

        XCTAssertTrue(check.isDefeat)
        if case .healthZero = check.reason {} else {
            XCTFail("Expected .healthZero")
        }
    }

    func testDefeat_healthNegative() {
        let context = makeContext(playerHealth: -5)

        let check = director.checkDefeatConditions(context: context)

        XCTAssertTrue(check.isDefeat)
        if case .healthZero = check.reason {} else {
            XCTFail("Expected .healthZero")
        }
    }

    func testDefeat_tensionMax() {
        let context = makeContext(worldTension: 100, playerHealth: 50)

        let check = director.checkDefeatConditions(context: context)

        XCTAssertTrue(check.isDefeat)
        if case .tensionMax = check.reason {} else {
            XCTFail("Expected .tensionMax, got \(String(describing: check.reason))")
        }
    }

    func testDefeat_tensionAboveMax() {
        let context = makeContext(worldTension: 120, playerHealth: 50)

        let check = director.checkDefeatConditions(context: context)

        XCTAssertTrue(check.isDefeat)
        if case .tensionMax = check.reason {} else {
            XCTFail("Expected .tensionMax, got \(String(describing: check.reason))")
        }
    }

    func testNoDefeat_normalState() {
        let context = makeContext(worldTension: 50, playerHealth: 50)

        let check = director.checkDefeatConditions(context: context)

        XCTAssertFalse(check.isDefeat)
        XCTAssertNil(check.reason)
    }

    func testDefeat_healthTakesPriorityOverTension() {
        let context = makeContext(worldTension: 100, playerHealth: 0)

        let check = director.checkDefeatConditions(context: context)

        XCTAssertTrue(check.isDefeat)
        if case .healthZero = check.reason {} else {
            XCTFail("Health check should take priority over tension check")
        }
    }

    // MARK: - getActiveQuests

    func testGetActiveQuests_returnsEmptyForUnknownIds() {
        let context = makeContext(activeQuestIds: ["nonexistent_quest_xyz"])

        let quests = director.getActiveQuests(context: context)

        // Unknown quest IDs should be filtered out by compactMap
        XCTAssertTrue(quests.isEmpty)
    }

    func testGetActiveQuests_emptyWhenNoActiveIds() {
        let context = makeContext(activeQuestIds: [])

        let quests = director.getActiveQuests(context: context)

        XCTAssertTrue(quests.isEmpty)
    }
}

/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/EventPipelineTests.swift
/// Назначение: Содержит реализацию файла EventPipelineTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import TwilightEngine
import TwilightEngineDevTools

final class EventPipelineTests: XCTestCase {

    var selector: EventSelector!
    var resolver: EventResolver!
    var pipeline: EventPipeline!
    var rng: WorldRNG!

    override func setUp() {
        super.setUp()
        selector = EventSelector()
        resolver = EventResolver()
        pipeline = EventPipeline(selector: selector, resolver: resolver)
        rng = WorldRNG(seed: 42)
    }

    override func tearDown() {
        selector = nil
        resolver = nil
        pipeline = nil
        rng = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    private func createTestEvent(
        id: String = "test_event",
        oneTime: Bool = false,
        completed: Bool = false,
        regionTypes: [RegionType] = [],
        regionStates: [RegionState] = [.stable, .borderland, .breach],
        requiredFlags: [String]? = nil,
        forbiddenFlags: [String]? = nil,
        weight: Int = 10
    ) -> GameEvent {
        return GameEvent(
            id: id,
            eventType: .narrative,
            title: "Test Event",
            description: "A test event",
            regionTypes: regionTypes,
            regionStates: regionStates,
            choices: [
                EventChoice(
                    id: "choice_1",
                    text: "Continue",
                    requirements: nil,
                    consequences: EventConsequences()
                )
            ],
            oneTime: oneTime,
            completed: completed,
            weight: weight,
            requiredFlags: requiredFlags,
            forbiddenFlags: forbiddenFlags
        )
    }

    private func createTestEventWithConsequences(
        healthChange: Int? = nil,
        faithChange: Int? = nil,
        balanceChange: Int? = nil,
        tensionChange: Int? = nil,
        setFlags: [String: Bool]? = nil
    ) -> GameEvent {
        return GameEvent(
            id: "consequence_event",
            eventType: .narrative,
            title: "Consequence Event",
            description: "Event with consequences",
            choices: [
                EventChoice(
                    id: "choice_1",
                    text: "Accept",
                    requirements: nil,
                    consequences: EventConsequences(
                        faithChange: faithChange,
                        healthChange: healthChange,
                        balanceChange: balanceChange,
                        tensionChange: tensionChange,
                        setFlags: setFlags
                    )
                )
            ]
        )
    }

    private func createTestContext(
        location: String = "forest",
        locationState: String = "stable",
        flags: [String: Bool] = [:],
        resources: [String: Int] = [:],
        completedEvents: Set<String> = []
    ) -> EventContext {
        return EventContext(
            currentLocation: location,
            locationState: locationState,
            pressure: 0,
            flags: flags,
            resources: resources,
            completedEvents: completedEvents
        )
    }

    // MARK: - EventSelector.isEventAvailable Tests

    func testEventAvailable_BasicEvent() {
        // Given
        let event = createTestEvent(oneTime: false)
        let context = createTestContext()

        // When
        let result = selector.isEventAvailable(event, context: context)

        // Then
        XCTAssertTrue(result, "Basic event should be available")
    }

    func testEventAvailable_OneTimeCompletedUnavailable() {
        // Given
        let event = createTestEvent(id: "one_time_event", oneTime: true, completed: true)
        let context = createTestContext()

        // When
        let result = selector.isEventAvailable(event, context: context)

        // Then
        XCTAssertFalse(result, "One-time completed event should not be available")
    }

    func testEventAvailable_OneTimeInContextCompletedSet() {
        // Given
        let event = createTestEvent(id: "context_event", oneTime: true, completed: false)
        let context = createTestContext(completedEvents: ["context_event"])

        // When
        let result = selector.isEventAvailable(event, context: context)

        // Then
        XCTAssertFalse(result, "One-time event in completed set should not be available")
    }

    func testEventAvailable_RegionTypeFiltering() {
        // Given
        let event = createTestEvent(regionTypes: [.forest, .swamp])
        let forestContext = createTestContext(location: "forest")
        let mountainContext = createTestContext(location: "mountain")

        // When
        let forestResult = selector.isEventAvailable(event, context: forestContext)
        let mountainResult = selector.isEventAvailable(event, context: mountainContext)

        // Then
        XCTAssertTrue(forestResult, "Event should be available in forest region")
        XCTAssertFalse(mountainResult, "Event should not be available in mountain region")
    }

    func testEventAvailable_RegionStateFiltering() {
        // Given
        let event = createTestEvent(regionStates: [.stable])
        let stableContext = createTestContext(locationState: "stable")
        let breachContext = createTestContext(locationState: "breach")

        // When
        let stableResult = selector.isEventAvailable(event, context: stableContext)
        let breachResult = selector.isEventAvailable(event, context: breachContext)

        // Then
        XCTAssertTrue(stableResult, "Event should be available in stable state")
        XCTAssertFalse(breachResult, "Event should not be available in breach state")
    }

    func testEventAvailable_RequiredFlagsFiltering() {
        // Given
        let event = createTestEvent(requiredFlags: ["met_elder", "visited_shrine"])
        let contextWithFlags = createTestContext(flags: ["met_elder": true, "visited_shrine": true])
        let contextMissingFlag = createTestContext(flags: ["met_elder": true])

        // When
        let withFlagsResult = selector.isEventAvailable(event, context: contextWithFlags)
        let missingFlagResult = selector.isEventAvailable(event, context: contextMissingFlag)

        // Then
        XCTAssertTrue(withFlagsResult, "Event should be available when all required flags are set")
        XCTAssertFalse(missingFlagResult, "Event should not be available when required flag is missing")
    }

    func testEventAvailable_ForbiddenFlagsFiltering() {
        // Given
        let event = createTestEvent(forbiddenFlags: ["cursed", "corrupted"])
        let contextWithoutForbidden = createTestContext(flags: ["blessed": true])
        let contextWithForbidden = createTestContext(flags: ["blessed": true, "cursed": true])

        // When
        let withoutForbiddenResult = selector.isEventAvailable(event, context: contextWithoutForbidden)
        let withForbiddenResult = selector.isEventAvailable(event, context: contextWithForbidden)

        // Then
        XCTAssertTrue(withoutForbiddenResult, "Event should be available when forbidden flags are not set")
        XCTAssertFalse(withForbiddenResult, "Event should not be available when forbidden flag is set")
    }

    // MARK: - EventSelector.weightedSelect Tests

    func testWeightedSelect_EmptyArray() {
        // Given
        let events: [GameEvent] = []

        // When
        let result = selector.weightedSelect(from: events, rng: rng)

        // Then
        XCTAssertNil(result, "Should return nil for empty array")
    }

    func testWeightedSelect_SingleEvent() {
        // Given
        let event = createTestEvent()
        let events = [event]

        // When
        let result = selector.weightedSelect(from: events, rng: rng)

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.id, event.id, "Should return the single event")
    }

    func testWeightedSelect_MultipleEvents() {
        // Given
        let event1 = createTestEvent(id: "event_1", weight: 10)
        let event2 = createTestEvent(id: "event_2", weight: 20)
        let event3 = createTestEvent(id: "event_3", weight: 30)
        let events = [event1, event2, event3]

        // When
        let result = selector.weightedSelect(from: events, rng: rng)

        // Then
        XCTAssertNotNil(result)
        XCTAssertTrue(events.contains { $0.id == result?.id }, "Should return one of the events")
    }

    // MARK: - EventResolver.resolve Tests

    func testResolve_HealthChange() {
        // Given
        let event = createTestEventWithConsequences(healthChange: -10)
        let context = EventResolutionContext(
            currentHealth: 50,
            currentFaith: 30,
            currentBalance: 50,
            currentTension: 20,
            currentFlags: [:]
        )

        // When
        let result = resolver.resolve(event: event, choiceIndex: 0, context: context)

        // Then
        XCTAssertTrue(result.success)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.stateChanges.contains { change in
            if case .healthChanged(let delta, let newValue) = change {
                return delta == -10 && newValue == 40
            }
            return false
        })
    }

    func testResolve_FaithChange() {
        // Given
        let event = createTestEventWithConsequences(faithChange: 15)
        let context = EventResolutionContext(
            currentHealth: 50,
            currentFaith: 30,
            currentBalance: 50,
            currentTension: 20,
            currentFlags: [:]
        )

        // When
        let result = resolver.resolve(event: event, choiceIndex: 0, context: context)

        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.stateChanges.contains { change in
            if case .faithChanged(let delta, let newValue) = change {
                return delta == 15 && newValue == 45
            }
            return false
        })
    }

    func testResolve_TensionChange() {
        // Given
        let event = createTestEventWithConsequences(tensionChange: 10)
        let context = EventResolutionContext(
            currentHealth: 50,
            currentFaith: 30,
            currentBalance: 50,
            currentTension: 20,
            currentFlags: [:]
        )

        // When
        let result = resolver.resolve(event: event, choiceIndex: 0, context: context)

        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.stateChanges.contains { change in
            if case .tensionChanged(let delta, let newValue) = change {
                return delta == 10 && newValue == 30
            }
            return false
        })
    }

    func testResolve_BalanceChange() {
        // Given
        let event = createTestEventWithConsequences(balanceChange: 20)
        let context = EventResolutionContext(
            currentHealth: 50,
            currentFaith: 30,
            currentBalance: 50,
            currentTension: 20,
            currentFlags: [:]
        )

        // When
        let result = resolver.resolve(event: event, choiceIndex: 0, context: context)

        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.stateChanges.contains { change in
            if case .balanceChanged(let delta, let newValue) = change {
                return delta == 20 && newValue == 70
            }
            return false
        })
    }

    func testResolve_FlagSetting() {
        // Given
        let event = createTestEventWithConsequences(
            setFlags: ["met_elder": true, "visited_shrine": true]
        )
        let context = EventResolutionContext(
            currentHealth: 50,
            currentFaith: 30,
            currentBalance: 50,
            currentTension: 20,
            currentFlags: [:]
        )

        // When
        let result = resolver.resolve(event: event, choiceIndex: 0, context: context)

        // Then
        XCTAssertTrue(result.success)
        let flagChanges = result.stateChanges.compactMap { change -> (String, Bool)? in
            if case .flagSet(let key, let value) = change {
                return (key, value)
            }
            return nil
        }
        XCTAssertEqual(flagChanges.count, 2)
        XCTAssertTrue(flagChanges.contains { $0.0 == "met_elder" && $0.1 == true })
        XCTAssertTrue(flagChanges.contains { $0.0 == "visited_shrine" && $0.1 == true })
    }

    func testResolve_InvalidChoiceIndex() {
        // Given
        let event = createTestEvent()
        let context = EventResolutionContext(
            currentHealth: 50,
            currentFaith: 30,
            currentBalance: 50,
            currentTension: 20,
            currentFlags: [:]
        )

        // When
        let result = resolver.resolve(event: event, choiceIndex: 99, context: context)

        // Then
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.error, "Invalid choice index")
        XCTAssertTrue(result.stateChanges.isEmpty)
    }

    func testResolve_OneTimeEventCompletion() {
        // Given
        let event = createTestEvent(id: "one_time", oneTime: true)
        let context = EventResolutionContext(
            currentHealth: 50,
            currentFaith: 30,
            currentBalance: 50,
            currentTension: 20,
            currentFlags: [:]
        )

        // When
        let result = resolver.resolve(event: event, choiceIndex: 0, context: context)

        // Then
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.stateChanges.contains { change in
            if case .eventCompleted(let eventId) = change {
                return eventId == "one_time"
            }
            return false
        })
    }

    // MARK: - EventPipeline.canChoose Tests

    func testCanChoose_NoRequirements() {
        // Given
        let event = GameEvent(
            id: "test_event",
            eventType: .narrative,
            title: "Test",
            description: "Test",
            choices: [
                EventChoice(
                    id: "choice_1",
                    text: "Accept",
                    requirements: nil,
                    consequences: EventConsequences()
                )
            ]
        )
        let context = createTestContext()

        // When
        let result = pipeline.canChoose(event: event, choiceIndex: 0, context: context)

        // Then
        XCTAssertTrue(result.available, "Choice with no requirements should be available")
        XCTAssertNil(result.reason)
    }

    func testCanChoose_RequirementsMet() {
        // Given
        let event = GameEvent(
            id: "test_event",
            eventType: .narrative,
            title: "Test",
            description: "Test",
            choices: [
                EventChoice(
                    id: "choice_1",
                    text: "Pray",
                    requirements: EventRequirements(
                        minimumFaith: 10,
                        minimumHealth: 5,
                        requiredFlags: ["met_elder"]
                    ),
                    consequences: EventConsequences()
                )
            ]
        )
        let context = createTestContext(
            flags: ["met_elder": true],
            resources: ["faith": 15, "health": 10]
        )

        // When
        let result = pipeline.canChoose(event: event, choiceIndex: 0, context: context)

        // Then
        XCTAssertTrue(result.available, "Choice should be available when requirements are met")
        XCTAssertNil(result.reason)
    }

    func testCanChoose_InsufficientFaith() {
        // Given
        let event = GameEvent(
            id: "test_event",
            eventType: .narrative,
            title: "Test",
            description: "Test",
            choices: [
                EventChoice(
                    id: "choice_1",
                    text: "Pray",
                    requirements: EventRequirements(minimumFaith: 20),
                    consequences: EventConsequences()
                )
            ]
        )
        let context = createTestContext(resources: ["faith": 10])

        // When
        let result = pipeline.canChoose(event: event, choiceIndex: 0, context: context)

        // Then
        XCTAssertFalse(result.available, "Choice should not be available with insufficient faith")
        XCTAssertNotNil(result.reason)
    }

    func testCanChoose_InvalidChoiceIndex() {
        // Given
        let event = createTestEvent()
        let context = createTestContext()

        // When
        let result = pipeline.canChoose(event: event, choiceIndex: 99, context: context)

        // Then
        XCTAssertFalse(result.available, "Invalid choice index should not be available")
        XCTAssertEqual(result.reason, .invalidChoiceIndex(index: 99, maxIndex: 0))
    }
}

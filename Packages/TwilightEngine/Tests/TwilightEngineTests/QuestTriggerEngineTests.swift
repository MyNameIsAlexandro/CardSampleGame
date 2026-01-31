import XCTest
@testable import TwilightEngine

final class QuestTriggerEngineTests: XCTestCase {

    var engine: QuestTriggerEngine!

    override func setUp() {
        super.setUp()
        engine = QuestTriggerEngine(contentRegistry: .shared)
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Condition Evaluation Tests

    func testEvaluateCondition_FlagSet_WhenFlagIsTrue_ReturnsTrue() {
        // Given
        let condition = CompletionCondition.flagSet("tutorial_completed")
        let context = makeContext(worldFlags: ["tutorial_completed": true])
        let action = QuestTriggerAction.flagSet(flagName: "tutorial_completed")

        // When
        let result = engine.evaluateCondition(condition, action: action, context: context)

        // Then
        XCTAssertTrue(result, "Flag condition should evaluate to true when flag is set")
    }

    func testEvaluateCondition_FlagSet_WhenFlagIsFalse_ReturnsFalse() {
        // Given
        let condition = CompletionCondition.flagSet("tutorial_completed")
        let context = makeContext(worldFlags: ["tutorial_completed": false])
        let action = QuestTriggerAction.flagSet(flagName: "tutorial_completed")

        // When
        let result = engine.evaluateCondition(condition, action: action, context: context)

        // Then
        XCTAssertFalse(result, "Flag condition should evaluate to false when flag is not set")
    }

    func testEvaluateCondition_VisitRegion_WhenMatchingRegion_ReturnsTrue() {
        // Given
        let condition = CompletionCondition.visitRegion("forest")
        let context = makeContext()
        let action = QuestTriggerAction.visitedRegion(regionId: "forest")

        // When
        let result = engine.evaluateCondition(condition, action: action, context: context)

        // Then
        XCTAssertTrue(result, "Visit region condition should evaluate to true for matching region")
    }

    func testEvaluateCondition_VisitRegion_WhenNonMatchingRegion_ReturnsFalse() {
        // Given
        let condition = CompletionCondition.visitRegion("forest")
        let context = makeContext()
        let action = QuestTriggerAction.visitedRegion(regionId: "mountains")

        // When
        let result = engine.evaluateCondition(condition, action: action, context: context)

        // Then
        XCTAssertFalse(result, "Visit region condition should evaluate to false for non-matching region")
    }

    func testEvaluateCondition_EventCompleted_WhenMatchingEvent_ReturnsTrue() {
        // Given
        let condition = CompletionCondition.eventCompleted("event_001")
        let context = makeContext()
        let action = QuestTriggerAction.completedEvent(eventId: "event_001", choiceId: "choice_a")

        // When
        let result = engine.evaluateCondition(condition, action: action, context: context)

        // Then
        XCTAssertTrue(result, "Event completed condition should evaluate to true for matching event")
    }

    func testEvaluateCondition_EventCompleted_WhenNonMatchingEvent_ReturnsFalse() {
        // Given
        let condition = CompletionCondition.eventCompleted("event_001")
        let context = makeContext()
        let action = QuestTriggerAction.completedEvent(eventId: "event_002", choiceId: "choice_a")

        // When
        let result = engine.evaluateCondition(condition, action: action, context: context)

        // Then
        XCTAssertFalse(result, "Event completed condition should evaluate to false for non-matching event")
    }

    func testEvaluateCondition_ChoiceMade_WhenBothMatch_ReturnsTrue() {
        // Given
        let condition = CompletionCondition.choiceMade(eventId: "event_001", choiceId: "choice_a")
        let context = makeContext()
        let action = QuestTriggerAction.completedEvent(eventId: "event_001", choiceId: "choice_a")

        // When
        let result = engine.evaluateCondition(condition, action: action, context: context)

        // Then
        XCTAssertTrue(result, "Choice made condition should evaluate to true when both event and choice match")
    }

    func testEvaluateCondition_ChoiceMade_WhenOnlyEventMatches_ReturnsFalse() {
        // Given
        let condition = CompletionCondition.choiceMade(eventId: "event_001", choiceId: "choice_a")
        let context = makeContext()
        let action = QuestTriggerAction.completedEvent(eventId: "event_001", choiceId: "choice_b")

        // When
        let result = engine.evaluateCondition(condition, action: action, context: context)

        // Then
        XCTAssertFalse(result, "Choice made condition should evaluate to false when only event matches")
    }

    func testEvaluateCondition_ResourceThreshold_WhenAboveThreshold_ReturnsTrue() {
        // Given
        let condition = CompletionCondition.resourceThreshold(resourceId: "gold", minValue: 100)
        let context = makeContext(resources: ["gold": 150])
        let action = QuestTriggerAction.resourceChanged(resourceId: "gold", newValue: 150)

        // When
        let result = engine.evaluateCondition(condition, action: action, context: context)

        // Then
        XCTAssertTrue(result, "Resource threshold condition should evaluate to true when resource is above minimum")
    }

    func testEvaluateCondition_ResourceThreshold_WhenBelowThreshold_ReturnsFalse() {
        // Given
        let condition = CompletionCondition.resourceThreshold(resourceId: "gold", minValue: 100)
        let context = makeContext(resources: ["gold": 50])
        let action = QuestTriggerAction.resourceChanged(resourceId: "gold", newValue: 50)

        // When
        let result = engine.evaluateCondition(condition, action: action, context: context)

        // Then
        XCTAssertFalse(result, "Resource threshold condition should evaluate to false when resource is below minimum")
    }

    func testEvaluateCondition_ResourceThreshold_WhenResourceMissing_ReturnsFalse() {
        // Given
        let condition = CompletionCondition.resourceThreshold(resourceId: "gold", minValue: 100)
        let context = makeContext(resources: [:])
        let action = QuestTriggerAction.resourceChanged(resourceId: "gold", newValue: 0)

        // When
        let result = engine.evaluateCondition(condition, action: action, context: context)

        // Then
        XCTAssertFalse(result, "Resource threshold condition should evaluate to false when resource is missing")
    }

    func testEvaluateCondition_DefeatEnemy_WhenMatchingEnemy_ReturnsTrue() {
        // Given
        let condition = CompletionCondition.defeatEnemy("goblin_chief")
        let context = makeContext()
        let action = QuestTriggerAction.defeatedEnemy(enemyId: "goblin_chief")

        // When
        let result = engine.evaluateCondition(condition, action: action, context: context)

        // Then
        XCTAssertTrue(result, "Defeat enemy condition should evaluate to true for matching enemy")
    }

    func testEvaluateCondition_DefeatEnemy_WhenNonMatchingEnemy_ReturnsFalse() {
        // Given
        let condition = CompletionCondition.defeatEnemy("goblin_chief")
        let context = makeContext()
        let action = QuestTriggerAction.defeatedEnemy(enemyId: "goblin_warrior")

        // When
        let result = engine.evaluateCondition(condition, action: action, context: context)

        // Then
        XCTAssertFalse(result, "Defeat enemy condition should evaluate to false for non-matching enemy")
    }

    func testEvaluateCondition_CollectItem_WhenMatchingItem_ReturnsTrue() {
        // Given
        let condition = CompletionCondition.collectItem("ancient_key")
        let context = makeContext()
        let action = QuestTriggerAction.collectedItem(itemId: "ancient_key")

        // When
        let result = engine.evaluateCondition(condition, action: action, context: context)

        // Then
        XCTAssertTrue(result, "Collect item condition should evaluate to true for matching item")
    }

    func testEvaluateCondition_CollectItem_WhenNonMatchingItem_ReturnsFalse() {
        // Given
        let condition = CompletionCondition.collectItem("ancient_key")
        let context = makeContext()
        let action = QuestTriggerAction.collectedItem(itemId: "rusty_key")

        // When
        let result = engine.evaluateCondition(condition, action: action, context: context)

        // Then
        XCTAssertFalse(result, "Collect item condition should evaluate to false for non-matching item")
    }

    func testEvaluateCondition_Manual_WhenManualProgressAction_ReturnsTrue() {
        // Given
        let condition = CompletionCondition.manual
        let context = makeContext()
        let action = QuestTriggerAction.manualProgress(objectiveId: "obj_001")

        // When
        let result = engine.evaluateCondition(condition, action: action, context: context)

        // Then
        XCTAssertTrue(result, "Manual condition should evaluate to true for manual progress action")
    }

    func testEvaluateCondition_Manual_WhenNonManualAction_ReturnsFalse() {
        // Given
        let condition = CompletionCondition.manual
        let context = makeContext()
        let action = QuestTriggerAction.visitedRegion(regionId: "forest")

        // When
        let result = engine.evaluateCondition(condition, action: action, context: context)

        // Then
        XCTAssertFalse(result, "Manual condition should evaluate to false for non-manual action")
    }

    // MARK: - Availability Check Tests

    func testCheckAvailability_AllConditionsMet_ReturnsTrue() {
        // Given
        let availability = Availability(
            requiredFlags: ["flag1"],
            forbiddenFlags: ["flag2"],
            minPressure: 10,
            maxPressure: 50
        )
        let context = makeContext(
            worldFlags: ["flag1": true, "flag2": false],
            resources: ["tension": 30]
        )

        // When
        let result = engine.checkAvailability(availability, context: context)

        // Then
        XCTAssertTrue(result, "Availability should be true when all conditions are met")
    }

    func testCheckAvailability_RequiredFlagMissing_ReturnsFalse() {
        // Given
        let availability = Availability(requiredFlags: ["required_flag"])
        let context = makeContext(worldFlags: ["required_flag": false])

        // When
        let result = engine.checkAvailability(availability, context: context)

        // Then
        XCTAssertFalse(result, "Availability should be false when required flag is not set")
    }

    func testCheckAvailability_ForbiddenFlagPresent_ReturnsFalse() {
        // Given
        let availability = Availability(forbiddenFlags: ["forbidden_flag"])
        let context = makeContext(worldFlags: ["forbidden_flag": true])

        // When
        let result = engine.checkAvailability(availability, context: context)

        // Then
        XCTAssertFalse(result, "Availability should be false when forbidden flag is set")
    }

    func testCheckAvailability_BelowMinPressure_ReturnsFalse() {
        // Given
        let availability = Availability(minPressure: 50)
        let context = makeContext(resources: ["tension": 30])

        // When
        let result = engine.checkAvailability(availability, context: context)

        // Then
        XCTAssertFalse(result, "Availability should be false when tension is below minimum pressure")
    }

    func testCheckAvailability_AboveMaxPressure_ReturnsFalse() {
        // Given
        let availability = Availability(maxPressure: 50)
        let context = makeContext(resources: ["tension": 70])

        // When
        let result = engine.checkAvailability(availability, context: context)

        // Then
        XCTAssertFalse(result, "Availability should be false when tension is above maximum pressure")
    }

    func testCheckAvailability_WithinPressureRange_ReturnsTrue() {
        // Given
        let availability = Availability(minPressure: 20, maxPressure: 80)
        let context = makeContext(resources: ["tension": 50])

        // When
        let result = engine.checkAvailability(availability, context: context)

        // Then
        XCTAssertTrue(result, "Availability should be true when tension is within pressure range")
    }

    func testCheckAvailability_NoConditions_ReturnsTrue() {
        // Given
        let availability = Availability()
        let context = makeContext()

        // When
        let result = engine.checkAvailability(availability, context: context)

        // Then
        XCTAssertTrue(result, "Availability should be true when no conditions are specified")
    }

    // MARK: - Helper Methods

    private func makeContext(
        activeQuests: [QuestState] = [],
        completedQuestIds: Set<String> = [],
        worldFlags: [String: Bool] = [:],
        resources: [String: Int] = [:],
        currentDay: Int = 1,
        currentRegionId: String = "start_region"
    ) -> QuestTriggerContext {
        return QuestTriggerContext(
            activeQuests: activeQuests,
            completedQuestIds: completedQuestIds,
            worldFlags: worldFlags,
            resources: resources,
            currentDay: currentDay,
            currentRegionId: currentRegionId
        )
    }
}

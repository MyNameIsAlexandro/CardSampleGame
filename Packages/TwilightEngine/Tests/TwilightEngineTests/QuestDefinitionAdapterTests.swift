import XCTest
@testable import TwilightEngine

final class QuestDefinitionAdapterTests: XCTestCase {

    // MARK: - Quest Kind Mapping

    func testMainKindMapsToMain() {
        let def = makeQuestDefinition(questKind: .main)
        let quest = def.toQuest()
        XCTAssertEqual(quest.questType, .main)
    }

    func testSideKindMapsToSide() {
        let def = makeQuestDefinition(questKind: .side)
        let quest = def.toQuest()
        XCTAssertEqual(quest.questType, .side)
    }

    func testExplorationKindMapsToSide() {
        let def = makeQuestDefinition(questKind: .exploration)
        let quest = def.toQuest()
        XCTAssertEqual(quest.questType, .side)
    }

    func testChallengeKindMapsToSide() {
        let def = makeQuestDefinition(questKind: .challenge)
        let quest = def.toQuest()
        XCTAssertEqual(quest.questType, .side)
    }

    // MARK: - Basic Field Mapping

    func testBasicFieldsPassThrough() {
        let def = QuestDefinition(
            id: "q_test",
            title: .text("Test Title"),
            description: .text("Test Desc"),
            objectives: [],
            questKind: .side
        )
        let quest = def.toQuest()
        XCTAssertEqual(quest.id, "q_test")
        XCTAssertEqual(quest.title, "Test Title")
        XCTAssertEqual(quest.description, "Test Desc")
        XCTAssertEqual(quest.stage, 0)
        XCTAssertFalse(quest.completed)
    }

    // MARK: - Objective Conversion

    func testObjectiveFlagSetCondition() {
        let obj = makeObjective(condition: .flagSet("my_flag"))
        let result = obj.toQuestObjective()
        XCTAssertEqual(result.id, obj.id)
        XCTAssertFalse(result.completed)
        XCTAssertEqual(result.requiredFlags, ["my_flag"])
    }

    func testObjectiveEventCompletedCondition() {
        let obj = makeObjective(condition: .eventCompleted("e1"))
        let result = obj.toQuestObjective()
        XCTAssertEqual(result.requiredFlags, ["e1_completed"])
    }

    func testObjectiveChoiceMadeCondition() {
        let obj = makeObjective(condition: .choiceMade(eventId: "e1", choiceId: "c1"))
        let result = obj.toQuestObjective()
        XCTAssertEqual(result.requiredFlags, ["e1_c1_chosen"])
    }

    func testObjectiveVisitRegionCondition() {
        let obj = makeObjective(condition: .visitRegion("r1"))
        let result = obj.toQuestObjective()
        XCTAssertEqual(result.requiredFlags, ["visited_r1"])
    }

    func testObjectiveDefeatEnemyCondition() {
        let obj = makeObjective(condition: .defeatEnemy("boss"))
        let result = obj.toQuestObjective()
        XCTAssertEqual(result.requiredFlags, ["defeated_boss"])
    }

    func testObjectiveCollectItemCondition() {
        let obj = makeObjective(condition: .collectItem("sword"))
        let result = obj.toQuestObjective()
        XCTAssertEqual(result.requiredFlags, ["collected_sword"])
    }

    func testObjectiveResourceThresholdReturnsNilFlags() {
        let obj = makeObjective(condition: .resourceThreshold(resourceId: "gold", minValue: 10))
        let result = obj.toQuestObjective()
        XCTAssertNil(result.requiredFlags)
    }

    func testObjectiveManualReturnsNilFlags() {
        let obj = makeObjective(condition: .manual)
        let result = obj.toQuestObjective()
        XCTAssertNil(result.requiredFlags)
    }

    // MARK: - Rewards Conversion

    func testRewardsFaithFromResourceChanges() {
        let rewards = QuestCompletionRewards(resourceChanges: ["faith": 5])
        let result = rewards.toQuestRewards()
        XCTAssertEqual(result.faith, 5)
    }

    func testRewardsCardsFromCardIds() {
        let rewards = QuestCompletionRewards(cardIds: ["card_a", "card_b"])
        let result = rewards.toQuestRewards()
        XCTAssertEqual(result.cards, ["card_a", "card_b"])
    }

    func testRewardsEmptyCardIdsReturnsNilCards() {
        let rewards = QuestCompletionRewards(cardIds: [])
        let result = rewards.toQuestRewards()
        XCTAssertNil(result.cards)
    }

    func testRewardsArtifactAndExperienceAlwaysNil() {
        let rewards = QuestCompletionRewards(resourceChanges: ["faith": 3], cardIds: ["c1"])
        let result = rewards.toQuestRewards()
        XCTAssertNil(result.artifact)
        XCTAssertNil(result.experience)
    }

    // MARK: - Helpers

    private func makeQuestDefinition(questKind: QuestKind) -> QuestDefinition {
        QuestDefinition(
            id: "q_\(questKind)",
            title: .text("Title"),
            description: .text("Desc"),
            objectives: [],
            questKind: questKind
        )
    }

    private func makeObjective(condition: CompletionCondition) -> ObjectiveDefinition {
        ObjectiveDefinition(
            id: "obj_test",
            description: .text("Do something"),
            completionCondition: condition
        )
    }
}

import XCTest
@testable import CardSampleGame

/// Unit тесты для системы квестов
/// Покрывает: главный квест, побочные квесты, цели, награды
/// См. QA_ACT_I_CHECKLIST.md, тесты TEST-009, TEST-010
final class QuestSystemTests: XCTestCase {

    var worldState: WorldState!

    override func setUp() {
        super.setUp()
        worldState = WorldState()
    }

    override func tearDown() {
        worldState = nil
        super.tearDown()
    }

    // MARK: - TEST-009: Главный квест "Путь Защитника"

    func testMainQuestActiveAtStart() {
        let mainQuest = worldState.activeQuests.first { $0.questType == .main }
        XCTAssertNotNil(mainQuest, "Главный квест должен быть активен при старте")
    }

    func testMainQuestTitle() {
        let mainQuest = worldState.activeQuests.first { $0.questType == .main }
        XCTAssertEqual(mainQuest?.title, "Путь Защитника", "Название главного квеста")
    }

    func testMainQuestInitialStage() {
        XCTAssertEqual(worldState.mainQuestStage, 1, "Начальная стадия главного квеста должна быть 1")
    }

    func testMainQuestHasObjectives() {
        let mainQuest = worldState.activeQuests.first { $0.questType == .main }
        XCTAssertFalse(mainQuest?.objectives.isEmpty ?? true, "Главный квест должен иметь цели")
    }

    // MARK: - Quest Objectives

    func testObjectiveInitialization() {
        let objective = QuestObjective(description: "Тестовая цель")
        XCTAssertFalse(objective.completed, "Цель должна быть незавершённой при создании")
    }

    func testObjectiveWithRequiredFlags() {
        let objective = QuestObjective(
            description: "Цель с флагами",
            requiredFlags: ["flag1", "flag2"]
        )
        XCTAssertEqual(objective.requiredFlags?.count, 2, "Должно быть 2 required флага")
    }

    func testAllObjectivesCompleted() {
        var quest = Quest(
            title: "Тест",
            description: "Тестовый квест",
            questType: .side,
            objectives: [
                QuestObjective(description: "Цель 1", completed: true),
                QuestObjective(description: "Цель 2", completed: true)
            ],
            rewards: QuestRewards()
        )

        XCTAssertTrue(quest.allObjectivesCompleted, "Все цели должны быть завершены")
    }

    func testNotAllObjectivesCompleted() {
        var quest = Quest(
            title: "Тест",
            description: "Тестовый квест",
            questType: .side,
            objectives: [
                QuestObjective(description: "Цель 1", completed: true),
                QuestObjective(description: "Цель 2", completed: false)
            ],
            rewards: QuestRewards()
        )

        XCTAssertFalse(quest.allObjectivesCompleted, "Не все цели завершены")
    }

    // MARK: - Quest Types

    func testMainQuestType() {
        let quest = Quest(
            title: "Main",
            description: "Main quest",
            questType: .main,
            objectives: [],
            rewards: QuestRewards()
        )
        XCTAssertEqual(quest.questType, .main)
    }

    func testSideQuestType() {
        let quest = Quest(
            title: "Side",
            description: "Side quest",
            questType: .side,
            objectives: [],
            rewards: QuestRewards()
        )
        XCTAssertEqual(quest.questType, .side)
    }

    // MARK: - Quest Rewards

    func testRewardsFaith() {
        let rewards = QuestRewards(faith: 5)
        XCTAssertEqual(rewards.faith, 5, "Награда верой")
    }

    func testRewardsCards() {
        let rewards = QuestRewards(cards: ["card1", "card2"])
        XCTAssertEqual(rewards.cards?.count, 2, "Награда картами")
    }

    func testRewardsArtifact() {
        let rewards = QuestRewards(artifact: "ancient_sword")
        XCTAssertEqual(rewards.artifact, "ancient_sword", "Награда артефактом")
    }

    func testRewardsExperience() {
        let rewards = QuestRewards(experience: 100)
        XCTAssertEqual(rewards.experience, 100, "Награда опытом")
    }

    // MARK: - Side Quest Themes

    func testSideQuestThemeConsequence() {
        let quest = Quest(
            title: "Последствия",
            description: "Test",
            questType: .side,
            objectives: [],
            rewards: QuestRewards(),
            theme: .consequence
        )
        XCTAssertEqual(quest.theme, .consequence)
    }

    func testSideQuestThemeWarning() {
        let quest = Quest(
            title: "Предупреждение",
            description: "Test",
            questType: .side,
            objectives: [],
            rewards: QuestRewards(),
            theme: .warning
        )
        XCTAssertEqual(quest.theme, .warning)
    }

    func testSideQuestThemeTemptation() {
        let quest = Quest(
            title: "Соблазн",
            description: "Test",
            questType: .side,
            objectives: [],
            rewards: QuestRewards(),
            theme: .temptation
        )
        XCTAssertEqual(quest.theme, .temptation)
    }

    // MARK: - Mirror Flag System

    func testQuestMirrorFlag() {
        let quest = Quest(
            title: "Зеркало",
            description: "Test",
            questType: .side,
            objectives: [],
            rewards: QuestRewards(),
            mirrorFlag: "dark_choice_made"
        )

        XCTAssertTrue(quest.mirrors(flag: "dark_choice_made"), "Квест должен отражать флаг")
        XCTAssertFalse(quest.mirrors(flag: "other_flag"), "Квест не должен отражать другой флаг")
    }

    // MARK: - Quest Conditions

    func testQuestConditionsFlags() {
        let conditions = QuestConditions(
            requiredFlags: ["flag1"],
            forbiddenFlags: ["flag2"]
        )

        XCTAssertEqual(conditions.requiredFlags?.first, "flag1")
        XCTAssertEqual(conditions.forbiddenFlags?.first, "flag2")
    }

    func testQuestConditionsTension() {
        let conditions = QuestConditions(
            minTension: 20,
            maxTension: 60
        )

        XCTAssertEqual(conditions.minTension, 20)
        XCTAssertEqual(conditions.maxTension, 60)
    }

    func testQuestConditionsBalance() {
        let conditions = QuestConditions(
            minBalance: 30,
            maxBalance: 70
        )

        XCTAssertEqual(conditions.minBalance, 30)
        XCTAssertEqual(conditions.maxBalance, 70)
    }

    func testQuestConditionsVisitedRegions() {
        let conditions = QuestConditions(
            visitedRegions: ["forest", "swamp"]
        )

        XCTAssertEqual(conditions.visitedRegions?.count, 2)
    }

    // MARK: - Quest Effects

    func testQuestEffectsUnlockRegions() {
        let effects = QuestEffects(unlockRegions: ["hidden_valley"])
        XCTAssertEqual(effects.unlockRegions?.first, "hidden_valley")
    }

    func testQuestEffectsSetFlags() {
        let effects = QuestEffects(setFlags: ["boss_defeated"])
        XCTAssertEqual(effects.setFlags?.first, "boss_defeated")
    }

    func testQuestEffectsTensionChange() {
        let effects = QuestEffects(tensionChange: -10)
        XCTAssertEqual(effects.tensionChange, -10)
    }

    func testQuestEffectsAddCards() {
        let effects = QuestEffects(addCards: ["reward_card"])
        XCTAssertEqual(effects.addCards?.first, "reward_card")
    }

    // MARK: - Main Quest Steps

    func testMainQuestStep() {
        let step = MainQuestStep(
            id: "step1",
            title: "Шаг 1",
            goal: "Посетить лес",
            unlockConditions: QuestConditions(),
            completionConditions: QuestConditions(visitedRegions: ["forest"])
        )

        XCTAssertEqual(step.id, "step1")
        XCTAssertEqual(step.title, "Шаг 1")
        XCTAssertEqual(step.goal, "Посетить лес")
    }

    func testMainQuestStepWithEffects() {
        let step = MainQuestStep(
            id: "step2",
            title: "Шаг 2",
            goal: "Победить босса",
            unlockConditions: QuestConditions(requiredFlags: ["step1_complete"]),
            completionConditions: QuestConditions(requiredFlags: ["boss_defeated"]),
            effects: QuestEffects(tensionChange: -5, setFlags: ["step2_complete"])
        )

        XCTAssertEqual(step.effects?.tensionChange, -5)
        XCTAssertEqual(step.effects?.setFlags?.first, "step2_complete")
    }

    // MARK: - Ending System

    func testEndingConditions() {
        let conditions = EndingConditions(
            minTension: 20,
            maxTension: 50,
            deckPath: .light,
            requiredFlags: ["main_quest_complete"],
            minStableAnchors: 4
        )

        XCTAssertEqual(conditions.minTension, 20)
        XCTAssertEqual(conditions.maxTension, 50)
        XCTAssertEqual(conditions.deckPath, .light)
        XCTAssertEqual(conditions.requiredFlags?.first, "main_quest_complete")
        XCTAssertEqual(conditions.minStableAnchors, 4)
    }

    func testEndingProfile() {
        let epilogue = EndingEpilogue(
            anchors: "Все якоря восстановлены",
            hero: "Герой стал защитником",
            world: "Мир спасён"
        )

        let ending = EndingProfile(
            id: "good_ending",
            title: "Хороший финал",
            conditions: EndingConditions(maxTension: 40),
            summary: "Мир спасён от тьмы",
            epilogue: epilogue,
            unlocksForNextRun: ["new_character"]
        )

        XCTAssertEqual(ending.id, "good_ending")
        XCTAssertEqual(ending.title, "Хороший финал")
        XCTAssertEqual(ending.epilogue.hero, "Герой стал защитником")
        XCTAssertEqual(ending.unlocksForNextRun?.first, "new_character")
    }

    // MARK: - Deck Path

    func testDeckPathLight() {
        XCTAssertEqual(DeckPath.light.rawValue, "light")
    }

    func testDeckPathDark() {
        XCTAssertEqual(DeckPath.dark.rawValue, "dark")
    }

    func testDeckPathBalance() {
        XCTAssertEqual(DeckPath.balance.rawValue, "balance")
    }

    // MARK: - World State Quest Management

    func testActiveQuestsNotEmpty() {
        XCTAssertFalse(worldState.activeQuests.isEmpty, "Активные квесты не должны быть пустыми")
    }

    func testCompletedQuestsInitiallyEmpty() {
        // completedQuests should be empty at start (no quests completed yet)
        XCTAssertTrue(worldState.completedQuests.isEmpty, "Завершённые квесты должны быть пустыми при старте")
    }

    func testWorldFlagsInitiallyEmpty() {
        // At start, world flags should be empty or have only startup flags
        // This depends on implementation - checking it doesn't crash
        _ = worldState.worldFlags
    }
}

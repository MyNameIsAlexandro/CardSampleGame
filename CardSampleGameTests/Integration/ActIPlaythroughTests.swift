import XCTest
@testable import CardSampleGame

/// Интеграционные тесты для полного прохождения Акта I
/// Покрывает: весь игровой цикл, квестовый прогресс, финал
/// См. QA_ACT_I_CHECKLIST.md, тесты TEST-009, TEST-015, TEST-016
final class ActIPlaythroughTests: XCTestCase {

    var worldState: WorldState!
    var player: Player!
    var gameState: GameState!

    override func setUp() {
        super.setUp()
        player = Player(name: "Тестовый герой")
        gameState = GameState(players: [player])
        worldState = gameState.worldState
    }

    override func tearDown() {
        worldState = nil
        player = nil
        gameState = nil
        super.tearDown()
    }

    // MARK: - TEST-001: Полная инициализация

    func testNewGameInitialization() {
        // Проверяем все начальные параметры
        XCTAssertEqual(worldState.worldTension, 30, "WorldTension = 30%")
        XCTAssertEqual(worldState.lightDarkBalance, 50, "Balance = 50")
        XCTAssertEqual(worldState.daysPassed, 0, "daysPassed = 0")
        XCTAssertEqual(worldState.regions.count, 7, "7 регионов")
        XCTAssertNotNil(worldState.currentRegionId, "currentRegionId установлен")
    }

    func testStartingRegionIsCorrect() {
        guard let startRegion = worldState.getCurrentRegion() else {
            XCTFail("Нет стартового региона")
            return
        }

        XCTAssertEqual(startRegion.name, "Деревня у тракта", "Стартовый регион")
        XCTAssertEqual(startRegion.state, .stable, "Стартовый регион Stable")
    }

    func testMainQuestActiveAtStart() {
        let mainQuest = worldState.activeQuests.first { $0.questType == .main }
        XCTAssertNotNil(mainQuest, "Главный квест активен")
        XCTAssertEqual(mainQuest?.title, "Путь Защитника")
    }

    func testPlayerInitialization() {
        XCTAssertEqual(player.health, 10, "HP = 10")
        XCTAssertEqual(player.balance, 50, "Balance = 50")
        XCTAssertEqual(player.faith, 3, "Faith = 3")
        XCTAssertTrue(player.activeCurses.isEmpty, "Нет проклятий")
    }

    // MARK: - TEST-009: Главный квест прогресс

    func testMainQuestStageProgression() {
        XCTAssertEqual(worldState.mainQuestStage, 1, "Начальная стадия = 1")

        // Симулируем прогресс квеста (в реальной игре через события)
        worldState.mainQuestStage = 2
        XCTAssertEqual(worldState.mainQuestStage, 2, "Стадия 2")

        worldState.mainQuestStage = 5
        XCTAssertEqual(worldState.mainQuestStage, 5, "Финальная стадия")
    }

    // MARK: - Day Cycle Integration

    func testDayCycleWithTravel() {
        let initialDays = worldState.daysPassed

        // Путешествие к соседнему региону
        guard let currentRegion = worldState.getCurrentRegion(),
              let neighborId = currentRegion.neighborIds.first else {
            XCTFail("Нет соседей")
            return
        }

        worldState.moveToRegion(neighborId)

        XCTAssertEqual(worldState.daysPassed, initialDays + 1, "Путешествие = +1 день")
    }

    func testTensionIncreasesEvery3Days() {
        let initialTension = worldState.worldTension

        // Симулируем 3 дня
        worldState.daysPassed = 3
        worldState.processDayStart()

        XCTAssertEqual(worldState.worldTension, initialTension + 2, "День 3: +2 Tension")

        // Симулируем 6 дней
        worldState.daysPassed = 6
        worldState.processDayStart()

        XCTAssertEqual(worldState.worldTension, initialTension + 4, "День 6: ещё +2 Tension")
    }

    // MARK: - Region Degradation Integration

    func testRegionDegradationDoesNotAffectStable() {
        // Установить все регионы в Stable
        for i in 0..<worldState.regions.count {
            worldState.regions[i].state = .stable
            if var anchor = worldState.regions[i].anchor {
                anchor.integrity = 100
                worldState.regions[i].anchor = anchor
            }
        }

        // Высокий tension для гарантии деградации
        worldState.worldTension = 100
        worldState.daysPassed = 3
        worldState.processDayStart()

        // Stable регионы не должны деградировать напрямую
        let allStable = worldState.regions.allSatisfy { $0.state == .stable }
        XCTAssertTrue(allStable, "Stable регионы не деградируют напрямую")
    }

    // MARK: - Combat Integration

    func testCombatWithRegionModifiers() {
        let player = Player(name: "Test")
        let context = CombatContext(regionState: .breach, playerCurses: [.weakness])

        let basePower = 5
        let adjustedPower = context.adjustedEnemyPower(basePower)

        XCTAssertEqual(adjustedPower, 7, "5 + 2 (breach) = 7")
        XCTAssertEqual(player.getDamageDealtModifier(), 0, "Без weakness = 0")

        player.applyCurse(type: .weakness, duration: 3)
        XCTAssertEqual(player.getDamageDealtModifier(), -1, "С weakness = -1")
    }

    func testCombatVictoryWithBloodCurse() {
        let player = Player(name: "Test")
        player.health = 5
        player.balance = 50
        player.applyCurse(type: .bloodCurse, duration: 10)

        // Симулируем победу в бою
        if player.hasCurse(.bloodCurse) {
            player.heal(2)
            player.shiftBalance(towards: .dark, amount: 5)
        }

        XCTAssertEqual(player.health, 7, "+2 HP от bloodCurse")
        XCTAssertEqual(player.balance, 45, "Сдвиг к тьме")
    }

    // MARK: - Defeat Conditions

    func testDefeatByHealthZero() {
        player.health = 1
        player.takeDamage(5)

        gameState.checkDefeatConditions()

        XCTAssertTrue(gameState.isDefeat, "Поражение при HP = 0")
    }

    func testDefeatByMaxTension() {
        worldState.worldTension = 100

        gameState.checkDefeatConditions()

        XCTAssertTrue(gameState.isDefeat, "Поражение при Tension = 100%")
    }

    // MARK: - Victory Conditions

    func testVictoryByQuestCompletion() {
        worldState.mainQuestStage = 5
        worldState.worldFlags["act5_completed"] = true

        gameState.checkQuestVictory()

        XCTAssertTrue(gameState.isVictory, "Победа при завершении главного квеста")
    }

    // MARK: - Event Log Integration

    func testEventLogRecordsThroughout() {
        worldState.logEvent(
            regionName: "Лес",
            eventTitle: "Встреча",
            choiceMade: "Помочь",
            outcome: "Награда",
            type: .exploration
        )

        worldState.logEvent(
            regionName: "Деревня",
            eventTitle: "Торговец",
            choiceMade: "Купить",
            outcome: "Карта получена",
            type: .choice
        )

        XCTAssertGreaterThanOrEqual(worldState.eventLog.count, 2, "Журнал ведёт записи")
    }

    func testEventLogLimit() {
        for i in 0..<150 {
            worldState.logEvent(
                regionName: "Регион \(i)",
                eventTitle: "Событие \(i)",
                choiceMade: "Выбор",
                outcome: "Результат",
                type: .exploration
            )
        }

        XCTAssertLessThanOrEqual(worldState.eventLog.count, 100, "Журнал не превышает 100 записей")
    }

    // MARK: - Flag System Integration

    func testFlagPersistence() {
        worldState.setFlag("quest_started", value: true)
        XCTAssertTrue(worldState.hasFlag("quest_started"))

        worldState.setFlag("quest_started", value: false)
        XCTAssertFalse(worldState.hasFlag("quest_started"))
    }

    func testEventFilteringByFlags() {
        let flagEvent = GameEvent(
            eventType: .narrative,
            title: "Flag Event",
            description: "Test",
            regionStates: [.stable, .borderland, .breach],
            choices: [EventChoice(text: "OK", consequences: EventConsequences())],
            requiredFlags: ["special_flag"]
        )

        let region = Region(name: "Test", type: .forest, state: .stable)

        XCTAssertFalse(flagEvent.canOccur(in: region, worldTension: 30, worldFlags: [:]))

        worldState.setFlag("special_flag", value: true)
        XCTAssertTrue(flagEvent.canOccur(in: region, worldTension: 30, worldFlags: worldState.worldFlags))
    }

    // MARK: - Turn Management Integration

    func testTurnEndsCorrectly() {
        gameState.startGame()

        let initialTurn = gameState.turnNumber
        gameState.endTurn()

        XCTAssertEqual(gameState.turnNumber, initialTurn + 1, "Номер хода увеличивается")
        XCTAssertEqual(gameState.actionsRemaining, 3, "Действия обновляются")
    }

    func testExhaustionReducesActionsOnTurnStart() {
        player.applyCurse(type: .exhaustion, duration: 3)
        gameState.startGame()
        gameState.endTurn()

        XCTAssertEqual(gameState.actionsRemaining, 2, "exhaustion: 3 - 1 = 2 действия")
    }

    // MARK: - Card Purchase Integration

    func testCardPurchaseWithFaith() {
        player.faith = 5
        let testCard = Card(name: "Test Card", type: .spell, description: "Test", cost: 3)
        gameState.marketCards = [testCard]

        let result = gameState.purchaseCard(testCard)

        XCTAssertTrue(result, "Покупка успешна")
        XCTAssertEqual(player.faith, 2, "Вера уменьшилась")
        XCTAssertTrue(gameState.marketCards.isEmpty, "Карта убрана из магазина")
        XCTAssertEqual(player.discard.count, 1, "Карта в сбросе")
    }

    func testCardPurchaseFailsWithoutFaith() {
        player.faith = 1
        let testCard = Card(name: "Expensive Card", type: .spell, description: "Test", cost: 5)
        gameState.marketCards = [testCard]

        let result = gameState.purchaseCard(testCard)

        XCTAssertFalse(result, "Покупка неуспешна")
        XCTAssertEqual(player.faith, 1, "Вера не изменилась")
    }

    // MARK: - World State Persistence (Conceptual)

    @MainActor
    func testWorldStateCanBeCoded() async {
        // Проверяем что WorldState соответствует Codable
        // @MainActor требуется т.к. WorldState.Codable conformance изолирован на MainActor
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(worldState)
            XCTAssertFalse(data.isEmpty, "WorldState можно закодировать")

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(WorldState.self, from: data)
            XCTAssertEqual(decoded.worldTension, worldState.worldTension, "Tension сохраняется")
            XCTAssertEqual(decoded.daysPassed, worldState.daysPassed, "Days сохраняются")
        } catch {
            XCTFail("Ошибка кодирования: \(error)")
        }
    }
}

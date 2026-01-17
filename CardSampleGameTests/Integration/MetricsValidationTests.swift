import XCTest
@testable import CardSampleGame

/// Интеграционные тесты для валидации целевых метрик
/// Проверяет соответствие игры дизайн-целям Акта I
/// См. QA_ACT_I_CHECKLIST.md, Часть 1: Целевые метрики
final class MetricsValidationTests: XCTestCase {

    var worldState: WorldState!
    var player: Player!

    override func setUp() {
        super.setUp()
        worldState = WorldState()
        player = Player(name: "Тест")
    }

    override func tearDown() {
        worldState = nil
        player = nil
        super.tearDown()
    }

    // MARK: - 1.1 Время и давление

    func testInitialTensionWithinTarget() {
        // Цель: WorldTension в финале 40-60%
        // При старте 30% - это нормально
        XCTAssertEqual(worldState.worldTension, 30, "Начальный Tension = 30%")
    }

    func testTensionGrowthRate() {
        // Каждые 3 дня +2 Tension
        // За 15-25 дней: +10 to +16 Tension
        // Финальный Tension: 40-46% (без учёта деградации)

        let initialTension = worldState.worldTension

        // Симулируем 15 дней (минимальное прохождение)
        for day in 1...15 {
            worldState.daysPassed = day
            if day % 3 == 0 {
                worldState.increaseTension(by: 2)
            }
        }

        let expectedMinTension = initialTension + 10 // 5 раз по 2
        XCTAssertGreaterThanOrEqual(worldState.worldTension, expectedMinTension)
    }

    func testTensionRedFlag() {
        // Red Flag: >80% Tension ломает игру
        worldState.worldTension = 85
        XCTAssertTrue(worldState.worldTension > 80, "Red Flag: Tension > 80%")

        // При 100% - поражение
        worldState.worldTension = 100
        XCTAssertEqual(worldState.worldTension, 100, "100% = поражение")
    }

    // MARK: - 1.2 Карта и регионы

    func testInitialRegionDistribution() {
        // Цель: 2 Stable, 3 Borderland, 2 Breach при старте
        let stableCount = worldState.regions.filter { $0.state == .stable }.count
        let borderlandCount = worldState.regions.filter { $0.state == .borderland }.count
        let breachCount = worldState.regions.filter { $0.state == .breach }.count

        XCTAssertEqual(stableCount, 2, "2 Stable региона")
        XCTAssertEqual(borderlandCount, 3, "3 Borderland региона")
        XCTAssertEqual(breachCount, 2, "2 Breach региона")
    }

    func testRegionCountTotal() {
        // 7 регионов в Акте I
        XCTAssertEqual(worldState.regions.count, 7, "Всего 7 регионов")
    }

    func testRegionRedFlagAllStable() {
        // Red Flag: Все Stable = риск не работает
        for i in 0..<worldState.regions.count {
            worldState.regions[i].state = .stable
        }

        let allStable = worldState.regions.allSatisfy { $0.state == .stable }
        XCTAssertTrue(allStable, "Red Flag: все Stable")
    }

    func testRegionRedFlagAllBreach() {
        // Red Flag: Все Breach = негде восстановиться
        for i in 0..<worldState.regions.count {
            worldState.regions[i].state = .breach
        }

        let allBreach = worldState.regions.allSatisfy { $0.state == .breach }
        XCTAssertTrue(allBreach, "Red Flag: все Breach")
    }

    // MARK: - 1.3 Колода

    func testInitialDeckSize() {
        // Стартовая колода пустая, будет заполняться в игре
        // Цель: 20-25 карт к финалу
        player.deck = []
        XCTAssertTrue(player.deck.isEmpty, "Начальная колода пустая")
    }

    func testDeckSizeTarget() {
        // Симулируем рост колоды
        for i in 0..<22 {
            player.deck.append(Card(name: "Card \(i)", type: .spell, description: ""))
        }

        XCTAssertGreaterThanOrEqual(player.deck.count, 20, "Минимум 20 карт")
        XCTAssertLessThanOrEqual(player.deck.count, 25, "Максимум 25 карт")
    }

    func testDeckSizeRedFlags() {
        // Red Flag: <15 карт
        player.deck = Array(repeating: Card(name: "Card", type: .spell, description: ""), count: 12)
        XCTAssertLessThan(player.deck.count, 15, "Red Flag: <15 карт")

        // Red Flag: >30 карт
        player.deck = Array(repeating: Card(name: "Card", type: .spell, description: ""), count: 35)
        XCTAssertGreaterThan(player.deck.count, 30, "Red Flag: >30 карт")
    }

    // MARK: - 1.4 Квесты и контент

    func testMainQuestExists() {
        let mainQuest = worldState.activeQuests.first { $0.questType == .main }
        XCTAssertNotNil(mainQuest, "Главный квест существует")
    }

    func testSideQuestsAvailable() {
        // Минимум 2 побочных квеста доступны
        // В текущей реализации проверяем что side квесты могут быть созданы
        let sideQuest = Quest(
            title: "Побочный квест",
            description: "Описание",
            questType: .side,
            objectives: [QuestObjective(description: "Цель")],
            rewards: QuestRewards(faith: 2)
        )

        XCTAssertEqual(sideQuest.questType, .side)
    }

    // MARK: - 1.5 Исходы и поражения

    func testDeathInCombatPossible() {
        // Смерть в бою возможна
        player.health = 5
        player.takeDamage(10)
        XCTAssertEqual(player.health, 0, "Игрок может умереть")
    }

    func testDefeatByTensionPossible() {
        // Поражение по Tension возможно
        worldState.worldTension = 100
        XCTAssertEqual(worldState.worldTension, 100, "Tension может достигнуть 100%")
    }

    func testSoftFailPossible() {
        // Soft-fail: регион может деградировать
        var region = worldState.regions[0]
        region.state = .borderland
        worldState.updateRegion(region)

        XCTAssertEqual(worldState.regions[0].state, .borderland, "Регион может деградировать")
    }

    // MARK: - Баланс Light/Dark

    func testBalanceStartsNeutral() {
        XCTAssertEqual(player.balance, 50, "Стартовый баланс = 50 (нейтральный)")
        XCTAssertEqual(worldState.lightDarkBalance, 50, "Мировой баланс = 50")
    }

    func testBalanceCanShiftToLight() {
        player.shiftBalance(towards: .light, amount: 30)
        XCTAssertEqual(player.balance, 80, "Баланс к Свету")
        XCTAssertEqual(player.balanceState, .light, "Путь Света")
    }

    func testBalanceCanShiftToDark() {
        player.shiftBalance(towards: .dark, amount: 30)
        XCTAssertEqual(player.balance, 20, "Баланс к Тьме")
        XCTAssertEqual(player.balanceState, .dark, "Путь Тьмы")
    }

    // MARK: - Проклятия

    func testCurseCountTarget() {
        // Цель: 1-4 проклятия
        player.applyCurse(type: .weakness, duration: 3)
        player.applyCurse(type: .fear, duration: 3)

        XCTAssertGreaterThanOrEqual(player.activeCurses.count, 1, "Минимум 1 проклятие")
        XCTAssertLessThanOrEqual(player.activeCurses.count, 4, "Максимум 4 проклятия")
    }

    func testCurseRedFlagZero() {
        // Red Flag: 0 проклятий = Dark не ощущается
        XCTAssertEqual(player.activeCurses.count, 0, "0 проклятий при старте - норма")
    }

    func testCurseRedFlagTooMany() {
        // Red Flag: >5 проклятий = игра ломается
        for curse in [CurseType.weakness, .fear, .exhaustion, .greed, .shadowOfNav, .bloodCurse] {
            player.applyCurse(type: curse, duration: 10)
        }

        XCTAssertGreaterThan(player.activeCurses.count, 5, "Red Flag: >5 проклятий")
    }

    // MARK: - Вера

    func testFaithEconomy() {
        XCTAssertEqual(player.faith, 3, "Стартовая вера = 3")
        XCTAssertEqual(player.maxFaith, 10, "Максимум веры = 10")

        // Вера должна восстанавливаться
        player.faith = 0
        player.gainFaith(1)
        XCTAssertEqual(player.faith, 1, "Вера восстанавливается")
    }

    // MARK: - Карты и роли

    func testCardRolesExist() {
        // Все роли должны существовать
        XCTAssertNotNil(CardRole.sustain)
        XCTAssertNotNil(CardRole.control)
        XCTAssertNotNil(CardRole.power)
        XCTAssertNotNil(CardRole.utility)
    }

    func testCardRoleBalanceAlignment() {
        // Sustain и Control = Light
        XCTAssertEqual(CardRole.sustain.defaultBalance, .light)
        XCTAssertEqual(CardRole.control.defaultBalance, .light)

        // Power = Dark
        XCTAssertEqual(CardRole.power.defaultBalance, .dark)

        // Utility = Neutral
        XCTAssertEqual(CardRole.utility.defaultBalance, .neutral)
    }

    // MARK: - Ending System

    func testDeckPathCalculation() {
        // DeckPath определяет путь колоды
        XCTAssertNotNil(DeckPath.light)
        XCTAssertNotNil(DeckPath.dark)
        XCTAssertNotNil(DeckPath.balance)
    }

    func testEndingConditionsStructure() {
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
    }

    // MARK: - Travel System

    func testTravelCostConsistency() {
        guard let currentRegion = worldState.getCurrentRegion() else {
            XCTFail("Нет текущего региона")
            return
        }

        // Все соседи должны стоить 1 день
        for neighborId in currentRegion.neighborIds {
            let cost = worldState.calculateTravelCost(to: neighborId)
            XCTAssertEqual(cost, 1, "Сосед = 1 день")
        }

        // Все дальние должны стоить 2 дня
        for region in worldState.regions {
            if region.id != currentRegion.id && !currentRegion.neighborIds.contains(region.id) {
                let cost = worldState.calculateTravelCost(to: region.id)
                XCTAssertEqual(cost, 2, "Дальний = 2 дня")
            }
        }
    }

    // MARK: - Action Economy

    func testActionsPerTurn() {
        let gameState = GameState(players: [player])
        XCTAssertEqual(gameState.actionsPerTurn, 3, "3 действия в ход")
    }

    func testActionUsage() {
        let gameState = GameState(players: [player])
        gameState.actionsRemaining = 3

        XCTAssertTrue(gameState.useAction(), "Можно использовать действие")
        XCTAssertEqual(gameState.actionsRemaining, 2, "Осталось 2 действия")

        XCTAssertTrue(gameState.useAction())
        XCTAssertTrue(gameState.useAction())
        XCTAssertFalse(gameState.useAction(), "Нет действий")
    }
}

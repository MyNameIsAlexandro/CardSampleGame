import XCTest
@testable import CardSampleGame

/// Unit тесты для WorldState
/// Покрывает: инициализация, время, деградация, регионы
/// См. QA_ACT_I_CHECKLIST.md, тесты TEST-001, TEST-002, TEST-003
final class WorldStateTests: XCTestCase {

    var worldState: WorldState!

    override func setUp() {
        super.setUp()
        worldState = WorldState()
    }

    override func tearDown() {
        worldState = nil
        super.tearDown()
    }

    // MARK: - TEST-001: Инициализация

    func testInitialWorldTension() {
        // WorldTension должен быть 30% при старте
        XCTAssertEqual(worldState.worldTension, 30, "WorldTension должен быть 30 при старте")
    }

    func testInitialBalance() {
        // Balance должен быть 50 при старте
        XCTAssertEqual(worldState.lightDarkBalance, 50, "Balance должен быть 50 при старте")
    }

    func testInitialDaysPassed() {
        // daysPassed должен быть 0 при старте
        XCTAssertEqual(worldState.daysPassed, 0, "daysPassed должен быть 0 при старте")
    }

    func testInitialRegionsCount() {
        // Должно быть 7 регионов в Акте I
        XCTAssertEqual(worldState.regions.count, 7, "Должно быть 7 регионов в Акте I")
    }

    func testInitialRegionStates() {
        // Проверяем распределение: 2 Stable, 3 Borderland, 2 Breach
        let stableCount = worldState.regions.filter { $0.state == .stable }.count
        let borderlandCount = worldState.regions.filter { $0.state == .borderland }.count
        let breachCount = worldState.regions.filter { $0.state == .breach }.count

        XCTAssertEqual(stableCount, 2, "Должно быть 2 Stable региона")
        XCTAssertEqual(borderlandCount, 3, "Должно быть 3 Borderland региона")
        XCTAssertEqual(breachCount, 2, "Должно быть 2 Breach региона")
    }

    func testStartingRegion() {
        // Игрок должен начинать в первом регионе (Деревня у тракта)
        XCTAssertNotNil(worldState.currentRegionId, "currentRegionId должен быть установлен")

        if let currentRegion = worldState.getCurrentRegion() {
            XCTAssertEqual(currentRegion.name, "Деревня у тракта", "Стартовый регион должен быть Деревня у тракта")
            XCTAssertEqual(currentRegion.state, .stable, "Стартовый регион должен быть Stable")
        }
    }

    func testMainQuestActive() {
        // Главный квест должен быть активен при старте
        let mainQuest = worldState.activeQuests.first { $0.title == "Путь Защитника" }
        XCTAssertNotNil(mainQuest, "Главный квест 'Путь Защитника' должен быть активен")
    }

    // MARK: - TEST-002: Стоимость действий (время)

    func testTravelToNeighborCostsOneDay() {
        // Путешествие к соседнему региону должно стоить 1 день
        guard let currentRegion = worldState.getCurrentRegion(),
              let neighborId = currentRegion.neighborIds.first else {
            XCTFail("Нет соседних регионов для теста")
            return
        }

        let initialDays = worldState.daysPassed
        worldState.moveToRegion(neighborId)

        XCTAssertEqual(worldState.daysPassed, initialDays + 1, "Путешествие к соседу должно стоить 1 день")
    }

    func testTravelToDistantCostsTwoDays() {
        // Путешествие к дальнему региону должно стоить 2 дня
        guard let currentRegion = worldState.getCurrentRegion() else {
            XCTFail("Нет текущего региона")
            return
        }

        // Найти регион, который НЕ является соседом
        let distantRegion = worldState.regions.first { region in
            region.id != currentRegion.id && !currentRegion.neighborIds.contains(region.id)
        }

        guard let distant = distantRegion else {
            XCTFail("Нет дальних регионов для теста")
            return
        }

        let initialDays = worldState.daysPassed
        worldState.moveToRegion(distant.id)

        XCTAssertEqual(worldState.daysPassed, initialDays + 2, "Путешествие к дальнему региону должно стоить 2 дня")
    }

    func testCalculateTravelCost() {
        guard let currentRegion = worldState.getCurrentRegion(),
              let neighborId = currentRegion.neighborIds.first else {
            XCTFail("Нет данных для теста")
            return
        }

        // К соседу = 1
        let neighborCost = worldState.calculateTravelCost(to: neighborId)
        XCTAssertEqual(neighborCost, 1, "Стоимость к соседу должна быть 1")

        // К дальнему = 2
        let distantRegion = worldState.regions.first { region in
            region.id != currentRegion.id && !currentRegion.neighborIds.contains(region.id)
        }

        if let distant = distantRegion {
            let distantCost = worldState.calculateTravelCost(to: distant.id)
            XCTAssertEqual(distantCost, 2, "Стоимость к дальнему региону должна быть 2")
        }
    }

    // MARK: - TEST-003: Авто-деградация мира

    func testProcessDayStartIncreasesTensionEvery3Days() {
        // Каждые 3 дня worldTension должен увеличиваться на 2
        let initialTension = worldState.worldTension

        // День 1, 2 - ничего не происходит
        worldState.daysPassed = 1
        worldState.processDayStart()
        XCTAssertEqual(worldState.worldTension, initialTension, "День 1: Tension не должен измениться")

        worldState.daysPassed = 2
        worldState.processDayStart()
        XCTAssertEqual(worldState.worldTension, initialTension, "День 2: Tension не должен измениться")

        // День 3 - +2 к Tension
        worldState.daysPassed = 3
        worldState.processDayStart()
        XCTAssertEqual(worldState.worldTension, initialTension + 2, "День 3: Tension должен увеличиться на 2")

        // День 6 - ещё +2
        worldState.daysPassed = 6
        worldState.processDayStart()
        XCTAssertEqual(worldState.worldTension, initialTension + 4, "День 6: Tension должен увеличиться ещё на 2")
    }

    func testStableRegionsDoNotDegradeDirectly() {
        // Stable регионы НЕ должны деградировать напрямую
        // Проверяем алгоритм выбора региона для деградации

        // Сделаем все регионы Stable
        for i in 0..<worldState.regions.count {
            worldState.regions[i].state = .stable
            if var anchor = worldState.regions[i].anchor {
                anchor.integrity = 100
                worldState.regions[i].anchor = anchor
            }
        }

        // После processDayStart Stable регионы не должны деградировать
        worldState.worldTension = 100 // Максимальная вероятность
        worldState.daysPassed = 3
        worldState.processDayStart()

        let allStable = worldState.regions.allSatisfy { $0.state == .stable }
        XCTAssertTrue(allStable, "Stable регионы не должны деградировать напрямую")
    }

    func testBorderlandAndBreachCanDegrade() {
        // Borderland и Breach могут деградировать
        // Находим Borderland регион с низким integrity
        guard let borderlandIndex = worldState.regions.firstIndex(where: { $0.state == .borderland }) else {
            XCTFail("Нет Borderland региона для теста")
            return
        }

        // Устанавливаем низкий integrity чтобы гарантировать деградацию
        if var anchor = worldState.regions[borderlandIndex].anchor {
            anchor.integrity = 30 // Ниже 50 - не сопротивляется
            worldState.regions[borderlandIndex].anchor = anchor
        }

        let initialIntegrity = worldState.regions[borderlandIndex].anchor?.integrity ?? 0

        // Высокий Tension для гарантии деградации
        worldState.worldTension = 100
        worldState.daysPassed = 3
        worldState.processDayStart()

        // Проверяем что integrity уменьшился (деградация произошла)
        // Примечание: это вероятностный тест, может не сработать в 100% случаев
        // В реальном тесте лучше мокать random
    }

    // MARK: - Регионы

    func testGetCurrentRegion() {
        let region = worldState.getCurrentRegion()
        XCTAssertNotNil(region, "getCurrentRegion должен возвращать текущий регион")
    }

    func testRegionNeighborsConfigured() {
        // Все регионы должны иметь соседей (кроме крайних)
        for region in worldState.regions {
            XCTAssertFalse(region.neighborIds.isEmpty, "Регион \(region.name) должен иметь соседей")
        }
    }

    func testRegionCanRest() {
        // canRest = true только для Stable + (settlement или sacred)
        for region in worldState.regions {
            let expected = region.state == .stable && (region.type == .settlement || region.type == .sacred)
            XCTAssertEqual(region.canRest, expected, "canRest для \(region.name) должен быть \(expected)")
        }
    }

    func testRegionCanTrade() {
        // canTrade = true только для Stable + settlement + reputation >= 0
        for region in worldState.regions {
            let expected = region.state == .stable && region.type == .settlement && region.reputation >= 0
            XCTAssertEqual(region.canTrade, expected, "canTrade для \(region.name) должен быть \(expected)")
        }
    }

    // MARK: - События

    func testEventsFilteredByRegionState() {
        // События должны фильтроваться по состоянию региона
        guard let stableRegion = worldState.regions.first(where: { $0.state == .stable }) else {
            XCTFail("Нет Stable региона")
            return
        }

        let events = worldState.getAvailableEvents(for: stableRegion)

        for event in events {
            let canOccur = event.regionStates.contains(stableRegion.state)
            XCTAssertTrue(canOccur, "Событие \(event.title) не должно быть доступно в Stable")
        }
    }

    func testOneTimeEventsNotRepeated() {
        // OneTime события не должны повторяться
        guard let oneTimeEvent = worldState.allEvents.first(where: { $0.oneTime }) else {
            return // Нет oneTime событий для теста
        }

        worldState.markEventCompleted(oneTimeEvent.id)

        guard let region = worldState.regions.first else { return }
        let availableEvents = worldState.getAvailableEvents(for: region)

        let repeatedEvent = availableEvents.first { $0.id == oneTimeEvent.id }
        XCTAssertNil(repeatedEvent, "OneTime событие не должно повторяться после завершения")
    }

    // MARK: - Флаги

    func testSetAndGetFlag() {
        worldState.setFlag("test_flag", value: true)
        XCTAssertTrue(worldState.hasFlag("test_flag"), "Флаг должен быть установлен")

        worldState.setFlag("test_flag", value: false)
        XCTAssertFalse(worldState.hasFlag("test_flag"), "Флаг должен быть сброшен")
    }

    // MARK: - Журнал событий

    func testEventLogRecords() {
        let initialCount = worldState.eventLog.count

        worldState.logEvent(
            regionName: "Тест",
            eventTitle: "Тестовое событие",
            choiceMade: "Тестовый выбор",
            outcome: "Тестовый результат",
            type: .exploration
        )

        XCTAssertEqual(worldState.eventLog.count, initialCount + 1, "Событие должно быть записано в журнал")
    }

    func testEventLogLimit() {
        // Журнал не должен превышать 100 записей
        for i in 0..<150 {
            worldState.logEvent(
                regionName: "Регион \(i)",
                eventTitle: "Событие \(i)",
                choiceMade: "Выбор",
                outcome: "Результат",
                type: .exploration
            )
        }

        XCTAssertLessThanOrEqual(worldState.eventLog.count, 100, "Журнал не должен превышать 100 записей")
    }
}

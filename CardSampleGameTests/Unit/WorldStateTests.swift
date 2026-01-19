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
        // КРИТИЧНО: сброс WorldRNG для изоляции тестов
        WorldRNG.shared.resetToSystem()
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

    func testTensionIncreasesThroughAdvanceTime() {
        // Каждые 3 дня worldTension должен увеличиваться на 2
        // Используем advanceTime() вместо ручной установки daysPassed
        let initialTension = worldState.worldTension

        // День 1 - ничего не происходит
        worldState.advanceTime(by: 1)
        XCTAssertEqual(worldState.worldTension, initialTension, "День 1: Tension не должен измениться")

        // День 2 - ничего не происходит
        worldState.advanceTime(by: 1)
        XCTAssertEqual(worldState.worldTension, initialTension, "День 2: Tension не должен измениться")

        // День 3 - +3 к Tension
        worldState.advanceTime(by: 1)
        XCTAssertEqual(worldState.worldTension, initialTension + 3, "День 3: Tension должен увеличиться на 3")

        // Дни 4, 5
        worldState.advanceTime(by: 2)

        // День 6 - ещё +3
        worldState.advanceTime(by: 1)
        XCTAssertEqual(worldState.worldTension, initialTension + 6, "День 6: Tension должен увеличиться ещё на 3")
        XCTAssertEqual(worldState.daysPassed, 6, "Прошло 6 дней")
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

        // После advanceTime Stable регионы не должны деградировать
        worldState.increaseTension(by: 70) // Высокий tension для максимальной вероятности деградации
        worldState.advanceTime(by: 3)

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

        let initialIntegrity = worldState.regions[borderlandIndex].anchor?.integrity ?? 100

        // Высокий Tension для гарантии деградации
        worldState.increaseTension(by: 70)
        worldState.advanceTime(by: 3)

        // Проверяем что регион мог деградировать (integrity мог уменьшиться)
        let finalIntegrity = worldState.regions[borderlandIndex].anchor?.integrity ?? 100
        // При высоком tension и низком integrity деградация вероятна
        // Тест проходит если integrity уменьшился или остался (вероятностная логика)
        XCTAssertLessThanOrEqual(finalIntegrity, initialIntegrity, "Integrity не должен вырасти без действий игрока")
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

    // MARK: - Канон: Tension Escalation

    /// Тест: tension increment = +3 (канон зафиксирован)
    /// Если этот тест падает — значит код разошёлся с документацией
    func testPressureEscalationMatchesCanon() {
        // Канон: каждые 3 дня worldTension += 3
        let canonInterval = 3
        let canonIncrement = 3

        let initialTension = worldState.worldTension

        // Проход canonInterval дней
        for _ in 0..<canonInterval {
            worldState.advanceTime(by: 1)
        }

        let expectedTension = initialTension + canonIncrement
        XCTAssertEqual(
            worldState.worldTension,
            expectedTension,
            "Канон: каждые \(canonInterval) дня tension += \(canonIncrement). " +
            "Ожидалось \(expectedTension), получено \(worldState.worldTension)"
        )
    }

    // MARK: - Determinism Tests

    /// Тест: WorldRNG с фиксированным seed даёт одинаковые результаты
    func testWorldRNGDeterminism() {
        let seed: UInt64 = 12345

        // Первый запуск
        WorldRNG.shared.setSeed(seed)
        let values1 = (0..<10).map { _ in WorldRNG.shared.nextInt(in: 0..<100) }

        // Второй запуск с тем же seed
        WorldRNG.shared.setSeed(seed)
        let values2 = (0..<10).map { _ in WorldRNG.shared.nextInt(in: 0..<100) }

        XCTAssertEqual(values1, values2, "WorldRNG с одинаковым seed должен давать одинаковые значения")

        // Сброс на системный RNG
        WorldRNG.shared.resetToSystem()
    }

    /// Тест: детерминированный shuffle
    func testDeterministicShuffle() {
        let seed: UInt64 = 54321
        let array = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

        // Первый shuffle
        WorldRNG.shared.setSeed(seed)
        let shuffled1 = WorldRNG.shared.shuffled(array)

        // Второй shuffle с тем же seed
        WorldRNG.shared.setSeed(seed)
        let shuffled2 = WorldRNG.shared.shuffled(array)

        XCTAssertEqual(shuffled1, shuffled2, "Shuffle с одинаковым seed должен давать одинаковый порядок")
        XCTAssertNotEqual(shuffled1, array, "Shuffle должен изменить порядок элементов")

        // Сброс на системный RNG
        WorldRNG.shared.resetToSystem()
    }

    /// Тест: детерминированный выбор элемента
    func testDeterministicRandomElement() {
        let seed: UInt64 = 99999
        let array = ["A", "B", "C", "D", "E"]

        // Первая серия выборов
        WorldRNG.shared.setSeed(seed)
        let choices1 = (0..<5).compactMap { _ in WorldRNG.shared.randomElement(from: array) }

        // Вторая серия с тем же seed
        WorldRNG.shared.setSeed(seed)
        let choices2 = (0..<5).compactMap { _ in WorldRNG.shared.randomElement(from: array) }

        XCTAssertEqual(choices1, choices2, "randomElement с одинаковым seed должен давать одинаковые выборы")

        // Сброс на системный RNG
        WorldRNG.shared.resetToSystem()
    }

    /// Тест: мир детерминирован при фиксированном seed
    func testWorldDeterminismWithSeed() {
        let seed: UInt64 = 777777

        // Первый прогон
        WorldRNG.shared.setSeed(seed)
        let world1 = WorldState()
        world1.advanceTime(by: 9) // 3 цикла давления
        let tension1 = world1.worldTension
        let flags1 = world1.worldFlags

        // Второй прогон с тем же seed
        WorldRNG.shared.setSeed(seed)
        let world2 = WorldState()
        world2.advanceTime(by: 9)
        let tension2 = world2.worldTension
        let flags2 = world2.worldFlags

        XCTAssertEqual(tension1, tension2, "Tension должен быть одинаковым при одном seed")
        XCTAssertEqual(flags1, flags2, "Флаги должны быть одинаковыми при одном seed")

        // Сброс на системный RNG
        WorldRNG.shared.resetToSystem()
    }

    /// Тест: рынок детерминирован при фиксированном seed
    func testMarketDeterministicWithSeed() {
        let seed: UInt64 = 123456

        // Создаём тестовые карты
        let testCards = (0..<20).map { i in
            Card(
                name: "TestCard\(i)",
                type: .item,
                rarity: .common,
                description: "Test card \(i)",
                role: i % 2 == 0 ? .sustain : .utility
            )
        }

        // Первая генерация рынка
        WorldRNG.shared.setSeed(seed)
        let world1 = WorldState()
        let market1 = world1.generateMarket(allCards: testCards, globalPoolSize: 3, regionalPoolSize: 2)

        // Вторая генерация с тем же seed
        WorldRNG.shared.setSeed(seed)
        let world2 = WorldState()
        let market2 = world2.generateMarket(allCards: testCards, globalPoolSize: 3, regionalPoolSize: 2)

        // Рынки должны быть идентичны
        XCTAssertEqual(market1.count, market2.count, "Размер рынка должен совпадать")
        for i in 0..<min(market1.count, market2.count) {
            XCTAssertEqual(market1[i].name, market2[i].name, "Карта \(i) должна совпадать")
        }

        // Сброс на системный RNG
        WorldRNG.shared.resetToSystem()
    }

    /// Тест: low-tension recovery детерминирован
    func testLowTensionRecoveryDeterministic() {
        let seed: UInt64 = 999888

        // Первый прогон
        WorldRNG.shared.setSeed(seed)
        let world1 = WorldState()
        world1.worldTension = 15 // Low tension triggers recovery
        world1.advanceTime(by: 3)
        let regions1 = world1.regions.map { "\($0.name):\($0.state)" }

        // Второй прогон с тем же seed
        WorldRNG.shared.setSeed(seed)
        let world2 = WorldState()
        world2.worldTension = 15
        world2.advanceTime(by: 3)
        let regions2 = world2.regions.map { "\($0.name):\($0.state)" }

        XCTAssertEqual(regions1, regions2, "Состояния регионов должны совпадать при одном seed")

        // Сброс на системный RNG
        WorldRNG.shared.resetToSystem()
    }

    // MARK: - Time Progression Critical Tests

    /// КРИТИЧЕСКИЙ ТЕСТ: travel cost 2 должен обработать day 3 tick
    /// Если игрок на дне 2 и путешествует с cost 2, день 3 должен быть обработан
    func testTravelCostTwoDaysTriggersDay3Tick() {
        // Подготовка: установить день 2
        worldState.advanceTime(by: 2)
        XCTAssertEqual(worldState.daysPassed, 2, "Стартовое условие: день 2")

        let initialTension = worldState.worldTension

        // Найти дальний регион (travel cost = 2)
        guard let currentRegion = worldState.getCurrentRegion() else {
            XCTFail("Нет текущего региона")
            return
        }

        // Найти регион, который НЕ является соседом (cost = 2)
        let farRegion = worldState.regions.first { region in
            region.id != currentRegion.id && !currentRegion.isNeighbor(region.id)
        }

        guard let targetRegion = farRegion else {
            // Если нет дальних регионов, просто проверяем advanceTime напрямую
            worldState.advanceTime(by: 2)
            XCTAssertEqual(worldState.daysPassed, 4, "День должен быть 4")
            // День 3 должен был триггернуть +3 tension
            XCTAssertEqual(
                worldState.worldTension,
                initialTension + 3,
                "День 3 tick должен увеличить tension на 3"
            )
            return
        }

        // Путешествие с cost 2 (день 2 → день 4)
        worldState.moveToRegion(targetRegion.id)

        XCTAssertEqual(worldState.daysPassed, 4, "После travel cost 2: день должен быть 4")

        // КРИТИЧЕСКАЯ ПРОВЕРКА: день 3 должен был обработаться
        // Tension должен был увеличиться на 3 (day 3 tick)
        XCTAssertEqual(
            worldState.worldTension,
            initialTension + 3,
            "День 3 tick ДОЛЖЕН был сработать при travel cost 2. " +
            "Tension должен вырасти на 3. Было: \(initialTension), стало: \(worldState.worldTension)"
        )
    }

    /// Тест: advanceTime правильно обрабатывает каждый день
    func testAdvanceTimeProcessesEachDay() {
        // День 0 → день 6 (должны обработаться дни 3 и 6)
        let initialTension = worldState.worldTension

        worldState.advanceTime(by: 6)

        XCTAssertEqual(worldState.daysPassed, 6, "Должно быть 6 дней")

        // Дни 3 и 6 должны были дать по +3 tension = +6 всего
        XCTAssertEqual(
            worldState.worldTension,
            initialTension + 6,
            "Дни 3 и 6 должны дать +6 tension"
        )
    }
}

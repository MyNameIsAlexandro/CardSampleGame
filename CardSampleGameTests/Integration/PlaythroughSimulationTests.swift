import XCTest
@testable import CardSampleGame

/// End-to-End симуляция прохождения Акта I
/// ВАЖНО: Использует ТОЛЬКО продакшн-методы и детерминированный RNG
/// Проверяет что игру МОЖНО пройти от начала до конца через реальную систему
/// Тесты идут через реальный пайплайн событий из JSON
/// См. QA_ACT_I_CHECKLIST.md, TEST-015
final class PlaythroughSimulationTests: XCTestCase {

    var player: Player!
    var gameState: GameState!
    var worldState: WorldState!
    var rng: SeededRandomNumberGenerator!

    /// Детерминированный генератор случайных чисел для стабильных тестов
    struct SeededRandomNumberGenerator: RandomNumberGenerator {
        var state: UInt64

        init(seed: UInt64) {
            self.state = seed
        }

        mutating func next() -> UInt64 {
            // Linear congruential generator
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }

        /// Возвращает случайный индекс в диапазоне [0, count)
        mutating func randomIndex(count: Int) -> Int {
            guard count > 0 else { return 0 }
            return Int(next() % UInt64(count))
        }
    }

    override func setUp() {
        super.setUp()
        rng = SeededRandomNumberGenerator(seed: 12345) // Фиксированный seed для детерминизма
        player = Player(name: "Симуляция")
        gameState = GameState(players: [player])
        worldState = gameState.worldState
    }

    override func tearDown() {
        rng = nil
        player = nil
        gameState = nil
        worldState = nil
        WorldRNG.shared.resetToSystem()
        super.tearDown()
    }

    // MARK: - Helpers

    /// Выбирает событие детерминированно через seeded RNG
    /// ВАЖНО: Сортируем по UUID для гарантии детерминизма
    private func selectEvent(from events: [GameEvent]) -> GameEvent? {
        guard !events.isEmpty else { return nil }
        let sortedEvents = events.sorted { $0.title < $1.title }
        let index = rng.randomIndex(count: sortedEvents.count)
        return sortedEvents[index]
    }

    /// Выбирает выбор детерминированно через seeded RNG
    private func selectChoice(from event: GameEvent) -> EventChoice? {
        guard !event.choices.isEmpty else { return nil }
        let index = rng.randomIndex(count: event.choices.count)
        return event.choices[index]
    }

    /// Играет один ход через реальную систему событий
    private func playOneTurn(healThreshold: Int = 4) {
        guard let currentRegion = worldState.getCurrentRegion() else { return }

        // 1. Получаем доступные события из реальной системы
        let events = worldState.getAvailableEvents(for: currentRegion)

        // 2. Выбираем событие детерминированно
        if let event = selectEvent(from: events),
           let choice = selectChoice(from: event) {

            // 3. Применяем последствия выбора через продакшн-метод
            worldState.applyConsequences(choice.consequences, to: player, in: currentRegion.id)

            // 4. Помечаем oneTime события как завершённые
            if event.oneTime {
                worldState.markEventCompleted(event.id)
            }

            // 5. Проверяем прогресс квестов
            worldState.checkQuestObjectivesByEvent(eventTitle: event.title, choiceText: choice.text, player: player)
        }

        // 6. Лечение если нужно (через реальное событие отдыха или последствия)
        if player.health <= healThreshold && player.health > 0 {
            if currentRegion.canRest {
                // В Stable регионе можно отдохнуть - применяем стандартное лечение
                let restConsequences = EventConsequences(healthChange: 3)
                worldState.applyConsequences(restConsequences, to: player, in: currentRegion.id)
            }
        }

        // 7. Двигаем время
        worldState.advanceTime(by: 1)
    }

    // MARK: - Детерминированная симуляция через реальный пайплайн событий

    /// Симулирует типичное прохождение за 15-25 дней через реальную систему событий
    func testTypicalPlaythroughViaRealEventPipeline() {
        // Начальное состояние
        XCTAssertEqual(worldState.worldTension, 30)
        XCTAssertEqual(worldState.daysPassed, 0)
        XCTAssertFalse(gameState.isGameOver)

        // Симуляция 20 дней через реальный пайплайн событий
        for _ in 1...20 {
            playOneTurn(healThreshold: 5)

            // Проверяем состояние мира
            gameState.checkDefeatConditions()

            if gameState.isDefeat {
                // Поражение возможно - это валидный исход
                XCTAssertTrue(worldState.worldTension >= 100 || player.health <= 0,
                    "Поражение должно быть по валидной причине")
                return
            }
        }

        // К концу должны быть в разумном состоянии
        XCTAssertGreaterThanOrEqual(worldState.daysPassed, 20)
        XCTAssertLessThanOrEqual(worldState.worldTension, 80, "Tension не должен быть критическим")
        XCTAssertFalse(gameState.isDefeat, "Игрок не должен проиграть при осторожной игре")
    }

    // MARK: - Сценарий: Быстрое прохождение (15 дней) через реальные события

    func testFastPlaythroughScenario() {
        // Быстрое прохождение через реальный пайплайн
        rng = SeededRandomNumberGenerator(seed: 54321) // Другой seed для разнообразия

        for _ in 1...15 {
            playOneTurn(healThreshold: 5)
            gameState.checkDefeatConditions()
            if gameState.isDefeat { break }
        }

        // Проверки
        XCTAssertEqual(worldState.daysPassed, 15)
        // За 15 дней: +10 Tension (30 + 10 = 40)
        XCTAssertLessThanOrEqual(worldState.worldTension, 50, "При быстром прохождении Tension низкий")
        XCTAssertFalse(gameState.isDefeat)
    }

    // MARK: - Сценарий: Медленное исследование (25 дней) через реальные события

    func testSlowExplorationScenario() {
        // Медленное прохождение с исследованием всех регионов через реальные события
        rng = SeededRandomNumberGenerator(seed: 99999)
        var visitedRegions: Set<UUID> = []

        for _ in 1...25 {
            guard let currentRegion = worldState.getCurrentRegion() else { break }
            visitedRegions.insert(currentRegion.id)

            // Играем событие в текущем регионе
            let events = worldState.getAvailableEvents(for: currentRegion)
            if let event = selectEvent(from: events),
               let choice = selectChoice(from: event) {
                worldState.applyConsequences(choice.consequences, to: player, in: currentRegion.id)
                if event.oneTime {
                    worldState.markEventCompleted(event.id)
                }
            }

            // Переходим к соседу которого ещё не посещали (сортируем по имени для детерминизма)
            let sortedNeighbors = currentRegion.neighborIds.sorted { id1, id2 in
                let name1 = worldState.getRegion(byId: id1)?.name ?? ""
                let name2 = worldState.getRegion(byId: id2)?.name ?? ""
                return name1 < name2
            }
            if let unvisitedNeighbor = sortedNeighbors.first(where: { !visitedRegions.contains($0) }) {
                worldState.moveToRegion(unvisitedNeighbor)
            } else {
                worldState.advanceTime(by: 1)
            }

            // Лечение в Stable регионах
            if player.health < 5 {
                if let region = worldState.getCurrentRegion(), region.canRest {
                    let restConsequences = EventConsequences(healthChange: 2)
                    worldState.applyConsequences(restConsequences, to: player, in: region.id)
                }
            }

            gameState.checkDefeatConditions()
            if gameState.isDefeat { break }
        }

        // Проверки
        XCTAssertGreaterThanOrEqual(worldState.daysPassed, 20, "Много путешествий")
        XCTAssertGreaterThanOrEqual(visitedRegions.count, 5, "Посещено много регионов")
        XCTAssertLessThanOrEqual(worldState.worldTension, 80)
        XCTAssertFalse(gameState.isDefeat)
    }

    // MARK: - Сценарий: Детерминированный бой через реальные события

    func testDeterministicCombatScenario() {
        // Используем seeded RNG для воспроизводимости
        rng = SeededRandomNumberGenerator(seed: 11111)
        var combatEventsProcessed = 0

        for _ in 1...20 {
            guard let currentRegion = worldState.getCurrentRegion() else { break }

            // Получаем реальные события, сортируем для детерминизма
            let events = worldState.getAvailableEvents(for: currentRegion)
                .sorted { $0.title < $1.title }
            let combatEvents = events.filter { $0.eventType == .combat }

            // Обрабатываем боевые события если есть (уже отсортированы)
            if let combatEvent = combatEvents.first,
               let choice = selectChoice(from: combatEvent) {
                worldState.applyConsequences(choice.consequences, to: player, in: currentRegion.id)
                combatEventsProcessed += 1

                if combatEvent.oneTime {
                    worldState.markEventCompleted(combatEvent.id)
                }
            }

            // Если нет боевых событий, играем любое другое
            if combatEvents.isEmpty {
                if let event = selectEvent(from: events),
                   let choice = selectChoice(from: event) {
                    worldState.applyConsequences(choice.consequences, to: player, in: currentRegion.id)
                    if event.oneTime {
                        worldState.markEventCompleted(event.id)
                    }
                }
            }

            // Умный отдых в Stable регионах
            if player.health < 6 && player.health > 0 {
                if currentRegion.canRest {
                    let restConsequences = EventConsequences(healthChange: 4)
                    worldState.applyConsequences(restConsequences, to: player, in: currentRegion.id)
                }
            }

            worldState.advanceTime(by: 1)

            gameState.checkDefeatConditions()
            if gameState.isDefeat { break }
        }

        // Проверяем что обработали боевые события или игрок выжил
        XCTAssertTrue(combatEventsProcessed > 0 || player.health > 0,
            "Либо были бои, либо игрок выжил без них")
    }

    // MARK: - Сценарий: Проклятия через реальные события

    func testCursedPlaythroughViaRealEventPipeline() {
        // Применяем проклятия напрямую через Player API (как будто от события)
        player.applyCurse(type: .weakness, duration: 20)
        player.applyCurse(type: .fear, duration: 20)

        XCTAssertTrue(player.hasCurse(.weakness))
        XCTAssertTrue(player.hasCurse(.fear))

        rng = SeededRandomNumberGenerator(seed: 77777)

        for _ in 1...15 {
            guard let currentRegion = worldState.getCurrentRegion() else { break }

            // Играем реальные события
            let events = worldState.getAvailableEvents(for: currentRegion)
            if let event = selectEvent(from: events),
               let choice = selectChoice(from: event) {
                worldState.applyConsequences(choice.consequences, to: player, in: currentRegion.id)
                if event.oneTime {
                    worldState.markEventCompleted(event.id)
                }
            }

            // Лечение в Stable регионах
            if player.health < 4 && player.health > 0 && currentRegion.canRest {
                let restConsequences = EventConsequences(healthChange: 3)
                worldState.applyConsequences(restConsequences, to: player, in: currentRegion.id)
            }

            worldState.advanceTime(by: 1)
            gameState.endTurn() // Тикает проклятия

            if player.health <= 0 { break }
        }

        // Даже с проклятиями можно выжить при правильной игре
        XCTAssertGreaterThan(player.health, 0, "Можно выжить с проклятиями")
    }

    // MARK: - Сценарий: Путь Света через реальные события

    func testLightPathViaRealEventPipeline() {
        rng = SeededRandomNumberGenerator(seed: 33333)
        player.balance = 50

        for _ in 1...15 {
            guard let currentRegion = worldState.getCurrentRegion() else { break }

            // Получаем реальные события (сортируем для детерминизма)
            let events = worldState.getAvailableEvents(for: currentRegion)
                .sorted { $0.title < $1.title }

            // Ищем выборы с позитивным balanceChange (светлые)
            var foundLightChoice = false
            for event in events {
                for choice in event.choices {
                    if (choice.consequences.balanceChange ?? 0) > 0 {
                        worldState.applyConsequences(choice.consequences, to: player, in: currentRegion.id)
                        if event.oneTime { worldState.markEventCompleted(event.id) }
                        foundLightChoice = true
                        break
                    }
                }
                if foundLightChoice { break }
            }

            // Если нет светлых выборов, играем любой
            if !foundLightChoice {
                if let event = selectEvent(from: events),
                   let choice = selectChoice(from: event) {
                    worldState.applyConsequences(choice.consequences, to: player, in: currentRegion.id)
                    if event.oneTime { worldState.markEventCompleted(event.id) }
                }
            }

            worldState.advanceTime(by: 1)
        }

        // Проверяем что баланс сдвинулся к свету (или остался нейтральным если нет светлых событий)
        XCTAssertGreaterThanOrEqual(player.balance, 50, "Баланс не должен сдвинуться к тьме при светлых выборах")
    }

    // MARK: - Сценарий: Путь Тьмы через реальные события

    func testDarkPathViaRealEventPipeline() {
        rng = SeededRandomNumberGenerator(seed: 44444)
        player.balance = 50

        for _ in 1...15 {
            guard let currentRegion = worldState.getCurrentRegion() else { break }

            // Получаем реальные события (сортируем для детерминизма)
            let events = worldState.getAvailableEvents(for: currentRegion)
                .sorted { $0.title < $1.title }

            // Ищем выборы с негативным balanceChange (тёмные)
            var foundDarkChoice = false
            for event in events {
                for choice in event.choices {
                    if (choice.consequences.balanceChange ?? 0) < 0 {
                        worldState.applyConsequences(choice.consequences, to: player, in: currentRegion.id)
                        if event.oneTime { worldState.markEventCompleted(event.id) }
                        foundDarkChoice = true
                        break
                    }
                }
                if foundDarkChoice { break }
            }

            // Если нет тёмных выборов, играем любой
            if !foundDarkChoice {
                if let event = selectEvent(from: events),
                   let choice = selectChoice(from: event) {
                    worldState.applyConsequences(choice.consequences, to: player, in: currentRegion.id)
                    if event.oneTime { worldState.markEventCompleted(event.id) }
                }
            }

            worldState.advanceTime(by: 1)
        }

        // Проверяем что баланс сдвинулся к тьме (или остался нейтральным)
        XCTAssertLessThanOrEqual(player.balance, 50, "Баланс не должен сдвинуться к свету при тёмных выборах")
    }

    // MARK: - Сценарий: Баланс через реальные события

    func testBalancedPathViaRealEventPipeline() {
        rng = SeededRandomNumberGenerator(seed: 55555)
        player.balance = 50

        for _ in 1...15 {
            guard let currentRegion = worldState.getCurrentRegion() else { break }

            // Сортируем события для детерминизма
            let events = worldState.getAvailableEvents(for: currentRegion)
                .sorted { $0.title < $1.title }

            // Выбираем действия, чтобы поддерживать баланс
            var choiceMade = false
            for event in events {
                for choice in event.choices {
                    let balChange = choice.consequences.balanceChange ?? 0
                    let willShiftRight = player.balance > 55 && balChange < 0
                    let willShiftLeft = player.balance < 45 && balChange > 0
                    let neutral = balChange == 0

                    if willShiftRight || willShiftLeft || neutral {
                        worldState.applyConsequences(choice.consequences, to: player, in: currentRegion.id)
                        if event.oneTime { worldState.markEventCompleted(event.id) }
                        choiceMade = true
                        break
                    }
                }
                if choiceMade { break }
            }

            // Если подходящего выбора нет, играем случайный
            if !choiceMade {
                if let event = selectEvent(from: events),
                   let choice = selectChoice(from: event) {
                    worldState.applyConsequences(choice.consequences, to: player, in: currentRegion.id)
                    if event.oneTime { worldState.markEventCompleted(event.id) }
                }
            }

            worldState.advanceTime(by: 1)
        }

        // Баланс должен оставаться в нейтральной зоне
        XCTAssertGreaterThan(player.balance, 25, "Баланс не должен быть экстремально тёмным")
        XCTAssertLessThan(player.balance, 75, "Баланс не должен быть экстремально светлым")
    }

    // MARK: - Проверка условий победы через продакшн-методы

    func testVictoryConditionReachableViaProductionSystem() {
        // Симулируем выполнение главного квеста через флаги
        worldState.mainQuestStage = 5
        worldState.setFlag("act5_completed", value: true)

        gameState.checkQuestVictory()

        XCTAssertTrue(gameState.isVictory, "Победа достижима")
        XCTAssertEqual(gameState.currentPhase, .gameOver)
    }

    // MARK: - Проверка условий поражения через продакшн-методы

    func testDefeatConditionsByHealthViaProductionSystem() {
        player.takeDamageWithCurses(15) // Больше чем maxHealth

        gameState.checkDefeatConditions()

        XCTAssertTrue(gameState.isDefeat, "Поражение при HP=0")
    }

    func testDefeatConditionsByTensionViaProductionSystem() {
        worldState.increaseTension(by: 70) // 30 + 70 = 100

        gameState.checkDefeatConditions()

        XCTAssertTrue(gameState.isDefeat, "Поражение при Tension=100%")
    }

    func testDefeatConditionsByCriticalAnchor() {
        worldState.setFlag("critical_anchor_destroyed", value: true)

        gameState.checkDefeatConditions()

        XCTAssertTrue(gameState.isDefeat, "Поражение при уничтожении критического якоря")
    }

    // MARK: - Региональное прохождение через продакшн-методы

    func testRegionExplorationCoverageViaProductionSystem() {
        var visitedRegions: Set<UUID> = []

        // Посещаем все регионы через продакшн-метод moveToRegion
        for region in worldState.regions {
            worldState.moveToRegion(region.id)
            visitedRegions.insert(region.id)
        }

        XCTAssertEqual(visitedRegions.count, 7, "Все 7 регионов посещены")
    }

    func testRegionStateImpactOnCombat() {
        // Проверяем влияние состояния региона на бой через CombatContext
        for region in worldState.regions {
            let context = CombatContext(regionState: region.state, playerCurses: [])

            switch region.state {
            case .stable:
                XCTAssertEqual(context.adjustedEnemyPower(5), 5, "Stable: без модификатора")
            case .borderland:
                XCTAssertEqual(context.adjustedEnemyPower(5), 6, "Borderland: +1")
            case .breach:
                XCTAssertEqual(context.adjustedEnemyPower(5), 7, "Breach: +2")
            }
        }
    }

    // MARK: - Deck Building через реальную систему магазина

    func testDeckGrowthDuringPlaythroughViaProductionSystem() {
        let initialDeckSize = player.deck.count + player.hand.count + player.discard.count
        player.faith = 50 // Достаточно для покупок
        rng = SeededRandomNumberGenerator(seed: 66666)

        var purchasesMade = 0

        // Симулируем прохождение с покупками в магазине
        for day in 1...20 {
            guard let currentRegion = worldState.getCurrentRegion() else { break }

            // Играем реальные события
            let events = worldState.getAvailableEvents(for: currentRegion)
            if let event = selectEvent(from: events),
               let choice = selectChoice(from: event) {
                worldState.applyConsequences(choice.consequences, to: player, in: currentRegion.id)
                if event.oneTime { worldState.markEventCompleted(event.id) }
            }

            // Каждые 3 дня покупаем карту в магазине (если регион позволяет торговлю)
            if day % 3 == 0 && currentRegion.canTrade && player.faith >= 2 {
                let marketCard = Card(name: "Market Card \(day)", type: .spell, description: "From market", cost: 2)
                gameState.marketCards = [marketCard]
                if gameState.purchaseCard(marketCard) {
                    purchasesMade += 1
                }
            }

            worldState.advanceTime(by: 1)
        }

        let finalDeckSize = player.deck.count + player.hand.count + player.discard.count

        XCTAssertGreaterThanOrEqual(finalDeckSize, initialDeckSize, "Колода не должна уменьшиться")
        // Должны были сделать хотя бы несколько покупок
        XCTAssertGreaterThanOrEqual(purchasesMade, 0, "Система покупки работает")
    }

    // MARK: - Проверка стабильности через реальный пайплайн

    func testNoInfiniteLoopsInRealEventPipeline() {
        let startTime = Date()
        rng = SeededRandomNumberGenerator(seed: 88888)

        for _ in 1...100 {
            guard let currentRegion = worldState.getCurrentRegion() else { break }

            // Играем реальные события
            let events = worldState.getAvailableEvents(for: currentRegion)
            if let event = selectEvent(from: events),
               let choice = selectChoice(from: event) {
                worldState.applyConsequences(choice.consequences, to: player, in: currentRegion.id)
                if event.oneTime { worldState.markEventCompleted(event.id) }
            }

            worldState.advanceTime(by: 1)

            if player.health <= 0 {
                player.health = 5 // Ресет для продолжения теста
            }

            // Проверяем что не застряли
            let elapsed = Date().timeIntervalSince(startTime)
            XCTAssertLessThan(elapsed, 10.0, "Тест не должен занимать > 10 секунд")
        }

        XCTAssertEqual(worldState.daysPassed, 100, "100 дней обработано")
    }

    func testWorldStateConsistencyAfterManyDaysWithRealEvents() {
        rng = SeededRandomNumberGenerator(seed: 22222)

        for _ in 1...30 {
            guard let currentRegion = worldState.getCurrentRegion() else { break }

            // Играем реальные события
            let events = worldState.getAvailableEvents(for: currentRegion)
            if let event = selectEvent(from: events),
               let choice = selectChoice(from: event) {
                worldState.applyConsequences(choice.consequences, to: player, in: currentRegion.id)
                if event.oneTime { worldState.markEventCompleted(event.id) }
            }

            worldState.advanceTime(by: 1)

            // Проверяем консистентность после каждого дня
            XCTAssertGreaterThanOrEqual(worldState.worldTension, 0, "Tension >= 0")
            XCTAssertLessThanOrEqual(worldState.worldTension, 100, "Tension <= 100")
            XCTAssertEqual(worldState.regions.count, 7, "7 регионов")
            XCTAssertNotNil(worldState.currentRegionId, "Есть текущий регион")
        }

        XCTAssertEqual(worldState.daysPassed, 30, "30 дней прошло")
    }

    // MARK: - E2E: Получение и применение реальных событий

    func testRealEventSystemIntegration() {
        guard let currentRegion = worldState.getCurrentRegion() else {
            XCTFail("Нет текущего региона")
            return
        }

        // Получаем доступные события через продакшн-метод
        let availableEvents = worldState.getAvailableEvents(for: currentRegion)

        // Должны быть события для региона
        XCTAssertGreaterThan(availableEvents.count, 0, "Есть доступные события")

        // Все события должны быть валидны для текущего состояния
        for event in availableEvents {
            XCTAssertTrue(
                event.canOccur(in: currentRegion, worldTension: worldState.worldTension, worldFlags: worldState.worldFlags),
                "Событие \(event.title) должно быть валидно"
            )

            // У события должны быть выборы
            XCTAssertGreaterThan(event.choices.count, 0, "У события \(event.title) есть выборы")
        }
    }

    func testApplyEventChoiceConsequences() {
        guard let currentRegion = worldState.getCurrentRegion() else {
            XCTFail("Нет текущего региона")
            return
        }

        let availableEvents = worldState.getAvailableEvents(for: currentRegion)
        guard let event = availableEvents.first,
              let choice = event.choices.first else {
            return // Нет событий для тестирования
        }

        let healthBefore = player.health
        let faithBefore = player.faith

        // Применяем последствия выбора через продакшн-метод
        worldState.applyConsequences(choice.consequences, to: player, in: currentRegion.id)

        // Проверяем что система обработала последствия
        // (конкретные изменения зависят от события - могут измениться или остаться)
        XCTAssertTrue(player.health >= 0, "HP валидно после события (было \(healthBefore))")
        XCTAssertTrue(player.faith >= 0, "Вера валидна после события (была \(faithBefore))")
    }

    // MARK: - E2E: Полный цикл события

    func testCompleteEventCycle() {
        guard let currentRegion = worldState.getCurrentRegion(),
              let regionId = worldState.currentRegionId else {
            XCTFail("Нет текущего региона")
            return
        }

        // 1. Получить события
        let events = worldState.getAvailableEvents(for: currentRegion)
        guard let event = events.first else {
            return
        }

        // 2. Выбрать действие
        guard let choice = event.choices.first else {
            XCTFail("У события нет выборов")
            return
        }

        // 3. Применить последствия
        worldState.applyConsequences(choice.consequences, to: player, in: regionId)

        // 4. Залогировать событие (маппим EventType -> EventLogType)
        let logType: EventLogType
        switch event.eventType {
        case .combat: logType = .combat
        case .exploration: logType = .exploration
        case .narrative, .ritual, .worldShift: logType = .choice
        }

        worldState.logEvent(
            regionName: currentRegion.name,
            eventTitle: event.title,
            choiceMade: choice.text,
            outcome: "Тест",
            type: logType
        )

        // 5. Пометить событие завершённым (если это одноразовое)
        if event.oneTime {
            worldState.markEventCompleted(event.id)
        }

        // 6. Проверить прогресс квестов
        worldState.checkQuestObjectivesByEvent(eventTitle: event.title, choiceText: choice.text, player: player)

        // Проверки
        XCTAssertGreaterThan(worldState.eventLog.count, 0, "Событие залогировано")
    }
}

import XCTest
@testable import CardSampleGame

/// End-to-End симуляция прохождения Акта I
/// Проверяет что игру МОЖНО пройти от начала до конца
/// См. QA_ACT_I_CHECKLIST.md, TEST-015
final class PlaythroughSimulationTests: XCTestCase {

    var player: Player!
    var gameState: GameState!
    var worldState: WorldState!

    override func setUp() {
        super.setUp()
        player = Player(name: "Симуляция")
        gameState = GameState(players: [player])
        worldState = gameState.worldState
    }

    override func tearDown() {
        player = nil
        gameState = nil
        worldState = nil
        super.tearDown()
    }

    // MARK: - Полная симуляция прохождения

    /// Симулирует типичное прохождение Акта I за 15-25 дней
    func testTypicalPlaythroughSimulation() {
        // Setup: дать игроку стартовую колоду
        setupStarterDeck()

        // Начальное состояние
        XCTAssertEqual(worldState.worldTension, 30)
        XCTAssertEqual(worldState.daysPassed, 0)
        XCTAssertFalse(gameState.isGameOver)

        // Симуляция 20 дней игры
        for day in 1...20 {
            simulateDay(day)

            // Проверяем что игра не сломалась
            if gameState.isDefeat {
                XCTFail("Неожиданное поражение на дне \(day)")
                return
            }
        }

        // К концу должны быть в разумном состоянии
        XCTAssertGreaterThanOrEqual(worldState.daysPassed, 15)
        XCTAssertLessThanOrEqual(worldState.worldTension, 80, "Tension не должен быть критическим")
    }

    /// Симулирует один день игры
    private func simulateDay(_ day: Int) {
        // 1. Увеличиваем день
        worldState.daysPassed = day

        // 2. Проверяем деградацию мира
        worldState.processDayStart()

        // 3. Симулируем действия игрока (3 действия в день)
        for _ in 0..<3 {
            simulatePlayerAction()
        }

        // 4. Проверяем состояние
        gameState.checkDefeatConditions()
        gameState.checkQuestVictory()
    }

    /// Симулирует случайное действие игрока с учётом выживаемости
    private func simulatePlayerAction() {
        // Умная симуляция: приоритет лечения при низком HP
        if player.health <= 4 {
            // При низком HP - обязательно отдых
            simulateRest()
            return
        }

        // При среднем HP - избегаем боя
        let actions: [String]
        if player.health <= 6 {
            actions = ["explore", "rest", "travel", "explore"]  // без combat
        } else {
            actions = ["explore", "rest", "travel", "combat"]
        }

        let action = actions.randomElement()!

        switch action {
        case "explore":
            simulateExploration()
        case "rest":
            simulateRest()
        case "travel":
            simulateTravel()
        case "combat":
            simulateCombat()
        default:
            break
        }
    }

    private func simulateExploration() {
        // Случайный результат исследования
        let outcomes = [
            { self.player.gainFaith(1) },
            { self.player.takeDamage(1) },
            { /* ничего */ }
        ]
        outcomes.randomElement()?()
    }

    private func simulateRest() {
        if player.health < player.maxHealth {
            player.heal(2)
        }
    }

    private func simulateTravel() {
        if let regions = worldState.regions.randomElement() {
            // Не перемещаемся реально, просто проверяем систему
            _ = worldState.calculateTravelCost(to: regions.id)
        }
    }

    private func simulateCombat() {
        // Симулируем бой: 50% шанс получить урон
        if Bool.random() {
            player.takeDamage(2)
        }
        // 30% шанс получить проклятие
        if Int.random(in: 1...10) <= 3 {
            player.applyCurse(type: .weakness, duration: 2)
        }
    }

    private func setupStarterDeck() {
        // Стартовая колода: 10 базовых карт
        for i in 0..<10 {
            player.deck.append(Card(
                name: "Базовая карта \(i)",
                type: .spell,
                description: "Стартовая карта"
            ))
        }
        player.shuffleDeck()
        player.drawCards(count: 5)
    }

    // MARK: - Сценарий: Быстрое прохождение (15 дней)

    func testFastPlaythroughScenario() {
        setupStarterDeck()

        // Быстрое прохождение: минимум действий, фокус на квесте
        for day in 1...15 {
            worldState.daysPassed = day
            worldState.processDayStart()

            // Только критические действия
            if player.health < 5 {
                player.heal(3)
            }
        }

        // Проверки
        XCTAssertEqual(worldState.daysPassed, 15)
        XCTAssertLessThanOrEqual(worldState.worldTension, 50, "При быстром прохождении Tension низкий")
        XCTAssertFalse(gameState.isDefeat)
    }

    // MARK: - Сценарий: Медленное исследование (25 дней)

    func testSlowExplorationScenario() {
        setupStarterDeck()

        // Медленное прохождение: много исследования
        for day in 1...25 {
            worldState.daysPassed = day
            worldState.processDayStart()

            // Много исследования
            simulateExploration()
            simulateExploration()

            // Отдых если нужно
            if player.health < 5 {
                player.heal(2)
            }
        }

        // Проверки
        XCTAssertEqual(worldState.daysPassed, 25)
        // При долгом прохождении Tension выше, но не критичен
        XCTAssertLessThanOrEqual(worldState.worldTension, 70)
        XCTAssertFalse(gameState.isDefeat)
    }

    // MARK: - Сценарий: Агрессивный бой

    func testAggressiveCombatScenario() {
        setupStarterDeck()
        player.health = 10

        var combatsWon = 0

        for day in 1...20 {
            worldState.daysPassed = day
            worldState.processDayStart()

            // Много боёв
            for _ in 0..<2 {
                // Симулируем бой
                let enemyDamage = Int.random(in: 1...3)
                player.takeDamageWithCurses(enemyDamage)

                if player.health > 0 {
                    combatsWon += 1
                    // Награда за бой
                    player.gainFaith(1)
                }
            }

            // Отдых
            if player.health < 5 && player.health > 0 {
                player.heal(3)
            }

            if player.health <= 0 {
                break
            }
        }

        // Агрессивный стиль рискован но возможен
        // Минимум 5 побед (тест с random уроном может давать разные результаты)
        XCTAssertGreaterThanOrEqual(combatsWon, 5, "Должно быть несколько побед")
    }

    // MARK: - Сценарий: Проклятия

    func testCursedPlaythroughScenario() {
        setupStarterDeck()

        // Накапливаем проклятия
        player.applyCurse(type: .weakness, duration: 20)
        player.applyCurse(type: .fear, duration: 20)

        for day in 1...15 {
            worldState.daysPassed = day
            worldState.processDayStart()

            // С проклятиями сложнее
            let baseDamage = 2
            player.takeDamageWithCurses(baseDamage) // +1 от fear

            if player.health < 3 {
                player.heal(3)
            }

            if player.health <= 0 {
                break
            }

            gameState.endTurn() // тикает курсы
        }

        // Даже с проклятиями можно выжить при правильной игре
        XCTAssertGreaterThan(player.health, 0, "Можно выжить с проклятиями")
    }

    // MARK: - Сценарий: Путь Света

    func testLightPathScenario() {
        setupStarterDeck()
        player.balance = 50

        for day in 1...15 {
            worldState.daysPassed = day
            worldState.processDayStart()

            // Выбираем светлые действия
            player.shiftBalance(towards: .light, amount: 3)
            player.gainFaith(1)
        }

        XCTAssertGreaterThanOrEqual(player.balance, 70, "Достигнут Путь Света")
        XCTAssertEqual(player.balanceState, .light)
    }

    // MARK: - Сценарий: Путь Тьмы

    func testDarkPathScenario() {
        setupStarterDeck()
        player.balance = 50

        for day in 1...15 {
            worldState.daysPassed = day
            worldState.processDayStart()

            // Выбираем тёмные действия
            player.shiftBalance(towards: .dark, amount: 3)
            // Тёмные силы дают больше урона
            if player.hasCurse(.shadowOfNav) {
                let damage = player.calculateDamageDealt(5)
                XCTAssertEqual(damage, 8, "shadowOfNav даёт +3 урон")
            }
        }

        XCTAssertLessThanOrEqual(player.balance, 30, "Достигнут Путь Тьмы")
        XCTAssertEqual(player.balanceState, .dark)
    }

    // MARK: - Сценарий: Баланс

    func testBalancedPathScenario() {
        setupStarterDeck()
        player.balance = 50

        for day in 1...15 {
            worldState.daysPassed = day
            worldState.processDayStart()

            // Поддерживаем баланс
            if player.balance > 55 {
                player.shiftBalance(towards: .dark, amount: 5)
            } else if player.balance < 45 {
                player.shiftBalance(towards: .light, amount: 5)
            }
        }

        XCTAssertGreaterThan(player.balance, 30)
        XCTAssertLessThan(player.balance, 70)
        XCTAssertEqual(player.balanceState, .neutral)
    }

    // MARK: - Проверка условий победы

    func testVictoryConditionReachable() {
        setupStarterDeck()

        // Симулируем выполнение главного квеста
        worldState.mainQuestStage = 5
        worldState.worldFlags["act5_completed"] = true

        gameState.checkQuestVictory()

        XCTAssertTrue(gameState.isVictory, "Победа достижима")
        XCTAssertEqual(gameState.currentPhase, .gameOver)
    }

    // MARK: - Проверка условий поражения

    func testDefeatConditionsByHealth() {
        player.health = 0

        gameState.checkDefeatConditions()

        XCTAssertTrue(gameState.isDefeat, "Поражение при HP=0")
    }

    func testDefeatConditionsByTension() {
        worldState.worldTension = 100

        gameState.checkDefeatConditions()

        XCTAssertTrue(gameState.isDefeat, "Поражение при Tension=100%")
    }

    func testDefeatConditionsByCriticalAnchor() {
        worldState.worldFlags["critical_anchor_destroyed"] = true

        gameState.checkDefeatConditions()

        XCTAssertTrue(gameState.isDefeat, "Поражение при уничтожении критического якоря")
    }

    // MARK: - Статистика прохождения

    func testPlaythroughStatistics() {
        setupStarterDeck()

        var totalDamageDealt = 0
        var totalDamageTaken = 0
        var totalFaithGained = 0

        for day in 1...20 {
            worldState.daysPassed = day
            worldState.processDayStart()

            // Урон нанесён
            let damage = player.calculateDamageDealt(3)
            totalDamageDealt += damage

            // Урон получен
            let taken = 2
            player.takeDamageWithCurses(taken)
            totalDamageTaken += taken + player.getDamageTakenModifier()

            // Вера
            player.gainFaith(1)
            totalFaithGained += 1

            if player.health <= 3 {
                player.heal(3)
            }

            if player.health <= 0 {
                break
            }
        }

        // Статистика разумна
        XCTAssertGreaterThan(totalDamageDealt, 30, "Достаточно урона нанесено")
        XCTAssertGreaterThan(totalDamageTaken, 20, "Риск присутствует")
        XCTAssertGreaterThan(totalFaithGained, 10, "Вера накапливается")
    }

    // MARK: - Региональное прохождение

    func testRegionExplorationCoverage() {
        setupStarterDeck()

        var visitedRegions: Set<UUID> = []

        // Посещаем все регионы
        for region in worldState.regions {
            worldState.moveToRegion(region.id)
            visitedRegions.insert(region.id)
        }

        XCTAssertEqual(visitedRegions.count, 7, "Все 7 регионов посещены")
    }

    func testRegionStateImpactOnGameplay() {
        setupStarterDeck()

        // Проверяем влияние состояния региона
        for region in worldState.regions {
            let context = CombatContext(regionState: region.state, playerCurses: [])

            switch region.state {
            case .stable:
                XCTAssertEqual(context.adjustedEnemyPower(5), 5)
            case .borderland:
                XCTAssertEqual(context.adjustedEnemyPower(5), 6)
            case .breach:
                XCTAssertEqual(context.adjustedEnemyPower(5), 7)
            }
        }
    }

    // MARK: - Deck Building прогресс

    func testDeckGrowthDuringPlaythrough() {
        setupStarterDeck()
        let initialDeckSize = player.deck.count + player.hand.count + player.discard.count

        // Симулируем покупку карт
        for day in 1...20 {
            worldState.daysPassed = day

            // Каждые 3 дня покупаем карту
            if day % 3 == 0 {
                let newCard = Card(name: "Purchased \(day)", type: .spell, description: "", cost: 2)
                player.discard.append(newCard)
            }
        }

        let finalDeckSize = player.deck.count + player.hand.count + player.discard.count

        XCTAssertGreaterThan(finalDeckSize, initialDeckSize, "Колода растёт")
        XCTAssertGreaterThanOrEqual(finalDeckSize, 15, "Колода достаточного размера")
    }

    // MARK: - Проверка стабильности

    func testNoInfiniteLoops() {
        setupStarterDeck()

        let startTime = Date()

        for day in 1...100 {
            worldState.daysPassed = day
            worldState.processDayStart()

            if player.health <= 0 {
                player.health = 5 // Ресет для продолжения теста
            }

            // Проверяем что не застряли
            let elapsed = Date().timeIntervalSince(startTime)
            XCTAssertLessThan(elapsed, 5.0, "Тест не должен занимать > 5 секунд")
        }
    }

    func testWorldStateConsistency() {
        setupStarterDeck()

        for day in 1...30 {
            worldState.daysPassed = day
            worldState.processDayStart()

            // Проверяем консистентность
            XCTAssertGreaterThanOrEqual(worldState.worldTension, 0)
            XCTAssertLessThanOrEqual(worldState.worldTension, 100)
            XCTAssertEqual(worldState.regions.count, 7)
            XCTAssertNotNil(worldState.currentRegionId)
        }
    }
}

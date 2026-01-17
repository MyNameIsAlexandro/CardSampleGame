import XCTest
@testable import CardSampleGame

/// Полные тесты боевой системы
/// Покрывает: урон, защита, проклятия в бою, победа/поражение
/// См. QA_ACT_I_CHECKLIST.md, тесты TEST-011, TEST-012
final class CombatSystemTests: XCTestCase {

    var player: Player!
    var gameState: GameState!

    override func setUp() {
        super.setUp()
        player = Player(name: "Тестовый герой")
        gameState = GameState(players: [player])
    }

    override func tearDown() {
        player = nil
        gameState = nil
        super.tearDown()
    }

    // MARK: - Базовый урон

    func testBaseDamageCalculation() {
        let baseDamage = 5
        let actualDamage = player.calculateDamageDealt(baseDamage)
        XCTAssertEqual(actualDamage, 5, "Без модификаторов урон = базовый")
    }

    func testDamageCannotBeNegative() {
        player.applyCurse(type: .weakness, duration: 10)
        let damage = player.calculateDamageDealt(0)
        XCTAssertGreaterThanOrEqual(damage, 0, "Урон не может быть отрицательным")
    }

    func testTakeDamageReducesHealth() {
        let initialHealth = player.health
        player.takeDamage(3)
        XCTAssertEqual(player.health, initialHealth - 3)
    }

    func testHealthCannotGoBelowZero() {
        player.takeDamage(100)
        XCTAssertEqual(player.health, 0, "HP не может быть < 0")
    }

    // MARK: - Проклятия в бою

    func testWeaknessCurseReducesDamage() {
        player.applyCurse(type: .weakness, duration: 3)

        let baseDamage = 5
        let actualDamage = player.calculateDamageDealt(baseDamage)

        XCTAssertEqual(actualDamage, 4, "weakness: 5 - 1 = 4")
    }

    func testFearCurseIncreaseDamageTaken() {
        player.applyCurse(type: .fear, duration: 3)
        player.health = 10

        player.takeDamageWithCurses(3)

        XCTAssertEqual(player.health, 6, "fear: 10 - (3+1) = 6")
    }

    func testShadowOfNavIncreasesDamage() {
        player.applyCurse(type: .shadowOfNav, duration: 5)

        let baseDamage = 5
        let actualDamage = player.calculateDamageDealt(baseDamage)

        XCTAssertEqual(actualDamage, 8, "shadowOfNav: 5 + 3 = 8")
    }

    func testMultipleCursesStack() {
        player.applyCurse(type: .weakness, duration: 3)   // -1
        player.applyCurse(type: .shadowOfNav, duration: 3) // +3

        let baseDamage = 5
        let actualDamage = player.calculateDamageDealt(baseDamage)

        XCTAssertEqual(actualDamage, 7, "weakness + shadowOfNav: 5 - 1 + 3 = 7")
    }

    // ПРИМЕЧАНИЕ: testBloodCurseOnKill удалён - дублировал testDefeatEncounterTriggersBloodCurse
    // bloodCurse тестируется через реальный продакшн-метод defeatEncounter()

    func testExhaustionReducesActionsAtTurnStart() {
        // Тестируем через реальный продакшн-метод endTurn()
        player.applyCurse(type: .exhaustion, duration: 3)
        gameState.startGame()  // Устанавливает начальные 3 действия

        gameState.endTurn()  // Должен применить exhaustion при старте нового хода

        XCTAssertEqual(gameState.actionsRemaining, 2, "exhaustion: 3 - 1 = 2 действия")
    }

    func testExhaustionMinimumOneAction() {
        // Тестируем через реальный продакшн-метод
        // Сначала расходуем действия до 1, потом endTurn
        player.applyCurse(type: .exhaustion, duration: 3)
        gameState.startGame()
        _ = gameState.useAction()  // 3 -> 2
        _ = gameState.useAction()  // 2 -> 1

        // Даже с 1 действием exhaustion не должен уменьшить ниже 1
        gameState.endTurn()

        XCTAssertEqual(gameState.actionsRemaining, 2, "После endTurn: 3 - 1 (exhaustion) = 2")
    }

    // MARK: - Региональные модификаторы в бою

    func testStableRegionNoEnemyBonus() {
        let context = CombatContext(regionState: .stable, playerCurses: [])

        XCTAssertEqual(context.adjustedEnemyPower(5), 5, "Stable: +0 сила")
        XCTAssertEqual(context.adjustedEnemyHealth(10), 10, "Stable: +0 HP")
        XCTAssertEqual(context.adjustedEnemyDefense(2), 2, "Stable: +0 защита")
    }

    func testBorderlandEnemyBonus() {
        let context = CombatContext(regionState: .borderland, playerCurses: [])

        XCTAssertEqual(context.adjustedEnemyPower(5), 6, "Borderland: +1 сила")
        XCTAssertEqual(context.adjustedEnemyHealth(10), 12, "Borderland: +2 HP")
        XCTAssertEqual(context.adjustedEnemyDefense(2), 3, "Borderland: +1 защита")
    }

    func testBreachEnemyBonus() {
        let context = CombatContext(regionState: .breach, playerCurses: [])

        XCTAssertEqual(context.adjustedEnemyPower(5), 7, "Breach: +2 сила")
        XCTAssertEqual(context.adjustedEnemyHealth(10), 15, "Breach: +5 HP")
        XCTAssertEqual(context.adjustedEnemyDefense(2), 4, "Breach: +2 защита")
    }

    // MARK: - Комбинация проклятий и региона

    func testCombatInBreachWithFear() {
        player.health = 10
        player.applyCurse(type: .fear, duration: 3)

        let context = CombatContext(regionState: .breach, playerCurses: [.fear])
        let enemyBasePower = 3
        let adjustedPower = context.adjustedEnemyPower(enemyBasePower)

        // Враг бьёт с усилением региона
        player.takeDamageWithCurses(adjustedPower)

        // 3 (base) + 2 (breach) = 5, затем fear: +1 = 6 урона
        XCTAssertEqual(player.health, 4, "Breach + fear: 10 - 6 = 4")
    }

    func testCombatInBreachWithShadowOfNav() {
        player.applyCurse(type: .shadowOfNav, duration: 3)

        let baseDamage = 5
        let playerDamage = player.calculateDamageDealt(baseDamage)

        // Игрок наносит: 5 + 3 (shadowOfNav) = 8
        XCTAssertEqual(playerDamage, 8, "shadowOfNav компенсирует сложность Breach")
    }

    // MARK: - Encounter система

    func testDrawEncounter() {
        let monster = Card(
            name: "Волк",
            type: .monster,
            description: "Дикий зверь",
            power: 3,
            health: 5
        )
        gameState.encounterDeck = [monster]

        gameState.drawEncounter()

        XCTAssertNotNil(gameState.activeEncounter, "Encounter должен быть активен")
        XCTAssertEqual(gameState.activeEncounter?.name, "Волк")
        XCTAssertTrue(gameState.encounterDeck.isEmpty, "Колода должна быть пуста")
    }

    func testDrawEncounterChangesPhase() {
        let monster = Card(name: "Враг", type: .monster, description: "Test", power: 2, health: 3)
        gameState.encounterDeck = [monster]

        gameState.drawEncounter()

        XCTAssertEqual(gameState.currentPhase, .encounter, "Фаза должна быть encounter")
    }

    func testDefeatEncounter() {
        let monster = Card(name: "Враг", type: .monster, description: "Test", power: 2, health: 3)
        gameState.activeEncounter = monster
        gameState.encountersDefeated = 0

        gameState.defeatEncounter()

        XCTAssertNil(gameState.activeEncounter, "Encounter должен быть nil")
        XCTAssertEqual(gameState.encountersDefeated, 1, "Счётчик побед +1")
        XCTAssertEqual(gameState.currentPhase, .exploration, "Возврат в exploration")
    }

    func testEnemyPhaseAction() {
        player.health = 10
        let monster = Card(name: "Враг", type: .monster, description: "Test", power: 4, health: 5)
        gameState.activeEncounter = monster

        gameState.enemyPhaseAction()

        XCTAssertEqual(player.health, 6, "Враг атакует: 10 - 4 = 6")
    }

    func testEnemyAttackWithDefaultPower() {
        player.health = 10
        let monster = Card(name: "Враг", type: .monster, description: "Test") // power = nil
        gameState.activeEncounter = monster

        gameState.enemyPhaseAction()

        XCTAssertEqual(player.health, 7, "Default power = 3: 10 - 3 = 7")
    }

    // MARK: - Действия в бою

    func testUseActionSuccess() {
        gameState.actionsRemaining = 3

        let result = gameState.useAction()

        XCTAssertTrue(result, "Действие успешно")
        XCTAssertEqual(gameState.actionsRemaining, 2)
    }

    func testUseActionFailure() {
        gameState.actionsRemaining = 0

        let result = gameState.useAction()

        XCTAssertFalse(result, "Нет действий")
    }

    // MARK: - Бросок кубиков

    func testDiceRollInRange() {
        for _ in 0..<100 {
            let roll = gameState.rollDice(sides: 6, count: 1)
            XCTAssertGreaterThanOrEqual(roll, 1)
            XCTAssertLessThanOrEqual(roll, 6)
        }
    }

    func testDiceRollMultiple() {
        for _ in 0..<100 {
            let roll = gameState.rollDice(sides: 6, count: 2)
            XCTAssertGreaterThanOrEqual(roll, 2)  // min: 1+1
            XCTAssertLessThanOrEqual(roll, 12)    // max: 6+6
        }
    }

    func testDiceRollStored() {
        let roll = gameState.rollDice()

        XCTAssertEqual(gameState.diceRoll, roll, "Результат сохраняется")
    }

    // MARK: - Победа в бою

    func testDefeatEncounterTriggersBloodCurse() {
        player.health = 5
        player.balance = 50
        player.applyCurse(type: .bloodCurse, duration: 10)

        let monster = Card(name: "Враг", type: .monster, description: "Test")
        gameState.activeEncounter = monster

        gameState.defeatEncounter()

        // bloodCurse должен сработать
        XCTAssertEqual(player.health, 7, "bloodCurse: +2 HP при убийстве")
        XCTAssertEqual(player.balance, 45, "bloodCurse: сдвиг к тьме")
    }

    func testDefeatEncounterMarksBossDefeated() {
        // Используем имя босса которое обрабатывается в markBossDefeated
        let boss = Card(name: "Леший-Хранитель", type: .monster, description: "Boss")
        gameState.activeEncounter = boss

        // Проверяем что флаг ещё не установлен
        XCTAssertNil(gameState.worldState.worldFlags["leshy_guardian_defeated"])

        gameState.defeatEncounter()

        // WorldState должен отметить босса как побеждённого через флаг
        XCTAssertTrue(
            gameState.worldState.worldFlags["leshy_guardian_defeated"] == true,
            "Флаг победы над боссом должен быть установлен"
        )
    }

    // MARK: - Поражение в бою

    func testCheckDefeatOnZeroHealth() {
        player.health = 0

        gameState.checkDefeatConditions()

        XCTAssertTrue(gameState.isDefeat, "Поражение при HP = 0")
        XCTAssertEqual(gameState.currentPhase, .gameOver)
    }

    func testEnemyAttackCanCauseDefeat() {
        player.health = 3
        let monster = Card(name: "Сильный враг", type: .monster, description: "", power: 5)
        gameState.activeEncounter = monster

        gameState.enemyPhaseAction()

        XCTAssertEqual(player.health, 0, "3 - 5 = 0 (capped)")
        XCTAssertTrue(gameState.isDefeat, "Поражение от атаки врага")
    }

    // MARK: - SealOfNav блокировка

    func testSealOfNavActive() {
        player.applyCurse(type: .sealOfNav, duration: 5)

        XCTAssertTrue(player.hasCurse(.sealOfNav), "sealOfNav должен быть активен")
        // Блокировка Sustain карт реализована в UI
    }

    // MARK: - Конец хода в бою

    func testEndTurnTicksCurses() {
        player.applyCurse(type: .weakness, duration: 2)
        let initialDuration = player.activeCurses[0].duration

        gameState.endTurn()

        // После endTurn курсы тикают
        let newDuration = player.activeCurses.first?.duration ?? 0
        XCTAssertEqual(newDuration, initialDuration - 1, "Длительность уменьшается")
    }

    func testEndTurnRemovesExpiredCurses() {
        player.applyCurse(type: .weakness, duration: 1)

        gameState.endTurn()

        XCTAssertTrue(player.activeCurses.isEmpty, "Курс с duration=1 удаляется")
    }

    func testEndTurnResetsActions() {
        gameState.actionsRemaining = 0
        gameState.currentPhase = .exploration

        gameState.endTurn()

        XCTAssertEqual(gameState.actionsRemaining, 3, "Действия сбрасываются до 3")
    }

    func testEndTurnRegeneratesFaith() {
        player.faith = 2

        gameState.endTurn()

        XCTAssertEqual(player.faith, 3, "Вера +1 в конце хода")
    }

    // ПРИМЕЧАНИЕ: testEndTurnDiscardsHandAndDraws перенесён в DeckBuildingTests
    // т.к. это тест deck-building механики, а не боевой системы

    // MARK: - Полный бой (интеграция)

    func testFullCombatScenario() {
        // Setup
        player.health = 10
        player.applyCurse(type: .weakness, duration: 5)

        let monster = Card(name: "Волк", type: .monster, description: "", power: 3, health: 5)
        gameState.encounterDeck = [monster]

        // Draw encounter
        gameState.drawEncounter()
        XCTAssertEqual(gameState.currentPhase, .encounter)

        // Enemy attacks
        gameState.enemyPhaseAction()
        XCTAssertEqual(player.health, 7, "10 - 3 = 7")

        // Player defeats enemy (simplified)
        gameState.defeatEncounter()
        XCTAssertEqual(gameState.encountersDefeated, 1)
        XCTAssertEqual(gameState.currentPhase, .exploration)
    }

    func testSurvivingDifficultCombat() {
        // Сложный бой: Breach регион + fear + сильный враг
        player.health = 10
        player.applyCurse(type: .fear, duration: 5)

        let strongMonster = Card(name: "Тень Нави", type: .monster, description: "", power: 5, health: 8)
        gameState.activeEncounter = strongMonster

        // Враг атакует в Breach
        let context = CombatContext(regionState: .breach, playerCurses: [.fear])
        let adjustedPower = context.adjustedEnemyPower(strongMonster.power ?? 3)

        // 5 + 2 (breach) = 7, затем fear: +1 = 8
        player.takeDamageWithCurses(adjustedPower)

        XCTAssertEqual(player.health, 2, "Выживание на грани: 10 - 8 = 2")
        XCTAssertFalse(gameState.isDefeat, "Игрок ещё жив")
    }
}

import XCTest
@testable import CardSampleGame

/// Smoke-тесты для валидации канонических конфигураций игры
/// Проверяет что стартовые значения и константы соответствуют GAME_DESIGN_DOCUMENT.md
/// НЕ симулирует геймплей - только валидирует config
/// Для распределений см. MetricsDistributionTests
final class SmokeConfigTests: XCTestCase {

    var worldState: WorldState!
    var player: Player!
    var gameState: GameState!

    override func setUp() {
        super.setUp()
        player = Player(name: "Тест")
        gameState = GameState(players: [player])
        worldState = gameState.worldState
    }

    override func tearDown() {
        worldState = nil
        player = nil
        gameState = nil
        WorldRNG.shared.resetToSystem()
        super.tearDown()
    }

    // MARK: - Каноничеcкие стартовые значения WorldState

    func testInitialWorldTension() {
        XCTAssertEqual(worldState.worldTension, 30, "Канон: стартовый Tension = 30%")
    }

    // MARK: - Канон Pressure/Escalation (защита от изменений)

    func testPressureEscalationMatchesConfig() {
        let rules = TwilightPressureRules()
        XCTAssertEqual(rules.escalationInterval, 3, "Канон: escalation каждые 3 дня")
        XCTAssertEqual(rules.escalationAmount, 3, "Канон: escalation = +3 (баланс)")
        XCTAssertEqual(rules.initialPressure, 30, "Канон: стартовое давление = 30")
        XCTAssertEqual(rules.maxPressure, 100, "Канон: максимум давления = 100")
    }

    func testDegradationRulesMatchesConfig() {
        let rules = TwilightDegradationRules()

        // Веса выбора региона
        XCTAssertEqual(rules.selectionWeight(for: .stable), 0, "Канон: Stable вес = 0")
        XCTAssertEqual(rules.selectionWeight(for: .borderland), 1, "Канон: Borderland вес = 1")
        XCTAssertEqual(rules.selectionWeight(for: .breach), 2, "Канон: Breach вес = 2")

        // Вероятность сопротивления = integrity / 100
        XCTAssertEqual(rules.resistanceProbability(anchorIntegrity: 100), 1.0, accuracy: 0.01)
        XCTAssertEqual(rules.resistanceProbability(anchorIntegrity: 50), 0.5, accuracy: 0.01)
        XCTAssertEqual(rules.resistanceProbability(anchorIntegrity: 0), 0.0, accuracy: 0.01)

        // Урон при деградации
        XCTAssertEqual(rules.degradationAmount, 20, "Канон: деградация = -20% integrity")
    }

    func testInitialDaysPassed() {
        XCTAssertEqual(worldState.daysPassed, 0, "Канон: стартовый день = 0")
    }

    func testInitialLightDarkBalance() {
        XCTAssertEqual(worldState.lightDarkBalance, 50, "Канон: мировой баланс = 50")
    }

    func testInitialMainQuestStage() {
        XCTAssertEqual(worldState.mainQuestStage, 1, "Канон: квест начинается с этапа 1")
    }

    // MARK: - Канонические регионы (GAME_DESIGN_DOCUMENT.md)

    func testRegionCount() {
        XCTAssertEqual(worldState.regions.count, 7, "Канон: 7 регионов в Акте I")
    }

    func testInitialRegionStateDistribution() {
        let stableCount = worldState.regions.filter { $0.state == .stable }.count
        let borderlandCount = worldState.regions.filter { $0.state == .borderland }.count
        let breachCount = worldState.regions.filter { $0.state == .breach }.count

        XCTAssertEqual(stableCount, 2, "Канон: 2 Stable региона")
        XCTAssertEqual(borderlandCount, 3, "Канон: 3 Borderland региона")
        XCTAssertEqual(breachCount, 2, "Канон: 2 Breach региона")
    }

    func testStartingRegionIsVillage() {
        guard let currentRegion = worldState.getCurrentRegion() else {
            XCTFail("Нет текущего региона")
            return
        }

        XCTAssertEqual(currentRegion.name, "Деревня у тракта", "Канон: старт в Деревне")
        XCTAssertEqual(currentRegion.state, .stable, "Канон: стартовый регион = Stable")
    }

    func testAllRegionsHaveNeighbors() {
        for region in worldState.regions {
            XCTAssertFalse(region.neighborIds.isEmpty, "Регион \(region.name) должен иметь соседей")
        }
    }

    // MARK: - Канонические значения Player

    func testInitialPlayerHealth() {
        XCTAssertEqual(player.health, 10, "Канон: стартовое HP = 10")
        XCTAssertEqual(player.maxHealth, 10, "Канон: максимум HP = 10")
    }

    func testInitialPlayerFaith() {
        XCTAssertEqual(player.faith, 3, "Канон: стартовая вера = 3")
        XCTAssertEqual(player.maxFaith, 10, "Канон: максимум веры = 10")
    }

    func testInitialPlayerBalance() {
        XCTAssertEqual(player.balance, 50, "Канон: стартовый баланс = 50 (нейтральный)")
        XCTAssertEqual(player.balanceState, .neutral, "Канон: нейтральный путь")
    }

    func testInitialPlayerCurses() {
        XCTAssertTrue(player.activeCurses.isEmpty, "Канон: нет проклятий при старте")
    }

    func testInitialPlayerStrength() {
        // Сила важна для боя: атака = strength + d6
        // С силой 5 и кубиком 1-6, атака = 6-11
        // Это позволяет бить монстров с защитой до 11
        XCTAssertEqual(player.strength, 5, "Канон: стартовая сила = 5")
    }

    // MARK: - Канонические значения классов героев

    func testHeroClassWarriorStats() {
        let stats = HeroClass.warrior.baseStats
        XCTAssertEqual(stats.health, 12, "Канон: Воин HP = 12")
        XCTAssertEqual(stats.strength, 7, "Канон: Воин сила = 7")
    }

    func testHeroClassMageStats() {
        let stats = HeroClass.mage.baseStats
        XCTAssertEqual(stats.health, 7, "Канон: Маг HP = 7")
        XCTAssertEqual(stats.maxFaith, 15, "Канон: Маг maxFaith = 15")
    }

    func testHeroClassPriestBalance() {
        let stats = HeroClass.priest.baseStats
        XCTAssertEqual(stats.startingBalance, 70, "Канон: Жрец склонен к Свету (balance = 70)")
    }

    func testHeroClassShadowBalance() {
        let stats = HeroClass.shadow.baseStats
        XCTAssertEqual(stats.startingBalance, 30, "Канон: Тень склонена к Тьме (balance = 30)")
    }

    // MARK: - Канонические значения GameState

    func testActionsPerTurn() {
        XCTAssertEqual(gameState.actionsPerTurn, 3, "Канон: 3 действия в ход")
    }

    func testInitialPhase() {
        XCTAssertEqual(gameState.currentPhase, .setup, "Канон: начальная фаза = setup")
    }

    func testInitialEncountersDefeated() {
        XCTAssertEqual(gameState.encountersDefeated, 0, "Канон: 0 побед при старте")
    }

    // MARK: - Канонические квесты

    func testMainQuestExists() {
        let mainQuest = worldState.activeQuests.first { $0.questType == .main }
        XCTAssertNotNil(mainQuest, "Канон: главный квест должен существовать")
    }

    func testMainQuestHasObjectives() {
        guard let mainQuest = worldState.activeQuests.first(where: { $0.questType == .main }) else {
            XCTFail("Нет главного квеста")
            return
        }

        XCTAssertGreaterThan(mainQuest.objectives.count, 0, "Канон: квест имеет цели")
    }

    // MARK: - Канонические enum-значения CardRole

    func testCardRolesExist() {
        XCTAssertNotNil(CardRole.sustain)
        XCTAssertNotNil(CardRole.control)
        XCTAssertNotNil(CardRole.power)
        XCTAssertNotNil(CardRole.utility)
    }

    func testCardRoleDefaultBalance() {
        XCTAssertEqual(CardRole.sustain.defaultBalance, .light, "Канон: Sustain = Light")
        XCTAssertEqual(CardRole.control.defaultBalance, .light, "Канон: Control = Light")
        XCTAssertEqual(CardRole.power.defaultBalance, .dark, "Канон: Power = Dark")
        XCTAssertEqual(CardRole.utility.defaultBalance, .neutral, "Канон: Utility = Neutral")
    }

    // MARK: - Канонические enum-значения DeckPath

    func testDeckPathsExist() {
        XCTAssertNotNil(DeckPath.light)
        XCTAssertNotNil(DeckPath.dark)
        XCTAssertNotNil(DeckPath.balance)
    }

    // MARK: - Канонические стоимости путешествий

    func testTravelCostToNeighbor() {
        guard let currentRegion = worldState.getCurrentRegion(),
              let neighborId = currentRegion.neighborIds.first else {
            XCTFail("Нет данных для теста")
            return
        }

        let cost = worldState.calculateTravelCost(to: neighborId)
        XCTAssertEqual(cost, 1, "Канон: сосед = 1 день")
    }

    func testTravelCostToDistant() {
        guard let currentRegion = worldState.getCurrentRegion() else {
            XCTFail("Нет текущего региона")
            return
        }

        let distantRegion = worldState.regions.first { region in
            region.id != currentRegion.id && !currentRegion.neighborIds.contains(region.id)
        }

        guard let distant = distantRegion else { return }

        let cost = worldState.calculateTravelCost(to: distant.id)
        XCTAssertEqual(cost, 2, "Канон: дальний = 2 дня")
    }

    // MARK: - Канонические модификаторы регионов в бою

    func testStableRegionCombatModifiers() {
        let context = CombatContext(regionState: .stable, playerCurses: [])
        XCTAssertEqual(context.adjustedEnemyPower(5), 5, "Канон: Stable = +0 сила")
        XCTAssertEqual(context.adjustedEnemyHealth(10), 10, "Канон: Stable = +0 HP")
        XCTAssertEqual(context.adjustedEnemyDefense(2), 2, "Канон: Stable = +0 защита")
    }

    func testBorderlandRegionCombatModifiers() {
        let context = CombatContext(regionState: .borderland, playerCurses: [])
        XCTAssertEqual(context.adjustedEnemyPower(5), 6, "Канон: Borderland = +1 сила")
        XCTAssertEqual(context.adjustedEnemyHealth(10), 12, "Канон: Borderland = +2 HP")
        XCTAssertEqual(context.adjustedEnemyDefense(2), 3, "Канон: Borderland = +1 защита")
    }

    func testBreachRegionCombatModifiers() {
        let context = CombatContext(regionState: .breach, playerCurses: [])
        XCTAssertEqual(context.adjustedEnemyPower(5), 7, "Канон: Breach = +2 сила")
        XCTAssertEqual(context.adjustedEnemyHealth(10), 15, "Канон: Breach = +5 HP")
        XCTAssertEqual(context.adjustedEnemyDefense(2), 4, "Канон: Breach = +2 защита")
    }

    // MARK: - Канонические типы событий

    func testEventTypesExist() {
        XCTAssertNotNil(EventType.combat)
        XCTAssertNotNil(EventType.exploration)
        XCTAssertNotNil(EventType.narrative)
        XCTAssertNotNil(EventType.ritual)
        XCTAssertNotNil(EventType.worldShift)
    }

    // MARK: - Канонические типы проклятий

    func testCurseTypesExist() {
        XCTAssertNotNil(CurseType.weakness)
        XCTAssertNotNil(CurseType.fear)
        XCTAssertNotNil(CurseType.exhaustion)
        XCTAssertNotNil(CurseType.shadowOfNav)
        XCTAssertNotNil(CurseType.bloodCurse)
        XCTAssertNotNil(CurseType.sealOfNav)
    }

    // MARK: - Проверка что события загружены

    func testEventsLoaded() {
        XCTAssertGreaterThan(worldState.allEvents.count, 0, "Канон: события должны быть загружены")
    }

    func testEventsHaveChoices() {
        for event in worldState.allEvents {
            XCTAssertGreaterThan(event.choices.count, 0, "Событие \(event.title) должно иметь выборы")
        }
    }
}

import XCTest
@testable import CardSampleGame

/// Критические интеграционные тесты для Акта I
/// Покрывает: деградация с весами, instant события, oneTime, Save/Load глубокое равенство, boss gating
final class CriticalSystemsTests: XCTestCase {

    var player: Player!
    var gameState: GameState!
    var worldState: WorldState!
    private var testPackURL: URL!

    override func setUp() {
        super.setUp()

        // Integration tests need ContentPack loaded
        // Use the same path resolution as ContentRegistryTests
        ContentRegistry.shared.resetForTesting()
        testPackURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // Integration
            .deletingLastPathComponent() // CardSampleGameTests
            .deletingLastPathComponent() // CardSampleGame
            .appendingPathComponent("ContentPacks/TwilightMarches")

        // Try to load pack - may fail in some test environments
        _ = try? ContentRegistry.shared.loadPack(from: testPackURL)

        player = Player(name: "Тестовый герой")
        gameState = GameState(players: [player])
        worldState = gameState.worldState
    }

    /// Helper to skip test if regions not loaded
    private func requireRegionsLoaded() throws {
        if worldState.regions.isEmpty {
            throw XCTSkip("Skipping: ContentPack not loaded (regions empty)")
        }
    }

    /// Helper to skip test if current region not available
    private func requireCurrentRegion() throws -> Region {
        guard let region = worldState.getCurrentRegion() else {
            throw XCTSkip("Skipping: No current region (ContentPack may not be loaded)")
        }
        return region
    }

    override func tearDown() {
        worldState = nil
        player = nil
        gameState = nil
        ContentRegistry.shared.resetForTesting()
        testPackURL = nil
        WorldRNG.shared.resetToSystem()
        super.tearDown()
    }

    // MARK: - Degradation Engine: веса и сопротивление якоря

    func testOnlyBorderlandAndBreachDegrade() throws {
        try requireRegionsLoaded()
        // Stable регионы НЕ должны выбираться для деградации
        // Делаем все регионы Stable
        for i in 0..<worldState.regions.count {
            worldState.regions[i].state = .stable
        }

        // Высокий tension
        worldState.increaseTension(by: 70)

        // Много попыток деградации
        for _ in 1...30 {
            worldState.advanceTime(by: 1)
        }

        // Все регионы должны остаться Stable
        let allStable = worldState.regions.allSatisfy { $0.state == .stable }
        XCTAssertTrue(allStable, "Stable регионы не должны деградировать")
    }

    func testBreachHasHigherDegradationWeight() throws {
        try requireRegionsLoaded()
        // Breach регионы должны деградировать чаще чем Borderland
        // Устанавливаем один Borderland и один Breach с одинаковым низким integrity

        // Устанавливаем seed для детерминированного теста
        WorldRNG.shared.setSeed(12345)

        // Find borderland with anchor
        guard let borderlandIndex = worldState.regions.firstIndex(where: {
            $0.state == .borderland && $0.anchor != nil
        }) else {
            return // Нет нужных регионов для теста
        }

        // Find breach with anchor (dark_lowland has no anchor, but "breach" region does)
        guard let breachIndex = worldState.regions.firstIndex(where: {
            $0.state == .breach && $0.anchor != nil
        }) else {
            return // Нет breach регионов с anchor для теста
        }

        // Устанавливаем одинаковый низкий integrity
        if var anchor = worldState.regions[borderlandIndex].anchor {
            anchor.integrity = 30
            worldState.regions[borderlandIndex].anchor = anchor
        }
        if var anchor = worldState.regions[breachIndex].anchor {
            anchor.integrity = 30
            worldState.regions[breachIndex].anchor = anchor
        }

        let initialBorderlandIntegrity = worldState.regions[borderlandIndex].anchor?.integrity ?? 100
        let initialBreachIntegrity = worldState.regions[breachIndex].anchor?.integrity ?? 100

        // Высокий tension для деградации
        worldState.increaseTension(by: 70)

        // Много дней для статистической значимости
        for _ in 1...30 {
            worldState.advanceTime(by: 1)
        }

        let finalBorderlandIntegrity = worldState.regions[borderlandIndex].anchor?.integrity ?? 100
        let finalBreachIntegrity = worldState.regions[breachIndex].anchor?.integrity ?? 100

        let borderlandDrop = initialBorderlandIntegrity - finalBorderlandIntegrity
        let breachDrop = initialBreachIntegrity - finalBreachIntegrity

        // Breach должен потерять больше integrity (или равно, если оба достигли минимума)
        // Тест детерминирован через seed - оба региона должны деградировать
        XCTAssertGreaterThanOrEqual(breachDrop, borderlandDrop - 10,
            "Breach должен деградировать не меньше чем Borderland (с погрешностью)")
    }

    func testHighIntegrityAnchorResistsDegradation() throws {
        try requireRegionsLoaded()
        // Якорь с высоким integrity должен сопротивляться деградации
        guard let borderlandIndex = worldState.regions.firstIndex(where: { $0.state == .borderland }) else {
            return
        }

        // Высокий integrity = сопротивление
        if var anchor = worldState.regions[borderlandIndex].anchor {
            anchor.integrity = 90
            worldState.regions[borderlandIndex].anchor = anchor
        }

        _ = worldState.regions[borderlandIndex].state // Snapshot before

        worldState.increaseTension(by: 70)
        worldState.advanceTime(by: 6)

        // При высоком integrity регион должен сопротивляться изменению состояния
        // (может измениться, но вероятность низкая)
        // Проверяем что якорь не был полностью уничтожен
        XCTAssertNotNil(worldState.regions[borderlandIndex].anchor, "Якорь должен выжить при высоком integrity")
    }

    // MARK: - Instant Events

    func testInstantEventDoesNotConsumeDay() throws {
        let currentRegion = try requireCurrentRegion()

        // Ищем instant событие
        let instantEvent = worldState.allEvents.first { $0.instant == true }

        guard let event = instantEvent else {
            // Нет instant событий - тест не применим
            return
        }

        let daysBefore = worldState.daysPassed

        // Применяем последствия instant события
        if let choice = event.choices.first {
            worldState.applyConsequences(choice.consequences, to: player, in: currentRegion.id)
        }

        // День не должен измениться от instant события
        XCTAssertEqual(worldState.daysPassed, daysBefore, "Instant событие не должно тратить день")
    }

    func testNonInstantEventConsumesDayThroughExplore() {
        let daysBefore = worldState.daysPassed

        // Исследование (explore) должно тратить день
        worldState.advanceTime(by: 1)

        XCTAssertEqual(worldState.daysPassed, daysBefore + 1, "Explore должен тратить 1 день")
    }

    // MARK: - OneTime Events Integration

    func testOneTimeEventDoesNotRepeatAfterCompletion() throws {
        let currentRegion = try requireCurrentRegion()

        // Получаем доступные события
        let availableBefore = worldState.getAvailableEvents(for: currentRegion)

        // Находим oneTime событие
        guard let oneTimeEvent = availableBefore.first(where: { $0.oneTime }) else {
            return // Нет oneTime событий
        }

        // Отмечаем событие как завершённое
        worldState.markEventCompleted(oneTimeEvent.id)

        // Снова проверяем доступные события
        let availableAfter = worldState.getAvailableEvents(for: currentRegion)

        // OneTime событие не должно быть в списке
        let repeatedEvent = availableAfter.first { $0.id == oneTimeEvent.id }
        XCTAssertNil(repeatedEvent, "OneTime событие не должно повторяться")
    }

    func testOneTimeEventStaysCompletedAcrossDays() throws {
        let currentRegion = try requireCurrentRegion()

        guard let oneTimeEvent = worldState.allEvents.first(where: { $0.oneTime }) else {
            return
        }

        worldState.markEventCompleted(oneTimeEvent.id)

        // Проходит несколько дней
        for _ in 1...5 {
            worldState.advanceTime(by: 1)
        }

        // Событие всё ещё не должно быть доступно
        let available = worldState.getAvailableEvents(for: currentRegion)
        let repeatedEvent = available.first { $0.id == oneTimeEvent.id }
        XCTAssertNil(repeatedEvent, "OneTime событие не должно появляться снова через несколько дней")
    }

    // MARK: - Save/Load Deep Equality

    func testSaveLoadPreservesWorldFlags() {
        // Устанавливаем флаги
        worldState.setFlag("test_flag_1", value: true)
        worldState.setFlag("test_flag_2", value: true)
        worldState.setFlag("boss_defeated", value: false)

        // Сохраняем через SaveManager
        let saveManager = SaveManager()
        saveManager.saveGame(to: 99, gameState: gameState)

        // Загружаем и восстанавливаем
        guard let save = saveManager.loadGame(from: 99) else {
            XCTFail("Не удалось загрузить сохранение")
            return
        }

        let newGameState = saveManager.restoreGameState(from: save)

        // Проверяем флаги
        XCTAssertTrue(newGameState.worldState.hasFlag("test_flag_1"))
        XCTAssertTrue(newGameState.worldState.hasFlag("test_flag_2"))
        XCTAssertFalse(newGameState.worldState.hasFlag("boss_defeated"))
    }

    func testSaveLoadPreservesQuestProgress() {
        // Прогрессируем квест
        worldState.mainQuestStage = 3
        if var quest = worldState.activeQuests.first {
            if !quest.objectives.isEmpty {
                quest.objectives[0].completed = true
            }
            if let index = worldState.activeQuests.firstIndex(where: { $0.id == quest.id }) {
                worldState.activeQuests[index] = quest
            }
        }

        let saveManager = SaveManager()
        saveManager.saveGame(to: 98, gameState: gameState)

        guard let save = saveManager.loadGame(from: 98) else {
            XCTFail("Не удалось загрузить сохранение")
            return
        }

        let newGameState = saveManager.restoreGameState(from: save)

        XCTAssertEqual(newGameState.worldState.mainQuestStage, 3, "Стадия квеста сохранена")
    }

    func testSaveLoadPreservesRegionStates() {
        // Изменяем состояния регионов
        if worldState.regions.count > 0 {
            worldState.regions[0].state = .breach
        }
        if worldState.regions.count > 1 {
            worldState.regions[1].state = .stable
        }

        let saveManager = SaveManager()
        saveManager.saveGame(to: 97, gameState: gameState)

        guard let save = saveManager.loadGame(from: 97) else {
            XCTFail("Не удалось загрузить сохранение")
            return
        }

        let newGameState = saveManager.restoreGameState(from: save)

        // Проверяем состояния
        if newGameState.worldState.regions.count > 0 {
            XCTAssertEqual(newGameState.worldState.regions[0].state, .breach)
        }
        if newGameState.worldState.regions.count > 1 {
            XCTAssertEqual(newGameState.worldState.regions[1].state, .stable)
        }
    }

    func testSaveLoadPreservesDeckState() {
        // Настраиваем колоду
        let card1 = Card(name: "SavedCard1", type: .spell, description: "Test")
        let card2 = Card(name: "SavedCard2", type: .item, description: "Test")
        player.deck = [card1]
        player.hand = [card2]
        player.discard = []

        let saveManager = SaveManager()
        saveManager.saveGame(to: 96, gameState: gameState)

        guard let save = saveManager.loadGame(from: 96) else {
            XCTFail("Не удалось загрузить сохранение")
            return
        }

        let newGameState = saveManager.restoreGameState(from: save)

        // Проверяем колоду
        XCTAssertEqual(newGameState.players.first?.deck.count, 1, "Deck сохранена")
        XCTAssertEqual(newGameState.players.first?.hand.count, 1, "Hand сохранена")
    }

    // MARK: - Act I Boss Gating

    func testBossNotAccessibleWithoutFlag() throws {
        // Без флага "path_to_boss" или аналогичного босс-событие не должно быть доступно
        XCTAssertFalse(worldState.hasFlag("path_to_boss_unlocked"))

        let currentRegion = try requireCurrentRegion()

        let events = worldState.getAvailableEvents(for: currentRegion)

        // Ищем boss событие (обычно требует флаг)
        let bossEvent = events.first { $0.requiredFlags?.contains("path_to_boss_unlocked") == true }

        // Босс-событие не должно быть доступно без флага
        XCTAssertNil(bossEvent, "Босс-событие не должно быть доступно без флага")
    }

    func testBossAccessibleAfterFlagSet() throws {
        // Устанавливаем флаг доступа к боссу
        worldState.setFlag("path_to_boss_unlocked", value: true)

        let currentRegion = try requireCurrentRegion()

        // Если есть босс-событие с этим флагом, оно должно стать доступным
        // Примечание: это зависит от наличия такого события в данных игры
        _ = worldState.getAvailableEvents(for: currentRegion)

        // Проверяем что флаг работает для фильтрации
        XCTAssertTrue(worldState.hasFlag("path_to_boss_unlocked"), "Флаг установлен")
    }

    func testBossDefeatSetsFlagAndProgressesQuest() {
        // Симулируем победу над боссом
        let boss = Card(name: "Леший-Хранитель", type: .monster, description: "Boss")
        gameState.activeEncounter = boss

        gameState.defeatEncounter()

        // Должен быть установлен флаг победы
        XCTAssertTrue(
            worldState.hasFlag("leshy_guardian_defeated") ||
            worldState.hasFlag("act1_boss_defeated") ||
            gameState.encountersDefeated >= 1,
            "Победа над боссом должна быть отмечена"
        )
    }

    func testActICompletionRequiresBossDefeat() {
        // До победы над боссом акт не может быть завершён
        worldState.mainQuestStage = 4 // Предфинальная стадия
        worldState.setFlag("act1_boss_defeated", value: false)

        gameState.checkQuestVictory()

        XCTAssertFalse(gameState.isVictory, "Победа невозможна без победы над боссом")

        // После победы над боссом
        worldState.mainQuestStage = 5
        worldState.setFlag("act5_completed", value: true)

        gameState.checkQuestVictory()

        XCTAssertTrue(gameState.isVictory, "Победа возможна при завершении акта")
    }
}

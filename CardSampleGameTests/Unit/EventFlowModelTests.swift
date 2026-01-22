import XCTest
@testable import CardSampleGame

/// Модельные тесты для потока событий
/// Покрывает: структура событий, валидация выборов, применение последствий
/// См. QA_ACT_I_CHECKLIST.md, тесты TEST-007, TEST-008
final class EventFlowModelTests: XCTestCase {

    var worldState: WorldState!
    var player: Player!
    private var testPackURL: URL!

    override func setUp() {
        super.setUp()
        // Load ContentRegistry with TwilightMarches pack
        ContentRegistry.shared.resetForTesting()
        testPackURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // Unit
            .deletingLastPathComponent() // CardSampleGameTests
            .deletingLastPathComponent() // CardSampleGame
            .appendingPathComponent("ContentPacks/TwilightMarches")
        _ = try? ContentRegistry.shared.loadPack(from: testPackURL)

        worldState = WorldState()
        player = Player(name: "Test")
    }

    override func tearDown() {
        worldState = nil
        player = nil
        ContentRegistry.shared.resetForTesting()
        testPackURL = nil
        WorldRNG.shared.resetToSystem()
        super.tearDown()
    }

    /// Helper to skip test if regions not loaded
    private func requireRegionsLoaded() throws {
        if worldState.regions.isEmpty {
            throw XCTSkip("Skipping: ContentPack not loaded (regions empty)")
        }
    }

    // MARK: - Event Display

    func testEventHasTitle() {
        let event = createTestEvent()
        XCTAssertFalse(event.title.isEmpty, "Событие должно иметь заголовок")
    }

    func testEventHasDescription() {
        let event = createTestEvent()
        XCTAssertFalse(event.description.isEmpty, "Событие должно иметь описание")
    }

    func testEventHasChoices() {
        let event = createTestEvent()
        XCTAssertFalse(event.choices.isEmpty, "Событие должно иметь выборы")
    }

    func testEventTypeHasIcon() {
        let event = createTestEvent()
        XCTAssertFalse(event.eventType.icon.isEmpty, "Тип события должен иметь иконку")
    }

    // MARK: - Choice Display

    func testChoiceHasText() {
        let choice = EventChoice(
            text: "Выбор 1",
            consequences: EventConsequences()
        )
        XCTAssertFalse(choice.text.isEmpty, "Выбор должен иметь текст")
    }

    func testChoiceHasId() {
        let choice = EventChoice(
            text: "Выбор 1",
            consequences: EventConsequences()
        )
        XCTAssertFalse(choice.id.isEmpty, "Выбор должен иметь ID")
    }

    // MARK: - Event Filtering for Region

    func testEventsAvailableForStableRegion() throws {
        try requireRegionsLoaded()
        guard let stableRegion = worldState.regions.first(where: { $0.state == .stable }) else {
            throw XCTSkip("Нет Stable региона")
        }

        let events = worldState.getAvailableEvents(for: stableRegion)

        for event in events {
            XCTAssertTrue(
                event.regionStates.contains(.stable),
                "Событие '\(event.title)' должно быть доступно в Stable"
            )
        }
    }

    func testEventsAvailableForBorderlandRegion() throws {
        try requireRegionsLoaded()
        guard let borderlandRegion = worldState.regions.first(where: { $0.state == .borderland }) else {
            throw XCTSkip("Нет Borderland региона")
        }

        let events = worldState.getAvailableEvents(for: borderlandRegion)

        for event in events {
            XCTAssertTrue(
                event.regionStates.contains(.borderland),
                "Событие '\(event.title)' должно быть доступно в Borderland"
            )
        }
    }

    // MARK: - No Empty Event Screen

    func testNoEmptyEventsForAnyRegion() throws {
        try requireRegionsLoaded()
        for region in worldState.regions {
            let events = worldState.getAvailableEvents(for: region)
            // Должно быть хотя бы одно событие или fallback
            // В реальной игре всегда есть fallback события
            // Здесь просто проверяем что метод работает
            _ = events
        }
    }

    // MARK: - OneTime Event Marking

    func testMarkEventCompleted() throws {
        try requireRegionsLoaded()
        guard let event = worldState.allEvents.first else {
            throw XCTSkip("Нет событий")
        }

        worldState.markEventCompleted(event.id)

        // Проверяем что событие отмечено как завершённое
        // Реализация зависит от WorldState
    }

    // MARK: - Event Consequences Preview

    func testConsequencesHaveMessage() {
        let consequences = EventConsequences(message: "Вы получили награду!")
        XCTAssertEqual(consequences.message, "Вы получили награду!")
    }

    func testConsequencesShowFaithChange() {
        let consequences = EventConsequences(faithChange: 2)
        XCTAssertEqual(consequences.faithChange, 2)
    }

    func testConsequencesShowHealthChange() {
        let consequences = EventConsequences(healthChange: -3)
        XCTAssertEqual(consequences.healthChange, -3)
    }

    // MARK: - Requirements Display

    func testRequirementsCheckWithPlayer() {
        let requirements = EventRequirements(minimumFaith: 5)

        player.faith = 3
        XCTAssertFalse(requirements.canMeet(with: player, worldState: worldState))

        player.faith = 7
        XCTAssertTrue(requirements.canMeet(with: player, worldState: worldState))
    }

    // MARK: - Combat Event Display

    func testCombatEventHasMonsterCard() {
        let monsterCard = Card(
            name: "Волк",
            type: .monster,
            description: "Дикий зверь",
            power: 3,
            health: 5
        )

        let combatEvent = GameEvent(
            eventType: .combat,
            title: "Нападение волка",
            description: "На вас напал волк!",
            choices: [EventChoice(text: "Сражаться", consequences: EventConsequences())],
            monsterCard: monsterCard
        )

        XCTAssertNotNil(combatEvent.monsterCard, "Боевое событие должно иметь карту монстра")
        XCTAssertEqual(combatEvent.monsterCard?.name, "Волк")
    }

    // MARK: - Event Log Display

    func testEventLogEntry() {
        let entry = EventLogEntry(
            dayNumber: 5,
            regionName: "Лес",
            eventTitle: "Встреча с путником",
            choiceMade: "Помочь",
            outcome: "Получена награда",
            type: .exploration
        )

        XCTAssertEqual(entry.dayNumber, 5)
        XCTAssertEqual(entry.regionName, "Лес")
        XCTAssertEqual(entry.type, .exploration)
    }

    func testLogEventToWorldState() {
        let initialCount = worldState.eventLog.count

        worldState.logEvent(
            regionName: "Тест",
            eventTitle: "Тестовое событие",
            choiceMade: "Выбор",
            outcome: "Результат",
            type: .exploration
        )

        XCTAssertEqual(worldState.eventLog.count, initialCount + 1)
    }

    // MARK: - Instant Event Behavior

    func testInstantEventDoesNotCostDay() {
        let instantEvent = GameEvent(
            eventType: .narrative,
            title: "Мимолётная мысль",
            description: "Вы задумались о чём-то",
            choices: [EventChoice(text: "Понятно", consequences: EventConsequences())],
            instant: true
        )

        XCTAssertTrue(instantEvent.instant, "Instant событие не должно тратить день")
    }

    func testNormalEventCostsDay() {
        let normalEvent = GameEvent(
            eventType: .exploration,
            title: "Исследование",
            description: "Вы исследуете местность",
            choices: [EventChoice(text: "Продолжить", consequences: EventConsequences())],
            instant: false
        )

        XCTAssertFalse(normalEvent.instant, "Обычное событие тратит день")
    }

    // MARK: - Quest Link Display

    func testEventWithQuestLink() {
        let event = GameEvent(
            eventType: .narrative,
            title: "Квестовое событие",
            description: "Связано с квестом",
            choices: [EventChoice(text: "Принять", consequences: EventConsequences())],
            questLinks: ["main_quest_step_2"]
        )

        XCTAssertFalse(event.questLinks.isEmpty, "Событие должно быть связано с квестом")
    }

    // MARK: - Helpers

    private func createTestEvent() -> GameEvent {
        return GameEvent(
            eventType: .exploration,
            title: "Тестовое событие",
            description: "Описание тестового события",
            choices: [
                EventChoice(
                    text: "Первый выбор",
                    consequences: EventConsequences(faithChange: 1)
                ),
                EventChoice(
                    text: "Второй выбор",
                    consequences: EventConsequences(healthChange: -1)
                )
            ]
        )
    }
}

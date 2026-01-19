import XCTest
@testable import CardSampleGame

/// Unit тесты для системы событий
/// Покрывает: фильтрация, веса, флаги, oneTime
/// См. QA_ACT_I_CHECKLIST.md, тесты TEST-007, TEST-008
final class EventSystemTests: XCTestCase {

    var worldState: WorldState!
    var player: Player!

    override func setUp() {
        super.setUp()
        worldState = WorldState()
        player = Player(name: "Тестовый игрок")
    }

    override func tearDown() {
        worldState = nil
        player = nil
        WorldRNG.shared.resetToSystem()
        super.tearDown()
    }

    // MARK: - TEST-007: Фильтрация событий

    func testEventFilterByRegionState() {
        // Создаём событие только для Borderland
        let borderlandEvent = GameEvent(
            eventType: .exploration,
            title: "Borderland Event",
            description: "Test",
            regionStates: [.borderland],
            choices: [createTestChoice()]
        )

        let stableRegion = Region(name: "Stable", type: .forest, state: .stable)
        let borderlandRegion = Region(name: "Borderland", type: .forest, state: .borderland)

        XCTAssertFalse(borderlandEvent.canOccur(in: stableRegion), "Событие не должно происходить в Stable")
        XCTAssertTrue(borderlandEvent.canOccur(in: borderlandRegion), "Событие должно происходить в Borderland")
    }

    func testEventFilterByRegionType() {
        // Создаём событие только для леса
        let forestEvent = GameEvent(
            eventType: .exploration,
            title: "Forest Event",
            description: "Test",
            regionTypes: [.forest],
            regionStates: [.stable, .borderland, .breach],
            choices: [createTestChoice()]
        )

        let forestRegion = Region(name: "Forest", type: .forest, state: .stable)
        let swampRegion = Region(name: "Swamp", type: .swamp, state: .stable)

        XCTAssertTrue(forestEvent.canOccur(in: forestRegion), "Событие должно происходить в лесу")
        XCTAssertFalse(forestEvent.canOccur(in: swampRegion), "Событие не должно происходить в болоте")
    }

    func testEventFilterByTensionMin() {
        let highTensionEvent = GameEvent(
            eventType: .worldShift,
            title: "High Tension Event",
            description: "Test",
            regionStates: [.stable, .borderland, .breach],
            choices: [createTestChoice()],
            minTension: 50
        )

        let region = Region(name: "Test", type: .forest, state: .stable)

        XCTAssertFalse(
            highTensionEvent.canOccur(in: region, worldTension: 30, worldFlags: [:]),
            "Событие не должно происходить при низком Tension"
        )
        XCTAssertTrue(
            highTensionEvent.canOccur(in: region, worldTension: 60, worldFlags: [:]),
            "Событие должно происходить при высоком Tension"
        )
    }

    func testEventFilterByTensionMax() {
        let lowTensionEvent = GameEvent(
            eventType: .exploration,
            title: "Low Tension Event",
            description: "Test",
            regionStates: [.stable, .borderland, .breach],
            choices: [createTestChoice()],
            maxTension: 40
        )

        let region = Region(name: "Test", type: .forest, state: .stable)

        XCTAssertTrue(
            lowTensionEvent.canOccur(in: region, worldTension: 30, worldFlags: [:]),
            "Событие должно происходить при низком Tension"
        )
        XCTAssertFalse(
            lowTensionEvent.canOccur(in: region, worldTension: 60, worldFlags: [:]),
            "Событие не должно происходить при высоком Tension"
        )
    }

    func testEventFilterByRequiredFlags() {
        let flagEvent = GameEvent(
            eventType: .exploration,
            title: "Flag Event",
            description: "Test",
            regionStates: [.stable, .borderland, .breach],
            choices: [createTestChoice()],
            requiredFlags: ["quest_started"]
        )

        let region = Region(name: "Test", type: .forest, state: .stable)

        XCTAssertFalse(
            flagEvent.canOccur(in: region, worldTension: 30, worldFlags: [:]),
            "Событие не должно происходить без флага"
        )
        XCTAssertTrue(
            flagEvent.canOccur(in: region, worldTension: 30, worldFlags: ["quest_started": true]),
            "Событие должно происходить с флагом"
        )
    }

    func testEventFilterByForbiddenFlags() {
        let noFlagEvent = GameEvent(
            eventType: .exploration,
            title: "No Flag Event",
            description: "Test",
            regionStates: [.stable, .borderland, .breach],
            choices: [createTestChoice()],
            forbiddenFlags: ["quest_completed"]
        )

        let region = Region(name: "Test", type: .forest, state: .stable)

        XCTAssertTrue(
            noFlagEvent.canOccur(in: region, worldTension: 30, worldFlags: [:]),
            "Событие должно происходить без запрещённого флага"
        )
        XCTAssertFalse(
            noFlagEvent.canOccur(in: region, worldTension: 30, worldFlags: ["quest_completed": true]),
            "Событие не должно происходить с запрещённым флагом"
        )
    }

    // MARK: - OneTime Events

    func testOneTimeEventNotRepeated() {
        let oneTimeEvent = GameEvent(
            eventType: .narrative,
            title: "One Time",
            description: "Test",
            regionStates: [.stable, .borderland, .breach],
            choices: [createTestChoice()],
            oneTime: true,
            completed: true
        )

        let region = Region(name: "Test", type: .forest, state: .stable)

        XCTAssertFalse(oneTimeEvent.canOccur(in: region), "Завершённое oneTime событие не должно повторяться")
    }

    func testRepeatingEventCanRepeat() {
        let repeatingEvent = GameEvent(
            eventType: .exploration,
            title: "Repeating",
            description: "Test",
            regionStates: [.stable, .borderland, .breach],
            choices: [createTestChoice()],
            oneTime: false,
            completed: true
        )

        let region = Region(name: "Test", type: .forest, state: .stable)

        XCTAssertTrue(repeatingEvent.canOccur(in: region), "Повторяющееся событие может произойти снова")
    }

    // MARK: - Weighted Event Selection

    func testWeightedEventSelection() {
        // Тестируем что события с большим весом выбираются чаще
        let highWeightEvent = GameEvent(
            eventType: .exploration,
            title: "High Weight",
            description: "Test",
            regionStates: [.stable],
            choices: [createTestChoice()],
            weight: 10
        )

        let lowWeightEvent = GameEvent(
            eventType: .exploration,
            title: "Low Weight",
            description: "Test",
            regionStates: [.stable],
            choices: [createTestChoice()],
            weight: 1
        )

        // Проверяем что веса корректно установлены
        XCTAssertEqual(highWeightEvent.weight, 10, "Высокий вес = 10")
        XCTAssertEqual(lowWeightEvent.weight, 1, "Низкий вес = 1")

        // Проверяем что общий вес можно вычислить для выборки
        let events = [highWeightEvent, lowWeightEvent]
        let totalWeight = events.reduce(0) { $0 + $1.weight }
        XCTAssertEqual(totalWeight, 11, "Общий вес = 11")

        // Статистический тест: выбираем 100 раз и проверяем распределение
        // Используем WorldRNG с seed для детерминизма в CI
        WorldRNG.shared.setSeed(42)
        var highWeightCount = 0
        for _ in 0..<100 {
            let randomValue = WorldRNG.shared.nextInt(in: 0..<totalWeight)
            if randomValue < highWeightEvent.weight {
                highWeightCount += 1
            }
        }
        WorldRNG.shared.resetToSystem()

        // Ожидаем примерно 90% выборов highWeight (10/11 ≈ 90%)
        // С seed=42 получаем стабильный результат
        XCTAssertGreaterThan(highWeightCount, 60, "Событие с высоким весом выбирается чаще")
    }

    // MARK: - Event Weight

    func testEventWeightMinimum() {
        let event = GameEvent(
            eventType: .exploration,
            title: "Test",
            description: "Test",
            choices: [createTestChoice()],
            weight: 0  // Должен стать 1
        )

        XCTAssertGreaterThanOrEqual(event.weight, 1, "Минимальный вес должен быть 1")
    }

    func testEventWeightPreserved() {
        let event = GameEvent(
            eventType: .exploration,
            title: "Test",
            description: "Test",
            choices: [createTestChoice()],
            weight: 5
        )

        XCTAssertEqual(event.weight, 5, "Вес должен сохраняться")
    }

    // MARK: - Instant Events

    func testInstantEventProperty() {
        let instantEvent = GameEvent(
            eventType: .narrative,
            title: "Instant",
            description: "Test",
            choices: [createTestChoice()],
            instant: true
        )

        XCTAssertTrue(instantEvent.instant, "Instant событие должно иметь instant = true")
    }

    func testNonInstantEventProperty() {
        let normalEvent = GameEvent(
            eventType: .exploration,
            title: "Normal",
            description: "Test",
            choices: [createTestChoice()],
            instant: false
        )

        XCTAssertFalse(normalEvent.instant, "Обычное событие должно иметь instant = false")
    }

    // MARK: - TEST-008: Event Consequences

    func testConsequencesFaithChange() {
        let consequences = EventConsequences(faithChange: 2)
        XCTAssertEqual(consequences.faithChange, 2, "faithChange должен быть установлен")
    }

    func testConsequencesHealthChange() {
        let consequences = EventConsequences(healthChange: -3)
        XCTAssertEqual(consequences.healthChange, -3, "healthChange должен быть установлен")
    }

    func testConsequencesBalanceChange() {
        let consequences = EventConsequences(balanceChange: 10)
        XCTAssertEqual(consequences.balanceChange, 10, "balanceChange должен быть установлен")
    }

    func testConsequencesTensionChange() {
        let consequences = EventConsequences(tensionChange: -5)
        XCTAssertEqual(consequences.tensionChange, -5, "tensionChange должен быть установлен")
    }

    func testConsequencesSetFlags() {
        let consequences = EventConsequences(setFlags: ["quest_started": true, "npc_met": true])
        XCTAssertEqual(consequences.setFlags?["quest_started"], true)
        XCTAssertEqual(consequences.setFlags?["npc_met"], true)
    }

    func testConsequencesAnchorIntegrity() {
        let consequences = EventConsequences(anchorIntegrityChange: -10)
        XCTAssertEqual(consequences.anchorIntegrityChange, -10, "anchorIntegrityChange должен быть установлен")
    }

    // MARK: - Event Choice Requirements

    func testChoiceRequirementsFaith() {
        let requirements = EventRequirements(minimumFaith: 5)

        player.faith = 3
        XCTAssertFalse(requirements.canMeet(with: player, worldState: worldState), "Не хватает веры")

        player.faith = 5
        XCTAssertTrue(requirements.canMeet(with: player, worldState: worldState), "Веры достаточно")
    }

    func testChoiceRequirementsHealth() {
        let requirements = EventRequirements(minimumHealth: 8)

        player.health = 5
        XCTAssertFalse(requirements.canMeet(with: player, worldState: worldState), "Не хватает здоровья")

        player.health = 10
        XCTAssertTrue(requirements.canMeet(with: player, worldState: worldState), "Здоровья достаточно")
    }

    func testChoiceRequirementsBalance() {
        let lightRequirements = EventRequirements(requiredBalance: .light)

        player.balance = 50
        XCTAssertFalse(lightRequirements.canMeet(with: player, worldState: worldState), "Нейтральный баланс")

        player.balance = 80
        XCTAssertTrue(lightRequirements.canMeet(with: player, worldState: worldState), "Путь Света")
    }

    func testChoiceRequirementsFlags() {
        let requirements = EventRequirements(requiredFlags: ["npc_saved"])

        XCTAssertFalse(requirements.canMeet(with: player, worldState: worldState), "Нет флага")

        worldState.worldFlags["npc_saved"] = true
        XCTAssertTrue(requirements.canMeet(with: player, worldState: worldState), "Флаг установлен")
    }

    // MARK: - Event Types

    func testEventTypeDisplayNames() {
        XCTAssertEqual(EventType.combat.displayName, "Бой")
        XCTAssertEqual(EventType.ritual.displayName, "Ритуал")
        XCTAssertEqual(EventType.narrative.displayName, "Встреча")
        XCTAssertEqual(EventType.exploration.displayName, "Исследование")
        XCTAssertEqual(EventType.worldShift.displayName, "Сдвиг Мира")
    }

    func testEventTypeIcons() {
        XCTAssertFalse(EventType.combat.icon.isEmpty, "Combat должен иметь иконку")
        XCTAssertFalse(EventType.ritual.icon.isEmpty, "Ritual должен иметь иконку")
        XCTAssertFalse(EventType.narrative.icon.isEmpty, "Narrative должен иметь иконку")
        XCTAssertFalse(EventType.exploration.icon.isEmpty, "Exploration должен иметь иконку")
        XCTAssertFalse(EventType.worldShift.icon.isEmpty, "WorldShift должен иметь иконку")
    }

    // MARK: - Helpers

    private func createTestChoice() -> EventChoice {
        return EventChoice(
            text: "Test choice",
            consequences: EventConsequences()
        )
    }
}

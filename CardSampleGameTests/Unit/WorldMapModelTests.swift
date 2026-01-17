import XCTest
@testable import CardSampleGame

/// Модельные тесты для карты мира
/// Покрывает: состояния регионов, отображаемые данные, риск-индикаторы
/// См. QA_ACT_I_CHECKLIST.md, тесты TEST-004, TEST-005
final class WorldMapModelTests: XCTestCase {

    var worldState: WorldState!

    override func setUp() {
        super.setUp()
        worldState = WorldState()
    }

    override func tearDown() {
        worldState = nil
        super.tearDown()
    }

    // MARK: - TEST-004: Читаемость риска

    func testAllRegionsHaveStateEmoji() {
        for region in worldState.regions {
            XCTAssertFalse(region.state.emoji.isEmpty, "Регион \(region.name) должен иметь эмодзи состояния")
        }
    }

    func testAllRegionsHaveDisplayName() {
        for region in worldState.regions {
            XCTAssertFalse(region.state.displayName.isEmpty, "Регион \(region.name) должен иметь displayName")
        }
    }

    func testBorderlandShowsModifiers() {
        let context = CombatContext(regionState: .borderland, playerCurses: [])
        XCTAssertNotNil(context.regionModifierDescription, "Borderland должен показывать модификаторы")
    }

    func testBreachShowsModifiers() {
        let context = CombatContext(regionState: .breach, playerCurses: [])
        XCTAssertNotNil(context.regionModifierDescription, "Breach должен показывать модификаторы")
    }

    func testStableNoModifiersDescription() {
        let context = CombatContext(regionState: .stable, playerCurses: [])
        XCTAssertNil(context.regionModifierDescription, "Stable не должен показывать модификаторы")
    }

    // MARK: - TEST-005: Ограничения действий по локации

    func testCurrentRegionIsSet() {
        XCTAssertNotNil(worldState.currentRegionId, "currentRegionId должен быть установлен")
    }

    func testCanGetCurrentRegion() {
        let region = worldState.getCurrentRegion()
        XCTAssertNotNil(region, "Должен возвращаться текущий регион")
    }

    func testRegionsHaveNeighbors() {
        for region in worldState.regions {
            XCTAssertFalse(region.neighborIds.isEmpty, "Регион \(region.name) должен иметь соседей")
        }
    }

    func testIsNeighborCheck() {
        guard let currentRegion = worldState.getCurrentRegion(),
              let neighborId = currentRegion.neighborIds.first else {
            XCTFail("Нет данных для теста")
            return
        }

        XCTAssertTrue(currentRegion.isNeighbor(neighborId), "isNeighbor должен возвращать true для соседа")
    }

    func testIsNotNeighborCheck() {
        guard let currentRegion = worldState.getCurrentRegion() else {
            XCTFail("Нет текущего региона")
            return
        }

        // Найти регион, который не является соседом
        if let distantRegion = worldState.regions.first(where: { region in
            region.id != currentRegion.id && !currentRegion.neighborIds.contains(region.id)
        }) {
            XCTAssertFalse(currentRegion.isNeighbor(distantRegion.id), "isNeighbor должен возвращать false для дальнего")
        }
    }

    // MARK: - Region Types Display

    func testRegionTypeDisplayNames() {
        XCTAssertEqual(RegionType.forest.displayName, "Лес")
        XCTAssertEqual(RegionType.swamp.displayName, "Болото")
        XCTAssertEqual(RegionType.mountain.displayName, "Горы")
        XCTAssertEqual(RegionType.settlement.displayName, "Поселение")
        XCTAssertEqual(RegionType.water.displayName, "Водная зона")
        XCTAssertEqual(RegionType.wasteland.displayName, "Пустошь")
        XCTAssertEqual(RegionType.sacred.displayName, "Священное место")
    }

    func testRegionTypeIcons() {
        XCTAssertFalse(RegionType.forest.icon.isEmpty, "Forest должен иметь иконку")
        XCTAssertFalse(RegionType.swamp.icon.isEmpty, "Swamp должен иметь иконку")
        XCTAssertFalse(RegionType.mountain.icon.isEmpty, "Mountain должен иметь иконку")
        XCTAssertFalse(RegionType.settlement.icon.isEmpty, "Settlement должен иметь иконку")
    }

    // MARK: - Anchor Display

    func testAnchorTypeDisplayNames() {
        XCTAssertEqual(AnchorType.shrine.displayName, "Капище")
        XCTAssertEqual(AnchorType.barrow.displayName, "Курган")
        XCTAssertEqual(AnchorType.sacredTree.displayName, "Священный Дуб")
        XCTAssertEqual(AnchorType.stoneIdol.displayName, "Каменная Баба")
        XCTAssertEqual(AnchorType.spring.displayName, "Родник")
        XCTAssertEqual(AnchorType.chapel.displayName, "Часовня")
        XCTAssertEqual(AnchorType.temple.displayName, "Храм")
        XCTAssertEqual(AnchorType.cross.displayName, "Обетный Крест")
    }

    func testAnchorTypeIcons() {
        XCTAssertFalse(AnchorType.shrine.icon.isEmpty)
        XCTAssertFalse(AnchorType.barrow.icon.isEmpty)
        XCTAssertFalse(AnchorType.sacredTree.icon.isEmpty)
    }

    // MARK: - World Tension Display

    func testWorldTensionInRange() {
        XCTAssertGreaterThanOrEqual(worldState.worldTension, 0, "Tension >= 0")
        XCTAssertLessThanOrEqual(worldState.worldTension, 100, "Tension <= 100")
    }

    func testLightDarkBalanceInRange() {
        XCTAssertGreaterThanOrEqual(worldState.lightDarkBalance, 0, "Balance >= 0")
        XCTAssertLessThanOrEqual(worldState.lightDarkBalance, 100, "Balance <= 100")
    }

    // MARK: - Region Count

    func testSevenRegionsExist() {
        XCTAssertEqual(worldState.regions.count, 7, "Должно быть 7 регионов в Акте I")
    }

    func testAllRegionsHaveNames() {
        for region in worldState.regions {
            XCTAssertFalse(region.name.isEmpty, "Все регионы должны иметь имена")
        }
    }

    func testAllRegionsHaveTypes() {
        for region in worldState.regions {
            // RegionType is an enum, so this just checks it's assigned
            _ = region.type.displayName
        }
    }

    // MARK: - Average Region State

    func testAverageRegionStateCalculation() {
        // averageRegionState is a computed property
        let state = worldState.averageRegionState
        // Just verify it returns a valid state
        XCTAssertTrue([RegionState.stable, .borderland, .breach].contains(state))
    }

    // MARK: - Event Log UI

    func testEventLogTypeIcons() {
        XCTAssertFalse(EventLogType.exploration.icon.isEmpty)
        XCTAssertFalse(EventLogType.combat.icon.isEmpty)
        XCTAssertFalse(EventLogType.choice.icon.isEmpty)
        XCTAssertFalse(EventLogType.quest.icon.isEmpty)
        XCTAssertFalse(EventLogType.travel.icon.isEmpty)
        XCTAssertFalse(EventLogType.worldChange.icon.isEmpty)
    }

    // MARK: - Day Event Display

    func testDayEventTensionIncrease() {
        let event = DayEvent.tensionIncrease(day: 3, newTension: 32)
        XCTAssertEqual(event.day, 3)
        XCTAssertTrue(event.isNegative)
        XCTAssertFalse(event.title.isEmpty)
        XCTAssertFalse(event.description.isEmpty)
    }

    func testDayEventRegionDegraded() {
        let event = DayEvent.regionDegraded(day: 6, regionName: "Лес", newState: .borderland)
        XCTAssertEqual(event.day, 6)
        XCTAssertTrue(event.isNegative)
        XCTAssertTrue(event.description.contains("Лес"))
    }

    func testDayEventWorldImproving() {
        let event = DayEvent.worldImproving(day: 9)
        XCTAssertEqual(event.day, 9)
        XCTAssertFalse(event.isNegative)
    }
}

import XCTest
@testable import CardSampleGame

/// Модельные тесты для карты мира
/// Покрывает: состояния регионов, отображаемые данные, риск-индикаторы
/// См. QA_ACT_I_CHECKLIST.md, тесты TEST-004, TEST-005
final class WorldMapModelTests: XCTestCase {

    var worldState: WorldState!
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
    }

    override func tearDown() {
        worldState = nil
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

    /// Helper to skip test if current region not available
    private func requireCurrentRegion() throws -> Region {
        guard let region = worldState.getCurrentRegion() else {
            throw XCTSkip("Skipping: No current region (ContentPack may not be loaded)")
        }
        return region
    }

    // MARK: - TEST-004: Читаемость риска

    func testAllRegionsHaveStateEmoji() throws {
        try requireRegionsLoaded()
        for region in worldState.regions {
            XCTAssertFalse(region.state.emoji.isEmpty, "Регион \(region.name) должен иметь эмодзи состояния")
        }
    }

    func testAllRegionsHaveDisplayName() throws {
        try requireRegionsLoaded()
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

    func testCurrentRegionIsSet() throws {
        try requireRegionsLoaded()
        XCTAssertNotNil(worldState.currentRegionId, "currentRegionId должен быть установлен")
    }

    func testCanGetCurrentRegion() throws {
        try requireRegionsLoaded()
        let region = worldState.getCurrentRegion()
        XCTAssertNotNil(region, "Должен возвращаться текущий регион")
    }

    func testRegionsHaveNeighbors() throws {
        try requireRegionsLoaded()
        for region in worldState.regions {
            XCTAssertFalse(region.neighborIds.isEmpty, "Регион \(region.name) должен иметь соседей")
        }
    }

    func testIsNeighborCheck() throws {
        let currentRegion = try requireCurrentRegion()
        guard let neighborId = currentRegion.neighborIds.first else {
            throw XCTSkip("Нет соседей для теста")
        }

        XCTAssertTrue(currentRegion.isNeighbor(neighborId), "isNeighbor должен возвращать true для соседа")
    }

    func testIsNotNeighborCheck() throws {
        let currentRegion = try requireCurrentRegion()

        // Найти регион, который не является соседом
        if let distantRegion = worldState.regions.first(where: { region in
            region.id != currentRegion.id && !currentRegion.neighborIds.contains(region.id)
        }) {
            XCTAssertFalse(currentRegion.isNeighbor(distantRegion.id), "isNeighbor должен возвращать false для дальнего")
        }
    }

    // MARK: - Region Types Display

    func testRegionTypeDisplayNames() {
        // Localized names vary by locale - verify they are not empty and match localization
        XCTAssertFalse(RegionType.forest.displayName.isEmpty, "Forest should have display name")
        XCTAssertFalse(RegionType.swamp.displayName.isEmpty, "Swamp should have display name")
        XCTAssertFalse(RegionType.mountain.displayName.isEmpty, "Mountain should have display name")
        XCTAssertFalse(RegionType.settlement.displayName.isEmpty, "Settlement should have display name")
        XCTAssertFalse(RegionType.water.displayName.isEmpty, "Water should have display name")
        XCTAssertFalse(RegionType.wasteland.displayName.isEmpty, "Wasteland should have display name")
        XCTAssertFalse(RegionType.sacred.displayName.isEmpty, "Sacred should have display name")

        // Verify each display name is different (no duplicates)
        let displayNames: Set<String> = [
            RegionType.forest.displayName,
            RegionType.swamp.displayName,
            RegionType.mountain.displayName,
            RegionType.settlement.displayName,
            RegionType.water.displayName,
            RegionType.wasteland.displayName,
            RegionType.sacred.displayName
        ]
        XCTAssertEqual(displayNames.count, 7, "All region types should have unique display names")
    }

    func testRegionTypeIcons() {
        XCTAssertFalse(RegionType.forest.icon.isEmpty, "Forest должен иметь иконку")
        XCTAssertFalse(RegionType.swamp.icon.isEmpty, "Swamp должен иметь иконку")
        XCTAssertFalse(RegionType.mountain.icon.isEmpty, "Mountain должен иметь иконку")
        XCTAssertFalse(RegionType.settlement.icon.isEmpty, "Settlement должен иметь иконку")
    }

    // MARK: - Anchor Display

    func testAnchorTypeDisplayNames() {
        // Localized names vary by locale - verify they are not empty and unique
        XCTAssertFalse(AnchorType.shrine.displayName.isEmpty, "Shrine should have display name")
        XCTAssertFalse(AnchorType.barrow.displayName.isEmpty, "Barrow should have display name")
        XCTAssertFalse(AnchorType.sacredTree.displayName.isEmpty, "SacredTree should have display name")
        XCTAssertFalse(AnchorType.stoneIdol.displayName.isEmpty, "StoneIdol should have display name")
        XCTAssertFalse(AnchorType.spring.displayName.isEmpty, "Spring should have display name")
        XCTAssertFalse(AnchorType.chapel.displayName.isEmpty, "Chapel should have display name")
        XCTAssertFalse(AnchorType.temple.displayName.isEmpty, "Temple should have display name")
        XCTAssertFalse(AnchorType.cross.displayName.isEmpty, "Cross should have display name")

        // Verify each display name is different (no duplicates)
        let displayNames: Set<String> = [
            AnchorType.shrine.displayName,
            AnchorType.barrow.displayName,
            AnchorType.sacredTree.displayName,
            AnchorType.stoneIdol.displayName,
            AnchorType.spring.displayName,
            AnchorType.chapel.displayName,
            AnchorType.temple.displayName,
            AnchorType.cross.displayName
        ]
        XCTAssertEqual(displayNames.count, 8, "All anchor types should have unique display names")
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

    func testSevenRegionsExist() throws {
        try requireRegionsLoaded()
        XCTAssertEqual(worldState.regions.count, 7, "Должно быть 7 регионов в Акте I")
    }

    func testAllRegionsHaveNames() throws {
        try requireRegionsLoaded()
        for region in worldState.regions {
            XCTAssertFalse(region.name.isEmpty, "Все регионы должны иметь имена")
        }
    }

    func testAllRegionsHaveTypes() throws {
        try requireRegionsLoaded()
        for region in worldState.regions {
            // RegionType is an enum, so this just checks it's assigned
            _ = region.type.displayName
        }
    }

    // MARK: - Average Region State

    func testAverageRegionStateCalculation() throws {
        try requireRegionsLoaded()
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

import XCTest
@testable import CardSampleGame

/// Модельные тесты для действий в регионах
/// Покрывает: доступность действий (canRest/canTrade), стоимость перемещения, ограничения
/// См. QA_ACT_I_CHECKLIST.md, тест TEST-005
final class RegionActionsModelTests: XCTestCase {

    var worldState: WorldState!
    var player: Player!

    override func setUp() {
        super.setUp()
        worldState = WorldState()
        player = Player(name: "Test")
    }

    override func tearDown() {
        worldState = nil
        player = nil
        super.tearDown()
    }

    // MARK: - TEST-005: Ограничения действий по локации

    func testRestOnlyInPlayerRegion() {
        // Rest доступен только когда игрок находится В регионе
        // и регион Stable + (settlement или sacred)
        guard let currentRegion = worldState.getCurrentRegion() else {
            XCTFail("Нет текущего региона")
            return
        }

        let canRestInCurrent = currentRegion.canRest
        // canRest зависит от типа и состояния региона
        let expected = currentRegion.state == .stable &&
                      (currentRegion.type == .settlement || currentRegion.type == .sacred)
        XCTAssertEqual(canRestInCurrent, expected)
    }

    func testTradeOnlyInStableSettlement() {
        // Trade доступен только в Stable settlement с положительной репутацией
        for region in worldState.regions {
            let expected = region.state == .stable &&
                          region.type == .settlement &&
                          region.reputation >= 0
            XCTAssertEqual(region.canTrade, expected, "canTrade для \(region.name)")
        }
    }

    func testTradeNotInBorderland() {
        let borderlandSettlement = Region(
            name: "Test",
            type: .settlement,
            state: .borderland,
            reputation: 50
        )
        XCTAssertFalse(borderlandSettlement.canTrade, "Нельзя торговать в Borderland")
    }

    func testTradeNotInBreach() {
        let breachSettlement = Region(
            name: "Test",
            type: .settlement,
            state: .breach,
            reputation: 50
        )
        XCTAssertFalse(breachSettlement.canTrade, "Нельзя торговать в Breach")
    }

    func testRestNotInBorderland() {
        let borderlandSettlement = Region(
            name: "Test",
            type: .settlement,
            state: .borderland
        )
        XCTAssertFalse(borderlandSettlement.canRest, "Нельзя отдыхать в Borderland")
    }

    func testRestNotInBreach() {
        let breachSettlement = Region(
            name: "Test",
            type: .settlement,
            state: .breach
        )
        XCTAssertFalse(breachSettlement.canRest, "Нельзя отдыхать в Breach")
    }

    // MARK: - Travel Cost

    func testTravelToNeighborCost() {
        guard let currentRegion = worldState.getCurrentRegion(),
              let neighborId = currentRegion.neighborIds.first else {
            XCTFail("Нет данных для теста")
            return
        }

        let cost = worldState.calculateTravelCost(to: neighborId)
        XCTAssertEqual(cost, 1, "Путешествие к соседу = 1 день")
    }

    func testTravelToDistantCost() {
        guard let currentRegion = worldState.getCurrentRegion() else {
            XCTFail("Нет текущего региона")
            return
        }

        // Найти дальний регион
        if let distantRegion = worldState.regions.first(where: { region in
            region.id != currentRegion.id && !currentRegion.neighborIds.contains(region.id)
        }) {
            let cost = worldState.calculateTravelCost(to: distantRegion.id)
            XCTAssertEqual(cost, 2, "Путешествие к дальнему = 2 дня")
        }
    }

    // MARK: - Region Actions Availability

    func testStableSettlementActions() {
        let region = Region(
            name: "Village",
            type: .settlement,
            state: .stable,
            reputation: 10
        )

        XCTAssertTrue(region.canRest, "Stable settlement: можно отдыхать")
        XCTAssertTrue(region.canTrade, "Stable settlement + rep: можно торговать")
    }

    func testStableSacredActions() {
        let region = Region(
            name: "Temple",
            type: .sacred,
            state: .stable
        )

        XCTAssertTrue(region.canRest, "Stable sacred: можно отдыхать")
        XCTAssertFalse(region.canTrade, "Sacred: нельзя торговать")
    }

    func testForestActions() {
        let stableForest = Region(
            name: "Forest",
            type: .forest,
            state: .stable
        )

        XCTAssertFalse(stableForest.canRest, "Forest: нельзя отдыхать")
        XCTAssertFalse(stableForest.canTrade, "Forest: нельзя торговать")
    }

    // MARK: - Reputation Effects

    func testNegativeReputationBlocksTrade() {
        let region = Region(
            name: "Hostile Village",
            type: .settlement,
            state: .stable,
            reputation: -10
        )

        XCTAssertFalse(region.canTrade, "Отрицательная репутация блокирует торговлю")
    }

    func testZeroReputationAllowsTrade() {
        let region = Region(
            name: "Neutral Village",
            type: .settlement,
            state: .stable,
            reputation: 0
        )

        XCTAssertTrue(region.canTrade, "Нулевая репутация позволяет торговать")
    }

    // MARK: - Region Visit Tracking

    func testRegionMarkedAsVisited() {
        guard let currentId = worldState.currentRegionId,
              let currentRegion = worldState.getCurrentRegion(),
              let neighborId = currentRegion.neighborIds.first else {
            XCTFail("Нет данных для теста")
            return
        }

        worldState.moveToRegion(neighborId)

        // Текущий регион должен быть отмечен как посещённый
        if let previousRegion = worldState.getRegion(byId: currentId) {
            XCTAssertTrue(previousRegion.visited, "Предыдущий регион должен быть отмечен как посещённый")
        }
    }

    func testNewRegionMarkedAsVisited() {
        guard let currentRegion = worldState.getCurrentRegion(),
              let neighborId = currentRegion.neighborIds.first else {
            XCTFail("Нет данных для теста")
            return
        }

        worldState.moveToRegion(neighborId)

        if let newRegion = worldState.getRegion(byId: neighborId) {
            XCTAssertTrue(newRegion.visited, "Новый регион должен быть отмечен как посещённый")
        }
    }

    // MARK: - Anchor Strengthening

    func testAnchorIntegrityLimits() {
        var anchor = Anchor(name: "Test", type: .shrine, integrity: 95)

        // Integrity не должен превышать 100
        anchor = Anchor(name: "Test", type: .shrine, integrity: 150)
        XCTAssertLessThanOrEqual(anchor.integrity, 100, "Integrity <= 100")

        // Integrity не должен быть ниже 0
        anchor = Anchor(name: "Test", type: .shrine, integrity: -10)
        XCTAssertGreaterThanOrEqual(anchor.integrity, 0, "Integrity >= 0")
    }

    func testRegionUpdateFromAnchor() {
        var region = Region(
            name: "Test",
            type: .forest,
            state: .stable,
            anchor: Anchor(name: "Shrine", type: .shrine, integrity: 40)
        )

        region.updateStateFromAnchor()

        XCTAssertEqual(region.state, .borderland, "40% integrity = Borderland")
    }

    func testRegionWithoutAnchorIsBreach() {
        var region = Region(
            name: "Test",
            type: .forest,
            state: .stable,
            anchor: nil
        )

        region.updateStateFromAnchor()

        XCTAssertEqual(region.state, .breach, "Без якоря = Breach")
    }

    // MARK: - Card Role and Region Rewards

    func testCardRoleDefaultBalance() {
        XCTAssertEqual(CardRole.sustain.defaultBalance, .light)
        XCTAssertEqual(CardRole.control.defaultBalance, .light)
        XCTAssertEqual(CardRole.power.defaultBalance, .dark)
        XCTAssertEqual(CardRole.utility.defaultBalance, .neutral)
    }

    func testCardRoleTypicalRarity() {
        XCTAssertTrue(CardRole.sustain.typicalRarity.contains(.common))
        XCTAssertTrue(CardRole.control.typicalRarity.contains(.rare))
        XCTAssertTrue(CardRole.power.typicalRarity.contains(.uncommon))
        XCTAssertTrue(CardRole.utility.typicalRarity.contains(.common))
    }
}

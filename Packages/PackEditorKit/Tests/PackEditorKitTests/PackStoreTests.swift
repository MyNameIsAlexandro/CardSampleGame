import XCTest
@testable import PackEditorKit
import TwilightEngine

final class PackStoreTests: XCTestCase {

    var store: PackStore!

    override func setUp() {
        super.setUp()
        store = PackStore()
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState_isEmpty() {
        XCTAssertNil(store.loadedPack)
        XCTAssertNil(store.packURL)
        XCTAssertFalse(store.isDirty)
        XCTAssertNil(store.balanceConfig)
        XCTAssertNil(store.validationSummary)
        XCTAssertTrue(store.enemies.isEmpty)
        XCTAssertTrue(store.events.isEmpty)
        XCTAssertTrue(store.regions.isEmpty)
    }

    func testPackTitle_noPackLoaded() {
        XCTAssertEqual(store.packTitle, "Pack Editor")
    }

    // MARK: - Entity Count / IDs (empty state)

    func testEntityCount_emptyState() {
        for category in ContentCategory.allCases {
            XCTAssertEqual(store.entityCount(for: category), 0,
                           "Expected 0 for \(category)")
        }
    }

    func testEntityIds_emptyState() {
        for category in ContentCategory.allCases {
            XCTAssertTrue(store.entityIds(for: category).isEmpty,
                          "Expected empty IDs for \(category)")
        }
    }

    // MARK: - Load Pack from Fixture

    func testLoadPack_fromFixture() throws {
        let fixtureURL = try fixturePackURL()
        try store.loadPack(from: fixtureURL)

        XCTAssertNotNil(store.loadedPack)
        XCTAssertEqual(store.packURL, fixtureURL)
        XCTAssertFalse(store.isDirty)
        XCTAssertEqual(store.enemies.count, 1)
        XCTAssertEqual(store.events.count, 1)
        XCTAssertEqual(store.regions.count, 1)
    }

    func testLoadPack_setsPackTitle() throws {
        let fixtureURL = try fixturePackURL()
        try store.loadPack(from: fixtureURL)

        XCTAssertTrue(store.packTitle.contains("test-pack"))
    }

    func testLoadPack_entityCountsCorrect() throws {
        let fixtureURL = try fixturePackURL()
        try store.loadPack(from: fixtureURL)

        XCTAssertEqual(store.entityCount(for: .enemies), 1)
        XCTAssertEqual(store.entityCount(for: .events), 1)
        XCTAssertEqual(store.entityCount(for: .regions), 1)
        XCTAssertEqual(store.entityCount(for: .cards), 0)
        XCTAssertEqual(store.entityCount(for: .heroes), 0)
    }

    func testLoadPack_entityIdsCorrect() throws {
        let fixtureURL = try fixturePackURL()
        try store.loadPack(from: fixtureURL)

        XCTAssertEqual(store.entityIds(for: .enemies), ["test_enemy_1"])
        XCTAssertEqual(store.entityIds(for: .events), ["test_event_1"])
        XCTAssertEqual(store.entityIds(for: .regions), ["test_region_1"])
    }

    func testLoadPack_entityNameResolved() throws {
        let fixtureURL = try fixturePackURL()
        try store.loadPack(from: fixtureURL)

        let name = store.entityName(for: "test_enemy_1", in: .enemies)
        XCTAssertEqual(name, "Test Goblin")
    }

    func testLoadPack_unknownEntityName_fallsBackToId() throws {
        let fixtureURL = try fixturePackURL()
        try store.loadPack(from: fixtureURL)

        let name = store.entityName(for: "nonexistent", in: .enemies)
        XCTAssertEqual(name, "nonexistent")
    }

    // MARK: - Load Pack Error

    func testLoadPack_invalidPath_throws() {
        let badURL = URL(fileURLWithPath: "/tmp/nonexistent_pack_xyz_123")
        XCTAssertThrowsError(try store.loadPack(from: badURL))
    }

    // MARK: - Save Without Load

    func testSavePack_withoutLoad_throws() {
        XCTAssertThrowsError(try store.savePack()) { error in
            XCTAssertTrue(error is PackStoreError)
        }
    }

    // MARK: - Validate

    func testValidate_withoutLoad_returnsNil() {
        let result = store.validate()
        XCTAssertNil(result)
    }

    func testValidate_withLoadedPack_returnsSummary() throws {
        let fixtureURL = try fixturePackURL()
        try store.loadPack(from: fixtureURL)

        let summary = store.validate()
        XCTAssertNotNil(summary)
        XCTAssertNotNil(store.validationSummary)
    }

    // MARK: - ContentCategory

    func testContentCategory_allCasesCount() {
        XCTAssertEqual(ContentCategory.allCases.count, 8)
    }

    func testContentCategory_iconNotEmpty() {
        for category in ContentCategory.allCases {
            XCTAssertFalse(category.icon.isEmpty, "\(category) icon should not be empty")
        }
    }

    func testContentCategory_idEqualsRawValue() {
        for category in ContentCategory.allCases {
            XCTAssertEqual(category.id, category.rawValue)
        }
    }

    // MARK: - Helpers

    private func fixturePackURL() throws -> URL {
        guard let url = Bundle.module.url(forResource: "Fixtures/TestPack", withExtension: nil) else {
            throw XCTSkip("Test fixture not found in bundle")
        }
        return url
    }
}

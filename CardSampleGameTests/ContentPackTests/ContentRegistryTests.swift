import XCTest
@testable import CardSampleGame

/// Tests for ContentRegistry functionality
final class ContentRegistryTests: XCTestCase {

    // MARK: - Properties

    private var testPackURL: URL!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        // Reset registry before each test
        ContentRegistry.shared.resetForTesting()

        // Point to the TwilightMarches pack
        testPackURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // ContentPackTests
            .deletingLastPathComponent() // CardSampleGameTests
            .deletingLastPathComponent() // CardSampleGame
            .appendingPathComponent("ContentPacks/TwilightMarches")
    }

    override func tearDown() {
        ContentRegistry.shared.resetForTesting()
        testPackURL = nil
        super.tearDown()
    }

    // MARK: - Pack Loading Tests

    func testLoadPackFromURL() throws {
        // When
        let pack = try ContentRegistry.shared.loadPack(from: testPackURL)

        // Then
        XCTAssertEqual(pack.manifest.packId, "twilight-marches-act1")
    }

    func testLoadPackRegistersContent() throws {
        // When
        try ContentRegistry.shared.loadPack(from: testPackURL)

        // Then
        XCTAssertGreaterThan(ContentRegistry.shared.getAllCards().count, 0)
        XCTAssertGreaterThan(ContentRegistry.shared.getAllHeroes().count, 0)
    }

    func testLoadPackUpdatesBalanceConfig() throws {
        // Given - No balance config before loading
        XCTAssertNil(ContentRegistry.shared.getBalanceConfig())

        // When
        try ContentRegistry.shared.loadPack(from: testPackURL)

        // Then
        XCTAssertNotNil(ContentRegistry.shared.getBalanceConfig())
    }

    func testCannotLoadSamePackTwice() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)

        // Then - Should throw when trying to load again
        XCTAssertThrowsError(try ContentRegistry.shared.loadPack(from: testPackURL)) { error in
            if case PackLoadError.packAlreadyLoaded(let packId) = error {
                XCTAssertEqual(packId, "twilight-marches-act1")
            } else {
                XCTFail("Expected packAlreadyLoaded error")
            }
        }
    }

    // MARK: - Content Access Tests

    func testGetCardById() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)

        // When - Try to get a known card
        let allCards = ContentRegistry.shared.getAllCards()
        guard let firstCard = allCards.first else {
            XCTFail("No cards loaded")
            return
        }

        // Then
        let fetchedCard = ContentRegistry.shared.getCard(id: firstCard.id)
        XCTAssertNotNil(fetchedCard)
        XCTAssertEqual(fetchedCard?.id, firstCard.id)
    }

    func testGetHeroById() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)

        // When
        let allHeroes = ContentRegistry.shared.getAllHeroes()
        guard let firstHero = allHeroes.first else {
            XCTFail("No heroes loaded")
            return
        }

        // Then
        let fetchedHero = ContentRegistry.shared.getHero(id: firstHero.id)
        XCTAssertNotNil(fetchedHero)
        XCTAssertEqual(fetchedHero?.id, firstHero.id)
    }

    func testGetNonExistentContent() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)

        // Then
        XCTAssertNil(ContentRegistry.shared.getCard(id: "nonexistent_card"))
        XCTAssertNil(ContentRegistry.shared.getHero(id: "nonexistent_hero"))
        XCTAssertNil(ContentRegistry.shared.getRegion(id: "nonexistent_region"))
    }

    // MARK: - Starting Deck Tests

    func testGetStartingDeckForHero() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)
        let allHeroes = ContentRegistry.shared.getAllHeroes()
        guard let hero = allHeroes.first else {
            XCTFail("No heroes loaded")
            return
        }

        // When
        let startingDeck = ContentRegistry.shared.getStartingDeck(forHero: hero.id)

        // Then
        XCTAssertFalse(startingDeck.isEmpty, "Hero should have starting deck")
        XCTAssertEqual(startingDeck.count, hero.startingDeckCardIDs.count)
    }

    // MARK: - Unload Tests

    func testUnloadPack() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)
        XCTAssertGreaterThan(ContentRegistry.shared.getAllCards().count, 0)

        // When
        ContentRegistry.shared.unloadPack("twilight-marches-act1")

        // Then - Content should be cleared
        XCTAssertEqual(ContentRegistry.shared.getAllCards().count, 0)
        XCTAssertNil(ContentRegistry.shared.getBalanceConfig())
    }

    func testUnloadAllPacks() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)
        XCTAssertGreaterThan(ContentRegistry.shared.getAllCards().count, 0)

        // When
        ContentRegistry.shared.unloadAllPacks()

        // Then
        XCTAssertEqual(ContentRegistry.shared.getAllCards().count, 0)
        XCTAssertEqual(ContentRegistry.shared.getAllHeroes().count, 0)
        XCTAssertTrue(ContentRegistry.shared.loadedPackIds.isEmpty)
    }

    // MARK: - Validation Tests

    func testValidateLoadedContent() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)

        // When
        let errors = ContentRegistry.shared.validateAllContent()

        // Then - Should have no critical errors (warnings are OK)
        let criticalErrors = errors.filter { $0.type == .brokenReference }
        XCTAssertTrue(criticalErrors.isEmpty, "Should have no broken references: \(criticalErrors)")
    }

    // MARK: - Inventory Tests

    func testTotalInventory() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)

        // When
        let inventory = ContentRegistry.shared.totalInventory

        // Then
        XCTAssertGreaterThan(inventory.cardCount, 0)
        XCTAssertGreaterThan(inventory.heroCount, 0)
        XCTAssertTrue(inventory.hasBalanceConfig)
    }

    // MARK: - ContentProvider Protocol Tests

    func testContentProviderProtocolConformance() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)
        let provider: ContentProvider = ContentRegistry.shared

        // When/Then - Should work as ContentProvider
        XCTAssertFalse(provider.getAllRegionDefinitions().isEmpty || provider.getAllEventDefinitions().isEmpty || provider.getAllQuestDefinitions().isEmpty || true)
    }

    // MARK: - Mock Content Tests

    func testRegisterMockContent() {
        // Given
        let mockRegion = RegionDefinition(
            id: "test_region",
            title: LocalizedString(en: "Test", ru: "Тест"),
            description: LocalizedString(en: "Test region", ru: "Тестовый регион"),
            neighborIds: []
        )

        // When
        ContentRegistry.shared.registerMockContent(
            regions: ["test_region": mockRegion]
        )

        // Then
        XCTAssertNotNil(ContentRegistry.shared.getRegion(id: "test_region"))
        XCTAssertEqual(ContentRegistry.shared.getAllRegions().count, 1)
    }
}

import XCTest
@testable import CardSampleGame

/// Tests for PackLoader functionality
final class PackLoaderTests: XCTestCase {

    // MARK: - Properties

    private var testPackURL: URL!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        // Point to the TwilightMarches pack in ContentPacks
        testPackURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // ContentPackTests
            .deletingLastPathComponent() // CardSampleGameTests
            .deletingLastPathComponent() // CardSampleGame
            .appendingPathComponent("ContentPacks/TwilightMarches")
    }

    override func tearDown() {
        testPackURL = nil
        super.tearDown()
    }

    // MARK: - Manifest Loading Tests

    func testLoadManifestFromValidPack() throws {
        // When
        let manifest = try PackManifest.load(from: testPackURL)

        // Then
        XCTAssertEqual(manifest.packId, "twilight-marches-act1")
        XCTAssertFalse(manifest.displayName.en.isEmpty)
        XCTAssertFalse(manifest.displayName.ru.isEmpty)
    }

    func testManifestVersionParsing() throws {
        // When
        let manifest = try PackManifest.load(from: testPackURL)

        // Then
        XCTAssertGreaterThanOrEqual(manifest.version.major, 1)
    }

    func testManifestCoreCompatibility() throws {
        // When
        let manifest = try PackManifest.load(from: testPackURL)

        // Then
        XCTAssertTrue(manifest.isCompatibleWithCore(), "Pack should be compatible with current Core version")
    }

    func testManifestPackType() throws {
        // When
        let manifest = try PackManifest.load(from: testPackURL)

        // Then - TwilightMarches is a campaign pack
        XCTAssertEqual(manifest.packType, .campaign)
    }

    func testManifestEntryRegion() throws {
        // When
        let manifest = try PackManifest.load(from: testPackURL)

        // Then - Campaign packs should have an entry region
        XCTAssertNotNil(manifest.entryRegionId)
    }

    func testManifestLocales() throws {
        // When
        let manifest = try PackManifest.load(from: testPackURL)

        // Then
        XCTAssertTrue(manifest.supportedLocales.contains("en"))
        XCTAssertTrue(manifest.supportedLocales.contains("ru"))
    }

    // MARK: - Content Loading Tests

    func testLoadPackContent() throws {
        // Given
        let manifest = try PackManifest.load(from: testPackURL)

        // When
        let pack = try PackLoader.load(manifest: manifest, from: testPackURL)

        // Then - Should load some content
        XCTAssertGreaterThan(pack.cards.count, 0, "Should load cards")
        XCTAssertGreaterThan(pack.heroes.count, 0, "Should load heroes")
    }

    func testLoadBalanceConfiguration() throws {
        // Given
        let manifest = try PackManifest.load(from: testPackURL)

        // When
        let pack = try PackLoader.load(manifest: manifest, from: testPackURL)

        // Then
        XCTAssertNotNil(pack.balanceConfig, "Should load balance configuration")
    }

    func testBalanceConfigurationValues() throws {
        // Given
        let manifest = try PackManifest.load(from: testPackURL)
        let pack = try PackLoader.load(manifest: manifest, from: testPackURL)

        // When
        let balance = try XCTUnwrap(pack.balanceConfig)

        // Then - Validate sensible values
        XCTAssertGreaterThan(balance.resources.maxHealth, 0)
        XCTAssertGreaterThan(balance.resources.maxFaith, 0)
        XCTAssertGreaterThanOrEqual(balance.resources.startingHealth, 1)
        XCTAssertGreaterThanOrEqual(balance.pressure.maxPressure, 1)
        XCTAssertGreaterThan(balance.anchor.maxIntegrity, 0)
    }

    // MARK: - Cards Loading Tests

    func testLoadCards() throws {
        // Given
        let manifest = try PackManifest.load(from: testPackURL)

        // When
        let pack = try PackLoader.load(manifest: manifest, from: testPackURL)

        // Then
        XCTAssertFalse(pack.cards.isEmpty, "Should load cards")

        // Verify card structure
        if let firstCard = pack.cards.values.first {
            XCTAssertFalse(firstCard.id.isEmpty)
            XCTAssertFalse(firstCard.name.isEmpty)
        }
    }

    func testCardsHaveValidFaithCost() throws {
        // Given
        let manifest = try PackManifest.load(from: testPackURL)
        let pack = try PackLoader.load(manifest: manifest, from: testPackURL)

        // Then - All cards should have non-negative faith cost
        for (id, card) in pack.cards {
            XCTAssertGreaterThanOrEqual(card.faithCost, 0, "Card '\(id)' has negative faith cost")
        }
    }

    // MARK: - Heroes Loading Tests

    func testLoadHeroes() throws {
        // Given
        let manifest = try PackManifest.load(from: testPackURL)

        // When
        let pack = try PackLoader.load(manifest: manifest, from: testPackURL)

        // Then
        XCTAssertFalse(pack.heroes.isEmpty, "Should load heroes")

        // Verify hero structure
        if let firstHero = pack.heroes.values.first {
            XCTAssertFalse(firstHero.id.isEmpty)
            XCTAssertFalse(firstHero.name.isEmpty)
        }
    }

    func testHeroesHaveStartingDecks() throws {
        // Given
        let manifest = try PackManifest.load(from: testPackURL)
        let pack = try PackLoader.load(manifest: manifest, from: testPackURL)

        // Then - Heroes should have starting decks
        for (id, hero) in pack.heroes {
            XCTAssertFalse(hero.startingDeckCardIDs.isEmpty, "Hero '\(id)' has no starting deck")
        }
    }

    // MARK: - Error Handling Tests

    func testLoadManifestFromInvalidPath() {
        // Given
        let invalidURL = URL(fileURLWithPath: "/nonexistent/path")

        // Then
        XCTAssertThrowsError(try PackManifest.load(from: invalidURL)) { error in
            // Should throw a file not found or similar error
            XCTAssertTrue(error is PackLoadError || error is DecodingError)
        }
    }

    // MARK: - Semantic Version Tests

    func testSemanticVersionComparison() {
        // Given
        let v100 = SemanticVersion(major: 1, minor: 0, patch: 0)
        let v110 = SemanticVersion(major: 1, minor: 1, patch: 0)
        let v111 = SemanticVersion(major: 1, minor: 1, patch: 1)
        let v200 = SemanticVersion(major: 2, minor: 0, patch: 0)

        // Then
        XCTAssertLessThan(v100, v110)
        XCTAssertLessThan(v110, v111)
        XCTAssertLessThan(v111, v200)
        XCTAssertEqual(v100, SemanticVersion(major: 1, minor: 0, patch: 0))
    }

    func testSemanticVersionFromString() {
        // Given
        let version = SemanticVersion(string: "1.2.3")

        // Then
        XCTAssertEqual(version?.major, 1)
        XCTAssertEqual(version?.minor, 2)
        XCTAssertEqual(version?.patch, 3)
    }

    func testSemanticVersionDescription() {
        // Given
        let version = SemanticVersion(major: 1, minor: 2, patch: 3)

        // Then
        XCTAssertEqual(version.description, "1.2.3")
    }
}

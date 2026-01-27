import XCTest
import TwilightEngine
import PackAuthoring
import CoreHeroesContent
import TwilightMarchesActIContent

@testable import CardSampleGame

/// Tests for PackLoader functionality
/// Note: PackLoader is used at compile-time to load JSON content packs.
/// These tests use the JSON source directories, not the binary .pack files.
final class PackLoaderTests: XCTestCase {

    // MARK: - Properties

    /// URL to JSON source directory (not .pack file)
    private var characterPackURL: URL?
    private var storyPackURL: URL?

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        // Use TestContentLoader JSON URLs for PackLoader tests
        characterPackURL = TestContentLoader.characterPackJSONURL
        storyPackURL = TestContentLoader.storyPackJSONURL
    }

    override func tearDown() {
        characterPackURL = nil
        storyPackURL = nil
        super.tearDown()
    }

    // MARK: - Character Pack Manifest Tests

    func testLoadCharacterPackManifest() throws {
        // Fail if character pack not available (Bundle.module resolution issue in tests)
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }

        // Given
        let url = characterPackURL!

        // When
        let manifest = try PackManifest.load(from: url)

        // Then
        XCTAssertEqual(manifest.packId, "core-heroes")
        XCTAssertEqual(manifest.packType, .character)
        XCTAssertFalse(manifest.displayName.en.isEmpty)
        XCTAssertFalse(manifest.displayName.ru.isEmpty)
    }

    // MARK: - Story Pack Manifest Tests

    func testLoadStoryPackManifest() throws {
        // Given
        let url = try XCTUnwrap(storyPackURL, "TwilightMarchesActI pack not available")

        // When
        let manifest = try PackManifest.load(from: url)

        // Then
        XCTAssertEqual(manifest.packId, "twilight-marches-act1")
        XCTAssertEqual(manifest.packType, .campaign)
        XCTAssertFalse(manifest.displayName.en.isEmpty)
        XCTAssertFalse(manifest.displayName.ru.isEmpty)
    }

    func testManifestVersionParsing() throws {
        // Given
        let url = try XCTUnwrap(storyPackURL, "TwilightMarchesActI pack not available")

        // When
        let manifest = try PackManifest.load(from: url)

        // Then
        XCTAssertGreaterThanOrEqual(manifest.version.major, 1)
    }

    func testManifestCoreCompatibility() throws {
        // Given
        let url = try XCTUnwrap(storyPackURL, "TwilightMarchesActI pack not available")

        // When
        let manifest = try PackManifest.load(from: url)

        // Then
        XCTAssertTrue(manifest.isCompatibleWithCore(), "Pack should be compatible with current Core version")
    }

    func testManifestPackType() throws {
        // Given
        let url = try XCTUnwrap(storyPackURL, "TwilightMarchesActI pack not available")

        // When
        let manifest = try PackManifest.load(from: url)

        // Then - TwilightMarchesActI is a campaign pack
        XCTAssertEqual(manifest.packType, .campaign)
    }

    func testManifestEntryRegion() throws {
        // Given
        let url = try XCTUnwrap(storyPackURL, "TwilightMarchesActI pack not available")

        // When
        let manifest = try PackManifest.load(from: url)

        // Then - Campaign packs should have an entry region
        XCTAssertNotNil(manifest.entryRegionId)
    }

    func testManifestLocales() throws {
        // Given
        let url = try XCTUnwrap(storyPackURL, "TwilightMarchesActI pack not available")

        // When
        let manifest = try PackManifest.load(from: url)

        // Then
        XCTAssertTrue(manifest.supportedLocales.contains("en"))
        XCTAssertTrue(manifest.supportedLocales.contains("ru"))
    }

    // MARK: - Content Loading Tests

    func testLoadCharacterPackContent() throws {
        // Fail if character pack not available (Bundle.module resolution issue in tests)
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }

        // Given
        let url = characterPackURL!
        let manifest = try PackManifest.load(from: url)

        // When
        let pack = try PackLoader.load(manifest: manifest, from: url)

        // Then - Should load heroes and cards
        XCTAssertGreaterThan(pack.cards.count, 0, "Should load cards")
        XCTAssertGreaterThan(pack.heroes.count, 0, "Should load heroes")
    }

    func testLoadStoryPackContent() throws {
        // Given
        let url = try XCTUnwrap(storyPackURL, "TwilightMarchesActI pack not available")
        let manifest = try PackManifest.load(from: url)

        // When
        let pack = try PackLoader.load(manifest: manifest, from: url)

        // Then - Should load story content
        XCTAssertGreaterThan(pack.regions.count, 0, "Should load regions")
        XCTAssertGreaterThan(pack.events.count, 0, "Should load events")
    }

    func testLoadBalanceConfiguration() throws {
        // Given
        let url = try XCTUnwrap(storyPackURL, "TwilightMarchesActI pack not available")
        let manifest = try PackManifest.load(from: url)

        // When
        let pack = try PackLoader.load(manifest: manifest, from: url)

        // Then
        XCTAssertNotNil(pack.balanceConfig, "Should load balance configuration")
    }

    func testBalanceConfigurationValues() throws {
        // Given
        let url = try XCTUnwrap(storyPackURL, "TwilightMarchesActI pack not available")
        let manifest = try PackManifest.load(from: url)
        let pack = try PackLoader.load(manifest: manifest, from: url)

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
        // Fail if character pack not available (Bundle.module resolution issue in tests)
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }

        // Given
        let url = characterPackURL!
        let manifest = try PackManifest.load(from: url)

        // When
        let pack = try PackLoader.load(manifest: manifest, from: url)

        // Then
        XCTAssertFalse(pack.cards.isEmpty, "Should load cards")

        // Verify card structure
        if let firstCard = pack.cards.values.first {
            XCTAssertFalse(firstCard.id.isEmpty)
            XCTAssertFalse(firstCard.name.isEmpty)
        }
    }

    func testCardsHaveValidFaithCost() throws {
        // Fail if character pack not available (Bundle.module resolution issue in tests)
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }

        // Given
        let url = characterPackURL!
        let manifest = try PackManifest.load(from: url)
        let pack = try PackLoader.load(manifest: manifest, from: url)

        // Then - All cards should have non-negative faith cost
        for (id, card) in pack.cards {
            XCTAssertGreaterThanOrEqual(card.faithCost, 0, "Card '\(id)' has negative faith cost")
        }
    }

    // MARK: - Heroes Loading Tests

    func testLoadHeroes() throws {
        // Fail if character pack not available (Bundle.module resolution issue in tests)
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }

        // Given
        let url = characterPackURL!
        let manifest = try PackManifest.load(from: url)

        // When
        let pack = try PackLoader.load(manifest: manifest, from: url)

        // Then
        XCTAssertFalse(pack.heroes.isEmpty, "Should load heroes")

        // Verify hero structure
        if let firstHero = pack.heroes.values.first {
            XCTAssertFalse(firstHero.id.isEmpty)
            XCTAssertFalse(firstHero.name.isEmpty)
        }
    }

    func testHeroesHaveStartingDecks() throws {
        // Fail if character pack not available (Bundle.module resolution issue in tests)
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }

        // Given
        let url = characterPackURL!
        let manifest = try PackManifest.load(from: url)
        let pack = try PackLoader.load(manifest: manifest, from: url)

        // Then - Heroes should have starting decks
        for (id, hero) in pack.heroes {
            XCTAssertFalse(hero.startingDeckCardIDs.isEmpty, "Hero '\(id)' has no starting deck")
        }
    }

    func testHeroesHaveValidBaseStats() throws {
        // Fail if character pack not available (Bundle.module resolution issue in tests)
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }

        // Given
        let url = characterPackURL!
        let manifest = try PackManifest.load(from: url)
        let pack = try PackLoader.load(manifest: manifest, from: url)

        // Then - Heroes should have valid base stats
        for (id, hero) in pack.heroes {
            XCTAssertGreaterThan(hero.baseStats.maxHealth, 0, "Hero '\(id)' has invalid maxHealth")
            XCTAssertGreaterThan(hero.baseStats.maxFaith, 0, "Hero '\(id)' has invalid maxFaith")
        }
    }

    func testHeroesHaveSpecialAbility() throws {
        // Fail if character pack not available (Bundle.module resolution issue in tests)
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }

        // Given
        let url = characterPackURL!
        let manifest = try PackManifest.load(from: url)
        let pack = try PackLoader.load(manifest: manifest, from: url)

        // Then - Heroes should have special ability from their class
        for (id, hero) in pack.heroes {
            XCTAssertFalse(hero.specialAbility.id.isEmpty, "Hero '\(id)' has no special ability")
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

    func testLoadPackWithCorruptedJSONThrows() throws {
        // Given: a temp directory with broken regions file
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PackLoaderTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Write corrupted regions JSON
        try "{ not valid json [[[".data(using: .utf8)!.write(to: tempDir.appendingPathComponent("regions.json"))

        // Create manifest programmatically pointing to the corrupted file
        let manifest = PackManifest(
            packId: "broken-test",
            displayName: LocalizedString(en: "Broken", ru: "Сломанный"),
            description: LocalizedString(en: "Test", ru: "Тест"),
            version: SemanticVersion(major: 1, minor: 0, patch: 0),
            packType: .campaign,
            coreVersionMin: SemanticVersion(major: 1, minor: 0, patch: 0),
            author: "test",
            regionsPath: "regions.json"
        )

        // Then
        XCTAssertThrowsError(try PackLoader.load(manifest: manifest, from: tempDir))
    }

    // MARK: - SHA256 Tests

    func testComputeSHA256ProducesConsistentHash() throws {
        // Given: a temp file with known content
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("sha256test_\(UUID().uuidString).txt")
        try "hello world".data(using: .utf8)!.write(to: tempFile)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        // When
        let hash1 = try PackLoader.computeSHA256(of: tempFile)
        let hash2 = try PackLoader.computeSHA256(of: tempFile)

        // Then
        XCTAssertEqual(hash1, hash2, "Same file should produce same hash")
        XCTAssertEqual(hash1.count, 64, "SHA256 hex string should be 64 characters")
    }

    func testComputeSHA256DiffersForDifferentContent() throws {
        let tempFile1 = FileManager.default.temporaryDirectory
            .appendingPathComponent("sha256test_a_\(UUID().uuidString).txt")
        let tempFile2 = FileManager.default.temporaryDirectory
            .appendingPathComponent("sha256test_b_\(UUID().uuidString).txt")
        try "content A".data(using: .utf8)!.write(to: tempFile1)
        try "content B".data(using: .utf8)!.write(to: tempFile2)
        defer {
            try? FileManager.default.removeItem(at: tempFile1)
            try? FileManager.default.removeItem(at: tempFile2)
        }

        // When
        let hash1 = try PackLoader.computeSHA256(of: tempFile1)
        let hash2 = try PackLoader.computeSHA256(of: tempFile2)

        // Then
        XCTAssertNotEqual(hash1, hash2, "Different content should produce different hashes")
    }

    func testComputeSHA256ThrowsForMissingFile() {
        let missingFile = URL(fileURLWithPath: "/nonexistent/file.txt")
        XCTAssertThrowsError(try PackLoader.computeSHA256(of: missingFile))
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

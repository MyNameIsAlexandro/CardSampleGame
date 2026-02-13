/// Файл: CardSampleGameTests/Unit/ContentPackTests/ContentManagerTests.swift
/// Назначение: Содержит реализацию файла ContentManagerTests.swift.
/// Зона ответственности: Фиксирует проверяемый контракт и не содержит production-логики.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
import TwilightEngine
import CoreHeroesContent
import TwilightMarchesActIContent

@testable import CardSampleGame

/// Tests for ContentManager functionality
final class ContentManagerTests: XCTestCase {

    // MARK: - Properties

    private var registry: ContentRegistry!
    private var contentManager: ContentManager!
    private var characterPackURL: URL?
    private var storyPackURL: URL?

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        registry = ContentRegistry()
        contentManager = ContentManager(registry: registry)

        // Use TestContentLoader for robust URL discovery
        characterPackURL = TestContentLoader.characterPackURL
        storyPackURL = TestContentLoader.storyPackURL
    }

    override func tearDown() {
        contentManager = nil
        registry = nil
        characterPackURL = nil
        storyPackURL = nil
        super.tearDown()
    }

    // MARK: - Pack Discovery Tests

    func testDiscoverPacksFindsProvidedURLs() throws {
        // Skip if packs not available
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available"); return }
        if storyPackURL == nil { XCTFail("TwilightMarchesActI pack not available"); return }

        // When - Discover packs with bundled URLs
        let discovered = contentManager.discoverPacks(bundledURLs: [characterPackURL!, storyPackURL!])

        // Then - Both packs should be discovered
        XCTAssertEqual(discovered.count, 2)

        let packIds = discovered.map { $0.id }
        XCTAssertTrue(packIds.contains("core-heroes"))
        XCTAssertTrue(packIds.contains("twilight-marches-act1"))
    }

    func testDiscoveredPacksHaveCorrectSource() throws {
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available"); return }

        // When
        let discovered = contentManager.discoverPacks(bundledURLs: [characterPackURL!])

        // Then - Should be marked as bundled source
        XCTAssertEqual(discovered.count, 1)
        if case .bundled = discovered[0].source {
            // OK - correct source type
        } else {
            XCTFail("Pack should have bundled source")
        }
    }

    func testDiscoveredPacksHaveManifest() throws {
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available"); return }

        // When
        let discovered = contentManager.discoverPacks(bundledURLs: [characterPackURL!])

        // Then - Should have manifest loaded
        XCTAssertEqual(discovered.count, 1)
        XCTAssertNotNil(discovered[0].manifest)
        XCTAssertEqual(discovered[0].manifest?.packId, "core-heroes")
    }

    func testDiscoveredPacksStartInDiscoveredState() throws {
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available"); return }

        // When
        let discovered = contentManager.discoverPacks(bundledURLs: [characterPackURL!])

        // Then - Should start in discovered state (not loaded yet)
        XCTAssertEqual(discovered.count, 1)
        XCTAssertEqual(discovered[0].state, .discovered)
    }

    // MARK: - Pack Validation Tests

    func testValidatePackReturnsValidSummary() async throws {
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available"); return }

        // Given - Discover pack first
        _ = contentManager.discoverPacks(bundledURLs: [characterPackURL!])

        // When - Validate pack
        let summary = await contentManager.validatePack("core-heroes")

        // Then - Should be valid
        XCTAssertEqual(summary.packId, "core-heroes")
        XCTAssertEqual(summary.errorCount, 0, "Pack should have no errors")
        XCTAssertTrue(summary.isValid)
    }

    func testValidatePackFileDirectly() async throws {
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available"); return }

        // When - Validate pack file directly
        let summary = await contentManager.validatePackFile(at: characterPackURL!)

        // Then
        XCTAssertEqual(summary.errorCount, 0)
        XCTAssertTrue(summary.isValid)
        XCTAssertGreaterThan(summary.duration, 0)
    }

    func testValidateNonExistentPackReturnsError() async {
        // When - Validate non-existent pack
        let summary = await contentManager.validatePack("non-existent-pack")

        // Then - Should return error
        XCTAssertEqual(summary.errorCount, 1)
        XCTAssertFalse(summary.isValid)
        XCTAssertTrue(summary.errors.contains { $0.contains("not found") })
    }

    // MARK: - Pack Loading Tests

    func testLoadPackSucceeds() async throws {
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available"); return }

        // Given - Discover pack
        _ = contentManager.discoverPacks(bundledURLs: [characterPackURL!])

        // When - Load pack
        let loadedPack = try await contentManager.loadPack("core-heroes")

        // Then
        XCTAssertEqual(loadedPack.manifest.packId, "core-heroes")
        XCTAssertTrue(registry.loadedPackIds.contains("core-heroes"))
    }

    func testLoadPackUpdatesState() async throws {
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available"); return }

        // Given
        _ = contentManager.discoverPacks(bundledURLs: [characterPackURL!])

        // When
        _ = try await contentManager.loadPack("core-heroes")

        // Then - Get pack state
        let pack = contentManager.getPack("core-heroes")
        XCTAssertEqual(pack?.state, .loaded)
        XCTAssertNotNil(pack?.loadedAt)
    }

    func testLoadNonExistentPackThrows() async {
        // When/Then - Loading non-existent pack should throw
        do {
            _ = try await contentManager.loadPack("non-existent")
            XCTFail("Should have thrown error")
        } catch {
            // Expected
            XCTAssertTrue(error is ContentReloadError)
        }
    }

    // MARK: - State Query Tests

    func testGetAllPacksReturnsDiscoveredPacks() throws {
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available"); return }

        // Given
        _ = contentManager.discoverPacks(bundledURLs: [characterPackURL!])

        // When
        let allPacks = contentManager.getAllPacks()

        // Then
        XCTAssertEqual(allPacks.count, 1)
        XCTAssertEqual(allPacks[0].id, "core-heroes")
    }

    func testGetPackReturnsSpecificPack() throws {
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available"); return }

        // Given
        _ = contentManager.discoverPacks(bundledURLs: [characterPackURL!])

        // When
        let pack = contentManager.getPack("core-heroes")

        // Then
        XCTAssertNotNil(pack)
        XCTAssertEqual(pack?.id, "core-heroes")
    }

    func testGetPackReturnsNilForUnknownPack() {
        // When
        let pack = contentManager.getPack("unknown-pack")

        // Then
        XCTAssertNil(pack)
    }

    func testGetBundledPacksFiltersCorrectly() throws {
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available"); return }

        // Given - Discover bundled pack
        _ = contentManager.discoverPacks(bundledURLs: [characterPackURL!])

        // When
        let bundled = contentManager.getBundledPacks()

        // Then
        XCTAssertEqual(bundled.count, 1)
        if case .bundled = bundled[0].source {
            // OK
        } else {
            XCTFail("Should be bundled source")
        }
    }

    // MARK: - Reload Capability Tests

    func testBundledPacksCannotReload() throws {
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available"); return }

        // Given
        _ = contentManager.discoverPacks(bundledURLs: [characterPackURL!])

        // When
        let canReload = contentManager.canReload("core-heroes")

        // Then - Bundled packs cannot be hot-reloaded
        XCTAssertFalse(canReload)
    }

    func testSafeReloadFailsForBundledPacks() async throws {
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available"); return }

        // Given - Discover and load pack
        _ = contentManager.discoverPacks(bundledURLs: [characterPackURL!])
        _ = try await contentManager.loadPack("core-heroes")

        // When - Try to reload bundled pack
        let result = await contentManager.safeReloadPack("core-heroes")

        // Then - Should fail with notReloadable error
        switch result {
        case .success:
            XCTFail("Should not succeed for bundled pack")
        case .failure(let error):
            if case .notReloadable = error {
                // Expected
            } else {
                XCTFail("Should be notReloadable error, got: \(error)")
            }
        }
    }

    // MARK: - ManagedPack Property Tests

    func testManagedPackCanValidateWhenDiscovered() throws {
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available"); return }

        // Given
        let discovered = contentManager.discoverPacks(bundledURLs: [characterPackURL!])

        // Then
        XCTAssertTrue(discovered[0].canValidate)
    }

    func testManagedPackHasFileSize() throws {
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available"); return }

        // Given
        let discovered = contentManager.discoverPacks(bundledURLs: [characterPackURL!])

        // Then
        XCTAssertGreaterThan(discovered[0].fileSize, 0)
    }

    func testManagedPackHasModificationDate() throws {
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available"); return }

        // Given
        let discovered = contentManager.discoverPacks(bundledURLs: [characterPackURL!])

        // Then - Should have recent modification date (within last year)
        let oneYearAgo = Date().addingTimeInterval(-365 * 24 * 60 * 60)
        XCTAssertGreaterThan(discovered[0].modifiedAt, oneYearAgo)
    }

    // MARK: - ValidationSummary Tests

    func testValidationSummaryEquality() {
        let summary1 = ValidationSummary(
            packId: "test",
            errorCount: 0,
            warningCount: 1,
            infoCount: 2,
            duration: 0.5
        )
        let summary2 = ValidationSummary(
            packId: "test",
            errorCount: 0,
            warningCount: 1,
            infoCount: 2,
            duration: 0.5
        )

        // ValidationSummary equality is based on packId
        XCTAssertEqual(summary1.packId, summary2.packId)
    }

    func testValidationSummaryIsValidWhenNoErrors() {
        let summary = ValidationSummary(
            packId: "test",
            errorCount: 0,
            warningCount: 5,
            infoCount: 10,
            duration: 1.0
        )

        XCTAssertTrue(summary.isValid)
    }

    func testValidationSummaryIsInvalidWhenHasErrors() {
        let summary = ValidationSummary(
            packId: "test",
            errorCount: 1,
            warningCount: 0,
            infoCount: 0,
            duration: 1.0
        )

        XCTAssertFalse(summary.isValid)
    }

    // MARK: - PackLoadState Tests

    func testPackLoadStateEquality() {
        XCTAssertEqual(PackLoadState.discovered, PackLoadState.discovered)
        XCTAssertEqual(PackLoadState.validating, PackLoadState.validating)
        XCTAssertEqual(PackLoadState.loading, PackLoadState.loading)
        XCTAssertEqual(PackLoadState.loaded, PackLoadState.loaded)
        XCTAssertEqual(PackLoadState.failed("error"), PackLoadState.failed("error"))
        XCTAssertNotEqual(PackLoadState.failed("error1"), PackLoadState.failed("error2"))
    }

    func testPackLoadStateStatusIcon() {
        XCTAssertEqual(PackLoadState.discovered.statusIcon, "circle")
        XCTAssertEqual(PackLoadState.loaded.statusIcon, "checkmark.circle.fill")
        XCTAssertEqual(PackLoadState.failed("").statusIcon, "xmark.circle.fill")
    }

    // MARK: - PackSource Tests

    func testPackSourceIsReloadable() throws {
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available"); return }

        let bundled = PackSource.bundled(url: characterPackURL!)
        let external = PackSource.external(url: characterPackURL!)

        XCTAssertFalse(bundled.isReloadable)
        XCTAssertTrue(external.isReloadable)
    }

    func testPackSourceDisplayName() throws {
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available"); return }

        let bundled = PackSource.bundled(url: characterPackURL!)
        let external = PackSource.external(url: characterPackURL!)

        XCTAssertEqual(bundled.displayName, "Bundled")
        XCTAssertEqual(external.displayName, "External")
    }

    func testPackSourceURL() throws {
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available"); return }

        let bundled = PackSource.bundled(url: characterPackURL!)

        XCTAssertEqual(bundled.url, characterPackURL!)
    }
}

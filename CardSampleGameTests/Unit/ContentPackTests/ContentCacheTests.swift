import XCTest
@testable import CardSampleGame

/// Tests for the content caching system
/// Verifies cache validation, storage, and retrieval functionality
final class ContentCacheTests: XCTestCase {

    var cache: FileSystemCache!

    override func setUp() {
        super.setUp()
        cache = FileSystemCache.shared
        // Clear cache for clean test state
        cache.clearAllCache()
        // Загружаем ContentPacks для тестов
        TestContentLoader.loadContentPacksIfNeeded()
    }

    override func tearDown() {
        // Clean up after tests
        cache.clearAllCache()
        super.tearDown()
    }

    // MARK: - Hash Computation Tests

    func testContentHashIsConsistent() throws {
        // Given: A content pack URL
        guard let packURL = findTestPackURL() else {
            throw XCTSkip("ContentPacks not found in test environment")
        }

        // When: Computing hash twice
        let hash1 = try CacheValidator.computeContentHash(for: packURL)
        let hash2 = try CacheValidator.computeContentHash(for: packURL)

        // Then: Hashes should be identical
        XCTAssertEqual(hash1, hash2, "Same content should produce same hash")
        XCTAssertFalse(hash1.isEmpty, "Hash should not be empty")
    }

    func testContentHashFormat() throws {
        // Given: A content pack URL
        guard let packURL = findTestPackURL() else {
            throw XCTSkip("ContentPacks not found in test environment")
        }

        // When: Computing hash
        let hash = try CacheValidator.computeContentHash(for: packURL)

        // Then: Hash should be valid SHA256 hex string (64 characters)
        XCTAssertEqual(hash.count, 64, "SHA256 hash should be 64 hex characters")
        XCTAssertTrue(hash.allSatisfy { $0.isHexDigit }, "Hash should contain only hex characters")
    }

    // MARK: - Cache Validity Tests

    func testCacheValidityWithMatchingHash() {
        // Given: Metadata with known values
        let metadata = CacheMetadata(
            packId: "test-pack",
            version: SemanticVersion(major: 1, minor: 0, patch: 0),
            contentHash: "abc123def456",
            cachedAt: Date(),
            engineVersion: CoreVersion.current.description
        )

        // When: Validating with same hash
        let isValid = CacheValidator.isCacheValid(
            metadata: metadata,
            currentHash: "abc123def456"
        )

        // Then: Cache should be valid
        XCTAssertTrue(isValid, "Cache with matching hash should be valid")
    }

    func testCacheInvalidWithDifferentHash() {
        // Given: Metadata with known hash
        let metadata = CacheMetadata(
            packId: "test-pack",
            version: SemanticVersion(major: 1, minor: 0, patch: 0),
            contentHash: "abc123def456",
            cachedAt: Date(),
            engineVersion: CoreVersion.current.description
        )

        // When: Validating with different hash
        let isValid = CacheValidator.isCacheValid(
            metadata: metadata,
            currentHash: "xyz789different"
        )

        // Then: Cache should be invalid
        XCTAssertFalse(isValid, "Cache with different hash should be invalid")
    }

    func testCacheInvalidWithMajorVersionChange() {
        // Given: Metadata with older engine version
        let metadata = CacheMetadata(
            packId: "test-pack",
            version: SemanticVersion(major: 1, minor: 0, patch: 0),
            contentHash: "abc123",
            cachedAt: Date(),
            engineVersion: "0.9.0"  // Different major version
        )

        // When: Validating with current engine (1.0.0)
        let isValid = CacheValidator.isCacheValid(
            metadata: metadata,
            currentHash: "abc123",
            currentEngineVersion: "1.0.0"
        )

        // Then: Cache should be invalid due to version mismatch
        XCTAssertFalse(isValid, "Cache with different major version should be invalid")
    }

    func testCacheValidWithPatchVersionChange() {
        // Given: Metadata with same major.minor but different patch
        let metadata = CacheMetadata(
            packId: "test-pack",
            version: SemanticVersion(major: 1, minor: 0, patch: 0),
            contentHash: "abc123",
            cachedAt: Date(),
            engineVersion: "1.0.0"
        )

        // When: Validating with different patch version
        let isValid = CacheValidator.isCacheValid(
            metadata: metadata,
            currentHash: "abc123",
            currentEngineVersion: "1.0.5"  // Same major.minor, different patch
        )

        // Then: Cache should still be valid
        XCTAssertTrue(isValid, "Cache with same major.minor should be valid regardless of patch")
    }

    // MARK: - Cache Storage Tests

    func testHasValidCacheReturnsFalseForEmptyCache() {
        // Given: Empty cache
        cache.clearAllCache()

        // When: Checking for cache
        let hasCache = cache.hasValidCache(for: "nonexistent-pack", contentHash: "any-hash")

        // Then: Should return false
        XCTAssertFalse(hasCache, "Empty cache should not have valid entries")
    }

    func testGetCacheMetadataReturnsNilForMissingPack() {
        // Given: Empty cache
        cache.clearAllCache()

        // When: Getting metadata for nonexistent pack
        let metadata = cache.getCacheMetadata(for: "nonexistent-pack")

        // Then: Should return nil
        XCTAssertNil(metadata, "Should return nil for missing pack")
    }

    // MARK: - Cache Save/Load Integration Tests

    func testSaveAndLoadPackRoundtrip() throws {
        // Given: A mock LoadedPack
        let mockPack = createMockLoadedPack()
        let testHash = "test-content-hash-12345"

        // When: Saving pack to cache
        try cache.savePack(mockPack, contentHash: testHash)

        // Then: Cache should exist
        XCTAssertTrue(
            cache.hasValidCache(for: mockPack.manifest.packId, contentHash: testHash),
            "Cache should be valid after saving"
        )

        // And: Loading should return the pack
        let loaded = try cache.loadCachedPack(packId: mockPack.manifest.packId)
        XCTAssertNotNil(loaded, "Should be able to load cached pack")
        XCTAssertEqual(loaded?.manifest.packId, mockPack.manifest.packId)
        XCTAssertEqual(loaded?.metadata.contentHash, testHash)
    }

    func testCacheInvalidation() throws {
        // Given: A cached pack
        let mockPack = createMockLoadedPack()
        try cache.savePack(mockPack, contentHash: "test-hash")

        // Verify it's cached
        XCTAssertNotNil(cache.getCacheMetadata(for: mockPack.manifest.packId))

        // When: Invalidating cache
        cache.invalidateCache(for: mockPack.manifest.packId)

        // Then: Cache should be gone
        XCTAssertNil(cache.getCacheMetadata(for: mockPack.manifest.packId))
    }

    func testClearAllCache() throws {
        // Given: Multiple cached packs
        let pack1 = createMockLoadedPack(packId: "pack-1")
        let pack2 = createMockLoadedPack(packId: "pack-2")
        try cache.savePack(pack1, contentHash: "hash1")
        try cache.savePack(pack2, contentHash: "hash2")

        // Verify both are cached
        XCTAssertEqual(cache.cachedPackIds.count, 2)

        // When: Clearing all cache
        cache.clearAllCache()

        // Then: All caches should be gone
        XCTAssertEqual(cache.cachedPackIds.count, 0)
    }

    // MARK: - CacheMetadata Tests

    func testCacheMetadataValidation() {
        // Given: Valid metadata
        let metadata = CacheMetadata(
            packId: "test",
            version: SemanticVersion(major: 1, minor: 0, patch: 0),
            contentHash: "abc123",
            cachedAt: Date(),
            engineVersion: "1.0.0"
        )

        // Then: isValid should work correctly
        XCTAssertTrue(metadata.isValid(currentHash: "abc123", currentEngineVersion: "1.0.0"))
        XCTAssertFalse(metadata.isValid(currentHash: "different", currentEngineVersion: "1.0.0"))
        XCTAssertFalse(metadata.isValid(currentHash: "abc123", currentEngineVersion: "2.0.0"))
    }

    // MARK: - CachedPackData Tests

    func testCachedPackDataConversion() {
        // Given: A LoadedPack
        let pack = createMockLoadedPack()
        let hash = "test-hash-value"

        // When: Converting to CachedPackData
        let cached = CachedPackData(from: pack, contentHash: hash)

        // Then: Data should be preserved
        XCTAssertEqual(cached.manifest.packId, pack.manifest.packId)
        XCTAssertEqual(cached.metadata.contentHash, hash)
        XCTAssertEqual(cached.regions.count, pack.regions.count)
        XCTAssertEqual(cached.events.count, pack.events.count)

        // And: Converting back should work
        let restored = cached.toLoadedPack()
        XCTAssertEqual(restored.manifest.packId, pack.manifest.packId)
        XCTAssertEqual(restored.regions.count, pack.regions.count)
    }

    // MARK: - Performance Tests

    func testCacheLoadPerformance() throws {
        // Given: A cached pack
        let mockPack = createMockLoadedPack()
        try cache.savePack(mockPack, contentHash: "perf-test-hash")

        // Measure load time
        measure {
            _ = try? cache.loadCachedPack(packId: mockPack.manifest.packId)
        }
    }

    // MARK: - Helpers

    private func findTestPackURL() -> URL? {
        // Try bundle first
        if let url = Bundle.main.url(forResource: "TwilightMarches", withExtension: nil, subdirectory: "ContentPacks") {
            return url
        }

        // Try test bundle
        if let url = Bundle(for: type(of: self)).url(forResource: "TwilightMarches", withExtension: nil, subdirectory: "ContentPacks") {
            return url
        }

        // Try file path for development
        #if DEBUG
        let projectPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("ContentPacks/TwilightMarches")

        if FileManager.default.fileExists(atPath: projectPath.path) {
            return projectPath
        }
        #endif

        return nil
    }

    private func createMockLoadedPack(packId: String = "test-pack") -> LoadedPack {
        let manifest = PackManifest(
            packId: packId,
            name: LocalizedString(en: "Test Pack", ru: "Тестовый пак"),
            version: SemanticVersion(major: 1, minor: 0, patch: 0),
            type: .campaign,
            coreVersionMin: SemanticVersion(major: 1, minor: 0, patch: 0),
            coreVersionMax: nil,
            author: "Test",
            description: nil,
            dependencies: [],
            supportedLocales: ["en", "ru"],
            entryRegionId: "test-region",
            entryQuestId: nil,
            regionsPath: nil,
            eventsPath: nil,
            questsPath: nil,
            anchorsPath: nil,
            heroesPath: nil,
            abilitiesPath: nil,
            cardsPath: nil,
            enemiesPath: nil,
            balancePath: nil,
            checksums: nil
        )

        var pack = LoadedPack(
            manifest: manifest,
            sourceURL: URL(fileURLWithPath: "/test"),
            loadedAt: Date()
        )

        // Add some mock content
        pack.regions["test-region"] = RegionDefinition(
            id: "test-region",
            title: LocalizedString(en: "Test Region", ru: "Тестовый регион"),
            description: nil,
            regionType: .settlement,
            neighborIds: [],
            initiallyDiscovered: true,
            anchorId: nil,
            eventPoolIds: [],
            initialState: .stable,
            degradationWeight: 1
        )

        return pack
    }
}

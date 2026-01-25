import Foundation

// MARK: - Content Cache Protocol

/// Protocol for content caching implementations
/// Allows different storage backends (FileSystem, CoreData, etc.)
public protocol ContentCache {
    /// Check if valid cache exists for a pack
    func hasValidCache(for packId: String, contentHash: String) -> Bool

    /// Load cached pack data
    func loadCachedPack(packId: String) throws -> CachedPackData?

    /// Save pack to cache
    func savePack(_ pack: LoadedPack, contentHash: String) throws

    /// Invalidate cache for a specific pack
    func invalidateCache(for packId: String)

    /// Clear all cached data
    func clearAllCache()

    /// Get cache metadata without loading full content
    func getCacheMetadata(for packId: String) -> CacheMetadata?
}

// MARK: - File System Cache

/// File-based cache implementation using JSON files
/// Stores cached packs in Application Support directory
public final class FileSystemCache: ContentCache {

    // MARK: - Singleton

    public static let shared = FileSystemCache()

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Base directory for cache storage
    /// ~/Library/Application Support/CardSampleGame/ContentCache/
    private var cacheDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("CardSampleGame")
            .appendingPathComponent("ContentCache")
    }

    // MARK: - Initialization

    private init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Ensure cache directory exists
        try? createCacheDirectoryIfNeeded()
    }

    // MARK: - ContentCache Protocol

    public func hasValidCache(for packId: String, contentHash: String) -> Bool {
        guard let metadata = getCacheMetadata(for: packId) else {
            return false
        }
        return CacheValidator.isCacheValid(
            metadata: metadata,
            currentHash: contentHash
        )
    }

    public func loadCachedPack(packId: String) throws -> CachedPackData? {
        let packDir = cacheDirectory.appendingPathComponent(packId)
        let contentURL = packDir.appendingPathComponent("content.json")

        guard fileManager.fileExists(atPath: contentURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: contentURL)
        let cached = try decoder.decode(CachedPackData.self, from: data)

        return cached
    }

    public func savePack(_ pack: LoadedPack, contentHash: String) throws {
        let packDir = cacheDirectory.appendingPathComponent(pack.manifest.packId)

        // Create pack directory
        try fileManager.createDirectory(at: packDir, withIntermediateDirectories: true)

        // Create cached data
        let cached = CachedPackData(from: pack, contentHash: contentHash)

        // Save metadata separately for quick validation
        let metadataURL = packDir.appendingPathComponent("metadata.json")
        let metadataData = try encoder.encode(cached.metadata)
        try metadataData.write(to: metadataURL)

        // Save full content
        let contentURL = packDir.appendingPathComponent("content.json")
        let contentData = try encoder.encode(cached)
        try contentData.write(to: contentURL)

        #if DEBUG
        print("💾 Saved pack to cache: \(pack.manifest.packId)")
        #endif
    }

    public func invalidateCache(for packId: String) {
        let packDir = cacheDirectory.appendingPathComponent(packId)
        try? fileManager.removeItem(at: packDir)
        #if DEBUG
        print("🗑️ Invalidated cache for: \(packId)")
        #endif
    }

    public func clearAllCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? createCacheDirectoryIfNeeded()
        #if DEBUG
        print("🗑️ Cleared all content cache")
        #endif
    }

    public func getCacheMetadata(for packId: String) -> CacheMetadata? {
        let metadataURL = cacheDirectory
            .appendingPathComponent(packId)
            .appendingPathComponent("metadata.json")

        guard fileManager.fileExists(atPath: metadataURL.path),
              let data = try? Data(contentsOf: metadataURL),
              let metadata = try? decoder.decode(CacheMetadata.self, from: data) else {
            return nil
        }

        return metadata
    }

    // MARK: - Cache Statistics

    /// Get list of all cached pack IDs
    var cachedPackIds: [String] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents
            .filter { $0.hasDirectoryPath }
            .map { $0.lastPathComponent }
    }

    /// Get total size of cache in bytes
    var totalCacheSize: Int64 {
        guard let enumerator = fileManager.enumerator(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var size: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                size += Int64(fileSize)
            }
        }
        return size
    }

    /// Formatted cache size string
    var formattedCacheSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalCacheSize)
    }

    // MARK: - Private Helpers

    private func createCacheDirectoryIfNeeded() throws {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try fileManager.createDirectory(
                at: cacheDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension FileSystemCache {
    /// Print cache status for debugging
    func printCacheStatus() {
        print("=== Content Cache Status ===")
        print("Location: \(cacheDirectory.path)")
        print("Total size: \(formattedCacheSize)")
        print("Cached packs:")
        for packId in cachedPackIds {
            if let metadata = getCacheMetadata(for: packId) {
                print("  - \(packId) v\(metadata.version) (hash: \(metadata.contentHash.prefix(8))...)")
            }
        }
        print("============================")
    }
}
#endif

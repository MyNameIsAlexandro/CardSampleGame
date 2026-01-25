import Foundation
import CryptoKit

// MARK: - Cache Validator

/// Validates content cache freshness using SHA256 hashing
/// Part of the universal caching system for the game engine
public struct CacheValidator {

    // MARK: - Hash Computation

    /// Compute SHA256 hash of all JSON files in a content pack
    /// - Parameter packURL: URL to the pack directory
    /// - Returns: Hex string of SHA256 hash
    /// - Throws: Error if files cannot be read
    public static func computeContentHash(for packURL: URL) throws -> String {
        var hasher = SHA256()
        let fileManager = FileManager.default

        // Start with manifest.json
        let manifestURL = packURL.appendingPathComponent("manifest.json")
        if let data = fileManager.contents(atPath: manifestURL.path) {
            hasher.update(data: data)
        }

        // Load manifest to get content paths
        let manifest = try PackManifest.load(from: packURL)
        let contentPaths = collectContentPaths(from: manifest)

        // Hash each content file in sorted order (for consistency)
        for relativePath in contentPaths.sorted() {
            let fileURL = packURL.appendingPathComponent(relativePath)

            if isDirectory(fileURL) {
                // Hash all JSON files in directory
                let jsonFiles = try getJSONFiles(in: fileURL)
                for jsonFile in jsonFiles.sorted(by: { $0.path < $1.path }) {
                    if let data = fileManager.contents(atPath: jsonFile.path) {
                        hasher.update(data: data)
                    }
                }
            } else if fileManager.fileExists(atPath: fileURL.path) {
                // Hash single file
                if let data = fileManager.contents(atPath: fileURL.path) {
                    hasher.update(data: data)
                }
            }
        }

        // Finalize and return hex string
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Validation

    /// Check if cached metadata is still valid
    /// - Parameters:
    ///   - metadata: Cached metadata to validate
    ///   - currentHash: Current content hash
    ///   - currentEngineVersion: Current engine version string
    /// - Returns: true if cache is valid and can be used
    public static func isCacheValid(
        metadata: CacheMetadata,
        currentHash: String,
        currentEngineVersion: String = CoreVersion.current.description
    ) -> Bool {
        return metadata.isValid(currentHash: currentHash, currentEngineVersion: currentEngineVersion)
    }

    // MARK: - Private Helpers

    /// Collect all content file paths from manifest
    private static func collectContentPaths(from manifest: PackManifest) -> [String] {
        var paths: [String] = []

        if let path = manifest.regionsPath { paths.append(path) }
        if let path = manifest.eventsPath { paths.append(path) }
        if let path = manifest.questsPath { paths.append(path) }
        if let path = manifest.anchorsPath { paths.append(path) }
        if let path = manifest.heroesPath { paths.append(path) }
        if let path = manifest.abilitiesPath { paths.append(path) }
        if let path = manifest.cardsPath { paths.append(path) }
        if let path = manifest.enemiesPath { paths.append(path) }
        if let path = manifest.balancePath { paths.append(path) }

        return paths
    }

    /// Check if URL points to a directory
    private static func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    /// Get all JSON files in a directory
    private static func getJSONFiles(in directoryURL: URL) throws -> [URL] {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return contents.filter { $0.pathExtension.lowercased() == "json" }
    }
}

// MARK: - Cache Error

/// Errors related to cache operations
public enum CacheError: Error, LocalizedError {
    case directoryCreationFailed(path: String)
    case saveFailed(reason: String)
    case loadFailed(reason: String)
    case invalidCacheData
    case hashComputationFailed

    public var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let path):
            return "Failed to create cache directory: \(path)"
        case .saveFailed(let reason):
            return "Failed to save cache: \(reason)"
        case .loadFailed(let reason):
            return "Failed to load cache: \(reason)"
        case .invalidCacheData:
            return "Cache data is invalid or corrupted"
        case .hashComputationFailed:
            return "Failed to compute content hash"
        }
    }
}

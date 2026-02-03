import Foundation
import Compression
import CryptoKit

// MARK: - Binary Pack Format
// .pack file = Header + gzip(JSON-encoded PackContent)
//
// Format v1 (10 bytes header): Magic(4) + Version(2) + OriginalSize(4)
// Format v2 (42 bytes header): Magic(4) + Version(2) + OriginalSize(4) + SHA256(32)

/// Magic bytes for .pack file identification
private let packMagic: [UInt8] = [0x54, 0x57, 0x50, 0x4B] // "TWPK"

/// Binary pack format versions
private let packFormatVersionV1: UInt16 = 1
private let packFormatVersionV2: UInt16 = 2

/// Current version for writing (always latest)
private let packFormatVersion: UInt16 = packFormatVersionV2

/// Header sizes
private let headerSizeV1 = 10  // Magic(4) + Version(2) + OriginalSize(4)
private let headerSizeV2 = 42  // V1 header + SHA256(32)

// MARK: - Pack Content (serializable)

/// All content in a pack, serializable to binary format
public struct PackContent: Codable {
    public let manifest: PackManifest
    public let regions: [String: RegionDefinition]
    public let events: [String: EventDefinition]
    public let quests: [String: QuestDefinition]
    public let anchors: [String: AnchorDefinition]
    public let heroes: [String: StandardHeroDefinition]
    public let cards: [String: StandardCardDefinition]
    public let enemies: [String: EnemyDefinition]
    public let fateCards: [String: FateCard]
    public let abilities: [HeroAbility]
    public let balanceConfig: BalanceConfiguration?

    // Custom Decodable to handle backward compatibility (old .pack files without fateCards)
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        manifest = try container.decode(PackManifest.self, forKey: .manifest)
        regions = try container.decode([String: RegionDefinition].self, forKey: .regions)
        events = try container.decode([String: EventDefinition].self, forKey: .events)
        quests = try container.decode([String: QuestDefinition].self, forKey: .quests)
        anchors = try container.decode([String: AnchorDefinition].self, forKey: .anchors)
        heroes = try container.decode([String: StandardHeroDefinition].self, forKey: .heroes)
        cards = try container.decode([String: StandardCardDefinition].self, forKey: .cards)
        enemies = try container.decode([String: EnemyDefinition].self, forKey: .enemies)
        fateCards = try container.decodeIfPresent([String: FateCard].self, forKey: .fateCards) ?? [:]
        abilities = try container.decode([HeroAbility].self, forKey: .abilities)
        balanceConfig = try container.decodeIfPresent(BalanceConfiguration.self, forKey: .balanceConfig)
    }

    /// Create from LoadedPack
    public init(from pack: LoadedPack) {
        self.manifest = pack.manifest
        self.regions = pack.regions
        self.events = pack.events
        self.quests = pack.quests
        self.anchors = pack.anchors
        self.heroes = pack.heroes
        self.cards = pack.cards
        self.enemies = pack.enemies
        self.fateCards = pack.fateCards
        self.abilities = AbilityRegistry.shared.allAbilities
        self.balanceConfig = pack.balanceConfig
    }

    /// Convert to LoadedPack
    public func toLoadedPack(sourceURL: URL) -> LoadedPack {
        var pack = LoadedPack(manifest: manifest, sourceURL: sourceURL)
        pack.regions = regions
        pack.events = events
        pack.quests = quests
        pack.anchors = anchors
        pack.heroes = heroes
        pack.cards = cards
        pack.enemies = enemies
        pack.fateCards = fateCards
        pack.balanceConfig = balanceConfig
        return pack
    }
}

// MARK: - Binary Pack Writer

/// Compiles JSON packs to binary .pack format
public final class BinaryPackWriter {

    /// Compile a LoadedPack to binary .pack file
    /// - Parameters:
    ///   - pack: The loaded pack to compile
    ///   - outputURL: Destination URL for .pack file
    /// - Throws: Error if compilation fails
    public static func compile(_ pack: LoadedPack, to outputURL: URL) throws {
        let content = PackContent(from: pack)
        try compile(content, to: outputURL)
    }

    /// Compile PackContent to binary .pack file (v2 format with SHA256 checksum)
    public static func compile(_ content: PackContent, to outputURL: URL) throws {
        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [] // Compact, no pretty print
        let jsonData = try encoder.encode(content)

        // Compress with gzip
        let compressedData = try compress(jsonData)

        // Compute SHA256 checksum of compressed data
        let hash = SHA256.hash(data: compressedData)
        let checksum = Data(hash)

        // Build v2 file: Header (42 bytes) + Compressed Data
        var fileData = Data()

        // Magic (4 bytes)
        fileData.append(contentsOf: packMagic)

        // Format version (2 bytes, little-endian) - v2
        var version = packFormatVersionV2.littleEndian
        fileData.append(Data(bytes: &version, count: 2))

        // Original size (4 bytes, for decompression buffer allocation)
        var originalSize = UInt32(jsonData.count).littleEndian
        fileData.append(Data(bytes: &originalSize, count: 4))

        // SHA256 checksum (32 bytes)
        fileData.append(checksum)

        // Compressed data
        fileData.append(compressedData)

        // Write to file
        try fileData.write(to: outputURL)
    }

    /// Compress data using zlib
    private static func compress(_ data: Data) throws -> Data {
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
        defer { destinationBuffer.deallocate() }

        let compressedSize = data.withUnsafeBytes { sourceBuffer -> Int in
            guard let sourcePtr = sourceBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return 0
            }
            return compression_encode_buffer(
                destinationBuffer,
                data.count,
                sourcePtr,
                data.count,
                nil,
                COMPRESSION_ZLIB
            )
        }

        guard compressedSize > 0 else {
            throw PackLoadError.contentLoadFailed(file: "compression", underlyingError: NSError(domain: "BinaryPack", code: 1, userInfo: [NSLocalizedDescriptionKey: "Compression failed"]))
        }

        return Data(bytes: destinationBuffer, count: compressedSize)
    }
}

// MARK: - Binary Pack Reader

/// Loads binary .pack files
public final class BinaryPackReader {

    /// Load a .pack file
    /// - Parameter url: URL to .pack file
    /// - Returns: Loaded pack content
    /// - Throws: PackLoadError if loading fails
    public static func load(from url: URL) throws -> LoadedPack {
        let content = try loadContent(from: url)

        // Register abilities BEFORE creating LoadedPack
        AbilityRegistry.shared.registerAll(content.abilities)

        return content.toLoadedPack(sourceURL: url)
    }

    /// Load pack content from .pack file (supports v1 and v2 formats)
    public static func loadContent(from url: URL) throws -> PackContent {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PackLoadError.fileNotFound(url.path)
        }

        let fileData = try Data(contentsOf: url)

        // Verify minimum size for v1 header (10 bytes)
        guard fileData.count >= headerSizeV1 else {
            throw PackLoadError.invalidManifest(reason: "File too small")
        }

        // Verify magic
        let magic = Array(fileData[0..<4])
        guard magic == packMagic else {
            throw PackLoadError.invalidManifest(reason: "Invalid pack file (bad magic)")
        }

        // Read format version
        let formatVersion = fileData[4..<6].withUnsafeBytes { $0.loadUnaligned(as: UInt16.self).littleEndian }

        // Route to appropriate loader based on version
        switch formatVersion {
        case packFormatVersionV1:
            return try loadV1(fileData: fileData, url: url)
        case packFormatVersionV2:
            return try loadV2(fileData: fileData, url: url)
        default:
            throw PackLoadError.invalidManifest(reason: "Unsupported pack format version: \(formatVersion)")
        }
    }

    /// Load v1 format (no checksum)
    private static func loadV1(fileData: Data, url: URL) throws -> PackContent {
        // Read original size
        let originalSize = Int(fileData[6..<10].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).littleEndian })

        // Decompress
        let compressedData = fileData[headerSizeV1...]
        let jsonData = try decompress(Data(compressedData), originalSize: originalSize)

        // Decode JSON
        do {
            return try JSONDecoder().decode(PackContent.self, from: jsonData)
        } catch {
            throw PackLoadError.contentLoadFailed(file: url.lastPathComponent, underlyingError: error)
        }
    }

    /// Load v2 format (with SHA256 checksum verification)
    private static func loadV2(fileData: Data, url: URL) throws -> PackContent {
        // Verify minimum size for v2 header
        guard fileData.count >= headerSizeV2 else {
            throw PackLoadError.invalidManifest(reason: "V2 file too small")
        }

        // Read original size
        let originalSize = Int(fileData[6..<10].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).littleEndian })

        // Read expected checksum (32 bytes at offset 10)
        let expectedChecksum = fileData[10..<42]

        // Get compressed data (after 42-byte header)
        let compressedData = Data(fileData[headerSizeV2...])

        // Verify SHA256 checksum
        let actualHash = SHA256.hash(data: compressedData)
        let actualChecksum = Data(actualHash)
        guard actualChecksum == expectedChecksum else {
            throw PackLoadError.checksumMismatch(
                file: url.lastPathComponent,
                expected: expectedChecksum.map { String(format: "%02x", $0) }.joined(),
                actual: actualChecksum.map { String(format: "%02x", $0) }.joined()
            )
        }

        // Decompress
        let jsonData = try decompress(compressedData, originalSize: originalSize)

        // Decode JSON
        do {
            return try JSONDecoder().decode(PackContent.self, from: jsonData)
        } catch {
            throw PackLoadError.contentLoadFailed(file: url.lastPathComponent, underlyingError: error)
        }
    }

    /// Decompress data using zlib
    private static func decompress(_ data: Data, originalSize: Int) throws -> Data {
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: originalSize)
        defer { destinationBuffer.deallocate() }

        let decompressedSize = data.withUnsafeBytes { sourceBuffer -> Int in
            guard let sourcePtr = sourceBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return 0
            }
            return compression_decode_buffer(
                destinationBuffer,
                originalSize,
                sourcePtr,
                data.count,
                nil,
                COMPRESSION_ZLIB
            )
        }

        guard decompressedSize == originalSize else {
            throw PackLoadError.contentLoadFailed(file: "decompression", underlyingError: NSError(domain: "BinaryPack", code: 2, userInfo: [NSLocalizedDescriptionKey: "Decompression failed: expected \(originalSize), got \(decompressedSize)"]))
        }

        return Data(bytes: destinationBuffer, count: decompressedSize)
    }

    /// Check if URL points to a valid .pack file (quick check, doesn't load content)
    public static func isValidPackFile(_ url: URL) -> Bool {
        guard url.pathExtension == "pack" else { return false }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }

        guard let magicData = try? handle.read(upToCount: 4) else { return false }
        return Array(magicData) == packMagic
    }

    /// Get file info without full content load (useful for pack listing/validation)
    public static func getFileInfo(from url: URL) throws -> PackFileInfo {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PackLoadError.fileNotFound(url.path)
        }

        let fileData = try Data(contentsOf: url)

        guard fileData.count >= headerSizeV1 else {
            throw PackLoadError.invalidManifest(reason: "File too small")
        }

        // Verify magic
        let magic = Array(fileData[0..<4])
        guard magic == packMagic else {
            throw PackLoadError.invalidManifest(reason: "Invalid pack file (bad magic)")
        }

        // Read version
        let version = fileData[4..<6].withUnsafeBytes { $0.loadUnaligned(as: UInt16.self).littleEndian }

        // Read original size
        let originalSize = Int(fileData[6..<10].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).littleEndian })

        // Get file size
        let fileSize = fileData.count

        // For v2, extract and verify checksum
        var checksumHex: String? = nil
        var isValid = true

        if version == packFormatVersionV2 && fileData.count >= headerSizeV2 {
            let expectedChecksum = fileData[10..<42]
            checksumHex = expectedChecksum.map { String(format: "%02x", $0) }.joined()

            // Verify checksum
            let compressedData = Data(fileData[headerSizeV2...])
            let actualHash = SHA256.hash(data: compressedData)
            let actualChecksum = Data(actualHash)
            isValid = actualChecksum == expectedChecksum
        }

        return PackFileInfo(
            version: version,
            originalSize: originalSize,
            compressedSize: fileSize - (version == packFormatVersionV2 ? headerSizeV2 : headerSizeV1),
            checksumHex: checksumHex,
            isValid: isValid
        )
    }
}

// MARK: - Pack File Info

/// Information about a .pack file without loading full content
public struct PackFileInfo {
    /// Format version (1 or 2)
    public let version: UInt16

    /// Original uncompressed JSON size in bytes
    public let originalSize: Int

    /// Compressed payload size in bytes
    public let compressedSize: Int

    /// SHA256 checksum hex string (nil for v1)
    public let checksumHex: String?

    /// Whether checksum verification passed (always true for v1)
    public let isValid: Bool

    /// Compression ratio
    public var compressionRatio: Double {
        guard originalSize > 0 else { return 0 }
        return Double(compressedSize) / Double(originalSize)
    }
}

// MARK: - Pack File Extension

public extension URL {
    /// Check if this URL points to a .pack file
    var isPackFile: Bool {
        pathExtension == "pack"
    }
}

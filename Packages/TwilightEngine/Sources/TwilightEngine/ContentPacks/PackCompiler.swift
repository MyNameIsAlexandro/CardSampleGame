import Foundation

// MARK: - Pack Compiler
// Compiles JSON content packs to binary .pack format
// Used at build-time, NOT at runtime

/// Compiles JSON packs to binary .pack format
public enum PackCompiler {

    /// Compile a JSON pack directory to a .pack file
    /// - Parameters:
    ///   - sourceURL: URL to pack directory containing manifest.json and content
    ///   - outputURL: Destination URL for the .pack file
    /// - Returns: Compilation result with statistics
    /// - Throws: PackLoadError if compilation fails
    @discardableResult
    public static func compile(from sourceURL: URL, to outputURL: URL) throws -> CompilationResult {
        let startTime = Date()

        // Load manifest
        let manifest = try PackManifest.load(from: sourceURL)

        // Verify Core compatibility
        guard manifest.isCompatibleWithCore() else {
            throw PackLoadError.incompatibleCoreVersion(
                required: manifest.coreVersionMin,
                current: CoreVersion.current
            )
        }

        // Load pack content using existing PackLoader (JSON parsing)
        let pack = try PackLoader.load(manifest: manifest, from: sourceURL)

        // Compile to binary
        try BinaryPackWriter.compile(pack, to: outputURL)

        let endTime = Date()
        let compilationTime = endTime.timeIntervalSince(startTime)

        // Calculate sizes
        let inputSize = try calculateDirectorySize(sourceURL)
        let outputSize = try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64 ?? 0

        return CompilationResult(
            packId: manifest.packId,
            version: manifest.version,
            inputSize: inputSize,
            outputSize: outputSize,
            compilationTime: compilationTime,
            contentStats: ContentStats(from: pack)
        )
    }

    /// Compile multiple packs
    /// - Parameters:
    ///   - sources: Array of (sourceURL, outputURL) pairs
    /// - Returns: Array of compilation results
    public static func compileAll(_ sources: [(source: URL, output: URL)]) throws -> [CompilationResult] {
        var results: [CompilationResult] = []
        for (source, output) in sources {
            let result = try compile(from: source, to: output)
            results.append(result)
        }
        return results
    }

    /// Validate a pack without compiling
    /// - Parameter sourceURL: URL to pack directory
    /// - Returns: Validation result
    public static func validate(at sourceURL: URL) throws -> ValidationResult {
        // Load manifest
        let manifest = try PackManifest.load(from: sourceURL)

        // Check Core compatibility
        let coreCompatible = manifest.isCompatibleWithCore()

        // Try loading pack (validates all content)
        var contentValid = true
        var contentError: String? = nil

        do {
            _ = try PackLoader.load(manifest: manifest, from: sourceURL)
        } catch {
            contentValid = false
            contentError = error.localizedDescription
        }

        return ValidationResult(
            packId: manifest.packId,
            version: manifest.version,
            coreCompatible: coreCompatible,
            contentValid: contentValid,
            error: contentError
        )
    }

    // MARK: - Helpers

    private static func calculateDirectorySize(_ url: URL) throws -> Int64 {
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys)
        )

        var totalSize: Int64 = 0
        while let fileURL = enumerator?.nextObject() as? URL {
            let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
            if resourceValues.isRegularFile == true {
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }
        }
        return totalSize
    }
}

// MARK: - Compilation Result

/// Result of pack compilation
public struct CompilationResult {
    public let packId: String
    public let version: SemanticVersion
    public let inputSize: Int64
    public let outputSize: Int64
    public let compilationTime: TimeInterval
    public let contentStats: ContentStats

    /// Compression ratio (output/input)
    public var compressionRatio: Double {
        guard inputSize > 0 else { return 0 }
        return Double(outputSize) / Double(inputSize)
    }

    /// Human-readable summary
    public var summary: String {
        let inputKB = Double(inputSize) / 1024
        let outputKB = Double(outputSize) / 1024
        let ratio = String(format: "%.1f%%", compressionRatio * 100)
        let time = String(format: "%.2fs", compilationTime)

        return """
        Pack: \(packId) v\(version)
        Size: \(String(format: "%.1f", inputKB))KB → \(String(format: "%.1f", outputKB))KB (\(ratio))
        Time: \(time)
        Content: \(contentStats.summary)
        """
    }
}

/// Content statistics
public struct ContentStats {
    public let regions: Int
    public let events: Int
    public let quests: Int
    public let heroes: Int
    public let cards: Int
    public let enemies: Int
    public let anchors: Int

    public init(from pack: LoadedPack) {
        self.regions = pack.regions.count
        self.events = pack.events.count
        self.quests = pack.quests.count
        self.heroes = pack.heroes.count
        self.cards = pack.cards.count
        self.enemies = pack.enemies.count
        self.anchors = pack.anchors.count
    }

    public var summary: String {
        var parts: [String] = []
        if regions > 0 { parts.append("\(regions) regions") }
        if events > 0 { parts.append("\(events) events") }
        if quests > 0 { parts.append("\(quests) quests") }
        if heroes > 0 { parts.append("\(heroes) heroes") }
        if cards > 0 { parts.append("\(cards) cards") }
        if enemies > 0 { parts.append("\(enemies) enemies") }
        return parts.joined(separator: ", ")
    }
}

/// Validation result
public struct ValidationResult {
    public let packId: String
    public let version: SemanticVersion
    public let coreCompatible: Bool
    public let contentValid: Bool
    public let error: String?

    public var isValid: Bool {
        coreCompatible && contentValid
    }

    public var summary: String {
        if isValid {
            return "✅ Pack '\(packId)' v\(version) is valid"
        } else {
            var issues: [String] = []
            if !coreCompatible { issues.append("Core version incompatible") }
            if !contentValid { issues.append(error ?? "Content validation failed") }
            return "❌ Pack '\(packId)' v\(version): \(issues.joined(separator: ", "))"
        }
    }
}

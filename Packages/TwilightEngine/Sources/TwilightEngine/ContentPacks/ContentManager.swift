import Foundation

// MARK: - Content Manager
// Manages pack discovery, validation, loading, and hot-reload

/// Source location for content packs
public enum PackSource: Equatable, Hashable {
    /// Bundled in app (read-only, cannot hot-reload)
    case bundled(url: URL)
    /// External in Documents folder (hot-reloadable)
    case external(url: URL)

    /// The file URL for this pack source.
    public var url: URL {
        switch self {
        case .bundled(let url), .external(let url):
            return url
        }
    }

    /// Whether this pack source supports hot-reload.
    public var isReloadable: Bool {
        if case .external = self { return true }
        return false
    }

    /// Human-readable label for this pack source type.
    public var displayName: String {
        switch self {
        case .bundled: return "Bundled"
        case .external: return "External"
        }
    }
}

/// State of a pack in the content management system
public enum PackLoadState: Equatable {
    case discovered           // Found on disk, not validated
    case validating           // Validation in progress
    case validated(ValidationSummary)  // Validation complete
    case loading              // Loading into registry
    case loaded               // Successfully loaded into ContentRegistry
    case failed(String)       // Load/validation failed with error

    /// SF Symbol name representing the current load state.
    public var statusIcon: String {
        switch self {
        case .discovered: return "circle"
        case .validating: return "arrow.triangle.2.circlepath"
        case .validated(let summary):
            if summary.errorCount > 0 { return "xmark.circle" }
            if summary.warningCount > 0 { return "exclamationmark.triangle" }
            return "checkmark.circle"
        case .loading: return "arrow.triangle.2.circlepath"
        case .loaded: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    /// Color name representing the current load state.
    public var statusColor: String {
        switch self {
        case .discovered: return "gray"
        case .validating, .loading: return "blue"
        case .validated(let summary):
            if summary.errorCount > 0 { return "red" }
            if summary.warningCount > 0 { return "yellow"  }
            return "green"
        case .loaded: return "green"
        case .failed: return "red"
        }
    }

    /// Equatable conformance comparing load state cases.
    public static func == (lhs: PackLoadState, rhs: PackLoadState) -> Bool {
        switch (lhs, rhs) {
        case (.discovered, .discovered): return true
        case (.validating, .validating): return true
        case (.validated(let l), .validated(let r)): return l.packId == r.packId
        case (.loading, .loading): return true
        case (.loaded, .loaded): return true
        case (.failed(let l), .failed(let r)): return l == r
        default: return false
        }
    }
}

/// Validation summary for display
public struct ValidationSummary: Equatable {
    /// Identifier of the validated pack.
    public let packId: String
    /// Number of validation errors found.
    public let errorCount: Int
    /// Number of validation warnings found.
    public let warningCount: Int
    /// Number of informational messages.
    public let infoCount: Int
    /// Time taken to validate, in seconds.
    public let duration: TimeInterval
    /// Descriptive error messages.
    public let errors: [String]
    /// Descriptive warning messages.
    public let warnings: [String]

    /// Whether the pack passed validation with no errors.
    public var isValid: Bool { errorCount == 0 }

    /// Create a validation summary with the given counts and messages.
    public init(packId: String, errorCount: Int, warningCount: Int, infoCount: Int,
                duration: TimeInterval, errors: [String] = [], warnings: [String] = []) {
        self.packId = packId
        self.errorCount = errorCount
        self.warningCount = warningCount
        self.infoCount = infoCount
        self.duration = duration
        self.errors = errors
        self.warnings = warnings
    }
}

/// A pack managed by ContentManager
public struct ManagedPack: Identifiable {
    /// Unique pack identifier.
    public let id: String              // packId
    /// Where this pack was discovered from.
    public let source: PackSource
    /// Current load state of the pack.
    public var state: PackLoadState
    /// Pack manifest, if successfully read.
    public var manifest: PackManifest?
    /// Most recent validation result, if any.
    public var lastValidation: ValidationSummary?
    /// File size in bytes on disk.
    public var fileSize: Int64
    /// Last modification date of the pack file.
    public var modifiedAt: Date
    /// Date the pack was loaded into the registry, if loaded.
    public var loadedAt: Date?

    /// Whether this pack can be hot-reloaded.
    public var canReload: Bool {
        source.isReloadable && (state == .loaded || isValidatedSuccessfully)
    }

    /// Whether this pack can currently be validated.
    public var canValidate: Bool {
        switch state {
        case .validating, .loading: return false
        default: return true
        }
    }

    /// Whether this pack is ready to be loaded into the registry.
    public var canLoad: Bool {
        isValidatedSuccessfully && state != .loaded && state != .loading
    }

    /// Whether the pack passed validation without errors.
    public var isValidatedSuccessfully: Bool {
        if case .validated(let summary) = state {
            return summary.isValid
        }
        return false
    }

    /// Whether validation or loading produced errors.
    public var hasErrors: Bool {
        if case .validated(let summary) = state {
            return summary.errorCount > 0
        }
        if case .failed = state {
            return true
        }
        return false
    }

    /// Whether validation produced warnings.
    public var hasWarnings: Bool {
        if case .validated(let summary) = state {
            return summary.warningCount > 0
        }
        return false
    }
}

extension ManagedPack: Equatable {
    /// Equatable conformance comparing pack identity and state.
    public static func == (lhs: ManagedPack, rhs: ManagedPack) -> Bool {
        lhs.id == rhs.id &&
        lhs.source == rhs.source &&
        lhs.state == rhs.state &&
        lhs.fileSize == rhs.fileSize &&
        lhs.modifiedAt == rhs.modifiedAt &&
        lhs.loadedAt == rhs.loadedAt
    }
}

/// Errors during content reload
public enum ContentReloadError: Error, LocalizedError {
    case packNotFound(packId: String)
    case notReloadable(reason: String)
    case validationFailed(summary: ValidationSummary)
    case loadFailed(underlying: Error)

    /// Localized description of the reload error.
    public var errorDescription: String? {
        switch self {
        case .packNotFound(let id): return "Pack '\(id)' not found"
        case .notReloadable(let reason): return "Cannot reload: \(reason)"
        case .validationFailed(let summary): return "Validation failed with \(summary.errorCount) errors"
        case .loadFailed(let error): return "Load failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Content Manager

/// Engine-level content management with hot-reload support
public final class ContentManager {
    // MARK: - Singleton

    /// Shared singleton instance of the content manager.
    public static let shared = ContentManager()

    // MARK: - State

    private var managedPacks: [String: ManagedPack] = [:]
    private let queue = DispatchQueue(label: "content-manager", qos: .userInitiated)

    /// External packs folder name
    private let externalPacksFolderName = "Packs"

    private init() {}

    // MARK: - Pack Discovery

    /// Get URL for external packs directory (Documents/Packs/)
    public func externalPacksDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let packsDir = documentsPath.appendingPathComponent(externalPacksFolderName)

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: packsDir.path) {
            try? FileManager.default.createDirectory(at: packsDir, withIntermediateDirectories: true)
        }

        return packsDir
    }

    /// Discover all available .pack files
    /// - Parameters:
    ///   - bundledURLs: URLs to bundled packs (from content modules)
    /// - Returns: Array of discovered packs
    public func discoverPacks(bundledURLs: [URL]) -> [ManagedPack] {
        var discovered: [ManagedPack] = []

        // Discover bundled packs
        for url in bundledURLs {
            if let pack = discoverPack(at: url, source: .bundled(url: url)) {
                discovered.append(pack)
            }
        }

        // Discover external packs in Documents/Packs/
        let externalDir = externalPacksDirectory()
        if let contents = try? FileManager.default.contentsOfDirectory(
            at: externalDir,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
        ) {
            for url in contents where url.pathExtension == "pack" {
                if let pack = discoverPack(at: url, source: .external(url: url)) {
                    // Don't add if bundled pack with same ID exists
                    if !discovered.contains(where: { $0.id == pack.id }) {
                        discovered.append(pack)
                    }
                }
            }
        }

        // Update internal state
        queue.sync {
            for pack in discovered {
                managedPacks[pack.id] = pack
            }
        }

        return discovered
    }

    /// Discover a single pack file
    private func discoverPack(at url: URL, source: PackSource) -> ManagedPack? {
        guard BinaryPackReader.isValidPackFile(url) else { return nil }

        // Get file attributes
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = (attributes?[.size] as? Int64) ?? 0
        let modifiedAt = (attributes?[.modificationDate] as? Date) ?? Date()

        // Try to read manifest quickly
        let manifest = try? BinaryPackReader.readManifestOnly(from: url)
        let packId = manifest?.packId ?? url.deletingPathExtension().lastPathComponent

        // Check if already loaded in ContentRegistry
        let isLoaded = ContentRegistry.shared.loadedPacks[packId] != nil
        let state: PackLoadState = isLoaded ? .loaded : .discovered

        return ManagedPack(
            id: packId,
            source: source,
            state: state,
            manifest: manifest,
            lastValidation: nil,
            fileSize: fileSize,
            modifiedAt: modifiedAt,
            loadedAt: isLoaded ? Date() : nil
        )
    }

    /// Scan for changes in external packs directory and re-discover all packs.
    public func scanForChanges(bundledURLs: [URL]) -> [ManagedPack] {
        return discoverPacks(bundledURLs: bundledURLs)
    }

    // MARK: - Get State

    /// Get all managed packs
    public func getAllPacks() -> [ManagedPack] {
        return queue.sync { Array(managedPacks.values) }
    }

    /// Get a specific managed pack
    public func getPack(_ packId: String) -> ManagedPack? {
        return queue.sync { managedPacks[packId] }
    }

    /// Get bundled packs only
    public func getBundledPacks() -> [ManagedPack] {
        return queue.sync {
            managedPacks.values.filter { if case .bundled = $0.source { return true } else { return false } }
        }
    }

    /// Get external packs only
    public func getExternalPacks() -> [ManagedPack] {
        return queue.sync {
            managedPacks.values.filter { if case .external = $0.source { return true } else { return false } }
        }
    }

    // MARK: - Validation

    /// Validate a pack without loading it
    /// - Parameter packId: ID of pack to validate
    /// - Returns: Validation summary
    public func validatePack(_ packId: String) async -> ValidationSummary {
        guard let pack = getPack(packId) else {
            return ValidationSummary(
                packId: packId,
                errorCount: 1,
                warningCount: 0,
                infoCount: 0,
                duration: 0,
                errors: ["Pack not found"]
            )
        }

        // Update state to validating
        updatePackState(packId, state: .validating)

        // Perform validation
        let summary = await validatePackFile(at: pack.source.url)

        // Update state with result
        updatePackState(packId, state: .validated(summary), validation: summary)

        return summary
    }

    /// Validate a .pack file directly
    public func validatePackFile(at url: URL) async -> ValidationSummary {
        let startTime = Date()
        var errors: [String] = []
        var warnings: [String] = []
        var infoCount = 0

        // 1. Check file exists and is valid .pack
        guard BinaryPackReader.isValidPackFile(url) else {
            return ValidationSummary(
                packId: "unknown",
                errorCount: 1,
                warningCount: 0,
                infoCount: 0,
                duration: Date().timeIntervalSince(startTime),
                errors: ["Not a valid .pack file"]
            )
        }

        // 2. Load content
        let content: PackContent
        do {
            content = try BinaryPackReader.loadContent(from: url)
            infoCount += 1  // Successfully loaded
        } catch {
            return ValidationSummary(
                packId: "unknown",
                errorCount: 1,
                warningCount: 0,
                infoCount: 0,
                duration: Date().timeIntervalSince(startTime),
                errors: ["Failed to load pack: \(error.localizedDescription)"]
            )
        }

        let packId = content.manifest.packId

        // 3. Validate manifest
        if content.manifest.packId.isEmpty {
            errors.append("Pack ID is empty")
        }
        if content.manifest.displayName.en.isEmpty {
            warnings.append("Display name (en) is empty")
        }

        // 4. Validate cross-references
        let tempPack = content.toLoadedPack(sourceURL: url)

        // Check region neighbor references
        for (id, region) in tempPack.regions {
            for neighborId in region.neighborIds {
                if tempPack.regions[neighborId] == nil {
                    warnings.append("Region '\(id)' references missing neighbor '\(neighborId)'")
                }
            }
        }

        // Check event region references
        for (id, event) in tempPack.events {
            if let regionIds = event.availability.regionIds {
                for regionId in regionIds {
                    if tempPack.regions[regionId] == nil {
                        warnings.append("Event '\(id)' references missing region '\(regionId)'")
                    }
                }
            }
        }

        // Check hero starting deck references
        for (id, hero) in tempPack.heroes {
            for cardId in hero.startingDeckCardIDs {
                if tempPack.cards[cardId] == nil {
                    // Card might be in another pack, so just warn
                    warnings.append("Hero '\(id)' starting deck references card '\(cardId)' (may be in another pack)")
                }
            }
        }

        // Check anchor region references
        for (id, anchor) in tempPack.anchors {
            if tempPack.regions[anchor.regionId] == nil {
                warnings.append("Anchor '\(id)' references missing region '\(anchor.regionId)'")
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        return ValidationSummary(
            packId: packId,
            errorCount: errors.count,
            warningCount: warnings.count,
            infoCount: infoCount,
            duration: duration,
            errors: errors,
            warnings: warnings
        )
    }

    // MARK: - Loading

    /// Load a pack into ContentRegistry
    /// - Parameter packId: ID of pack to load
    /// - Returns: Loaded pack
    public func loadPack(_ packId: String) async throws -> LoadedPack {
        guard let pack = getPack(packId) else {
            throw ContentReloadError.packNotFound(packId: packId)
        }

        // Update state
        updatePackState(packId, state: .loading)

        do {
            let loadedPack = try ContentRegistry.shared.loadPack(from: pack.source.url)
            updatePackState(packId, state: .loaded)
            queue.sync { managedPacks[packId]?.loadedAt = Date() }
            return loadedPack
        } catch {
            updatePackState(packId, state: .failed(error.localizedDescription))
            throw error
        }
    }

    // MARK: - Hot Reload

    /// Safely reload a pack with validation and rollback support
    /// - Parameter packId: ID of pack to reload
    /// - Returns: Result with new pack or error (old pack preserved on failure)
    public func safeReloadPack(_ packId: String) async -> Result<LoadedPack, ContentReloadError> {
        guard let pack = getPack(packId) else {
            return .failure(.packNotFound(packId: packId))
        }

        guard pack.source.isReloadable else {
            return .failure(.notReloadable(reason: "Bundled packs cannot be hot-reloaded"))
        }

        // 1. Validate BEFORE unloading
        updatePackState(packId, state: .validating)
        let validation = await validatePackFile(at: pack.source.url)

        guard validation.isValid else {
            updatePackState(packId, state: .validated(validation), validation: validation)
            return .failure(.validationFailed(summary: validation))
        }

        // 2. Perform safe reload via ContentRegistry
        updatePackState(packId, state: .loading)
        let result = ContentRegistry.shared.safeReloadPack(packId, from: pack.source.url)

        switch result {
        case .success(let newPack):
            updatePackState(packId, state: .loaded)
            queue.sync { managedPacks[packId]?.loadedAt = Date() }
            return .success(newPack)

        case .failure(let error):
            updatePackState(packId, state: .failed(error.localizedDescription))
            return .failure(.loadFailed(underlying: error))
        }
    }

    /// Check if a pack can be reloaded
    public func canReload(_ packId: String) -> Bool {
        return getPack(packId)?.canReload ?? false
    }

    // MARK: - Private Helpers

    private func updatePackState(_ packId: String, state: PackLoadState, validation: ValidationSummary? = nil) {
        queue.sync {
            managedPacks[packId]?.state = state
            if let validation = validation {
                managedPacks[packId]?.lastValidation = validation
            }
        }
    }

    // MARK: - Reset (for testing)

    /// Reset all managed packs
    public func reset() {
        queue.sync {
            managedPacks.removeAll()
        }
    }
}

// MARK: - BinaryPackReader Extension

extension BinaryPackReader {
    /// Read only the manifest from a .pack file (fast, for discovery)
    public static func readManifestOnly(from url: URL) throws -> PackManifest {
        let content = try loadContent(from: url)
        return content.manifest
    }
}


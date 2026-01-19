import Foundation

// MARK: - Semantic Versioning

/// Semantic version for Core and Packs
/// Format: MAJOR.MINOR.PATCH
struct SemanticVersion: Codable, Comparable, Hashable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    var description: String { "\(major).\(minor).\(patch)" }

    init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    init?(string: String) {
        let parts = string.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        self.major = parts[0]
        self.minor = parts[1]
        self.patch = parts[2]
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    /// Check if this version is compatible with required version
    /// - Same MAJOR version required
    /// - MINOR can be >= required
    func isCompatible(with required: SemanticVersion) -> Bool {
        return major == required.major && (minor > required.minor || (minor == required.minor && patch >= required.patch))
    }
}

// MARK: - Pack Types

/// Types of content packs
enum PackType: String, Codable {
    /// Campaign content: regions, events, quests, enemies, story
    case campaign

    /// Investigator/Hero content: heroes, starting decks, player cards
    case investigator

    /// Balance tuning: numbers, weights, costs (no new content)
    case balance

    /// Rules extension: new game mechanics, capabilities
    case rulesExtension = "rules_extension"

    /// Full standalone pack: complete game content
    case full
}

/// Pack dependency declaration
struct PackDependency: Codable, Hashable {
    /// ID of required pack
    let packId: String

    /// Minimum required version
    let minVersion: SemanticVersion

    /// Maximum compatible version (nil = any)
    let maxVersion: SemanticVersion?

    /// Is this dependency optional?
    let isOptional: Bool

    init(packId: String, minVersion: SemanticVersion, maxVersion: SemanticVersion? = nil, isOptional: Bool = false) {
        self.packId = packId
        self.minVersion = minVersion
        self.maxVersion = maxVersion
        self.isOptional = isOptional
    }
}

// MARK: - Content Inventory

/// Summary of content provided by a pack
struct ContentInventory: Codable {
    let regionCount: Int
    let eventCount: Int
    let questCount: Int
    let heroCount: Int
    let cardCount: Int
    let anchorCount: Int
    let enemyCount: Int

    let hasBalanceConfig: Bool
    let hasRulesExtension: Bool
    let hasCampaignContent: Bool

    /// Supported locales (e.g., ["en", "ru"])
    let supportedLocales: [String]

    static let empty = ContentInventory(
        regionCount: 0, eventCount: 0, questCount: 0,
        heroCount: 0, cardCount: 0, anchorCount: 0, enemyCount: 0,
        hasBalanceConfig: false, hasRulesExtension: false, hasCampaignContent: false,
        supportedLocales: []
    )
}

// MARK: - Pack Load Errors

/// Errors that can occur during pack loading
enum PackLoadError: Error, LocalizedError {
    case manifestNotFound(path: String)
    case invalidManifest(reason: String)
    case incompatibleCoreVersion(required: SemanticVersion, current: SemanticVersion)
    case missingDependency(packId: String, required: SemanticVersion)
    case dependencyVersionMismatch(packId: String, required: SemanticVersion, found: SemanticVersion)
    case contentLoadFailed(file: String, underlyingError: Error)
    case validationFailed(errorCount: Int, firstError: String)
    case checksumMismatch(file: String, expected: String, actual: String)
    case packAlreadyLoaded(packId: String)
    case circularDependency(chain: [String])

    var errorDescription: String? {
        switch self {
        case .manifestNotFound(let path):
            return "Pack manifest not found at: \(path)"
        case .invalidManifest(let reason):
            return "Invalid pack manifest: \(reason)"
        case .incompatibleCoreVersion(let required, let current):
            return "Pack requires Core \(required), but running \(current)"
        case .missingDependency(let packId, let version):
            return "Missing dependency: \(packId) >= \(version)"
        case .dependencyVersionMismatch(let packId, let required, let found):
            return "Dependency \(packId) requires \(required), found \(found)"
        case .contentLoadFailed(let file, let error):
            return "Failed to load \(file): \(error.localizedDescription)"
        case .validationFailed(let errorCount, let firstError):
            return "Validation failed with \(errorCount) errors. First: \(firstError)"
        case .checksumMismatch(let file, let expected, let actual):
            return "Checksum mismatch for \(file): expected \(expected), got \(actual)"
        case .packAlreadyLoaded(let packId):
            return "Pack already loaded: \(packId)"
        case .circularDependency(let chain):
            return "Circular dependency detected: \(chain.joined(separator: " -> "))"
        }
    }
}

// MARK: - Loaded Pack

/// Represents a successfully loaded pack
struct LoadedPack {
    let manifest: PackManifest
    let sourceURL: URL
    let loadedAt: Date

    /// Content provided by this pack (indexed by ID)
    var regions: [String: RegionDefinition] = [:]
    var events: [String: EventDefinition] = [:]
    var quests: [String: QuestDefinition] = [:]
    var anchors: [String: AnchorDefinition] = [:]
    var heroes: [String: StandardHeroDefinition] = [:]
    var cards: [String: StandardCardDefinition] = [:]

    /// Balance configuration (if pack provides one)
    var balanceConfig: BalanceConfiguration?

    /// Computed inventory
    var inventory: ContentInventory {
        ContentInventory(
            regionCount: regions.count,
            eventCount: events.count,
            questCount: quests.count,
            heroCount: heroes.count,
            cardCount: cards.count,
            anchorCount: anchors.count,
            enemyCount: 0, // TODO: Add enemy support
            hasBalanceConfig: balanceConfig != nil,
            hasRulesExtension: false, // TODO: Add rules extension support
            hasCampaignContent: !regions.isEmpty || !events.isEmpty || !quests.isEmpty,
            supportedLocales: manifest.supportedLocales
        )
    }
}

// MARK: - Core Version

/// Current version of the Core engine
/// This is the single source of truth for engine version
struct CoreVersion {
    static let current = SemanticVersion(major: 1, minor: 0, patch: 0)

    /// Minimum pack version that current core supports
    static let minSupportedPackVersion = SemanticVersion(major: 1, minor: 0, patch: 0)
}

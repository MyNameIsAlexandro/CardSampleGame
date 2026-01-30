import Foundation

// MARK: - Semantic Versioning

/// Semantic version for Core and Packs
/// Format: MAJOR.MINOR.PATCH
public struct SemanticVersion: Comparable, Hashable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public var description: String { "\(major).\(minor).\(patch)" }

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init?(string: String) {
        let parts = string.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        self.major = parts[0]
        self.minor = parts[1]
        self.patch = parts[2]
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    /// Check if this version is compatible with required version
    /// - Same MAJOR version required
    /// - MINOR can be >= required
    public func isCompatible(with required: SemanticVersion) -> Bool {
        return major == required.major && (minor > required.minor || (minor == required.minor && patch >= required.patch))
    }
}

// MARK: - SemanticVersion Codable

extension SemanticVersion: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        let parts = string.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 3 else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid version format: \(string). Expected MAJOR.MINOR.PATCH"
            )
        }
        self.major = parts[0]
        self.minor = parts[1]
        self.patch = parts[2]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

// MARK: - Pack Types

/// Types of content packs
public enum PackType: String, Codable {
    /// Campaign content: regions, events, quests, enemies, story
    case campaign

    /// Character/Hero content: heroes, starting decks, player cards
    /// Note: Called "Character Pack" (not "Investigator Pack" as in Arkham Horror)
    /// to match the game's theme
    case character

    /// Balance tuning: numbers, weights, costs (no new content)
    case balance

    /// Rules extension: new game mechanics, capabilities
    case rulesExtension = "rules_extension"

    /// Full standalone pack: complete game content
    case full

    /// Load priority for pack ordering (lower = loaded first)
    public var loadPriority: Int {
        switch self {
        case .character: return 100  // Characters first
        case .balance: return 200    // Balance tuning second
        case .campaign: return 300   // Campaigns after characters
        case .rulesExtension: return 400
        case .full: return 500       // Full packs last
        }
    }

    /// Whether this pack type provides heroes
    public var providesHeroes: Bool {
        switch self {
        case .character, .full: return true
        case .campaign, .balance, .rulesExtension: return false
        }
    }

    /// Whether this pack type provides story content
    public var providesStory: Bool {
        switch self {
        case .campaign, .full: return true
        case .character, .balance, .rulesExtension: return false
        }
    }
}

/// Mission type for story packs
public enum MissionType: String, Codable {
    /// Multi-session campaign that spans multiple play sessions
    case campaign

    /// Single-session standalone mission
    case standalone
}

/// Pack dependency declaration
public struct PackDependency: Codable, Hashable {
    /// ID of required pack
    public let packId: String

    /// Minimum required version
    public let minVersion: SemanticVersion

    /// Maximum compatible version (nil = any)
    public let maxVersion: SemanticVersion?

    /// Is this dependency optional?
    public let isOptional: Bool

    public init(packId: String, minVersion: SemanticVersion, maxVersion: SemanticVersion? = nil, isOptional: Bool = false) {
        self.packId = packId
        self.minVersion = minVersion
        self.maxVersion = maxVersion
        self.isOptional = isOptional
    }
}

// MARK: - Content Inventory

/// Summary of content provided by a pack
public struct ContentInventory: Codable {
    public let regionCount: Int
    public let eventCount: Int
    public let questCount: Int
    public let heroCount: Int
    public let cardCount: Int
    public let anchorCount: Int
    public let enemyCount: Int

    public let hasBalanceConfig: Bool
    public let hasRulesExtension: Bool
    public let hasCampaignContent: Bool

    /// Supported locales (e.g., ["en", "ru"])
    public let supportedLocales: [String]

    public static let empty = ContentInventory(
        regionCount: 0, eventCount: 0, questCount: 0,
        heroCount: 0, cardCount: 0, anchorCount: 0, enemyCount: 0,
        hasBalanceConfig: false, hasRulesExtension: false, hasCampaignContent: false,
        supportedLocales: []
    )
}

// MARK: - Pack Load Errors

/// Errors that can occur during pack loading
public enum PackLoadError: Error, LocalizedError {
    case manifestNotFound(path: String)
    case invalidManifest(reason: String)
    case incompatibleCoreVersion(required: SemanticVersion, current: SemanticVersion)
    case missingDependency(packId: String, required: SemanticVersion)
    case dependencyVersionMismatch(packId: String, required: SemanticVersion, found: SemanticVersion)
    case contentLoadFailed(file: String, underlyingError: Error)
    case validationFailed(errorCount: Int, firstError: String)
    case checksumMismatch(file: String, expected: String, actual: String)
    case fileNotFound(_ path: String)  // Epic 0.3: checksum verification
    case packAlreadyLoaded(packId: String)
    case circularDependency(chain: [String])

    public var errorDescription: String? {
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
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .packAlreadyLoaded(let packId):
            return "Pack already loaded: \(packId)"
        case .circularDependency(let chain):
            return "Circular dependency detected: \(chain.joined(separator: " -> "))"
        }
    }
}

// MARK: - Loaded Pack

/// Represents a successfully loaded pack
public struct LoadedPack {
    public let manifest: PackManifest
    public let sourceURL: URL
    public let loadedAt: Date

    /// Content provided by this pack (indexed by ID)
    public var regions: [String: RegionDefinition] = [:]
    public var events: [String: EventDefinition] = [:]
    public var quests: [String: QuestDefinition] = [:]
    public var anchors: [String: AnchorDefinition] = [:]
    public var heroes: [String: StandardHeroDefinition] = [:]
    public var cards: [String: StandardCardDefinition] = [:]
    public var enemies: [String: EnemyDefinition] = [:]
    public var fateCards: [String: FateCard] = [:]
    public var behaviors: [String: BehaviorDefinition] = [:]

    /// Balance configuration (if pack provides one)
    public var balanceConfig: BalanceConfiguration?

    /// Computed inventory
    public var inventory: ContentInventory {
        ContentInventory(
            regionCount: regions.count,
            eventCount: events.count,
            questCount: quests.count,
            heroCount: heroes.count,
            cardCount: cards.count,
            anchorCount: anchors.count,
            enemyCount: enemies.count,
            hasBalanceConfig: balanceConfig != nil,
            hasRulesExtension: false, // TODO: Add rules extension support
            hasCampaignContent: !regions.isEmpty || !events.isEmpty || !quests.isEmpty,
            supportedLocales: manifest.supportedLocales
        )
    }

    public init(manifest: PackManifest, sourceURL: URL, loadedAt: Date = Date()) {
        self.manifest = manifest
        self.sourceURL = sourceURL
        self.loadedAt = loadedAt
    }
}

// MARK: - Core Version

/// Current version of the Core engine
/// This is the single source of truth for engine version
public struct CoreVersion {
    public static let current = SemanticVersion(major: 1, minor: 0, patch: 0)

    /// Minimum pack version that current core supports
    public static let minSupportedPackVersion = SemanticVersion(major: 1, minor: 0, patch: 0)
}

// MARK: - Content Cache Types

/// Metadata for cached content pack
/// Used to validate cache freshness without loading full content
public struct CacheMetadata: Codable {
    /// Pack identifier
    public let packId: String

    /// Pack version at cache time
    public let version: SemanticVersion

    /// SHA256 hash of all pack JSON files
    /// Used to detect content changes
    public let contentHash: String

    /// When the cache was created
    public let cachedAt: Date

    /// Engine version when cache was created
    /// Cache is invalidated if major/minor version changes
    public let engineVersion: String

    public init(packId: String, version: SemanticVersion, contentHash: String, cachedAt: Date, engineVersion: String) {
        self.packId = packId
        self.version = version
        self.contentHash = contentHash
        self.cachedAt = cachedAt
        self.engineVersion = engineVersion
    }

    /// Validates if cache is still fresh
    public func isValid(currentHash: String, currentEngineVersion: String) -> Bool {
        // Hash must match
        guard contentHash == currentHash else { return false }

        // Engine major.minor must match
        guard let cached = SemanticVersion(string: engineVersion),
              let current = SemanticVersion(string: currentEngineVersion) else {
            return false
        }

        return cached.major == current.major && cached.minor == current.minor
    }
}

/// Serialized pack data for persistent cache
/// Contains all content that can be restored without re-parsing JSON
public struct CachedPackData: Codable {
    /// Cache metadata for validation
    public let metadata: CacheMetadata

    /// Original manifest
    public let manifest: PackManifest

    /// All content indexed by ID
    public let regions: [String: RegionDefinition]
    public let events: [String: EventDefinition]
    public let quests: [String: QuestDefinition]
    public let anchors: [String: AnchorDefinition]
    public let heroes: [String: StandardHeroDefinition]
    public let cards: [String: StandardCardDefinition]
    public let enemies: [String: EnemyDefinition]

    /// Hero abilities (stored separately in AbilityRegistry at runtime)
    public let abilities: [HeroAbility]

    /// Balance configuration (if any)
    public let balanceConfig: BalanceConfiguration?

    /// Create from LoadedPack
    public init(from pack: LoadedPack, contentHash: String) {
        self.metadata = CacheMetadata(
            packId: pack.manifest.packId,
            version: pack.manifest.version,
            contentHash: contentHash,
            cachedAt: Date(),
            engineVersion: CoreVersion.current.description
        )
        self.manifest = pack.manifest
        self.regions = pack.regions
        self.events = pack.events
        self.quests = pack.quests
        self.anchors = pack.anchors
        self.heroes = pack.heroes
        self.cards = pack.cards
        self.enemies = pack.enemies
        // Capture abilities from AbilityRegistry at cache time
        self.abilities = AbilityRegistry.shared.allAbilities
        self.balanceConfig = pack.balanceConfig
    }

    /// Convert back to LoadedPack
    public func toLoadedPack(sourceURL: URL = URL(fileURLWithPath: "cached")) -> LoadedPack {
        var pack = LoadedPack(
            manifest: manifest,
            sourceURL: sourceURL,
            loadedAt: metadata.cachedAt
        )
        pack.regions = regions
        pack.events = events
        pack.quests = quests
        pack.anchors = anchors
        pack.heroes = heroes
        pack.cards = cards
        pack.enemies = enemies
        pack.balanceConfig = balanceConfig
        return pack
    }
}

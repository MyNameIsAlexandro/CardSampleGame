/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/ContentPacks/PackTypes+Cache.swift
/// Назначение: Содержит реализацию файла PackTypes+Cache.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

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
        self.abilities = Array(pack.abilities.values)
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
        var abilityMap: [String: HeroAbility] = [:]
        for ability in abilities {
            abilityMap[ability.id] = ability
        }
        pack.abilities = abilityMap
        pack.balanceConfig = balanceConfig
        return pack
    }
}

/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/ContentPacks/PackTypes+LoadedPack.swift
/// Назначение: Содержит реализацию файла PackTypes+LoadedPack.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

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
/// Placeholder for future rules extension support.
/// Packs may override or extend game rules (e.g., custom combat modifiers, win conditions).
public struct RulesExtension: Codable, Equatable {
    public init() {}
}

public struct LoadedPack {
    public var manifest: PackManifest
    public var sourceURL: URL
    public var loadedAt: Date

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
    public var abilities: [String: HeroAbility] = [:]

    /// Balance configuration (if pack provides one)
    public var balanceConfig: BalanceConfiguration?

    /// Rules extension (if pack provides one)
    public var rulesExtension: RulesExtension?

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
            hasRulesExtension: rulesExtension != nil,
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

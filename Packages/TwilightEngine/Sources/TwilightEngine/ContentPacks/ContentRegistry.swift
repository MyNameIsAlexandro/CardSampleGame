/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/ContentPacks/ContentRegistry.swift
/// Назначение: Содержит реализацию файла ContentRegistry.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Content Registry

/// Central registry for all loaded game content
/// This is the primary interface for accessing content from loaded packs
public final class ContentRegistry {
    // MARK: - State

    /// All loaded packs, keyed by pack ID
    public private(set) var loadedPacks: [String: LoadedPack] = [:]

    /// Combined content from all packs (merged by priority)
    internal private(set) var mergedRegions: [String: RegionDefinition] = [:]
    internal private(set) var mergedEvents: [String: EventDefinition] = [:]
    internal private(set) var mergedQuests: [String: QuestDefinition] = [:]
    internal private(set) var mergedAnchors: [String: AnchorDefinition] = [:]
    internal private(set) var mergedHeroes: [String: StandardHeroDefinition] = [:]
    internal private(set) var mergedCards: [String: StandardCardDefinition] = [:]
    internal private(set) var mergedEnemies: [String: EnemyDefinition] = [:]
    internal private(set) var mergedFateCards: [String: FateCard] = [:]
    internal private(set) var mergedBehaviors: [String: BehaviorDefinition] = [:]
    internal private(set) var mergedAbilities: [String: HeroAbility] = [:]

    /// Active balance configuration (from highest priority pack)
    internal private(set) var activeBalanceConfig: BalanceConfiguration?

    /// Pack load order (for priority resolution)
    internal private(set) var loadOrder: [String] = []

    // MARK: - Sub-Registries

    /// Hero definitions registry.
    public let heroRegistry = HeroRegistry()

    /// Ability definitions registry.
    public let abilityRegistry = AbilityRegistry()

    // MARK: - Initialization

    public init() {}

    private static var isVerboseLoggingEnabled: Bool {
        #if DEBUG
        guard let rawValue = ProcessInfo.processInfo.environment["TWILIGHT_TEST_VERBOSE"]?.lowercased() else {
            return false
        }
        return rawValue == "1" || rawValue == "true" || rawValue == "yes" || rawValue == "on"
        #else
        return false
        #endif
    }

    private func verboseLog(_ message: @autoclosure () -> String) {
        #if DEBUG
        guard Self.isVerboseLoggingEnabled else {
            return
        }
        print(message())
        #endif
    }

    // MARK: - Pack Loading

    /// Load multiple .pack files from URLs, sorted by priority
    /// Character packs are loaded before campaign packs
    /// - Parameter urls: URLs to .pack files
    /// - Returns: Array of loaded packs in load order
    /// - Throws: PackLoadError if loading fails
    @discardableResult
    public func loadPacks(from urls: [URL]) throws -> [LoadedPack] {
        // Load all pack contents
        var contentsWithUrls: [(content: PackContent, url: URL)] = []
        for url in urls {
            let content = try BinaryPackReader.loadContent(from: url)
            contentsWithUrls.append((content, url))
        }

        // Sort by pack type priority (character packs first, then campaigns)
        contentsWithUrls.sort { $0.content.manifest.packType.loadPriority < $1.content.manifest.packType.loadPriority }

        // Register packs in priority order
        var result: [LoadedPack] = []
        for (content, url) in contentsWithUrls {
            let pack = try registerPackContent(content, from: url)
            result.append(pack)
        }

        return result
    }

    /// Register pack content (internal helper)
    private func registerPackContent(_ content: PackContent, from url: URL) throws -> LoadedPack {
        let pack = content.toLoadedPack(sourceURL: url)

        // Check if already loaded
        if loadedPacks[pack.manifest.packId] != nil {
            throw PackLoadError.packAlreadyLoaded(packId: pack.manifest.packId)
        }

        // Verify Core compatibility
        guard pack.manifest.isCompatibleWithCore() else {
            throw PackLoadError.incompatibleCoreVersion(
                required: pack.manifest.coreVersionMin,
                current: CoreVersion.current
            )
        }

        // Check dependencies
        try validateDependencies(for: pack.manifest)

        // Register the pack
        loadedPacks[pack.manifest.packId] = pack
        loadOrder.append(pack.manifest.packId)

        // Merge content
        mergeContent(from: pack)

        return pack
    }

    /// Load a .pack file
    /// - Parameter url: URL to .pack file (binary format only)
    /// - Returns: The loaded pack
    /// - Throws: PackLoadError if loading fails
    @discardableResult
    public func loadPack(from url: URL) throws -> LoadedPack {
        // Verify it's a valid .pack file (checks extension AND magic bytes)
        guard BinaryPackReader.isValidPackFile(url) else {
            throw PackLoadError.invalidManifest(
                reason: "Invalid or missing .pack file. Only binary .pack files are supported. " +
                        "Use 'swift run pack-compiler compile' to compile JSON packs."
            )
        }

        // Load binary pack content
        let content = try BinaryPackReader.loadContent(from: url)
        return try registerPackContent(content, from: url)
    }

    /// Unload a pack
    /// - Parameter packId: ID of pack to unload
    public func unloadPack(_ packId: String) {
        guard loadedPacks[packId] != nil else { return }

        loadedPacks.removeValue(forKey: packId)
        loadOrder.removeAll { $0 == packId }

        // Rebuild merged content
        rebuildMergedContent()
    }

    /// Unload all packs
    public func unloadAllPacks() {
        loadedPacks.removeAll()
        loadOrder.removeAll()
        clearMergedContent()
    }

    // MARK: - Safe Reload (Hot-Reload Support)

    /// Safely reload a pack with rollback on failure
    /// - Parameters:
    ///   - packId: ID of pack to reload
    ///   - url: URL to new pack file
    /// - Returns: Result with loaded pack or error (old pack preserved on failure)
    public func safeReloadPack(_ packId: String, from url: URL) -> Result<LoadedPack, Error> {
        // Store old state for potential rollback
        let oldPack = loadedPacks[packId]
        let oldLoadOrder = loadOrder

        do {
            // Unload old pack
            unloadPack(packId)

            // Load new pack
            let newPack = try loadPack(from: url)

            verboseLog("ContentRegistry: Successfully reloaded '\(packId)'")

            return .success(newPack)
        } catch {
            // Rollback: restore old pack if it existed
            if let oldPack = oldPack {
                loadedPacks[packId] = oldPack
                // Restore load order
                loadOrder = oldLoadOrder
                rebuildMergedContent()

                verboseLog("ContentRegistry: Rolled back to previous version of '\(packId)'")
            }
            return .failure(error)
        }
    }


    // MARK: - Private Methods

    private func validateDependencies(for manifest: PackManifest) throws {
        for dependency in manifest.dependencies {
            if dependency.isOptional { continue }

            guard let loadedPack = loadedPacks[dependency.packId] else {
                throw PackLoadError.missingDependency(
                    packId: dependency.packId,
                    required: dependency.minVersion
                )
            }

            let loadedVersion = loadedPack.manifest.version
            if loadedVersion < dependency.minVersion {
                throw PackLoadError.dependencyVersionMismatch(
                    packId: dependency.packId,
                    required: dependency.minVersion,
                    found: loadedVersion
                )
            }

            if let maxVersion = dependency.maxVersion, loadedVersion > maxVersion {
                throw PackLoadError.dependencyVersionMismatch(
                    packId: dependency.packId,
                    required: dependency.minVersion,
                    found: loadedVersion
                )
            }
        }
    }

    func mergeContent(from pack: LoadedPack) {
        // Merge regions (later packs override earlier)
        for (id, region) in pack.regions {
            mergedRegions[id] = region
        }

        // Merge events
        for (id, event) in pack.events {
            mergedEvents[id] = event
        }

        // Merge quests
        for (id, quest) in pack.quests {
            mergedQuests[id] = quest
        }

        // Merge anchors
        for (id, anchor) in pack.anchors {
            mergedAnchors[id] = anchor
        }

        // Merge heroes and register into HeroRegistry for backward compatibility
        for (id, hero) in pack.heroes {
            mergedHeroes[id] = hero
            heroRegistry.register(hero)
        }
        if !pack.heroes.isEmpty {
            verboseLog("ContentRegistry: Registered \(pack.heroes.count) heroes into HeroRegistry")
        }

        // Merge abilities
        for (id, ability) in pack.abilities {
            mergedAbilities[id] = ability
            abilityRegistry.register(ability)
        }

        // Merge cards
        for (id, card) in pack.cards {
            mergedCards[id] = card
        }

        // Merge enemies
        for (id, enemy) in pack.enemies {
            mergedEnemies[id] = enemy
        }

        // Merge fate cards
        for (id, card) in pack.fateCards {
            mergedFateCards[id] = card
        }

        // Merge behaviors
        for (id, behavior) in pack.behaviors {
            mergedBehaviors[id] = behavior
        }

        // Update balance config if pack provides one
        if let balanceConfig = pack.balanceConfig {
            activeBalanceConfig = balanceConfig
        }
    }

    private func rebuildMergedContent() {
        clearMergedContent()

        // Re-merge in load order
        for packId in loadOrder {
            if let pack = loadedPacks[packId] {
                mergeContent(from: pack)
            }
        }
    }

    private func clearMergedContent() {
        mergedRegions.removeAll()
        mergedEvents.removeAll()
        mergedQuests.removeAll()
        mergedAnchors.removeAll()
        mergedHeroes.removeAll()
        mergedCards.removeAll()
        mergedEnemies.removeAll()
        mergedFateCards.removeAll()
        mergedBehaviors.removeAll()
        mergedAbilities.removeAll()
        activeBalanceConfig = nil
        heroRegistry.clear()
        abilityRegistry.clear()
    }

    func checkDuplicateIds() -> [ContentValidationError] {
        var errors: [ContentValidationError] = []

        // Track which pack each ID came from
        var regionSources: [String: [String]] = [:]
        var eventSources: [String: [String]] = [:]

        for packId in loadOrder {
            guard let pack = loadedPacks[packId] else { continue }

            for regionId in pack.regions.keys {
                regionSources[regionId, default: []].append(packId)
            }

            for eventId in pack.events.keys {
                eventSources[eventId, default: []].append(packId)
            }
        }

        // Report duplicates (informational - later packs override earlier)
        for (id, sources) in regionSources where sources.count > 1 {
            errors.append(ContentValidationError(
                type: .duplicateId,
                definitionId: id,
                message: "Region defined in multiple packs: \(sources.joined(separator: ", ")) (later overrides earlier)"
            ))
        }

        for (id, sources) in eventSources where sources.count > 1 {
            errors.append(ContentValidationError(
                type: .duplicateId,
                definitionId: id,
                message: "Event defined in multiple packs: \(sources.joined(separator: ", ")) (later overrides earlier)"
            ))
        }

        return errors
    }

    func collectSupportedLocales() -> [String] {
        var locales = Set<String>()
        for pack in loadedPacks.values {
            for locale in pack.manifest.supportedLocales {
                locales.insert(locale)
            }
        }
        return Array(locales).sorted()
    }

    func replaceTestingContent(
        regions: [String: RegionDefinition],
        events: [String: EventDefinition],
        quests: [String: QuestDefinition],
        anchors: [String: AnchorDefinition],
        heroes: [String: StandardHeroDefinition],
        cards: [String: StandardCardDefinition],
        enemies: [String: EnemyDefinition],
        fateCards: [String: FateCard],
        behaviors: [String: BehaviorDefinition],
        abilities: [String: HeroAbility],
        balanceConfig: BalanceConfiguration?
    ) {
        unloadAllPacks()
        mergedRegions = regions
        mergedEvents = events
        mergedQuests = quests
        mergedAnchors = anchors
        mergedHeroes = heroes
        mergedCards = cards
        mergedEnemies = enemies
        mergedFateCards = fateCards
        mergedBehaviors = behaviors
        mergedAbilities = abilities
        activeBalanceConfig = balanceConfig

        for hero in heroes.values {
            heroRegistry.register(hero)
        }

        for ability in abilities.values {
            abilityRegistry.register(ability)
        }
    }

    @discardableResult
    func registerMockPackForTesting(_ pack: LoadedPack) -> LoadedPack {
        let packId = pack.manifest.packId
        guard loadedPacks[packId] == nil else {
            return pack
        }
        loadedPacks[packId] = pack
        loadOrder.append(packId)
        mergeContent(from: pack)
        return pack
    }
}

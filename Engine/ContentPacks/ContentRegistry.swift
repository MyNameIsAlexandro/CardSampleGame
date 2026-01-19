import Foundation

// MARK: - Content Registry

/// Central registry for all loaded game content
/// This is the primary interface for accessing content from loaded packs
final class ContentRegistry {
    // MARK: - Singleton

    static let shared = ContentRegistry()

    // MARK: - State

    /// All loaded packs, keyed by pack ID
    private(set) var loadedPacks: [String: LoadedPack] = [:]

    /// Combined content from all packs (merged by priority)
    private var mergedRegions: [String: RegionDefinition] = [:]
    private var mergedEvents: [String: EventDefinition] = [:]
    private var mergedQuests: [String: QuestDefinition] = [:]
    private var mergedAnchors: [String: AnchorDefinition] = [:]
    private var mergedHeroes: [String: StandardHeroDefinition] = [:]
    private var mergedCards: [String: StandardCardDefinition] = [:]

    /// Active balance configuration (from highest priority pack)
    private var activeBalanceConfig: BalanceConfiguration?

    /// Pack load order (for priority resolution)
    private var loadOrder: [String] = []

    // MARK: - Initialization

    private init() {}

    // MARK: - Pack Loading

    /// Load a pack from URL
    /// - Parameter url: URL to pack directory or .pack file
    /// - Returns: The loaded pack
    /// - Throws: PackLoadError if loading fails
    @discardableResult
    func loadPack(from url: URL) throws -> LoadedPack {
        // Check if already loaded
        let manifest = try PackManifest.load(from: url)
        if loadedPacks[manifest.packId] != nil {
            throw PackLoadError.packAlreadyLoaded(packId: manifest.packId)
        }

        // Verify Core compatibility
        guard manifest.isCompatibleWithCore() else {
            throw PackLoadError.incompatibleCoreVersion(
                required: manifest.coreVersionMin,
                current: CoreVersion.current
            )
        }

        // Check dependencies
        try validateDependencies(for: manifest)

        // Load the pack content
        let pack = try PackLoader.load(manifest: manifest, from: url)

        // Register the pack
        loadedPacks[manifest.packId] = pack
        loadOrder.append(manifest.packId)

        // Merge content
        mergeContent(from: pack)

        return pack
    }

    /// Unload a pack
    /// - Parameter packId: ID of pack to unload
    func unloadPack(_ packId: String) {
        guard loadedPacks[packId] != nil else { return }

        loadedPacks.removeValue(forKey: packId)
        loadOrder.removeAll { $0 == packId }

        // Rebuild merged content
        rebuildMergedContent()
    }

    /// Unload all packs
    func unloadAllPacks() {
        loadedPacks.removeAll()
        loadOrder.removeAll()
        clearMergedContent()
    }

    // MARK: - Content Access

    /// Get region definition by ID
    func getRegion(id: String) -> RegionDefinition? {
        return mergedRegions[id]
    }

    /// Get all region definitions
    func getAllRegions() -> [RegionDefinition] {
        return Array(mergedRegions.values)
    }

    /// Get event definition by ID
    func getEvent(id: String) -> EventDefinition? {
        return mergedEvents[id]
    }

    /// Get all event definitions
    func getAllEvents() -> [EventDefinition] {
        return Array(mergedEvents.values)
    }

    /// Get quest definition by ID
    func getQuest(id: String) -> QuestDefinition? {
        return mergedQuests[id]
    }

    /// Get all quest definitions
    func getAllQuests() -> [QuestDefinition] {
        return Array(mergedQuests.values)
    }

    /// Get anchor definition by ID
    func getAnchor(id: String) -> AnchorDefinition? {
        return mergedAnchors[id]
    }

    /// Get anchor for a specific region
    func getAnchor(forRegion regionId: String) -> AnchorDefinition? {
        return mergedAnchors.values.first { $0.regionId == regionId }
    }

    /// Get all anchor definitions
    func getAllAnchors() -> [AnchorDefinition] {
        return Array(mergedAnchors.values)
    }

    /// Get hero definition by ID
    func getHero(id: String) -> StandardHeroDefinition? {
        return mergedHeroes[id]
    }

    /// Get all hero definitions
    func getAllHeroes() -> [StandardHeroDefinition] {
        return Array(mergedHeroes.values)
    }

    /// Get card definition by ID
    func getCard(id: String) -> StandardCardDefinition? {
        return mergedCards[id]
    }

    /// Get all card definitions
    func getAllCards() -> [StandardCardDefinition] {
        return Array(mergedCards.values)
    }

    /// Get cards by type
    func getCards(ofType type: CardType) -> [StandardCardDefinition] {
        return mergedCards.values.filter { $0.cardType == type }
    }

    /// Get the active balance configuration
    func getBalanceConfig() -> BalanceConfiguration? {
        return activeBalanceConfig
    }

    // MARK: - Query Methods

    /// Get events available for a region with given pressure
    func getAvailableEvents(forRegion regionId: String, pressure: Int) -> [EventDefinition] {
        return mergedEvents.values.filter { event in
            let regionMatches = event.availability.regionIds?.contains(regionId) ?? true
            let pressureMatches: Bool
            if let minPressure = event.availability.minPressure,
               let maxPressure = event.availability.maxPressure {
                pressureMatches = (minPressure...maxPressure).contains(pressure)
            } else if let minPressure = event.availability.minPressure {
                pressureMatches = pressure >= minPressure
            } else if let maxPressure = event.availability.maxPressure {
                pressureMatches = pressure <= maxPressure
            } else {
                pressureMatches = true
            }
            return regionMatches && pressureMatches
        }
    }

    /// Get starting deck for a hero
    func getStartingDeck(forHero heroId: String) -> [StandardCardDefinition] {
        guard let hero = getHero(id: heroId) else { return [] }
        return hero.startingDeckCardIDs.compactMap { getCard(id: $0) }
    }

    // MARK: - Validation

    /// Validate all loaded content for cross-references
    func validateAllContent() -> [ContentValidationError] {
        var errors: [ContentValidationError] = []

        // Validate region neighbor references
        for (id, region) in mergedRegions {
            for neighborId in region.neighborIds {
                if mergedRegions[neighborId] == nil {
                    errors.append(ContentValidationError(
                        type: .brokenReference,
                        definitionId: id,
                        message: "Region references non-existent neighbor '\(neighborId)'"
                    ))
                }
            }
        }

        // Validate event region references
        for (id, event) in mergedEvents {
            if let regionIds = event.availability.regionIds {
                for regionId in regionIds {
                    if mergedRegions[regionId] == nil {
                        errors.append(ContentValidationError(
                            type: .brokenReference,
                            definitionId: id,
                            message: "Event references non-existent region '\(regionId)'"
                        ))
                    }
                }
            }
        }

        // Validate anchor region references
        for (id, anchor) in mergedAnchors {
            if mergedRegions[anchor.regionId] == nil {
                errors.append(ContentValidationError(
                    type: .brokenReference,
                    definitionId: id,
                    message: "Anchor references non-existent region '\(anchor.regionId)'"
                ))
            }
        }

        // Validate hero starting deck references
        for (id, hero) in mergedHeroes {
            for cardId in hero.startingDeckCardIDs {
                if mergedCards[cardId] == nil {
                    errors.append(ContentValidationError(
                        type: .brokenReference,
                        definitionId: id,
                        message: "Hero references non-existent card '\(cardId)'"
                    ))
                }
            }
        }

        // Check for duplicate IDs within same type (shouldn't happen with maps, but check pack sources)
        errors.append(contentsOf: checkDuplicateIds())

        return errors
    }

    // MARK: - Statistics

    /// Get combined inventory of all loaded content
    var totalInventory: ContentInventory {
        ContentInventory(
            regionCount: mergedRegions.count,
            eventCount: mergedEvents.count,
            questCount: mergedQuests.count,
            heroCount: mergedHeroes.count,
            cardCount: mergedCards.count,
            anchorCount: mergedAnchors.count,
            enemyCount: 0, // TODO: Add enemy support
            hasBalanceConfig: activeBalanceConfig != nil,
            hasRulesExtension: false,
            hasCampaignContent: !mergedRegions.isEmpty || !mergedEvents.isEmpty,
            supportedLocales: collectSupportedLocales()
        )
    }

    /// Get list of all loaded pack IDs in load order
    var loadedPackIds: [String] {
        return loadOrder
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

    private func mergeContent(from pack: LoadedPack) {
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

        // Merge heroes
        for (id, hero) in pack.heroes {
            mergedHeroes[id] = hero
        }

        // Merge cards
        for (id, card) in pack.cards {
            mergedCards[id] = card
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
        activeBalanceConfig = nil
    }

    private func checkDuplicateIds() -> [ContentValidationError] {
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

    private func collectSupportedLocales() -> [String] {
        var locales = Set<String>()
        for pack in loadedPacks.values {
            for locale in pack.manifest.supportedLocales {
                locales.insert(locale)
            }
        }
        return Array(locales).sorted()
    }
}

// MARK: - Content Provider Protocol Conformance

extension ContentRegistry: ContentProvider {
    func getRegionDefinition(id: String) -> RegionDefinition? {
        return getRegion(id: id)
    }

    func getAllRegionDefinitions() -> [RegionDefinition] {
        return getAllRegions()
    }

    func getEventDefinition(id: String) -> EventDefinition? {
        return getEvent(id: id)
    }

    func getAllEventDefinitions() -> [EventDefinition] {
        return getAllEvents()
    }

    func getAnchorDefinition(id: String) -> AnchorDefinition? {
        return getAnchor(id: id)
    }

    func getAnchorDefinition(forRegion regionId: String) -> AnchorDefinition? {
        return getAnchor(forRegion: regionId)
    }

    func getAllAnchorDefinitions() -> [AnchorDefinition] {
        return getAllAnchors()
    }

    func getEventDefinitions(forRegion regionId: String) -> [EventDefinition] {
        return mergedEvents.values.filter { event in
            event.availability.regionIds?.contains(regionId) ?? false
        }
    }

    func getEventDefinitions(forPool poolId: String) -> [EventDefinition] {
        return mergedEvents.values.filter { event in
            event.poolIds.contains(poolId)
        }
    }

    func getAllQuestDefinitions() -> [QuestDefinition] {
        return getAllQuests()
    }

    func getQuestDefinition(id: String) -> QuestDefinition? {
        return getQuest(id: id)
    }

    func getAllMiniGameChallenges() -> [MiniGameChallengeDefinition] {
        // Extract from events that have mini-game challenges
        return mergedEvents.values.compactMap { $0.miniGameChallenge }
    }

    func getMiniGameChallenge(id: String) -> MiniGameChallengeDefinition? {
        return mergedEvents.values.compactMap { $0.miniGameChallenge }.first { $0.id == id }
    }

    func validate() -> [ContentValidationError] {
        // Use ContentValidator for full validation
        let validator = ContentValidator(provider: self)
        return validator.validate()
    }
}

// MARK: - Testing Support

extension ContentRegistry {
    /// Reset registry for testing
    /// - Warning: Only use in tests!
    func resetForTesting() {
        unloadAllPacks()
    }

    /// Register mock content for testing
    /// - Warning: Only use in tests!
    func registerMockContent(
        regions: [String: RegionDefinition] = [:],
        events: [String: EventDefinition] = [:],
        anchors: [String: AnchorDefinition] = [:],
        heroes: [String: StandardHeroDefinition] = [:],
        cards: [String: StandardCardDefinition] = [:]
    ) {
        mergedRegions = regions
        mergedEvents = events
        mergedAnchors = anchors
        mergedHeroes = heroes
        mergedCards = cards
    }
}

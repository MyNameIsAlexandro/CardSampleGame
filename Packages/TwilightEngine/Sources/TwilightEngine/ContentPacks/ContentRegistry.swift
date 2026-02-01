import Foundation

// MARK: - Content Registry

/// Central registry for all loaded game content
/// This is the primary interface for accessing content from loaded packs
public final class ContentRegistry {
    // MARK: - Singleton

    /// Shared singleton instance of the content registry.
    public static let shared = ContentRegistry()

    // MARK: - State

    /// All loaded packs, keyed by pack ID
    public private(set) var loadedPacks: [String: LoadedPack] = [:]

    /// Combined content from all packs (merged by priority)
    private var mergedRegions: [String: RegionDefinition] = [:]
    private var mergedEvents: [String: EventDefinition] = [:]
    private var mergedQuests: [String: QuestDefinition] = [:]
    private var mergedAnchors: [String: AnchorDefinition] = [:]
    private var mergedHeroes: [String: StandardHeroDefinition] = [:]
    private var mergedCards: [String: StandardCardDefinition] = [:]
    private var mergedEnemies: [String: EnemyDefinition] = [:]
    private var mergedFateCards: [String: FateCard] = [:]
    private var mergedBehaviors: [String: BehaviorDefinition] = [:]

    /// Active balance configuration (from highest priority pack)
    private var activeBalanceConfig: BalanceConfiguration?

    /// Pack load order (for priority resolution)
    private var loadOrder: [String] = []

    // MARK: - Initialization

    public init() {}

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
        // Register abilities BEFORE creating pack (needed for hero definitions)
        AbilityRegistry.shared.registerAll(content.abilities)

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

            #if DEBUG
            print("ContentRegistry: Successfully reloaded '\(packId)'")
            #endif

            return .success(newPack)
        } catch {
            // Rollback: restore old pack if it existed
            if let oldPack = oldPack {
                loadedPacks[packId] = oldPack
                // Restore load order
                loadOrder = oldLoadOrder
                rebuildMergedContent()

                #if DEBUG
                print("ContentRegistry: Rolled back to previous version of '\(packId)'")
                #endif
            }
            return .failure(error)
        }
    }

    // MARK: - Content Access

    /// Get region definition by ID
    public func getRegion(id: String) -> RegionDefinition? {
        return mergedRegions[id]
    }

    /// Get all region definitions
    public func getAllRegions() -> [RegionDefinition] {
        return Array(mergedRegions.values)
    }

    /// Get event definition by ID
    public func getEvent(id: String) -> EventDefinition? {
        return mergedEvents[id]
    }

    /// Get all event definitions
    public func getAllEvents() -> [EventDefinition] {
        return Array(mergedEvents.values)
    }

    /// Get quest definition by ID
    public func getQuest(id: String) -> QuestDefinition? {
        return mergedQuests[id]
    }

    /// Get all quest definitions
    public func getAllQuests() -> [QuestDefinition] {
        return Array(mergedQuests.values)
    }

    /// Get anchor definition by ID
    public func getAnchor(id: String) -> AnchorDefinition? {
        return mergedAnchors[id]
    }

    /// Get anchor for a specific region
    public func getAnchor(forRegion regionId: String) -> AnchorDefinition? {
        return mergedAnchors.values.first { $0.regionId == regionId }
    }

    /// Get all anchor definitions
    public func getAllAnchors() -> [AnchorDefinition] {
        return Array(mergedAnchors.values)
    }

    /// Get hero definition by ID
    public func getHero(id: String) -> StandardHeroDefinition? {
        return mergedHeroes[id]
    }

    /// Get all hero definitions
    public func getAllHeroes() -> [StandardHeroDefinition] {
        return Array(mergedHeroes.values)
    }

    /// Get card definition by ID
    public func getCard(id: String) -> StandardCardDefinition? {
        return mergedCards[id]
    }

    /// Get all card definitions
    public func getAllCards() -> [StandardCardDefinition] {
        return Array(mergedCards.values)
    }

    /// Get cards by type
    public func getCards(ofType type: CardType) -> [StandardCardDefinition] {
        return mergedCards.values.filter { $0.cardType == type }
    }

    /// Get enemy definition by ID
    public func getEnemy(id: String) -> EnemyDefinition? {
        return mergedEnemies[id]
    }

    /// Get all enemy definitions
    public func getAllEnemies() -> [EnemyDefinition] {
        return Array(mergedEnemies.values)
    }

    /// Get fate card by ID
    public func getFateCard(id: String) -> FateCard? {
        return mergedFateCards[id]
    }

    /// Get all fate cards
    public func getAllFateCards() -> [FateCard] {
        return Array(mergedFateCards.values)
    }

    /// Get the active balance configuration
    public func getBalanceConfig() -> BalanceConfiguration? {
        return activeBalanceConfig
    }

    // MARK: - Query Methods

    /// Get events available for a region with given pressure and state
    /// - Parameters:
    ///   - regionId: Region definition ID (from pack manifest)
    ///   - pressure: Current world tension (0-100)
    ///   - regionState: Current region state (e.g., "stable", "borderland", "breach")
    public func getAvailableEvents(forRegion regionId: String, pressure: Int, regionState: String? = nil) -> [EventDefinition] {
        return mergedEvents.values.filter { event in
            // Check region ID matches (nil = any region)
            let regionMatches = event.availability.regionIds?.contains(regionId) ?? true

            // Check region state matches (nil = any state)
            let stateMatches: Bool
            if let requiredStates = event.availability.regionStates, !requiredStates.isEmpty {
                if let currentState = regionState {
                    stateMatches = requiredStates.contains(currentState)
                } else {
                    // No current state provided, assume all states match
                    stateMatches = true
                }
            } else {
                // No state requirements
                stateMatches = true
            }

            // Check pressure/tension matches
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

            return regionMatches && stateMatches && pressureMatches
        }
    }

    /// Get starting deck for a hero
    public func getStartingDeck(forHero heroId: String) -> [StandardCardDefinition] {
        guard let hero = getHero(id: heroId) else { return [] }
        return hero.startingDeckCardIDs.compactMap { getCard(id: $0) }
    }

    // MARK: - Validation

    /// Validate all loaded content for cross-references
    public func validateAllContent() -> [ContentValidationError] {
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
    public var totalInventory: ContentInventory {
        ContentInventory(
            regionCount: mergedRegions.count,
            eventCount: mergedEvents.count,
            questCount: mergedQuests.count,
            heroCount: mergedHeroes.count,
            cardCount: mergedCards.count,
            anchorCount: mergedAnchors.count,
            enemyCount: mergedEnemies.count,
            hasBalanceConfig: activeBalanceConfig != nil,
            hasRulesExtension: false,
            hasCampaignContent: !mergedRegions.isEmpty || !mergedEvents.isEmpty,
            supportedLocales: collectSupportedLocales()
        )
    }

    /// Get list of all loaded pack IDs in load order
    public var loadedPackIds: [String] {
        return loadOrder
    }

    // MARK: - Pack Type Queries

    /// Get all loaded character packs
    public func getCharacterPacks() -> [LoadedPack] {
        return loadedPacks.values.filter { $0.manifest.packType.providesHeroes }
    }

    /// Get all loaded story/campaign packs
    public func getStoryPacks() -> [LoadedPack] {
        return loadedPacks.values.filter { $0.manifest.packType.providesStory }
    }

    /// Check if content is ready for gameplay (has both heroes and story)
    public var isReadyForGameplay: Bool {
        let hasHeroes = !mergedHeroes.isEmpty
        let hasStory = !mergedRegions.isEmpty || !mergedEvents.isEmpty || !mergedQuests.isEmpty
        return hasHeroes && hasStory
    }

    /// Check if at least one character pack is loaded
    public var hasCharacterPack: Bool {
        return !getCharacterPacks().isEmpty
    }

    /// Check if at least one story pack is loaded
    public var hasStoryPack: Bool {
        return !getStoryPacks().isEmpty
    }

    // MARK: - Season/Campaign Queries

    /// Get all packs belonging to a specific season
    /// - Parameter season: Season identifier (e.g., "season1")
    /// - Returns: Array of packs in that season
    public func getPacksBySeason(_ season: String) -> [LoadedPack] {
        return loadedPacks.values.filter { $0.manifest.season == season }
    }

    /// Get all packs in a campaign, sorted by campaign order
    /// - Parameter campaignId: Campaign identifier (e.g., "dark-forest")
    /// - Returns: Array of packs sorted by campaignOrder
    public func getPacksByCampaign(_ campaignId: String) -> [LoadedPack] {
        return loadedPacks.values
            .filter { $0.manifest.campaignId == campaignId }
            .sorted { ($0.manifest.campaignOrder ?? 0) < ($1.manifest.campaignOrder ?? 0) }
    }

    /// Get all available seasons from loaded packs
    /// - Returns: Array of unique season identifiers, sorted alphabetically
    public func getAvailableSeasons() -> [String] {
        let seasons = Set(loadedPacks.values.compactMap { $0.manifest.season })
        return seasons.sorted()
    }

    /// Get all campaign IDs within a specific season
    /// - Parameter season: Season identifier
    /// - Returns: Array of unique campaign IDs in that season
    public func getCampaignsInSeason(_ season: String) -> [String] {
        let campaignIds = Set(
            loadedPacks.values
                .filter { $0.manifest.season == season }
                .compactMap { $0.manifest.campaignId }
        )
        return campaignIds.sorted()
    }

    /// Check if all acts of a campaign are loaded
    /// Uses campaignOrder to verify continuity (1, 2, 3...)
    /// - Parameter campaignId: Campaign identifier
    /// - Returns: true if campaign has sequential acts starting from 1
    public func isCampaignComplete(_ campaignId: String) -> Bool {
        let packs = getPacksByCampaign(campaignId)
        guard !packs.isEmpty else { return false }

        // Check for sequential campaignOrder starting from 1
        let orders = packs.compactMap { $0.manifest.campaignOrder }.sorted()
        guard !orders.isEmpty else { return true } // No order = single pack = complete

        // Verify sequence: [1], [1,2], [1,2,3], etc.
        for (index, order) in orders.enumerated() {
            if order != index + 1 {
                return false
            }
        }
        return true
    }

    /// Get the next pack in a campaign sequence after the given pack
    /// - Parameter packId: Current pack ID
    /// - Returns: Next pack in campaign order, or nil if last/not in campaign
    public func getNextPackInCampaign(after packId: String) -> LoadedPack? {
        guard let currentPack = loadedPacks[packId],
              let campaignId = currentPack.manifest.campaignId,
              let currentOrder = currentPack.manifest.campaignOrder else {
            return nil
        }

        let campaignPacks = getPacksByCampaign(campaignId)
        return campaignPacks.first { $0.manifest.campaignOrder == currentOrder + 1 }
    }

    /// Get packs required to play a specific pack (story continuity)
    /// - Parameter packId: Pack ID to check
    /// - Returns: Array of required packs that are loaded
    public func getRequiredPacks(for packId: String) -> [LoadedPack] {
        guard let pack = loadedPacks[packId],
              let requiredIds = pack.manifest.requiresPacks else {
            return []
        }
        return requiredIds.compactMap { loadedPacks[$0] }
    }

    /// Check if all required packs for a given pack are loaded
    /// - Parameter packId: Pack ID to check
    /// - Returns: true if all required packs are available
    public func hasAllRequiredPacks(for packId: String) -> Bool {
        guard let pack = loadedPacks[packId],
              let requiredIds = pack.manifest.requiresPacks else {
            return true // No requirements
        }
        return requiredIds.allSatisfy { loadedPacks[$0] != nil }
    }

    /// Validate that content requirements are met for gameplay
    /// Returns errors if story pack is loaded without character pack
    public func validateContentRequirements() -> [ContentValidationError] {
        var errors: [ContentValidationError] = []

        // Story packs require at least one character pack
        if hasStoryPack && !hasCharacterPack {
            errors.append(ContentValidationError(
                type: .missingRequired,
                definitionId: "content-requirements",
                message: "Story pack requires at least one character pack to be loaded"
            ))
        }

        // Check that story packs have the heroes they recommend
        for pack in getStoryPacks() {
            for heroId in pack.manifest.recommendedHeroes {
                if getHero(id: heroId) == nil {
                    errors.append(ContentValidationError(
                        type: .brokenReference,
                        definitionId: pack.manifest.packId,
                        message: "Story pack recommends hero '\(heroId)' which is not available"
                    ))
                }
            }
        }

        return errors
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

        // Merge heroes and register into HeroRegistry for backward compatibility
        for (id, hero) in pack.heroes {
            mergedHeroes[id] = hero
            HeroRegistry.shared.register(hero)
        }
        #if DEBUG
        if !pack.heroes.isEmpty {
            print("ContentRegistry: Registered \(pack.heroes.count) heroes into HeroRegistry")
        }
        #endif

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
    /// Get region definition by ID (ContentProvider protocol).
    public func getRegionDefinition(id: String) -> RegionDefinition? {
        return getRegion(id: id)
    }

    /// Get all region definitions (ContentProvider protocol).
    public func getAllRegionDefinitions() -> [RegionDefinition] {
        return getAllRegions()
    }

    /// Get event definition by ID (ContentProvider protocol).
    public func getEventDefinition(id: String) -> EventDefinition? {
        return getEvent(id: id)
    }

    /// Get all event definitions (ContentProvider protocol).
    public func getAllEventDefinitions() -> [EventDefinition] {
        return getAllEvents()
    }

    /// Get anchor definition by ID (ContentProvider protocol).
    public func getAnchorDefinition(id: String) -> AnchorDefinition? {
        return getAnchor(id: id)
    }

    /// Get anchor definition for a region (ContentProvider protocol).
    public func getAnchorDefinition(forRegion regionId: String) -> AnchorDefinition? {
        return getAnchor(forRegion: regionId)
    }

    /// Get all anchor definitions (ContentProvider protocol).
    public func getAllAnchorDefinitions() -> [AnchorDefinition] {
        return getAllAnchors()
    }

    /// Get event definitions for a specific region.
    public func getEventDefinitions(forRegion regionId: String) -> [EventDefinition] {
        return mergedEvents.values.filter { event in
            event.availability.regionIds?.contains(regionId) ?? false
        }
    }

    /// Get event definitions from a specific pool.
    public func getEventDefinitions(forPool poolId: String) -> [EventDefinition] {
        return mergedEvents.values.filter { event in
            event.poolIds.contains(poolId)
        }
    }

    /// Get all quest definitions (ContentProvider protocol).
    public func getAllQuestDefinitions() -> [QuestDefinition] {
        return getAllQuests()
    }

    /// Get quest definition by ID (ContentProvider protocol).
    public func getQuestDefinition(id: String) -> QuestDefinition? {
        return getQuest(id: id)
    }

    /// Get all mini-game challenges from loaded events.
    public func getAllMiniGameChallenges() -> [MiniGameChallengeDefinition] {
        return mergedEvents.values.compactMap { $0.miniGameChallenge }
    }

    /// Get mini-game challenge by ID.
    public func getMiniGameChallenge(id: String) -> MiniGameChallengeDefinition? {
        return mergedEvents.values.compactMap { $0.miniGameChallenge }.first { $0.id == id }
    }

    /// Validate all loaded content for errors and inconsistencies.
    public func validate() -> [ContentValidationError] {
        let validator = ContentValidator(provider: self)
        return validator.validate()
    }
}

// MARK: - Encounter System Convenience Properties (Stubs)

extension ContentRegistry {
    /// Convenience property for all fate cards
    public var allFateCards: [FateCard] { getAllFateCards() }

    /// Convenience property for all enemies
    public var allEnemies: [EnemyDefinition] { getAllEnemies() }

    /// Convenience property for balance pack (stub until behaviors system)
    public var balancePack: BalancePackAccess { BalancePackAccess(config: getBalanceConfig()) }

    /// All registered behavior IDs
    public var allBehaviorIds: [String] { Array(mergedBehaviors.keys) }

    /// All registered behaviors
    public var allBehaviors: [BehaviorDefinition] { Array(mergedBehaviors.values) }

    /// Get behavior by ID
    public func getBehavior(id: String) -> BehaviorDefinition? {
        mergedBehaviors[id]
    }
}

/// Stub balance pack access for gate tests
public struct BalancePackAccess {
    let config: BalanceConfiguration?

    public var allKeys: [String] { [] }

    /// Returns a balance value for the given key.
    /// - Parameter key: The balance configuration key.
    /// - Returns: The value, or nil if not found.
    public func value(for key: String) -> Any? { nil }
}

// MARK: - Testing Support

extension ContentRegistry {
    /// Reset registry for testing
    /// - Warning: Only use in tests!
    public func resetForTesting() {
        unloadAllPacks()
    }

    /// Register mock content for testing
    /// - Warning: Only use in tests!
    public func registerMockContent(
        regions: [String: RegionDefinition] = [:],
        events: [String: EventDefinition] = [:],
        anchors: [String: AnchorDefinition] = [:],
        heroes: [String: StandardHeroDefinition] = [:],
        cards: [String: StandardCardDefinition] = [:],
        enemies: [String: EnemyDefinition] = [:],
        fateCards: [String: FateCard] = [:],
        behaviors: [String: BehaviorDefinition] = [:]
    ) {
        mergedRegions = regions
        mergedEvents = events
        mergedAnchors = anchors
        mergedHeroes = heroes
        mergedCards = cards
        mergedEnemies = enemies
        mergedFateCards = fateCards
        mergedBehaviors = behaviors
    }

    /// Load a mock pack for testing (simulates real pack loading)
    /// This properly tracks pack in loadedPacks and merges content
    /// - Warning: Only use in tests!
    @discardableResult
    public func loadMockPack(_ pack: LoadedPack) -> LoadedPack {
        let packId = pack.manifest.packId

        // Check if already loaded
        guard loadedPacks[packId] == nil else {
            return pack
        }

        // Register the pack
        loadedPacks[packId] = pack
        loadOrder.append(packId)

        // Merge content
        mergeContent(from: pack)

        return pack
    }

    /// Check for ID collisions between loaded packs
    /// Returns pairs of (entityType, id, packIds) for any collisions
    /// - Warning: Only use in tests!
    public func checkIdCollisions() -> [(entityType: String, id: String, packs: [String])] {
        var collisions: [(entityType: String, id: String, packs: [String])] = []

        // Check regions
        var regionSources: [String: [String]] = [:]
        for packId in loadOrder {
            guard let pack = loadedPacks[packId] else { continue }
            for regionId in pack.regions.keys {
                regionSources[regionId, default: []].append(packId)
            }
        }
        for (id, sources) in regionSources where sources.count > 1 {
            collisions.append(("Region", id, sources))
        }

        // Check events
        var eventSources: [String: [String]] = [:]
        for packId in loadOrder {
            guard let pack = loadedPacks[packId] else { continue }
            for eventId in pack.events.keys {
                eventSources[eventId, default: []].append(packId)
            }
        }
        for (id, sources) in eventSources where sources.count > 1 {
            collisions.append(("Event", id, sources))
        }

        // Check heroes
        var heroSources: [String: [String]] = [:]
        for packId in loadOrder {
            guard let pack = loadedPacks[packId] else { continue }
            for heroId in pack.heroes.keys {
                heroSources[heroId, default: []].append(packId)
            }
        }
        for (id, sources) in heroSources where sources.count > 1 {
            collisions.append(("Hero", id, sources))
        }

        // Check cards
        var cardSources: [String: [String]] = [:]
        for packId in loadOrder {
            guard let pack = loadedPacks[packId] else { continue }
            for cardId in pack.cards.keys {
                cardSources[cardId, default: []].append(packId)
            }
        }
        for (id, sources) in cardSources where sources.count > 1 {
            collisions.append(("Card", id, sources))
        }

        return collisions
    }
}

/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/ContentPacks/ContentRegistry+AccessAndQueries.swift
/// Назначение: Содержит реализацию файла ContentRegistry+AccessAndQueries.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

extension ContentRegistry {

    // MARK: - Content Access

    /// Get region definition by ID
    public func getRegion(id: String) -> RegionDefinition? {
        return mergedRegions[id]
    }

    /// Get all region definitions
    public func getAllRegions() -> [RegionDefinition] {
        return mergedRegions.keys.sorted().compactMap { mergedRegions[$0] }
    }

    /// Get event definition by ID
    public func getEvent(id: String) -> EventDefinition? {
        return mergedEvents[id]
    }

    /// Get all event definitions
    public func getAllEvents() -> [EventDefinition] {
        return mergedEvents.keys.sorted().compactMap { mergedEvents[$0] }
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

    /// Get ability by ID
    public func getAbility(id: String) -> HeroAbility? {
        return mergedAbilities[id]
    }

    /// Get all abilities
    public func getAllAbilities() -> [HeroAbility] {
        return Array(mergedAbilities.values)
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
        return mergedEvents.keys.sorted().compactMap { eventId in
            guard let event = mergedEvents[eventId] else { return nil }

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

            return regionMatches && stateMatches && pressureMatches ? event : nil
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


}

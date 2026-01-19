import Foundation

// MARK: - JSON Content Provider
// Reference: Docs/MIGRATION_PLAN.md, Feature A3 / EPIC D
// Phase 5 Implementation - Real cartridge-data-driven

/// Content provider that loads definitions from JSON files.
/// This is the "cartridge" approach - content as external data.
class JSONContentProvider: ContentProvider {
    // MARK: - Configuration

    /// Base path for content JSON files
    let contentPath: String

    /// Bundle containing content (nil = main bundle)
    let bundle: Bundle

    // MARK: - Cached Definitions (internal for @testable import)

    private(set) var regions: [String: RegionDefinition] = [:]
    private(set) var anchors: [String: AnchorDefinition] = [:]
    private(set) var events: [String: EventDefinition] = [:]
    private(set) var quests: [String: QuestDefinition] = [:]
    private(set) var miniGameChallenges: [String: MiniGameChallengeDefinition] = [:]

    // MARK: - Event Indices (internal for @testable import)

    private(set) var eventsByPool: [String: [EventDefinition]] = [:]
    private(set) var eventsByRegion: [String: [EventDefinition]] = [:]

    // MARK: - Loading State

    private(set) var isLoaded: Bool = false
    private(set) var loadErrors: [String] = []

    // MARK: - Initialization

    init(contentPath: String = "Content", bundle: Bundle? = nil) {
        self.contentPath = contentPath
        self.bundle = bundle ?? Bundle.main
    }

    /// Initialize and load content
    convenience init(loadImmediately: Bool, contentPath: String = "Content", bundle: Bundle? = nil) {
        self.init(contentPath: contentPath, bundle: bundle)
        if loadImmediately {
            do {
                try loadAllContent()
            } catch {
                loadErrors.append("Failed to load content: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Loading

    /// Load all content from JSON files
    func loadAllContent() throws {
        loadErrors.removeAll()

        // Load regions (files are at bundle root after Xcode copies them)
        if let regionsURL = bundle.url(forResource: "regions", withExtension: "json") {
            try loadRegions(from: regionsURL)
        } else {
            loadErrors.append("regions.json not found")
        }

        // Load anchors
        if let anchorsURL = bundle.url(forResource: "anchors", withExtension: "json") {
            try loadAnchors(from: anchorsURL)
        } else {
            loadErrors.append("anchors.json not found")
        }

        // Load quests
        if let questsURL = bundle.url(forResource: "quests", withExtension: "json") {
            try loadQuests(from: questsURL)
        } else {
            loadErrors.append("quests.json not found")
        }

        // Load challenges
        if let challengesURL = bundle.url(forResource: "challenges", withExtension: "json") {
            try loadChallenges(from: challengesURL)
        } else {
            loadErrors.append("challenges.json not found")
        }

        // Load event pools
        try loadEventPools()

        // Build indices
        buildEventIndices()

        isLoaded = true
    }

    /// Reload content (for development hot-reload)
    func reloadContent() throws {
        regions.removeAll()
        anchors.removeAll()
        events.removeAll()
        quests.removeAll()
        miniGameChallenges.removeAll()
        eventsByPool.removeAll()
        eventsByRegion.removeAll()
        isLoaded = false

        try loadAllContent()
    }

    // MARK: - Individual Loaders

    private func loadRegions(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let container = try JSONDecoder().decode(RegionsContainer.self, from: data)
        for region in container.regions {
            regions[region.id] = region.toDefinition()
        }
    }

    private func loadAnchors(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let container = try JSONDecoder().decode(AnchorsContainer.self, from: data)
        for anchor in container.anchors {
            anchors[anchor.id] = anchor.toDefinition()
        }
    }

    private func loadQuests(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let container = try JSONDecoder().decode(QuestsContainer.self, from: data)
        for quest in container.quests {
            quests[quest.id] = quest.toDefinition()
        }
    }

    private func loadChallenges(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let container = try JSONDecoder().decode(ChallengesContainer.self, from: data)
        for challenge in container.challenges {
            miniGameChallenges[challenge.id] = challenge.toDefinition()
        }
    }

    private func loadEventPools() throws {
        // Event pool files are at bundle root after Xcode copies them
        let poolNames = ["pool_common", "pool_village", "pool_forest", "pool_swamp",
                        "pool_mountain", "pool_sacred", "pool_breach", "pool_boss"]

        for poolName in poolNames {
            if let poolURL = bundle.url(forResource: poolName, withExtension: "json") {
                try loadEventPool(from: poolURL)
            }
        }
    }

    private func loadEventPool(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let container = try JSONDecoder().decode(EventPoolContainer.self, from: data)
        for event in container.events {
            let definition = event.toDefinition()
            events[definition.id] = definition
        }
    }

    private func buildEventIndices() {
        eventsByPool.removeAll()
        eventsByRegion.removeAll()

        for event in events.values {
            // Index by pool
            for poolId in event.poolIds {
                eventsByPool[poolId, default: []].append(event)
            }

            // Index by region (from availability)
            if let regionIds = event.availability.regionIds {
                for regionId in regionIds {
                    eventsByRegion[regionId, default: []].append(event)
                }
            }
        }
    }

    // MARK: - ContentProvider Implementation

    func getAllRegionDefinitions() -> [RegionDefinition] {
        return Array(regions.values)
    }

    func getRegionDefinition(id: String) -> RegionDefinition? {
        return regions[id]
    }

    func getAllAnchorDefinitions() -> [AnchorDefinition] {
        return Array(anchors.values)
    }

    func getAnchorDefinition(id: String) -> AnchorDefinition? {
        return anchors[id]
    }

    func getAnchorDefinition(forRegion regionId: String) -> AnchorDefinition? {
        return anchors.values.first { $0.regionId == regionId }
    }

    func getAllEventDefinitions() -> [EventDefinition] {
        return Array(events.values)
    }

    func getEventDefinition(id: String) -> EventDefinition? {
        return events[id]
    }

    func getEventDefinitions(forRegion regionId: String) -> [EventDefinition] {
        guard let region = regions[regionId] else { return [] }

        var result: [EventDefinition] = []
        for poolId in region.eventPoolIds {
            result.append(contentsOf: eventsByPool[poolId] ?? [])
        }
        result.append(contentsOf: eventsByRegion[regionId] ?? [])

        var seen = Set<String>()
        return result.filter { seen.insert($0.id).inserted }
    }

    func getEventDefinitions(forPool poolId: String) -> [EventDefinition] {
        return eventsByPool[poolId] ?? []
    }

    func getAllQuestDefinitions() -> [QuestDefinition] {
        return Array(quests.values)
    }

    func getQuestDefinition(id: String) -> QuestDefinition? {
        return quests[id]
    }

    func getAllMiniGameChallenges() -> [MiniGameChallengeDefinition] {
        return Array(miniGameChallenges.values)
    }

    func getMiniGameChallenge(id: String) -> MiniGameChallengeDefinition? {
        return miniGameChallenges[id]
    }

    func validate() -> [ContentValidationError] {
        let validator = ContentValidator(provider: self)
        return validator.validate()
    }
}

// MARK: - JSON Schema Containers

/// Container for regions.json
private struct RegionsContainer: Codable {
    let version: String?
    let description: String?
    let regions: [JSONRegion]
}

/// Container for anchors.json
private struct AnchorsContainer: Codable {
    let version: String?
    let description: String?
    let anchors: [JSONAnchor]
}

/// Container for quests.json
private struct QuestsContainer: Codable {
    let version: String?
    let description: String?
    let quests: [JSONQuest]
}

/// Container for challenges.json
private struct ChallengesContainer: Codable {
    let version: String?
    let description: String?
    let challenges: [JSONChallenge]
}

/// Container for event pool files
private struct EventPoolContainer: Codable {
    let version: String?
    let poolId: String?
    let description: String?
    let events: [JSONEvent]
}

// MARK: - JSON Schema Types

private struct JSONRegion: Codable {
    let id: String
    let titleKey: String
    let descriptionKey: String
    let neighborIds: [String]
    let initiallyDiscovered: Bool?
    let anchorId: String?
    let eventPoolIds: [String]?
    let initialState: String?
    let degradationWeight: Int?

    func toDefinition() -> RegionDefinition {
        let state: RegionStateType
        switch initialState?.lowercased() {
        case "stable": state = .stable
        case "borderland": state = .borderland
        case "breach": state = .breach
        default: state = .stable
        }

        return RegionDefinition(
            id: id,
            titleKey: titleKey,
            descriptionKey: descriptionKey,
            neighborIds: neighborIds,
            initiallyDiscovered: initiallyDiscovered ?? false,
            anchorId: anchorId,
            eventPoolIds: eventPoolIds ?? [],
            initialState: state,
            degradationWeight: degradationWeight ?? 1
        )
    }
}

private struct JSONAnchor: Codable {
    let id: String
    let titleKey: String
    let descriptionKey: String
    let regionId: String
    let anchorType: String?
    let initialInfluence: String?
    let power: Int?
    let initialIntegrity: Int?

    func toDefinition() -> AnchorDefinition {
        let influence: AnchorInfluence
        switch initialInfluence?.lowercased() {
        case "light": influence = .light
        case "dark": influence = .dark
        default: influence = .neutral
        }

        return AnchorDefinition(
            id: id,
            titleKey: titleKey,
            descriptionKey: descriptionKey,
            regionId: regionId,
            anchorType: anchorType ?? "shrine",
            initialInfluence: influence,
            power: power ?? 5,
            initialIntegrity: initialIntegrity ?? 100
        )
    }
}

private struct JSONEvent: Codable {
    let id: String
    let titleKey: String
    let bodyKey: String
    let eventType: String?
    let poolIds: [String]?
    let availability: JSONAvailability?
    let weight: Int?
    let isOneTime: Bool?
    let choices: [JSONChoice]?
    let combatData: JSONCombatData?

    func toDefinition() -> EventDefinition {
        let kind: EventKind
        switch eventType?.lowercased() {
        case "combat": kind = .miniGame(.combat)
        case "ritual": kind = .miniGame(.ritual)
        case "exploration": kind = .miniGame(.exploration)
        default: kind = .inline
        }

        let avail = availability?.toAvailability() ?? .always

        let choiceDefs = choices?.map { $0.toDefinition() } ?? []

        return EventDefinition(
            id: id,
            titleKey: titleKey,
            bodyKey: bodyKey,
            eventKind: kind,
            availability: avail,
            poolIds: poolIds ?? [],
            weight: weight ?? 10,
            isOneTime: isOneTime ?? false,
            choices: choiceDefs
        )
    }
}

private struct JSONAvailability: Codable {
    let regionStates: [String]?
    let regionIds: [String]?
    let minPressure: Int?
    let maxPressure: Int?
    let minBalance: Int?
    let maxBalance: Int?
    let requiredFlags: [String]?
    let forbiddenFlags: [String]?

    func toAvailability() -> Availability {
        return Availability(
            requiredFlags: requiredFlags ?? [],
            forbiddenFlags: forbiddenFlags ?? [],
            minPressure: minPressure,
            maxPressure: maxPressure,
            minBalance: minBalance,
            maxBalance: maxBalance,
            regionStates: regionStates,
            regionIds: regionIds
        )
    }
}

private struct JSONChoice: Codable {
    let id: String
    let labelKey: String
    let tooltipKey: String?
    let requirements: JSONChoiceRequirements?
    let consequences: JSONChoiceConsequences?

    func toDefinition() -> ChoiceDefinition {
        let reqs = requirements?.toRequirements()
        let cons = consequences?.toConsequences() ?? .none

        return ChoiceDefinition(
            id: id,
            labelKey: labelKey,
            tooltipKey: tooltipKey,
            requirements: reqs,
            consequences: cons
        )
    }
}

private struct JSONChoiceRequirements: Codable {
    let minFaith: Int?
    let minHealth: Int?
    let minBalance: Int?
    let maxBalance: Int?
    let requiredFlags: [String]?
    let forbiddenFlags: [String]?

    func toRequirements() -> ChoiceRequirements {
        var minResources: [String: Int] = [:]
        if let faith = minFaith { minResources["faith"] = faith }
        if let health = minHealth { minResources["health"] = health }

        return ChoiceRequirements(
            minResources: minResources,
            requiredFlags: requiredFlags ?? [],
            forbiddenFlags: forbiddenFlags ?? [],
            minBalance: minBalance,
            maxBalance: maxBalance
        )
    }
}

private struct JSONChoiceConsequences: Codable {
    let resourceChanges: [String: Int]?
    let setFlags: [String: Bool]?
    let clearFlags: [String]?
    let balanceShift: Int?
    let tensionChange: Int?
    let reputationChange: Int?
    let anchorIntegrityChange: Int?
    let addCards: [String]?
    let addCurse: String?
    let giveArtifact: String?
    let startCombat: Bool?
    let startQuest: String?
    let messageKey: String?

    func toConsequences() -> ChoiceConsequences {
        let resources = resourceChanges ?? [:]

        // Convert flag dict to array
        let flags = setFlags?.filter { $0.value }.map { $0.key } ?? []
        let clear = clearFlags ?? []

        return ChoiceConsequences(
            resourceChanges: resources,
            setFlags: flags,
            clearFlags: clear,
            balanceDelta: balanceShift ?? 0,
            resultKey: messageKey
        )
    }
}

private struct JSONCombatData: Codable {
    let enemyId: String?
    let enemyName: String?
    let enemyPower: Int?
    let enemyDefense: Int?
    let enemyHealth: Int?
    let isBoss: Bool?
}

private struct JSONQuest: Codable {
    let id: String
    let titleKey: String
    let descriptionKey: String
    let questType: String?
    let initialStatus: String?
    let objectives: [JSONObjective]?
    let rewards: JSONQuestRewards?

    func toDefinition() -> QuestDefinition {
        let objDefs = objectives?.map { $0.toDefinition() } ?? []

        return QuestDefinition(
            id: id,
            titleKey: titleKey,
            descriptionKey: descriptionKey,
            objectives: objDefs
        )
    }
}

private struct JSONObjective: Codable {
    let id: String
    let descriptionKey: String
    let completionCondition: JSONCompletionCondition?
    let nextObjectiveId: String?

    func toDefinition() -> ObjectiveDefinition {
        let condition = completionCondition?.toCondition() ?? .manual

        return ObjectiveDefinition(
            id: id,
            descriptionKey: descriptionKey,
            completionCondition: condition,
            nextObjectiveId: nextObjectiveId
        )
    }
}

private struct JSONCompletionCondition: Codable {
    let type: String?
    let regionId: String?
    let eventId: String?
    let flag: String?
    let anchorIds: [String]?
    let threshold: Int?

    func toCondition() -> CompletionCondition {
        switch type?.lowercased() {
        case "visitregion":
            return .visitRegion(regionId ?? "")
        case "eventcompleted":
            return .eventCompleted(eventId ?? "")
        case "flagset":
            return .flagSet(flag ?? "")
        default:
            return .manual
        }
    }
}

private struct JSONQuestRewards: Codable {
    let resourceChanges: [String: Int]?
    let setFlags: [String: Bool]?
    let balanceShift: Int?
    let tensionChange: Int?
    let reputationChange: Int?
    let giveArtifact: String?
    let unlockRegions: [String]?
    let addCurse: String?
}

private struct JSONChallenge: Codable {
    let id: String
    let challengeKind: String?
    let difficulty: Int?
    let titleKey: String?
    let descriptionKey: String?
    let enemyData: JSONCombatData?
    let requirements: JSONChoiceRequirements?
    let rewards: JSONChallengeRewards?
    let penalties: JSONChallengePenalties?
    let isBoss: Bool?

    func toDefinition() -> MiniGameChallengeDefinition {
        let kind: MiniGameChallengeKind
        switch challengeKind?.lowercased() {
        case "combat": kind = .combat
        case "ritual": kind = .ritual
        case "exploration": kind = .exploration
        case "dialogue": kind = .dialogue
        case "puzzle": kind = .puzzle
        default: kind = .combat
        }

        return MiniGameChallengeDefinition(
            id: id,
            challengeKind: kind,
            difficulty: difficulty ?? 5,
            enemyId: enemyData?.enemyId
        )
    }
}

private struct JSONChallengeRewards: Codable {
    let victoryFaith: Int?
    let victoryBalance: Int?
    let setFlags: [String: Bool]?
    let discoverRegion: Bool?
    let findArtifact: Bool?
}

private struct JSONChallengePenalties: Codable {
    let defeatHealth: Int?
    let defeatTension: Int?
    let faithCost: Int?
    let healthCost: Int?
    let tensionGain: Int?
}

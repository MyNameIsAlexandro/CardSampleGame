import Foundation

// MARK: - JSON Content Provider
// Reference: Docs/MIGRATION_PLAN.md, Feature A3 / EPIC D
// Phase 5 Implementation - Real cartridge-data-driven

/// Content provider that loads definitions from JSON files.
/// This is the "cartridge" approach - content as external data.
public class JSONContentProvider: ContentProvider {
    // MARK: - Configuration

    /// Base path for content JSON files
    public let contentPath: String

    /// Bundle containing content (nil = main bundle)
    public let bundle: Bundle

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

    public init(contentPath: String = "Content", bundle: Bundle? = nil) {
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
    public func loadAllContent() throws {
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
    public func reloadContent() throws {
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
        // quests.json can be either a container with "quests" array or a direct array
        do {
            let container = try JSONDecoder().decode(QuestsContainer.self, from: data)
            for quest in container.quests {
                quests[quest.id] = quest.toDefinition()
            }
        } catch {
            // Try direct array format (like events.json)
            let questArray = try JSONDecoder().decode([JSONQuest].self, from: data)
            for quest in questArray {
                quests[quest.id] = quest.toDefinition()
            }
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
        // Events are now in events.json with pool_ids field, not separate pool files
        // Load events.json which contains all events with their pool associations
        if let eventsURL = bundle.url(forResource: "events", withExtension: "json") {
            try loadEvents(from: eventsURL)
        } else {
            loadErrors.append("events.json not found")
        }
    }

    private func loadEvents(from url: URL) throws {
        let data = try Data(contentsOf: url)
        // events.json is a direct array, not wrapped in a container
        let eventArray = try JSONDecoder().decode([JSONEvent].self, from: data)
        for event in eventArray {
            let definition = event.toDefinition()
            events[definition.id] = definition
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

    public func getAllRegionDefinitions() -> [RegionDefinition] {
        return Array(regions.values)
    }

    public func getRegionDefinition(id: String) -> RegionDefinition? {
        return regions[id]
    }

    public func getAllAnchorDefinitions() -> [AnchorDefinition] {
        return Array(anchors.values)
    }

    public func getAnchorDefinition(id: String) -> AnchorDefinition? {
        return anchors[id]
    }

    public func getAnchorDefinition(forRegion regionId: String) -> AnchorDefinition? {
        return anchors.values.first { $0.regionId == regionId }
    }

    public func getAllEventDefinitions() -> [EventDefinition] {
        return Array(events.values)
    }

    public func getEventDefinition(id: String) -> EventDefinition? {
        return events[id]
    }

    public func getEventDefinitions(forRegion regionId: String) -> [EventDefinition] {
        guard let region = regions[regionId] else { return [] }

        var result: [EventDefinition] = []
        for poolId in region.eventPoolIds {
            result.append(contentsOf: eventsByPool[poolId] ?? [])
        }
        result.append(contentsOf: eventsByRegion[regionId] ?? [])

        var seen = Set<String>()
        return result.filter { seen.insert($0.id).inserted }
    }

    public func getEventDefinitions(forPool poolId: String) -> [EventDefinition] {
        return eventsByPool[poolId] ?? []
    }

    public func getAllQuestDefinitions() -> [QuestDefinition] {
        return Array(quests.values)
    }

    public func getQuestDefinition(id: String) -> QuestDefinition? {
        return quests[id]
    }

    public func getAllMiniGameChallenges() -> [MiniGameChallengeDefinition] {
        return Array(miniGameChallenges.values)
    }

    public func getMiniGameChallenge(id: String) -> MiniGameChallengeDefinition? {
        return miniGameChallenges[id]
    }

    public func validate() -> [ContentValidationError] {
        let validator = ContentValidator(provider: self)
        return validator.validate()
    }
}

// MARK: - JSON Schema Containers

/// Container for regions.json
private struct RegionsContainer: Codable {
    public let version: String?
    public let description: String?
    public let regions: [JSONRegion]
}

/// Container for anchors.json
private struct AnchorsContainer: Codable {
    public let version: String?
    public let description: String?
    public let anchors: [JSONAnchor]
}

/// Container for quests.json
private struct QuestsContainer: Codable {
    public let version: String?
    public let description: String?
    public let quests: [JSONQuest]
}

/// Container for challenges.json
private struct ChallengesContainer: Codable {
    public let version: String?
    public let description: String?
    public let challenges: [JSONChallenge]
}

/// Container for event pool files
private struct EventPoolContainer: Codable {
    public let version: String?
    public let poolId: String?
    public let description: String?
    public let events: [JSONEvent]
}

// MARK: - JSON Schema Types

private struct JSONRegion: Codable {
    public let id: String
    public let title: LocalizedString
    public let description: LocalizedString
    public let regionType: String?
    public let neighborIds: [String]
    public let initiallyDiscovered: Bool?
    public let anchorId: String?
    public let eventPoolIds: [String]?
    public let initialState: String?
    public let degradationWeight: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, description, neighborIds, initiallyDiscovered, anchorId
        case eventPoolIds, initialState, degradationWeight
        case regionType = "region_type"
    }

    public func toDefinition() -> RegionDefinition {
        let state: RegionStateType
        switch initialState?.lowercased() {
        case "stable": state = .stable
        case "borderland": state = .borderland
        case "breach": state = .breach
        default: state = .stable
        }

        return RegionDefinition(
            id: id,
            title: .inline(title),
            description: .inline(description),
            regionType: regionType ?? "forest",
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
    public let id: String
    public let title: LocalizedString
    public let description: LocalizedString
    public let regionId: String
    public let anchorType: String?
    public let initialInfluence: String?
    public let power: Int?
    public let initialIntegrity: Int?

    public func toDefinition() -> AnchorDefinition {
        let influence: AnchorInfluence
        switch initialInfluence?.lowercased() {
        case "light": influence = .light
        case "dark": influence = .dark
        default: influence = .neutral
        }

        return AnchorDefinition(
            id: id,
            title: .inline(title),
            description: .inline(description),
            regionId: regionId,
            anchorType: anchorType ?? "shrine",
            initialInfluence: influence,
            power: power ?? 5,
            initialIntegrity: initialIntegrity ?? 100
        )
    }
}

/// Represents event_kind which can be either a string "inline" or object {"mini_game": "combat"}
private enum JSONEventKind: Codable {
    case inline
    case miniGame(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // Try string first (e.g., "inline")
        if let stringValue = try? container.decode(String.self) {
            if stringValue == "inline" {
                self = .inline
            } else {
                // Treat other strings as mini_game type
                self = .miniGame(stringValue)
            }
            return
        }

        // Try object (e.g., {"mini_game": "combat"})
        if let dictValue = try? container.decode([String: String].self),
           let miniGameType = dictValue["mini_game"] {
            self = .miniGame(miniGameType)
            return
        }

        // Default to inline
        self = .inline
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .inline:
            try container.encode("inline")
        case .miniGame(let type):
            try container.encode(["mini_game": type])
        }
    }

    public func toEventKind() -> EventKind {
        switch self {
        case .inline:
            return .inline
        case .miniGame(let type):
            switch type.lowercased() {
            case "combat": return .miniGame(.combat)
            case "ritual": return .miniGame(.ritual)
            case "exploration": return .miniGame(.exploration)
            case "dialogue": return .miniGame(.dialogue)
            case "puzzle": return .miniGame(.puzzle)
            default: return .miniGame(.combat)
            }
        }
    }
}

private struct JSONEvent: Codable {
    public let id: String
    public let title: LocalizedString
    public let body: LocalizedString
    public let eventKind: JSONEventKind?
    public let eventType: String?
    public let poolIds: [String]?
    public let availability: JSONAvailability?
    public let weight: Int?
    public let isOneTime: Bool?
    public let isInstant: Bool?
    public let cooldown: Int?
    public let choices: [JSONChoice]?
    public let combatData: JSONCombatData?
    public let miniGameChallenge: JSONMiniGameChallenge?

    enum CodingKeys: String, CodingKey {
        case id, title, body, availability, weight, choices, combatData
        case eventKind = "event_kind"
        case eventType = "event_type"
        case poolIds = "pool_ids"
        case isOneTime = "is_one_time"
        case isInstant = "is_instant"
        case cooldown
        case miniGameChallenge = "mini_game_challenge"
    }

    public func toDefinition() -> EventDefinition {
        let kind: EventKind
        // Prefer eventKind (can be string or object), fall back to eventType (legacy string)
        if let ek = eventKind {
            kind = ek.toEventKind()
        } else if let et = eventType {
            switch et.lowercased() {
            case "combat": kind = .miniGame(.combat)
            case "ritual": kind = .miniGame(.ritual)
            case "exploration": kind = .miniGame(.exploration)
            default: kind = .inline
            }
        } else {
            kind = .inline
        }

        let avail = availability?.toAvailability() ?? .always

        let choiceDefs = choices?.map { $0.toDefinition() } ?? []

        // Create MiniGameChallengeDefinition from JSON mini_game_challenge
        let challenge: MiniGameChallengeDefinition?
        if let json = miniGameChallenge, let enemyId = json.enemyId {
            challenge = MiniGameChallengeDefinition(
                id: "challenge_\(enemyId)",
                challengeKind: .combat,
                difficulty: json.difficulty ?? 1,
                enemyId: enemyId,
                victoryConsequences: json.rewards?.toConsequences() ?? .none,
                defeatConsequences: json.penalties?.toConsequences() ?? .none
            )
        } else {
            challenge = nil
        }

        return EventDefinition(
            id: id,
            title: .inline(title),
            body: .inline(body),
            eventKind: kind,
            availability: avail,
            poolIds: poolIds ?? [],
            weight: weight ?? 10,
            isOneTime: isOneTime ?? false,
            choices: choiceDefs,
            miniGameChallenge: challenge
        )
    }
}

private struct JSONAvailability: Codable {
    public let regionStates: [String]?
    public let regionIds: [String]?
    public let minPressure: Int?
    public let maxPressure: Int?
    public let minBalance: Int?
    public let maxBalance: Int?
    public let requiredFlags: [String]?
    public let forbiddenFlags: [String]?

    enum CodingKeys: String, CodingKey {
        case regionStates = "region_states"
        case regionIds = "region_ids"
        case minPressure = "min_pressure"
        case maxPressure = "max_pressure"
        case minBalance = "min_balance"
        case maxBalance = "max_balance"
        case requiredFlags = "required_flags"
        case forbiddenFlags = "forbidden_flags"
    }

    public func toAvailability() -> Availability {
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
    public let id: String
    public let label: LocalizedString
    public let tooltip: LocalizedString?
    public let requirements: JSONChoiceRequirements?
    public let consequences: JSONChoiceConsequences?

    public func toDefinition() -> ChoiceDefinition {
        let reqs = requirements?.toRequirements()
        let cons = consequences?.toConsequences() ?? .none

        return ChoiceDefinition(
            id: id,
            label: .inline(label),
            tooltip: tooltip.map { .inline($0) },
            requirements: reqs,
            consequences: cons
        )
    }
}

private struct JSONChoiceRequirements: Codable {
    public let minFaith: Int?
    public let minHealth: Int?
    public let minBalance: Int?
    public let maxBalance: Int?
    public let requiredFlags: [String]?
    public let forbiddenFlags: [String]?

    public func toRequirements() -> ChoiceRequirements {
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
    public let resourceChanges: [String: Int]?
    public let setFlags: [String: Bool]?
    public let clearFlags: [String]?
    public let balanceShift: Int?
    public let tensionChange: Int?
    public let reputationChange: Int?
    public let anchorIntegrityChange: Int?
    public let addCards: [String]?
    public let addCurse: String?
    public let giveArtifact: String?
    public let startCombat: Bool?
    public let startQuest: String?
    public let messageKey: String?

    public func toConsequences() -> ChoiceConsequences {
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
    public let enemyId: String?
    public let enemyName: String?
    public let enemyPower: Int?
    public let enemyDefense: Int?
    public let enemyHealth: Int?
    public let isBoss: Bool?
}

/// JSON representation of mini_game_challenge field in events
private struct JSONMiniGameChallenge: Codable {
    public let enemyId: String?
    public let difficulty: Int?
    public let rewards: JSONChallengeConsequences?
    public let penalties: JSONChallengeConsequences?

    enum CodingKeys: String, CodingKey {
        case enemyId = "enemy_id"
        case difficulty, rewards, penalties
    }
}

/// JSON representation of rewards/penalties in mini_game_challenge
private struct JSONChallengeConsequences: Codable {
    public let resourceChanges: [String: Int]?
    public let setFlags: [String]?
    public let balanceShift: Int?

    enum CodingKeys: String, CodingKey {
        case resourceChanges = "resource_changes"
        case setFlags = "set_flags"
        case balanceShift = "balance_shift"
    }

    public func toConsequences() -> ChoiceConsequences {
        return ChoiceConsequences(
            resourceChanges: resourceChanges ?? [:],
            setFlags: setFlags ?? [],
            clearFlags: [],
            balanceDelta: balanceShift ?? 0
        )
    }
}

private struct JSONQuest: Codable {
    public let id: String
    public let title: LocalizedString
    public let description: LocalizedString
    public let questKind: String?
    public let availability: JSONQuestAvailability?
    public let autoStart: Bool?
    public let objectives: [JSONObjective]?
    public let completionRewards: JSONQuestCompletionRewards?
    public let failurePenalties: JSONQuestCompletionRewards?

    enum CodingKeys: String, CodingKey {
        case id, title, description, objectives, availability
        case questKind = "quest_kind"
        case autoStart = "auto_start"
        case completionRewards = "completion_rewards"
        case failurePenalties = "failure_penalties"
    }

    public func toDefinition() -> QuestDefinition {
        let objDefs = objectives?.map { $0.toDefinition() } ?? []

        let kind: QuestKind
        switch questKind?.lowercased() {
        case "main": kind = .main
        case "side": kind = .side
        case "exploration": kind = .exploration
        case "challenge": kind = .challenge
        default: kind = .side
        }

        let avail = availability?.toAvailability() ?? .always
        let rewards = completionRewards?.toRewards() ?? .none
        let penalties = failurePenalties?.toRewards() ?? .none

        return QuestDefinition(
            id: id,
            title: .inline(title),
            description: .inline(description),
            objectives: objDefs,
            questKind: kind,
            availability: avail,
            autoStart: autoStart ?? false,
            completionRewards: rewards,
            failurePenalties: penalties
        )
    }
}

private struct JSONObjective: Codable {
    public let id: String
    public let description: LocalizedString
    public let hint: LocalizedString?
    public let completionCondition: JSONCompletionCondition?
    public let targetValue: Int?
    public let isOptional: Bool?
    public let nextObjectiveId: String?
    public let alternativeNextIds: [String]?

    enum CodingKeys: String, CodingKey {
        case id, description, hint
        case completionCondition = "completion_condition"
        case targetValue = "target_value"
        case isOptional = "is_optional"
        case nextObjectiveId = "next_objective_id"
        case alternativeNextIds = "alternative_next_ids"
    }

    public func toDefinition() -> ObjectiveDefinition {
        let condition = completionCondition?.toCondition() ?? .manual

        return ObjectiveDefinition(
            id: id,
            description: .inline(description),
            hint: hint.map { .inline($0) },
            completionCondition: condition,
            targetValue: targetValue ?? 1,
            isOptional: isOptional ?? false,
            nextObjectiveId: nextObjectiveId,
            alternativeNextIds: alternativeNextIds ?? []
        )
    }
}

/// Completion condition that can be either:
/// - Direct format: {"flag_set": "flag_name"} or {"visit_region": "region_id"}
/// - Object format: {"type": "flagset", "flag": "flag_name"}
private struct JSONCompletionCondition: Codable {
    // Direct format keys
    public let flagSet: String?
    public let visitRegion: String?
    public let eventCompleted: String?
    public let defeatEnemy: String?
    public let collectItem: String?

    // Choice made format: {"choice_made": {"event_id": "...", "choice_id": "..."}}
    public let choiceMade: JSONChoiceMadeCondition?

    // Resource threshold format: {"resource_threshold": {"resource_id": "...", "min_value": 10}}
    public let resourceThreshold: JSONResourceThresholdCondition?

    // Legacy object format fields
    public let type: String?
    public let regionId: String?
    public let eventId: String?
    public let flag: String?
    public let threshold: Int?

    enum CodingKeys: String, CodingKey {
        case flagSet = "flag_set"
        case visitRegion = "visit_region"
        case eventCompleted = "event_completed"
        case defeatEnemy = "defeat_enemy"
        case collectItem = "collect_item"
        case choiceMade = "choice_made"
        case resourceThreshold = "resource_threshold"
        case type, regionId, eventId, flag, threshold
    }

    public func toCondition() -> CompletionCondition {
        // Check direct format keys first
        if let flag = flagSet {
            return .flagSet(flag)
        }
        if let region = visitRegion {
            return .visitRegion(region)
        }
        if let event = eventCompleted {
            return .eventCompleted(event)
        }
        if let enemy = defeatEnemy {
            return .defeatEnemy(enemy)
        }
        if let item = collectItem {
            return .collectItem(item)
        }
        if let choice = choiceMade {
            return .choiceMade(eventId: choice.eventId ?? "", choiceId: choice.choiceId ?? "")
        }
        if let resource = resourceThreshold {
            return .resourceThreshold(resourceId: resource.resourceId ?? "", minValue: resource.minValue ?? 0)
        }

        // Fall back to legacy object format
        switch type?.lowercased() {
        case "visitregion", "visit_region":
            return .visitRegion(regionId ?? "")
        case "eventcompleted", "event_completed":
            return .eventCompleted(eventId ?? "")
        case "flagset", "flag_set":
            return .flagSet(flag ?? "")
        case "defeatenemy", "defeat_enemy":
            return .defeatEnemy(eventId ?? "")
        default:
            return .manual
        }
    }
}

private struct JSONChoiceMadeCondition: Codable {
    public let eventId: String?
    public let choiceId: String?

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case choiceId = "choice_id"
    }
}

private struct JSONResourceThresholdCondition: Codable {
    public let resourceId: String?
    public let minValue: Int?

    enum CodingKeys: String, CodingKey {
        case resourceId = "resource_id"
        case minValue = "min_value"
    }
}

private struct JSONQuestAvailability: Codable {
    public let requiredFlags: [String]?
    public let forbiddenFlags: [String]?
    public let minPressure: Int?
    public let maxPressure: Int?
    public let minBalance: Int?
    public let maxBalance: Int?
    public let regionStates: [String]?
    public let regionIds: [String]?

    enum CodingKeys: String, CodingKey {
        case requiredFlags = "required_flags"
        case forbiddenFlags = "forbidden_flags"
        case minPressure = "min_pressure"
        case maxPressure = "max_pressure"
        case minBalance = "min_balance"
        case maxBalance = "max_balance"
        case regionStates = "region_states"
        case regionIds = "region_ids"
    }

    public func toAvailability() -> Availability {
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

private struct JSONQuestCompletionRewards: Codable {
    public let resourceChanges: [String: Int]?
    public let setFlags: [String]?
    public let cardIds: [String]?
    public let balanceDelta: Int?

    enum CodingKeys: String, CodingKey {
        case resourceChanges = "resource_changes"
        case setFlags = "set_flags"
        case cardIds = "card_ids"
        case balanceDelta = "balance_delta"
    }

    public func toRewards() -> QuestCompletionRewards {
        return QuestCompletionRewards(
            resourceChanges: resourceChanges ?? [:],
            setFlags: setFlags ?? [],
            cardIds: cardIds ?? [],
            balanceDelta: balanceDelta ?? 0
        )
    }
}

private struct JSONQuestRewards: Codable {
    public let resourceChanges: [String: Int]?
    public let setFlags: [String: Bool]?
    public let balanceShift: Int?
    public let tensionChange: Int?
    public let reputationChange: Int?
    public let giveArtifact: String?
    public let unlockRegions: [String]?
    public let addCurse: String?
}

private struct JSONChallenge: Codable {
    public let id: String
    public let challengeKind: String?
    public let difficulty: Int?
    public let titleKey: String?
    public let descriptionKey: String?
    public let enemyData: JSONCombatData?
    public let requirements: JSONChoiceRequirements?
    public let rewards: JSONChallengeRewards?
    public let penalties: JSONChallengePenalties?
    public let isBoss: Bool?

    public func toDefinition() -> MiniGameChallengeDefinition {
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
    public let victoryFaith: Int?
    public let victoryBalance: Int?
    public let setFlags: [String: Bool]?
    public let discoverRegion: Bool?
    public let findArtifact: Bool?
}

private struct JSONChallengePenalties: Codable {
    public let defeatHealth: Int?
    public let defeatTension: Int?
    public let faithCost: Int?
    public let healthCost: Int?
    public let tensionGain: Int?
}

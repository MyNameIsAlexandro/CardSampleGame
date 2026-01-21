import Foundation

// MARK: - Code Content Provider
// Reference: Docs/MIGRATION_PLAN.md, Feature A3
// Adapter for existing TwilightMarchesConfig content

/// Content provider that loads definitions from Swift code.
/// This is an adapter for the existing TwilightMarchesConfig.swift content.
/// Will be replaced/augmented by JSONContentProvider in Phase 5.
class CodeContentProvider: ContentProvider {
    // MARK: - Cached Definitions

    private var regions: [String: RegionDefinition] = [:]
    private var anchors: [String: AnchorDefinition] = [:]
    private var events: [String: EventDefinition] = [:]
    private var quests: [String: QuestDefinition] = [:]
    private var miniGameChallenges: [String: MiniGameChallengeDefinition] = [:]

    // MARK: - Event Pool Index

    private var eventsByPool: [String: [EventDefinition]] = [:]
    private var eventsByRegion: [String: [EventDefinition]] = [:]

    // MARK: - Initialization

    init() {
        loadContent()
    }

    /// Load all content from code definitions
    private func loadContent() {
        loadRegions()
        loadAnchors()
        loadEvents()
        loadQuests()
        loadMiniGameChallenges()
        buildEventIndices()
    }

    // MARK: - Content Loading (Override in subclass for actual content)

    /// Load region definitions
    /// Subclass should override to provide actual regions
    func loadRegions() {
        // Default implementation - subclass overrides with actual content
        // Example region for testing (uses generic IDs, not game-specific):
        let testRegion = RegionDefinition(
            id: "test_region",
            title: LocalizedString(en: "Test Region", ru: "Тестовый Регион"),
            description: LocalizedString(en: "A test region", ru: "Тестовый регион"),
            regionType: "forest",
            neighborIds: ["test_neighbor"],
            initiallyDiscovered: true,
            anchorId: "test_anchor",
            eventPoolIds: ["pool_common"],
            initialState: .stable
        )
        regions[testRegion.id] = testRegion
    }

    /// Load anchor definitions
    func loadAnchors() {
        // Default implementation - subclass overrides (uses generic IDs, not game-specific)
        let testAnchor = AnchorDefinition(
            id: "test_anchor",
            title: LocalizedString(en: "Test Anchor", ru: "Тестовый Якорь"),
            description: LocalizedString(en: "A test anchor", ru: "Тестовый якорь"),
            regionId: "test_region"
        )
        anchors[testAnchor.id] = testAnchor
    }

    /// Load event definitions
    func loadEvents() {
        // Default implementation - subclass overrides
        let testEvent = EventDefinition(
            id: "event_test",
            title: LocalizedString(en: "Test Event", ru: "Тестовое Событие"),
            body: LocalizedString(en: "A test event", ru: "Тестовое событие"),
            eventKind: .inline,
            poolIds: ["pool_common"],
            choices: [
                ChoiceDefinition(
                    id: "choice_a",
                    label: LocalizedString(en: "Choice A", ru: "Выбор А"),
                    consequences: ChoiceConsequences(resourceChanges: ["faith": -2])
                ),
                ChoiceDefinition(
                    id: "choice_b",
                    label: LocalizedString(en: "Choice B", ru: "Выбор Б"),
                    consequences: ChoiceConsequences(resourceChanges: ["health": -3])
                )
            ]
        )
        events[testEvent.id] = testEvent
    }

    /// Load quest definitions
    func loadQuests() {
        // Default implementation - subclass overrides
        let testQuest = QuestDefinition(
            id: "quest_test",
            title: LocalizedString(en: "Test Quest", ru: "Тестовое Задание"),
            description: LocalizedString(en: "A test quest", ru: "Тестовое задание"),
            objectives: [
                ObjectiveDefinition(
                    id: "obj_1",
                    description: LocalizedString(en: "Objective 1", ru: "Цель 1"),
                    completionCondition: .manual,
                    nextObjectiveId: "obj_2"
                ),
                ObjectiveDefinition(
                    id: "obj_2",
                    description: LocalizedString(en: "Objective 2", ru: "Цель 2"),
                    completionCondition: .manual
                )
            ]
        )
        quests[testQuest.id] = testQuest
    }

    /// Load mini-game challenge definitions
    func loadMiniGameChallenges() {
        // Default implementation - subclass overrides
        let testCombat = MiniGameChallengeDefinition(
            id: "combat_test",
            challengeKind: .combat,
            difficulty: 5
        )
        miniGameChallenges[testCombat.id] = testCombat
    }

    /// Build event indices for fast lookup
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

    // MARK: - JSON Event Loading Utility

    /// Load events from a JSON file URL
    /// - Parameter url: URL to the events.json file
    /// - Throws: Decoding errors
    func loadEventsFromJSON(url: URL) throws {
        let data = try Data(contentsOf: url)
        let jsonEvents = try JSONDecoder().decode([JSONEventForLoading].self, from: data)
        for jsonEvent in jsonEvents {
            events[jsonEvent.id] = jsonEvent.toDefinition()
        }
        buildEventIndices()
    }

    // MARK: - Registration (for building content)

    func registerRegion(_ region: RegionDefinition) {
        regions[region.id] = region
    }

    func registerAnchor(_ anchor: AnchorDefinition) {
        anchors[anchor.id] = anchor
    }

    func registerEvent(_ event: EventDefinition) {
        events[event.id] = event
    }

    func registerQuest(_ quest: QuestDefinition) {
        quests[quest.id] = quest
    }

    func registerMiniGameChallenge(_ challenge: MiniGameChallengeDefinition) {
        miniGameChallenges[challenge.id] = challenge
    }

    func rebuildIndices() {
        buildEventIndices()
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
        // Get events from region's pools
        guard let region = regions[regionId] else { return [] }

        var result: [EventDefinition] = []
        for poolId in region.eventPoolIds {
            result.append(contentsOf: eventsByPool[poolId] ?? [])
        }

        // Add events specifically for this region
        result.append(contentsOf: eventsByRegion[regionId] ?? [])

        // Remove duplicates while preserving order
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

// MARK: - JSON Event Loading Structures

/// Simplified event_kind that can be either "inline" string or {"mini_game": "combat"} object
enum JSONEventKindForLoading: Codable {
    case inline
    case miniGame(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = stringValue == "inline" ? .inline : .miniGame(stringValue)
            return
        }
        if let dictValue = try? container.decode([String: String].self),
           let miniGameType = dictValue["mini_game"] {
            self = .miniGame(miniGameType)
            return
        }
        self = .inline
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .inline: try container.encode("inline")
        case .miniGame(let type): try container.encode(["mini_game": type])
        }
    }

    func toEventKind() -> EventKind {
        switch self {
        case .inline: return .inline
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

/// JSON structure for loading events from file
struct JSONEventForLoading: Codable {
    let id: String
    let title: LocalizedString
    let body: LocalizedString
    let eventKind: JSONEventKindForLoading?
    let eventType: String?
    let poolIds: [String]?
    let availability: JSONAvailabilityForLoading?
    let weight: Int?
    let isOneTime: Bool?
    let isInstant: Bool?
    let cooldown: Int?
    let choices: [JSONChoiceForLoading]?
    let miniGameChallenge: JSONMiniGameChallengeForLoading?

    enum CodingKeys: String, CodingKey {
        case id, title, body, availability, weight, choices
        case eventKind = "event_kind"
        case eventType = "event_type"
        case poolIds = "pool_ids"
        case isOneTime = "is_one_time"
        case isInstant = "is_instant"
        case cooldown
        case miniGameChallenge = "mini_game_challenge"
    }

    func toDefinition() -> EventDefinition {
        let kind: EventKind
        if let ek = eventKind { kind = ek.toEventKind() }
        else if let et = eventType {
            switch et.lowercased() {
            case "combat": kind = .miniGame(.combat)
            case "ritual": kind = .miniGame(.ritual)
            case "exploration": kind = .miniGame(.exploration)
            default: kind = .inline
            }
        } else { kind = .inline }

        let avail = availability?.toAvailability() ?? .always
        let choiceDefs = choices?.map { $0.toDefinition() } ?? []

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
        } else { challenge = nil }

        return EventDefinition(
            id: id,
            title: title,
            body: body,
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

struct JSONAvailabilityForLoading: Codable {
    let regionStates: [String]?
    let regionIds: [String]?
    let minPressure: Int?
    let maxPressure: Int?
    let minBalance: Int?
    let maxBalance: Int?
    let requiredFlags: [String]?
    let forbiddenFlags: [String]?

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

    func toAvailability() -> Availability {
        Availability(
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

struct JSONChoiceForLoading: Codable {
    let id: String
    let label: LocalizedString
    let tooltip: LocalizedString?
    let requirements: JSONChoiceRequirementsForLoading?
    let consequences: JSONChoiceConsequencesForLoading?

    func toDefinition() -> ChoiceDefinition {
        ChoiceDefinition(
            id: id,
            label: label,
            tooltip: tooltip,
            requirements: requirements?.toRequirements(),
            consequences: consequences?.toConsequences() ?? .none
        )
    }
}

struct JSONChoiceRequirementsForLoading: Codable {
    let minResources: [String: Int]?
    let minFaith: Int?
    let minHealth: Int?
    let minBalance: Int?
    let maxBalance: Int?
    let requiredFlags: [String]?
    let forbiddenFlags: [String]?

    enum CodingKeys: String, CodingKey {
        case minResources = "min_resources"
        case minFaith = "min_faith"
        case minHealth = "min_health"
        case minBalance = "min_balance"
        case maxBalance = "max_balance"
        case requiredFlags = "required_flags"
        case forbiddenFlags = "forbidden_flags"
    }

    func toRequirements() -> ChoiceRequirements {
        var resources = minResources ?? [:]
        if let faith = minFaith { resources["faith"] = faith }
        if let health = minHealth { resources["health"] = health }
        return ChoiceRequirements(
            minResources: resources,
            requiredFlags: requiredFlags ?? [],
            forbiddenFlags: forbiddenFlags ?? [],
            minBalance: minBalance,
            maxBalance: maxBalance
        )
    }
}

struct JSONChoiceConsequencesForLoading: Codable {
    let resourceChanges: [String: Int]?
    let setFlags: [String]?
    let clearFlags: [String]?
    let balanceDelta: Int?
    let regionStateChange: JSONRegionStateChangeForLoading?
    let questProgress: JSONQuestProgressForLoading?
    let triggerEventId: String?
    let resultKey: String?

    enum CodingKeys: String, CodingKey {
        case resourceChanges = "resource_changes"
        case setFlags = "set_flags"
        case clearFlags = "clear_flags"
        case balanceDelta = "balance_delta"
        case regionStateChange = "region_state_change"
        case questProgress = "quest_progress"
        case triggerEventId = "trigger_event_id"
        case resultKey = "result_key"
    }

    func toConsequences() -> ChoiceConsequences {
        let stateChange: RegionStateChange?
        if let rsc = regionStateChange {
            let transition: RegionStateChange.StateTransition?
            switch rsc.transition?.lowercased() {
            case "restore": transition = .restore
            case "degrade": transition = .degrade
            default: transition = nil
            }
            stateChange = RegionStateChange(
                regionId: rsc.regionId,
                newState: nil,
                transition: transition
            )
        } else { stateChange = nil }

        let questProg: QuestProgressTrigger?
        if let qp = questProgress {
            let action: QuestProgressTrigger.QuestAction
            switch qp.action?.lowercased() {
            case "complete": action = .complete
            case "unlock": action = .unlock
            case "fail": action = .fail
            case "advance": action = .advance
            default: action = .complete
            }
            questProg = QuestProgressTrigger(
                questId: qp.questId ?? "",
                objectiveId: qp.objectiveId,
                action: action
            )
        } else { questProg = nil }

        return ChoiceConsequences(
            resourceChanges: resourceChanges ?? [:],
            setFlags: setFlags ?? [],
            clearFlags: clearFlags ?? [],
            balanceDelta: balanceDelta ?? 0,
            regionStateChange: stateChange,
            questProgress: questProg,
            resultKey: resultKey
        )
    }
}

struct JSONRegionStateChangeForLoading: Codable {
    let regionId: String?
    let newState: String?
    let transition: String?

    enum CodingKeys: String, CodingKey {
        case regionId = "region_id"
        case newState = "new_state"
        case transition
    }
}

struct JSONQuestProgressForLoading: Codable {
    let questId: String?
    let objectiveId: String?
    let action: String?

    enum CodingKeys: String, CodingKey {
        case questId = "quest_id"
        case objectiveId = "objective_id"
        case action
    }
}

struct JSONMiniGameChallengeForLoading: Codable {
    let enemyId: String?
    let difficulty: Int?
    let rewards: JSONChallengeConsequencesForLoading?
    let penalties: JSONChallengeConsequencesForLoading?

    enum CodingKeys: String, CodingKey {
        case enemyId = "enemy_id"
        case difficulty, rewards, penalties
    }
}

struct JSONChallengeConsequencesForLoading: Codable {
    let resourceChanges: [String: Int]?
    let setFlags: [String]?
    let balanceShift: Int?

    enum CodingKeys: String, CodingKey {
        case resourceChanges = "resource_changes"
        case setFlags = "set_flags"
        case balanceShift = "balance_shift"
    }

    func toConsequences() -> ChoiceConsequences {
        ChoiceConsequences(
            resourceChanges: resourceChanges ?? [:],
            setFlags: setFlags ?? [],
            clearFlags: [],
            balanceDelta: balanceShift ?? 0
        )
    }
}

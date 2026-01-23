import Foundation

// MARK: - Quest Definition
// Reference: Docs/ENGINE_ARCHITECTURE.md, Section 4.1
// Reference: Docs/EXPLORATION_CORE_DESIGN.md, Section 13

/// Immutable definition of a quest.
/// Runtime state (currentStage, completedObjectives) lives in QuestRuntimeState.
struct QuestDefinition: GameDefinition {
    // MARK: - Identity

    /// Unique quest identifier (e.g., "quest_main_act1")
    let id: String

    // MARK: - Localized Content

    /// Quest title with all language variants
    let title: LocalizedString

    /// Quest description with all language variants
    let description: LocalizedString

    // MARK: - Structure

    /// Ordered list of objectives (stages)
    let objectives: [ObjectiveDefinition]

    /// Quest kind classification
    let questKind: QuestKind

    // MARK: - Availability

    /// Conditions for this quest to become available
    let availability: Availability

    /// If true, quest starts automatically when available
    let autoStart: Bool

    // MARK: - Rewards

    /// Rewards given on quest completion
    let completionRewards: QuestCompletionRewards

    /// Penalties on quest failure
    let failurePenalties: QuestCompletionRewards

    // MARK: - Initialization

    init(
        id: String,
        title: LocalizedString,
        description: LocalizedString,
        objectives: [ObjectiveDefinition],
        questKind: QuestKind = .side,
        availability: Availability = .always,
        autoStart: Bool = false,
        completionRewards: QuestCompletionRewards = .none,
        failurePenalties: QuestCompletionRewards = .none
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.objectives = objectives
        self.questKind = questKind
        self.availability = availability
        self.autoStart = autoStart
        self.completionRewards = completionRewards
        self.failurePenalties = failurePenalties
    }
}

// MARK: - Quest Kind

/// Quest kind classification (Engine-specific, distinct from legacy QuestType)
enum QuestKind: String, Codable, Hashable {
    case main           // Main storyline
    case side           // Optional side quest
    case exploration    // Discovery/exploration quest
    case challenge      // Optional challenge quest
}

// MARK: - Objective Definition

/// Immutable definition of a quest objective (stage).
struct ObjectiveDefinition: Codable, Hashable, Identifiable {
    // MARK: - Identity

    /// Unique objective identifier within the quest
    let id: String

    // MARK: - Localized Content

    /// Objective description with all language variants
    let description: LocalizedString

    /// Objective hint with all language variants (optional)
    let hint: LocalizedString?

    // MARK: - Completion Conditions

    /// Condition type for completion
    let completionCondition: CompletionCondition

    /// Target value for progress-based objectives
    let targetValue: Int

    // MARK: - Flow Control

    /// If true, this objective is optional
    let isOptional: Bool

    /// Next objective ID (nil = quest complete)
    let nextObjectiveId: String?

    /// Alternative objective IDs (for branching)
    let alternativeNextIds: [String]

    // MARK: - Initialization

    init(
        id: String,
        description: LocalizedString,
        hint: LocalizedString? = nil,
        completionCondition: CompletionCondition,
        targetValue: Int = 1,
        isOptional: Bool = false,
        nextObjectiveId: String? = nil,
        alternativeNextIds: [String] = []
    ) {
        self.id = id
        self.description = description
        self.hint = hint
        self.completionCondition = completionCondition
        self.targetValue = targetValue
        self.isOptional = isOptional
        self.nextObjectiveId = nextObjectiveId
        self.alternativeNextIds = alternativeNextIds
    }
}

// MARK: - Completion Condition

/// How an objective is completed
enum CompletionCondition: Codable, Hashable {
    /// Complete when specific flag is set
    case flagSet(String)

    /// Complete when visiting specific region
    case visitRegion(String)

    /// Complete when specific event is resolved
    case eventCompleted(String)

    /// Complete when specific choice is made
    case choiceMade(eventId: String, choiceId: String)

    /// Complete when resource threshold reached
    case resourceThreshold(resourceId: String, minValue: Int)

    /// Complete when defeating specific enemy
    case defeatEnemy(String)

    /// Complete when collecting specific item
    case collectItem(String)

    /// Complete manually (via quest progress trigger)
    case manual

    // MARK: - Custom Codable

    /// Coding keys for JSON format: {"flag_set": "value"} or {"visit_region": "value"}
    private enum CodingKeys: String, CodingKey {
        case flagSet
        case visitRegion
        case eventCompleted
        case choiceMade
        case resourceThreshold
        case defeatEnemy
        case collectItem
        case manual
        // For choiceMade sub-keys
        case eventId
        case choiceId
        // For resourceThreshold sub-keys
        case resourceId
        case minValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Try each case - JSON format is {"key": "value"} or {"key": {...}}
        if let value = try container.decodeIfPresent(String.self, forKey: .flagSet) {
            self = .flagSet(value)
            return
        }

        if let value = try container.decodeIfPresent(String.self, forKey: .visitRegion) {
            self = .visitRegion(value)
            return
        }

        if let value = try container.decodeIfPresent(String.self, forKey: .eventCompleted) {
            self = .eventCompleted(value)
            return
        }

        if let value = try container.decodeIfPresent(String.self, forKey: .defeatEnemy) {
            self = .defeatEnemy(value)
            return
        }

        if let value = try container.decodeIfPresent(String.self, forKey: .collectItem) {
            self = .collectItem(value)
            return
        }

        if container.contains(.manual) {
            self = .manual
            return
        }

        // Try nested container for choiceMade: {"choice_made": {"event_id": "...", "choice_id": "..."}}
        if container.contains(.choiceMade) {
            let nested = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .choiceMade)
            let eventId = try nested.decode(String.self, forKey: .eventId)
            let choiceId = try nested.decode(String.self, forKey: .choiceId)
            self = .choiceMade(eventId: eventId, choiceId: choiceId)
            return
        }

        // Try nested container for resourceThreshold: {"resource_threshold": {"resource_id": "...", "min_value": 10}}
        if container.contains(.resourceThreshold) {
            let nested = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .resourceThreshold)
            let resourceId = try nested.decode(String.self, forKey: .resourceId)
            let minValue = try nested.decode(Int.self, forKey: .minValue)
            self = .resourceThreshold(resourceId: resourceId, minValue: minValue)
            return
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Unknown completion condition type"
            )
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .flagSet(let value):
            try container.encode(value, forKey: .flagSet)
        case .visitRegion(let value):
            try container.encode(value, forKey: .visitRegion)
        case .eventCompleted(let value):
            try container.encode(value, forKey: .eventCompleted)
        case .choiceMade(let eventId, let choiceId):
            var nested = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .choiceMade)
            try nested.encode(eventId, forKey: .eventId)
            try nested.encode(choiceId, forKey: .choiceId)
        case .resourceThreshold(let resourceId, let minValue):
            var nested = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .resourceThreshold)
            try nested.encode(resourceId, forKey: .resourceId)
            try nested.encode(minValue, forKey: .minValue)
        case .defeatEnemy(let value):
            try container.encode(value, forKey: .defeatEnemy)
        case .collectItem(let value):
            try container.encode(value, forKey: .collectItem)
        case .manual:
            try container.encode(true, forKey: .manual)
        }
    }
}

// MARK: - Quest Completion Rewards

/// Rewards/penalties for quest completion (Engine-specific, distinct from legacy QuestRewards)
struct QuestCompletionRewards: Codable, Hashable {
    /// Resource changes
    let resourceChanges: [String: Int]

    /// Flags to set
    let setFlags: [String]

    /// Cards to add to deck
    let cardIds: [String]

    /// Balance change
    let balanceDelta: Int

    init(
        resourceChanges: [String: Int] = [:],
        setFlags: [String] = [],
        cardIds: [String] = [],
        balanceDelta: Int = 0
    ) {
        self.resourceChanges = resourceChanges
        self.setFlags = setFlags
        self.cardIds = cardIds
        self.balanceDelta = balanceDelta
    }

    /// No rewards
    static let none = QuestCompletionRewards()
}

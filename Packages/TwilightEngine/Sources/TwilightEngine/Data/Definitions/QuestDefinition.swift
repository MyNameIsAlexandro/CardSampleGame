import Foundation

// MARK: - Quest Definition
// Reference: Docs/ENGINE_ARCHITECTURE.md, Section 4.1
// Reference: Docs/EXPLORATION_CORE_DESIGN.md, Section 13

/// Immutable definition of a quest.
/// Runtime state (currentStage, completedObjectives) lives in QuestRuntimeState.
public struct QuestDefinition: GameDefinition {
    // MARK: - Identity

    /// Unique quest identifier (e.g., "quest_main_act1")
    public var id: String

    // MARK: - Localized Content

    /// Quest title (supports inline LocalizedString or StringKey)
    public var title: LocalizableText

    /// Quest description (supports inline LocalizedString or StringKey)
    public var description: LocalizableText

    // MARK: - Structure

    /// Ordered list of objectives (stages)
    public var objectives: [ObjectiveDefinition]

    /// Quest kind classification
    public var questKind: QuestKind

    // MARK: - Availability

    /// Conditions for this quest to become available
    public var availability: Availability

    /// If true, quest starts automatically when available
    public var autoStart: Bool

    // MARK: - Rewards

    /// Rewards given on quest completion
    public var completionRewards: QuestCompletionRewards

    /// Penalties on quest failure
    public var failurePenalties: QuestCompletionRewards

    // MARK: - Initialization

    public init(
        id: String,
        title: LocalizableText,
        description: LocalizableText,
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
public enum QuestKind: String, Codable, Hashable {
    case main           // Main storyline
    case side           // Optional side quest
    case exploration    // Discovery/exploration quest
    case challenge      // Optional challenge quest
}

// MARK: - Objective Definition

/// Immutable definition of a quest objective (stage).
public struct ObjectiveDefinition: Codable, Hashable, Identifiable {
    // MARK: - Identity

    /// Unique objective identifier within the quest
    public var id: String

    // MARK: - Localized Content

    /// Objective description (supports inline LocalizedString or StringKey)
    public var description: LocalizableText

    /// Objective hint (supports inline LocalizedString or StringKey, optional)
    public var hint: LocalizableText?

    // MARK: - Completion Conditions

    /// Condition type for completion
    public var completionCondition: CompletionCondition

    /// Target value for progress-based objectives
    public var targetValue: Int

    // MARK: - Flow Control

    /// If true, this objective is optional
    public var isOptional: Bool

    /// Next objective ID (nil = quest complete)
    public var nextObjectiveId: String?

    /// Alternative objective IDs (for branching)
    public var alternativeNextIds: [String]

    // MARK: - Initialization

    public init(
        id: String,
        description: LocalizableText,
        hint: LocalizableText? = nil,
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
public enum CompletionCondition: Codable, Hashable {
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

    public init(from decoder: Decoder) throws {
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

    public func encode(to encoder: Encoder) throws {
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
public struct QuestCompletionRewards: Codable, Hashable {
    /// Resource changes
    public var resourceChanges: [String: Int]

    /// Flags to set
    public var setFlags: [String]

    /// Cards to add to deck
    public var cardIds: [String]

    /// Balance change
    public var balanceDelta: Int

    public init(
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
    public static let none = QuestCompletionRewards()
}

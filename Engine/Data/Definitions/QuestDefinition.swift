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

    // MARK: - Localization Keys

    /// Localization key for quest title
    let titleKey: String

    /// Localization key for quest description
    let descriptionKey: String

    // MARK: - Structure

    /// Ordered list of objectives (stages)
    let objectives: [ObjectiveDefinition]

    /// Quest type classification
    let questType: QuestType

    // MARK: - Availability

    /// Conditions for this quest to become available
    let availability: Availability

    /// If true, quest starts automatically when available
    let autoStart: Bool

    // MARK: - Rewards

    /// Rewards given on quest completion
    let completionRewards: QuestRewards

    /// Penalties on quest failure
    let failurePenalties: QuestRewards

    // MARK: - Initialization

    init(
        id: String,
        titleKey: String,
        descriptionKey: String,
        objectives: [ObjectiveDefinition],
        questType: QuestType = .side,
        availability: Availability = .always,
        autoStart: Bool = false,
        completionRewards: QuestRewards = .none,
        failurePenalties: QuestRewards = .none
    ) {
        self.id = id
        self.titleKey = titleKey
        self.descriptionKey = descriptionKey
        self.objectives = objectives
        self.questType = questType
        self.availability = availability
        self.autoStart = autoStart
        self.completionRewards = completionRewards
        self.failurePenalties = failurePenalties
    }
}

// MARK: - Quest Type

enum QuestType: String, Codable, Hashable {
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

    // MARK: - Localization Keys

    /// Localization key for objective description
    let descriptionKey: String

    /// Localization key for objective hint (optional)
    let hintKey: String?

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
        descriptionKey: String,
        hintKey: String? = nil,
        completionCondition: CompletionCondition,
        targetValue: Int = 1,
        isOptional: Bool = false,
        nextObjectiveId: String? = nil,
        alternativeNextIds: [String] = []
    ) {
        self.id = id
        self.descriptionKey = descriptionKey
        self.hintKey = hintKey
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
}

// MARK: - Quest Rewards

/// Rewards/penalties for quest completion
struct QuestRewards: Codable, Hashable {
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
    static let none = QuestRewards()
}

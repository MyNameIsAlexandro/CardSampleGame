import Foundation

// MARK: - Quest Trigger Engine
// Data-driven quest progression system
// Replaces hardcoded checkQuestObjectives* methods in WorldState

/// Engine for evaluating quest triggers and updating quest progress
/// All quest logic is data-driven from QuestDefinition/ObjectiveDefinition
public final class QuestTriggerEngine {

    // MARK: - Dependencies

    private let contentRegistry: ContentRegistry

    // MARK: - Initialization

    public init(contentRegistry: ContentRegistry = .shared) {
        self.contentRegistry = contentRegistry
    }

    // MARK: - Action Processing

    /// Process a game action and return quest progress updates
    /// Called after every action to check if any quest objectives are triggered
    public func processAction(
        _ action: QuestTriggerAction,
        context: QuestTriggerContext
    ) -> [QuestProgressUpdate] {
        var updates: [QuestProgressUpdate] = []

        // Get all active quests
        let activeQuests = context.activeQuests

        for questState in activeQuests {
            guard let questDef = contentRegistry.getQuest(id: questState.definitionId) else {
                continue
            }

            // Check current objective
            guard let currentObjectiveId = questState.currentObjectiveId,
                  let objectiveDef = questDef.objectives.first(where: { $0.id == currentObjectiveId }) else {
                continue
            }

            // Evaluate if objective is completed by this action
            if evaluateCondition(objectiveDef.completionCondition, action: action, context: context) {
                let update = QuestProgressUpdate(
                    questId: questDef.id,
                    objectiveId: currentObjectiveId,
                    type: .objectiveCompleted,
                    nextObjectiveId: objectiveDef.nextObjectiveId,
                    flagsToSet: extractFlagsToSet(from: objectiveDef, questDef: questDef)
                )
                updates.append(update)
            }
        }

        // Check for newly available quests
        let newQuestUpdates = checkForNewQuests(action: action, context: context)
        updates.append(contentsOf: newQuestUpdates)

        return updates
    }

    // MARK: - Condition Evaluation

    /// Evaluate a single completion condition against an action
    public func evaluateCondition(
        _ condition: CompletionCondition,
        action: QuestTriggerAction,
        context: QuestTriggerContext
    ) -> Bool {
        switch condition {
        case .flagSet(let flagName):
            return context.worldFlags[flagName] == true

        case .visitRegion(let regionId):
            if case .visitedRegion(let visitedId) = action {
                return visitedId == regionId
            }
            return false

        case .eventCompleted(let eventId):
            if case .completedEvent(let completedId, _) = action {
                return completedId == eventId
            }
            return false

        case .choiceMade(let eventId, let choiceId):
            if case .completedEvent(let completedEventId, let selectedChoiceId) = action {
                return completedEventId == eventId && selectedChoiceId == choiceId
            }
            return false

        case .resourceThreshold(let resourceId, let minValue):
            let currentValue = context.resources[resourceId] ?? 0
            return currentValue >= minValue

        case .defeatEnemy(let enemyId):
            if case .defeatedEnemy(let defeatedId) = action {
                return defeatedId == enemyId
            }
            return false

        case .collectItem(let itemId):
            if case .collectedItem(let collectedId) = action {
                return collectedId == itemId
            }
            return false

        case .manual:
            if case .manualProgress = action {
                // Manual triggers need explicit objective ID match
                return true
            }
            return false
        }
    }

    // MARK: - New Quest Availability

    /// Check if any new quests become available after this action
    private func checkForNewQuests(
        action: QuestTriggerAction,
        context: QuestTriggerContext
    ) -> [QuestProgressUpdate] {
        var updates: [QuestProgressUpdate] = []

        let allQuests = contentRegistry.getAllQuests()
        let activeQuestIds = Set(context.activeQuests.map { $0.definitionId })
        let completedQuestIds = context.completedQuestIds

        for questDef in allQuests {
            // Skip already active or completed quests
            if activeQuestIds.contains(questDef.id) || completedQuestIds.contains(questDef.id) {
                continue
            }

            // Check availability conditions
            if isQuestAvailable(questDef, context: context) {
                if questDef.autoStart {
                    let update = QuestProgressUpdate(
                        questId: questDef.id,
                        objectiveId: questDef.objectives.first?.id,
                        type: .questStarted,
                        nextObjectiveId: questDef.objectives.first?.id,
                        flagsToSet: []
                    )
                    updates.append(update)
                }
            }
        }

        return updates
    }

    /// Check if a quest's availability conditions are met
    private func isQuestAvailable(_ quest: QuestDefinition, context: QuestTriggerContext) -> Bool {
        return checkAvailability(quest.availability, context: context)
    }

    // MARK: - Flag Extraction

    /// Extract flags that should be set when objective completes
    private func extractFlagsToSet(
        from objective: ObjectiveDefinition,
        questDef: QuestDefinition
    ) -> [String] {
        var flags: [String] = []

        // Check if this is the final objective
        if objective.nextObjectiveId == nil && objective.alternativeNextIds.isEmpty {
            // Quest completion - add completion flags from rewards
            flags.append(contentsOf: questDef.completionRewards.setFlags)
        }

        return flags
    }
}

// MARK: - Quest Trigger Action

/// Actions that can trigger quest progression
public enum QuestTriggerAction {
    /// Player visited a region
    case visitedRegion(regionId: String)

    /// Player completed an event with a specific choice
    case completedEvent(eventId: String, choiceId: String)

    /// Player defeated an enemy
    case defeatedEnemy(enemyId: String)

    /// Player collected an item
    case collectedItem(itemId: String)

    /// Flag was set (can trigger flag-based conditions)
    case flagSet(flagName: String)

    /// Manual progress trigger (for special cases)
    case manualProgress(objectiveId: String)

    /// Resource changed (can trigger threshold conditions)
    case resourceChanged(resourceId: String, newValue: Int)
}

// MARK: - Quest Trigger Context

/// Context needed for evaluating quest triggers
public struct QuestTriggerContext {
    /// Currently active quests with their state
    public let activeQuests: [QuestState]

    /// IDs of completed quests
    public let completedQuestIds: Set<String>

    /// Current world flags
    public let worldFlags: [String: Bool]

    /// Current resources (health, faith, etc.)
    public let resources: [String: Int]

    /// Current game day
    public let currentDay: Int

    /// Current region ID
    public let currentRegionId: String
}

/// Minimal quest state for trigger evaluation
public struct QuestState {
    public let definitionId: String
    public let currentObjectiveId: String?
    public let completedObjectiveIds: Set<String>
}

// MARK: - Quest Progress Update

/// Result of quest trigger evaluation
public struct QuestProgressUpdate {
    /// Quest that was updated
    public let questId: String

    /// Objective that was completed (if any)
    public let objectiveId: String?

    /// Type of update
    public let type: QuestUpdateType

    /// Next objective to activate (if any)
    public let nextObjectiveId: String?

    /// Flags to set as a result of this update
    public let flagsToSet: [String]
}

/// Type of quest update
public enum QuestUpdateType {
    case questStarted
    case objectiveCompleted
    case questCompleted
    case questFailed
}

// MARK: - Availability Check

extension QuestTriggerEngine {
    /// Check if availability conditions are met
    public func checkAvailability(_ availability: Availability, context: QuestTriggerContext) -> Bool {
        // Check required flags
        for flag in availability.requiredFlags {
            if context.worldFlags[flag] != true {
                return false
            }
        }

        // Check forbidden flags
        for flag in availability.forbiddenFlags {
            if context.worldFlags[flag] == true {
                return false
            }
        }

        // Check pressure/tension range
        if let minPressure = availability.minPressure {
            let tension = context.resources["tension"] ?? 0
            if tension < minPressure {
                return false
            }
        }
        if let maxPressure = availability.maxPressure {
            let tension = context.resources["tension"] ?? 0
            if tension > maxPressure {
                return false
            }
        }

        return true
    }
}

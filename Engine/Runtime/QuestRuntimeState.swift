import Foundation

// MARK: - Quest Runtime State
// Reference: Docs/ENGINE_ARCHITECTURE.md, Section 4.2
// Reference: Docs/MIGRATION_PLAN.md, Feature A2

/// Mutable runtime state for the quest system.
/// Tracks quest progress, completion, etc.
struct QuestRuntimeState: Codable, Equatable {
    // MARK: - Quest Tracking

    /// State of each quest (keyed by quest definition ID)
    var questStates: [String: SingleQuestState]

    // MARK: - Initialization

    init(questStates: [String: SingleQuestState] = [:]) {
        self.questStates = questStates
    }

    // MARK: - Quest Operations

    /// Get state for a specific quest
    func getQuestState(_ questId: String) -> SingleQuestState? {
        return questStates[questId]
    }

    /// Start a new quest
    mutating func startQuest(_ questId: String, firstObjectiveId: String) {
        questStates[questId] = SingleQuestState(
            definitionId: questId,
            status: .active,
            currentObjectiveId: firstObjectiveId
        )
    }

    /// Update quest state
    mutating func updateQuest(_ questId: String, update: (inout SingleQuestState) -> Void) {
        if var state = questStates[questId] {
            update(&state)
            questStates[questId] = state
        }
    }

    /// Get all active quests
    var activeQuests: [SingleQuestState] {
        return questStates.values.filter { $0.status == .active }
    }

    /// Get all completed quests
    var completedQuests: [SingleQuestState] {
        return questStates.values.filter { $0.status == .completed }
    }
}

// MARK: - Single Quest State

/// Runtime state of a single quest.
struct SingleQuestState: Codable, Equatable {
    /// Reference to quest definition
    let definitionId: String

    /// Current quest status
    var status: QuestStatus

    /// Current objective ID (nil if completed or failed)
    var currentObjectiveId: String?

    /// Completed objective IDs
    var completedObjectiveIds: Set<String>

    /// Failed objective IDs
    var failedObjectiveIds: Set<String>

    /// Quest-specific flags
    var flags: [String: Bool]

    /// Progress values for objectives (e.g., "kill_count": 3)
    var progressValues: [String: Int]

    init(
        definitionId: String,
        status: QuestStatus = .locked,
        currentObjectiveId: String? = nil,
        completedObjectiveIds: Set<String> = [],
        failedObjectiveIds: Set<String> = [],
        flags: [String: Bool] = [:],
        progressValues: [String: Int] = [:]
    ) {
        self.definitionId = definitionId
        self.status = status
        self.currentObjectiveId = currentObjectiveId
        self.completedObjectiveIds = completedObjectiveIds
        self.failedObjectiveIds = failedObjectiveIds
        self.flags = flags
        self.progressValues = progressValues
    }

    // MARK: - Objective Operations

    /// Complete current objective and move to next
    mutating func completeCurrentObjective(nextObjectiveId: String?) {
        if let currentId = currentObjectiveId {
            completedObjectiveIds.insert(currentId)
        }
        currentObjectiveId = nextObjectiveId

        // If no next objective, quest is complete
        if nextObjectiveId == nil {
            status = .completed
        }
    }

    /// Fail current objective
    mutating func failCurrentObjective() {
        if let currentId = currentObjectiveId {
            failedObjectiveIds.insert(currentId)
        }
        status = .failed
        currentObjectiveId = nil
    }

    /// Increment progress for a key
    mutating func incrementProgress(_ key: String, by amount: Int = 1) {
        progressValues[key, default: 0] += amount
    }

    /// Check progress against target
    func checkProgress(_ key: String, target: Int) -> Bool {
        return (progressValues[key] ?? 0) >= target
    }
}

// MARK: - Quest Status

/// Possible statuses for a quest
enum QuestStatus: String, Codable, Hashable {
    /// Quest not yet available/visible
    case locked

    /// Quest available but not started
    case available

    /// Quest in progress
    case active

    /// Quest successfully completed
    case completed

    /// Quest failed
    case failed
}

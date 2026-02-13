/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Quest/QuestTriggerModels.swift
/// Назначение: Содержит реализацию файла QuestTriggerModels.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Quest Trigger Action

/// Actions that can trigger quest progression.
public enum QuestTriggerAction: Sendable {
    /// Player visited a region.
    case visitedRegion(regionId: String)

    /// Player completed an event with a specific choice.
    case completedEvent(eventId: String, choiceId: String)

    /// Player defeated an enemy.
    case defeatedEnemy(enemyId: String)

    /// Player collected an item.
    case collectedItem(itemId: String)

    /// Flag was set (can trigger flag-based conditions).
    case flagSet(flagName: String)

    /// Manual progress trigger (for special cases).
    case manualProgress(objectiveId: String)

    /// Resource changed (can trigger threshold conditions).
    case resourceChanged(resourceId: String, newValue: Int)
}

// MARK: - Quest Trigger Context

/// Context needed for evaluating quest triggers.
public struct QuestTriggerContext: Sendable {
    /// Currently active quests with their state.
    public let activeQuests: [QuestState]

    /// IDs of completed quests.
    public let completedQuestIds: Set<String>

    /// Current world flags.
    public let worldFlags: [String: Bool]

    /// Current resources (health, faith, etc.).
    public let resources: [String: Int]

    /// Current game day.
    public let currentDay: Int

    /// Current region ID.
    public let currentRegionId: String
}

/// Minimal quest state for trigger evaluation.
public struct QuestState: Sendable {
    public let definitionId: String
    public let currentObjectiveId: String?
    public let completedObjectiveIds: Set<String>
}

// MARK: - Quest Progress Update

/// Result of quest trigger evaluation.
public struct QuestProgressUpdate: Sendable {
    /// Quest that was updated.
    public let questId: String

    /// Objective that was completed (if any).
    public let objectiveId: String?

    /// Type of update.
    public let type: QuestUpdateType

    /// Next objective to activate (if any).
    public let nextObjectiveId: String?

    /// Flags to set as a result of this update.
    public let flagsToSet: [String]
}

/// Type of quest update.
public enum QuestUpdateType: Sendable {
    case questStarted
    case objectiveCompleted
    case questCompleted
    case questFailed
}

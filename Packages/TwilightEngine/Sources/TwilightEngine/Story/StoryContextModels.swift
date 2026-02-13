/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Story/StoryContextModels.swift
/// Назначение: Содержит реализацию файла StoryContextModels.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Story Context

/// All context needed for story decisions.
public struct StoryContext: Sendable {
    // World State
    let currentRegionId: String
    let regionStates: [String: RegionStateType]
    let worldTension: Int
    let currentDay: Int

    // Player State
    let playerHealth: Int
    let playerFaith: Int
    let playerBalance: Int

    // Quest State
    let activeQuestIds: Set<String>
    let completedQuestIds: Set<String>
    let questObjectiveStates: [String: Set<String>]  // questId -> completed objective IDs

    // Flags & History
    let worldFlags: [String: Bool]
    let completedEventIds: Set<String>
    let visitedRegionIds: Set<String>

    // Campaign Info
    let campaignId: String
    let actNumber: Int
}

// MARK: - Story Action

/// Actions that affect story progression.
public enum StoryAction: Sendable {
    case visitedRegion(regionId: String)
    case completedEvent(eventId: String, choiceId: String)
    case defeatedEnemy(enemyId: String)
    case dayPassed(newDay: Int)
    case tensionChanged(newTension: Int)
    case flagSet(flagName: String, value: Bool)
    case anchorChanged(regionId: String, newIntegrity: Int)
}

// MARK: - Story Update

/// Result of story processing.
public struct StoryUpdate: Sendable {
    /// Quest progress updates.
    let questUpdates: [QuestProgressUpdate]

    /// Newly unlocked events.
    let unlockedEvents: [String]

    /// Events that became unavailable.
    let lockedEvents: [String]

    /// World flags to set.
    let flagsToSet: [String: Bool]

    /// Narrative messages to display.
    let narrativeMessages: [LocalizedString]

    /// If set, game has ended.
    let gameEnding: GameEnding?

    public static let none = StoryUpdate(
        questUpdates: [],
        unlockedEvents: [],
        lockedEvents: [],
        flagsToSet: [:],
        narrativeMessages: [],
        gameEnding: nil
    )
}

// MARK: - Game Ending

/// How the game ended.
public enum GameEnding: Sendable {
    case victory(endingId: String, description: LocalizedString)
    case defeat(reason: DefeatReason, description: LocalizedString)
}

public enum DefeatReason: Sendable {
    case healthZero
    case tensionMax
    case questFailed
    case anchorDestroyed
}

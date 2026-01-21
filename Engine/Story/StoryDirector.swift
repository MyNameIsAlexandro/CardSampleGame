import Foundation

// MARK: - Story Director Protocol
// Dynamic event composition and quest management system
// Makes each game session unique and the world feel alive

/// Protocol for story management - selects events, manages quest flow
/// Different campaigns can have different Director implementations
protocol StoryDirector {

    // MARK: - Event Selection

    /// Select the next event for a region based on current context
    /// Returns nil if no suitable events are available
    func selectEvent(
        forRegion regionId: String,
        context: StoryContext,
        using rng: inout WorldRNG
    ) -> EventDefinition?

    /// Get all events available in current context (for debugging/testing)
    func getAvailableEvents(context: StoryContext) -> [EventDefinition]

    // MARK: - Action Processing

    /// Process a completed action and return story updates
    /// This is called after every game action to update quests, unlock events, etc.
    func processAction(
        _ action: StoryAction,
        context: StoryContext
    ) -> StoryUpdate

    // MARK: - Quest Management

    /// Get currently active quests
    func getActiveQuests(context: StoryContext) -> [QuestDefinition]

    /// Check if victory conditions are met
    func checkVictoryConditions(context: StoryContext) -> VictoryCheck

    /// Check if defeat conditions are met
    func checkDefeatConditions(context: StoryContext) -> DefeatCheck
}

// MARK: - Story Context

/// All context needed for story decisions
struct StoryContext {
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

/// Actions that affect story progression
enum StoryAction {
    case visitedRegion(regionId: String)
    case completedEvent(eventId: String, choiceId: String)
    case defeatedEnemy(enemyId: String)
    case dayPassed(newDay: Int)
    case tensionChanged(newTension: Int)
    case flagSet(flagName: String, value: Bool)
    case anchorChanged(regionId: String, newIntegrity: Int)
}

// MARK: - Story Update

/// Result of story processing - what changed
struct StoryUpdate {
    /// Quest progress updates
    let questUpdates: [QuestProgressUpdate]

    /// Newly unlocked events
    let unlockedEvents: [String]

    /// Events that became unavailable
    let lockedEvents: [String]

    /// World flags to set
    let flagsToSet: [String: Bool]

    /// Narrative messages to display
    let narrativeMessages: [LocalizedString]

    /// If set, game has ended
    let gameEnding: GameEnding?

    static let none = StoryUpdate(
        questUpdates: [],
        unlockedEvents: [],
        lockedEvents: [],
        flagsToSet: [:],
        narrativeMessages: [],
        gameEnding: nil
    )
}

// MARK: - Game Ending

/// How the game ended
enum GameEnding {
    case victory(endingId: String, description: LocalizedString)
    case defeat(reason: DefeatReason, description: LocalizedString)
}

enum DefeatReason {
    case healthZero
    case tensionMax
    case questFailed
    case anchorDestroyed
}

// MARK: - Victory/Defeat Checks

struct VictoryCheck {
    let isVictory: Bool
    let endingId: String?
    let description: LocalizedString?
}

struct DefeatCheck {
    let isDefeat: Bool
    let reason: DefeatReason?
    let description: LocalizedString?
}

// MARK: - Event Pool

/// Pool of events for a specific context
struct EventPool {
    let id: String
    let events: [EventDefinition]
    let selectionStrategy: EventSelectionStrategy
}

enum EventSelectionStrategy {
    case weighted      // Use event weights
    case sequential    // In order (for story events)
    case random        // Pure random
    case priority      // Highest priority first
}

// MARK: - Default Implementation

/// Base implementation with common logic
class BaseStoryDirector: StoryDirector {

    let contentRegistry: ContentRegistry
    let questTriggerEngine: QuestTriggerEngine

    init(contentRegistry: ContentRegistry = .shared) {
        self.contentRegistry = contentRegistry
        self.questTriggerEngine = QuestTriggerEngine(contentRegistry: contentRegistry)
    }

    // MARK: - Event Selection

    func selectEvent(
        forRegion regionId: String,
        context: StoryContext,
        using rng: inout WorldRNG
    ) -> EventDefinition? {
        let available = getAvailableEvents(context: context)
            .filter { event in
                // Filter by region
                if let regionIds = event.availability.regionIds, !regionIds.isEmpty {
                    return regionIds.contains(regionId)
                }
                return true
            }

        guard !available.isEmpty else { return nil }

        // Weighted random selection
        let totalWeight = available.reduce(0) { $0 + $1.weight }
        var roll = rng.nextInt(in: 1...totalWeight)

        for event in available {
            roll -= event.weight
            if roll <= 0 {
                return event
            }
        }

        return available.last
    }

    func getAvailableEvents(context: StoryContext) -> [EventDefinition] {
        return contentRegistry.getAllEvents().filter { event in
            isEventAvailable(event, context: context)
        }
    }

    /// Check if an event is available in current context
    func isEventAvailable(_ event: EventDefinition, context: StoryContext) -> Bool {
        // Check one-time events
        if event.isOneTime && context.completedEventIds.contains(event.id) {
            return false
        }

        // Check required flags
        for flag in event.availability.requiredFlags {
            if context.worldFlags[flag] != true {
                return false
            }
        }

        // Check forbidden flags
        for flag in event.availability.forbiddenFlags {
            if context.worldFlags[flag] == true {
                return false
            }
        }

        // Check tension range
        if let minPressure = event.availability.minPressure {
            if context.worldTension < minPressure {
                return false
            }
        }
        if let maxPressure = event.availability.maxPressure {
            if context.worldTension > maxPressure {
                return false
            }
        }

        // Check region states
        if let regionStates = event.availability.regionStates, !regionStates.isEmpty {
            let currentState = context.regionStates[context.currentRegionId]?.rawValue ?? "stable"
            if !regionStates.contains(currentState) {
                return false
            }
        }

        return true
    }

    // MARK: - Action Processing

    func processAction(_ action: StoryAction, context: StoryContext) -> StoryUpdate {
        // Convert to QuestTriggerAction
        let triggerAction = convertToTriggerAction(action)

        // Build trigger context
        let triggerContext = buildTriggerContext(from: context)

        // Process through quest trigger engine
        let questUpdates = questTriggerEngine.processAction(triggerAction, context: triggerContext)

        // Collect flags to set
        var flagsToSet: [String: Bool] = [:]
        for update in questUpdates {
            for flag in update.flagsToSet {
                flagsToSet[flag] = true
            }
        }

        // Check for game ending
        let victoryCheck = checkVictoryConditions(context: context)
        let defeatCheck = checkDefeatConditions(context: context)

        var gameEnding: GameEnding? = nil
        if victoryCheck.isVictory {
            gameEnding = .victory(
                endingId: victoryCheck.endingId ?? "default",
                description: victoryCheck.description ?? LocalizedString(en: "Victory!", ru: "Победа!")
            )
        } else if defeatCheck.isDefeat {
            gameEnding = .defeat(
                reason: defeatCheck.reason ?? .healthZero,
                description: defeatCheck.description ?? LocalizedString(en: "Defeat", ru: "Поражение")
            )
        }

        return StoryUpdate(
            questUpdates: questUpdates,
            unlockedEvents: [],
            lockedEvents: [],
            flagsToSet: flagsToSet,
            narrativeMessages: [],
            gameEnding: gameEnding
        )
    }

    // MARK: - Quest Management

    func getActiveQuests(context: StoryContext) -> [QuestDefinition] {
        return context.activeQuestIds.compactMap { contentRegistry.getQuest(id: $0) }
    }

    func checkVictoryConditions(context: StoryContext) -> VictoryCheck {
        // Default: check for act completion flag
        let actCompletedFlag = "act\(context.actNumber)_completed"
        if context.worldFlags[actCompletedFlag] == true {
            return VictoryCheck(
                isVictory: true,
                endingId: "act\(context.actNumber)_standard",
                description: LocalizedString(
                    en: "Act \(context.actNumber) completed!",
                    ru: "Акт \(context.actNumber) завершён!"
                )
            )
        }
        return VictoryCheck(isVictory: false, endingId: nil, description: nil)
    }

    func checkDefeatConditions(context: StoryContext) -> DefeatCheck {
        // Check health
        if context.playerHealth <= 0 {
            return DefeatCheck(
                isDefeat: true,
                reason: .healthZero,
                description: LocalizedString(en: "You have fallen...", ru: "Вы пали...")
            )
        }

        // Check tension
        if context.worldTension >= 100 {
            return DefeatCheck(
                isDefeat: true,
                reason: .tensionMax,
                description: LocalizedString(
                    en: "The darkness has consumed the world...",
                    ru: "Тьма поглотила мир..."
                )
            )
        }

        return DefeatCheck(isDefeat: false, reason: nil, description: nil)
    }

    // MARK: - Helpers

    private func convertToTriggerAction(_ action: StoryAction) -> QuestTriggerAction {
        switch action {
        case .visitedRegion(let regionId):
            return .visitedRegion(regionId: regionId)
        case .completedEvent(let eventId, let choiceId):
            return .completedEvent(eventId: eventId, choiceId: choiceId)
        case .defeatedEnemy(let enemyId):
            return .defeatedEnemy(enemyId: enemyId)
        case .flagSet(let flagName, _):
            return .flagSet(flagName: flagName)
        case .dayPassed, .tensionChanged, .anchorChanged:
            // These don't directly trigger quest objectives
            return .resourceChanged(resourceId: "day", newValue: 0)
        }
    }

    private func buildTriggerContext(from context: StoryContext) -> QuestTriggerContext {
        let activeQuests = context.activeQuestIds.compactMap { questId -> QuestState? in
            guard let quest = contentRegistry.getQuest(id: questId) else { return nil }
            let completedIds = context.questObjectiveStates[questId] ?? []
            let currentObjectiveId = quest.objectives.first { !completedIds.contains($0.id) }?.id
            return QuestState(
                definitionId: questId,
                currentObjectiveId: currentObjectiveId,
                completedObjectiveIds: completedIds
            )
        }

        return QuestTriggerContext(
            activeQuests: activeQuests,
            completedQuestIds: context.completedQuestIds,
            worldFlags: context.worldFlags,
            resources: [
                "health": context.playerHealth,
                "faith": context.playerFaith,
                "balance": context.playerBalance,
                "tension": context.worldTension
            ],
            currentDay: context.currentDay,
            currentRegionId: context.currentRegionId
        )
    }
}

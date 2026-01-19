import Foundation
import Combine

// MARK: - Engine Adapters
// Bridge between new Engine and legacy Models during migration
// NOTE: These adapters are still required for save/load compatibility
// They can be removed once EngineSave replaces GameSave completely

// MARK: - WorldState Engine Adapter

/// Bridges TwilightGameEngine with legacy WorldState
/// Provides bidirectional sync during migration period
final class WorldStateEngineAdapter {
    // MARK: - Properties

    let worldState: WorldState
    private weak var engine: TwilightGameEngine?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(worldState: WorldState, engine: TwilightGameEngine) {
        self.worldState = worldState
        self.engine = engine

        // Note: We don't set up automatic sync here because
        // during Phase 3, all changes should go through Engine
        // Legacy sync is one-way: Engine -> WorldState
    }

    // MARK: - Apply Engine Changes to Legacy

    /// Apply state changes from engine to legacy WorldState
    func applyChanges(_ changes: [StateChange]) {
        for change in changes {
            applyChange(change)
        }
    }

    private func applyChange(_ change: StateChange) {
        switch change {
        case .dayAdvanced(let newDay):
            worldState.daysPassed = newDay

        case .tensionChanged(_, let newValue):
            worldState.worldTension = newValue

        case .regionChanged(let regionId):
            worldState.currentRegionId = regionId

        case .regionStateChanged(let regionId, let newState):
            if let index = worldState.regions.firstIndex(where: { $0.id == regionId }),
               let state = RegionState(rawValue: newState) {
                worldState.regions[index].state = state
            }

        case .anchorIntegrityChanged(let anchorId, _, let newValue):
            // Find region with this anchor and update
            for (index, region) in worldState.regions.enumerated() {
                if region.anchor?.id == anchorId {
                    worldState.regions[index].anchor?.integrity = newValue
                    break
                }
            }

        case .flagSet(let key, let value):
            worldState.worldFlags[key] = value

        case .eventCompleted(let eventId):
            // Mark event as completed in allEvents
            if let index = worldState.allEvents.firstIndex(where: { $0.id == eventId }) {
                worldState.allEvents[index].completed = true
            }

        case .questProgressed(let questId, let newStage):
            // Update quest stage in WorldState's activeQuests
            // questId is String, Quest.id is UUID - convert for comparison
            if let index = worldState.activeQuests.firstIndex(where: { $0.id.uuidString == questId }) {
                worldState.activeQuests[index].stage = newStage
            }

        default:
            // Other changes handled elsewhere or not applicable to WorldState
            break
        }
    }

    // MARK: - Query WorldState for Engine

    /// Get event consequences for a choice
    func getEventConsequences(eventId: UUID, choiceIndex: Int) -> EventConsequences? {
        // Find the event in current available events
        guard let region = worldState.getCurrentRegion() else { return nil }

        let events = worldState.getAvailableEvents(for: region)
        guard let event = events.first(where: { $0.id == eventId }),
              choiceIndex < event.choices.count else {
            return nil
        }

        return event.choices[choiceIndex].consequences
    }

    /// Generate event for region
    func generateEvent(for regionId: UUID, trigger: EventTrigger) -> UUID? {
        guard let region = worldState.getRegion(byId: regionId) else { return nil }

        let events = worldState.getAvailableEvents(for: region)

        // Weight-based selection using WorldRNG
        guard !events.isEmpty else { return nil }

        // Select event using weights
        let totalWeight = events.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return events.first?.id }

        let roll = WorldRNG.shared.nextInt(in: 0..<totalWeight)
        var cumulative = 0
        for event in events {
            cumulative += event.weight
            if roll < cumulative {
                return event.id
            }
        }

        return events.first?.id
    }

    /// Check quest progress and return changes
    func checkQuestProgress() -> [StateChange] {
        var changes: [StateChange] = []

        // Delegate to WorldState's quest checking
        // This is a simplified version - full implementation would check all triggers
        for quest in worldState.activeQuests where !quest.completed {
            let previousStage = quest.stage
            worldState.checkQuestProgress(quest)

            if let updatedQuest = worldState.activeQuests.first(where: { $0.id == quest.id }),
               updatedQuest.stage != previousStage {
                changes.append(.questProgressed(questId: quest.id.uuidString, newStage: updatedQuest.stage))
            }
        }

        return changes
    }
}

// MARK: - Player Engine Adapter

/// Bridges TwilightGameEngine with legacy Player model
final class PlayerEngineAdapter {
    // MARK: - Properties

    let player: Player
    private weak var engine: TwilightGameEngine?

    // MARK: - Initialization

    init(player: Player, engine: TwilightGameEngine) {
        self.player = player
        self.engine = engine
    }

    // MARK: - Update Methods

    func updateHealth(_ newValue: Int) {
        player.health = newValue
    }

    func updateFaith(_ newValue: Int) {
        player.faith = newValue
    }

    func updateBalance(_ newValue: Int) {
        player.balance = newValue
    }

    func updateStrength(_ newValue: Int) {
        player.strength = newValue
    }

    // MARK: - Sync Methods

    /// Sync player state from engine resources
    func syncFromEngine() {
        // During migration, engine state is authoritative
        // Player model is updated to match
    }

    /// Sync engine resources from player
    func syncToEngine() {
        // This would push player state to engine
        // Used during initial setup
    }
}

// MARK: - Unused Adapters Removed
// GameStateEngineAdapter and EngineMigrationHelper were removed as part of Phase 4 cleanup.
// ContentView now uses Engine-First architecture directly.

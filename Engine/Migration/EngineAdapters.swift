import Foundation
import Combine

// MARK: - Engine Adapters
// Bridge between new Engine and legacy Models during migration
// These will be removed once full migration is complete

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
            worldState.completedEventIds.insert(eventId)

        case .questProgressed(let questId, let newStage):
            // Update quest stage in WorldState
            if let index = worldState.quests.firstIndex(where: { $0.id == questId }) {
                worldState.quests[index].currentStage = newStage
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

        let selectedEvent = worldState.selectWeightedEvent(from: events)
        return selectedEvent?.id
    }

    /// Check quest progress and return changes
    func checkQuestProgress() -> [StateChange] {
        var changes: [StateChange] = []

        // Delegate to WorldState's quest checking
        // This is a simplified version - full implementation would check all triggers
        for quest in worldState.quests where quest.state == .active {
            let previousStage = quest.currentStage
            worldState.checkQuestProgress(for: quest.id)

            if let updatedQuest = worldState.quests.first(where: { $0.id == quest.id }),
               updatedQuest.currentStage != previousStage {
                changes.append(.questProgressed(questId: quest.id, newStage: updatedQuest.currentStage))
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

// MARK: - GameState Engine Adapter

/// Bridges TwilightGameEngine with legacy GameState
final class GameStateEngineAdapter: ObservableObject {
    // MARK: - Properties

    let gameState: GameState
    let engine: TwilightGameEngine

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published (for UI binding during transition)

    @Published var isProcessingAction: Bool = false

    // MARK: - Initialization

    init(gameState: GameState) {
        self.gameState = gameState
        self.engine = TwilightGameEngine()

        // Connect engine to legacy models
        engine.connectToLegacy(
            worldState: gameState.worldState,
            player: gameState.players.first ?? Player(name: "Default")
        )

        setupBindings()
    }

    private func setupBindings() {
        // Forward engine game over state to legacy
        engine.$isGameOver
            .sink { [weak self] isOver in
                self?.gameState.isGameOver = isOver
            }
            .store(in: &cancellables)

        engine.$gameResult
            .compactMap { $0 }
            .sink { [weak self] result in
                switch result {
                case .victory:
                    self?.gameState.isVictory = true
                case .defeat:
                    self?.gameState.isDefeat = true
                case .abandoned:
                    break
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Action Forwarding

    /// Perform action through engine (recommended way)
    @MainActor
    func performAction(_ action: TwilightGameAction) async -> ActionResult {
        isProcessingAction = true
        defer { isProcessingAction = false }

        let result = engine.performAction(action)

        // Handle UI updates based on result
        await handleActionResult(result)

        return result
    }

    /// Synchronous version for simple actions
    @discardableResult
    func performActionSync(_ action: TwilightGameAction) -> ActionResult {
        isProcessingAction = true
        defer { isProcessingAction = false }

        return engine.performAction(action)
    }

    private func handleActionResult(_ result: ActionResult) async {
        // UI-specific handling
        if result.combatStarted {
            // Prepare combat UI
        }

        if let eventId = result.currentEvent {
            // Show event UI
        }

        if let gameEnd = result.gameEnded {
            // Show game over UI
        }
    }

    // MARK: - Legacy Action Translation

    /// Translate legacy action calls to engine actions
    /// Used during migration to intercept old-style calls

    func travel(to regionId: UUID) -> ActionResult {
        return performActionSync(.travel(toRegionId: regionId))
    }

    func rest() -> ActionResult {
        return performActionSync(.rest)
    }

    func explore() -> ActionResult {
        return performActionSync(.explore)
    }

    func strengthenAnchor() -> ActionResult {
        return performActionSync(.strengthenAnchor)
    }

    func chooseEventOption(eventId: UUID, choiceIndex: Int) -> ActionResult {
        return performActionSync(.chooseEventOption(eventId: eventId, choiceIndex: choiceIndex))
    }
}

// MARK: - Migration Helper

/// Helper to gradually migrate UI from direct WorldState access to Engine
struct EngineMigrationHelper {
    /// Check if engine is being used (for feature flags)
    static var useEngine: Bool {
        // Set to true to enable engine-based actions
        // During migration, this can be toggled for testing
        return true
    }

    /// Log migration warnings for direct state mutations
    static func warnDirectMutation(method: String, file: String = #file, line: Int = #line) {
        #if DEBUG
        print("⚠️ MIGRATION WARNING: Direct state mutation '\(method)' at \(file):\(line)")
        print("   → Use Engine.performAction() instead")
        #endif
    }
}

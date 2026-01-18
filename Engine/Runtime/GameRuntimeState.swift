import Foundation

// MARK: - Game Runtime State
// Reference: Docs/ENGINE_ARCHITECTURE.md, Section 4.2
// Reference: Docs/MIGRATION_PLAN.md, Feature A2

/// Combined runtime state for the entire game.
/// This is the single source of truth for game state.
/// All changes go through GameEngine.performAction().
struct GameRuntimeState: Codable, Equatable {
    // MARK: - Component States

    /// World state (regions, anchors, flags, pressure, time)
    var world: WorldRuntimeState

    /// Player state (resources, deck, balance, curses)
    var player: PlayerRuntimeState

    /// Event state (completion tracking, cooldowns)
    var events: EventRuntimeState

    /// Quest state (progress, completion)
    var quests: QuestRuntimeState

    // MARK: - Game Meta

    /// Current game phase
    var phase: EngineGamePhase

    /// Random seed for this playthrough
    let playthroughSeed: UInt64

    /// Save slot identifier
    var saveSlot: Int?

    // MARK: - Initialization

    init(
        world: WorldRuntimeState,
        player: PlayerRuntimeState,
        events: EventRuntimeState = EventRuntimeState(),
        quests: QuestRuntimeState = QuestRuntimeState(),
        phase: EngineGamePhase = .playing,
        playthroughSeed: UInt64 = 0,
        saveSlot: Int? = nil
    ) {
        self.world = world
        self.player = player
        self.events = events
        self.quests = quests
        self.phase = phase
        self.playthroughSeed = playthroughSeed
        self.saveSlot = saveSlot
    }

    // MARK: - Convenience Accessors

    /// Current region ID
    var currentRegionId: String {
        return world.currentRegionId
    }

    /// Current time (days)
    var currentTime: Int {
        return world.currentTime
    }

    /// Current pressure
    var currentPressure: Int {
        return world.pressure
    }

    /// Check game over conditions
    var isGameOver: Bool {
        // Pressure maximum
        if world.isPressureMaximum {
            return true
        }
        // Player death (health <= 0)
        if player.getResource("health") <= 0 {
            return true
        }
        return false
    }

    /// Get combined flags (world + player)
    func getAllFlags() -> Set<String> {
        var allFlags = Set<String>()
        for (key, value) in world.flags where value {
            allFlags.insert(key)
        }
        for (key, value) in player.flags where value {
            allFlags.insert(key)
        }
        return allFlags
    }
}

// MARK: - Factory Methods

extension GameRuntimeState {
    /// Create a new game state with default values
    static func newGame(
        startingRegionId: String,
        startingResources: [String: Int],
        startingDeck: [String],
        seed: UInt64? = nil
    ) -> GameRuntimeState {
        let actualSeed = seed ?? UInt64.random(in: 0...UInt64.max)

        let world = WorldRuntimeState(
            currentRegionId: startingRegionId,
            currentTime: 0,
            pressure: 0
        )

        let player = PlayerRuntimeState(
            resources: startingResources,
            balance: 0,
            drawPile: startingDeck
        )

        return GameRuntimeState(
            world: world,
            player: player,
            playthroughSeed: actualSeed
        )
    }
}

// MARK: - Snapshot for Regression Testing

extension GameRuntimeState {
    /// Create a snapshot for comparison
    struct Snapshot: Equatable {
        let pressure: Int
        let time: Int
        let health: Int
        let faith: Int
        let balance: Int
        let currentRegionId: String
        let visitedRegionsCount: Int
        let completedEventsCount: Int
        let activeQuestsCount: Int
        let deckSize: Int
        let flagCount: Int
    }

    /// Generate snapshot for testing
    func snapshot() -> Snapshot {
        let visitedCount = world.regionsState.values.filter { $0.visitCount > 0 }.count

        return Snapshot(
            pressure: world.pressure,
            time: world.currentTime,
            health: player.getResource("health"),
            faith: player.getResource("faith"),
            balance: player.balance,
            currentRegionId: world.currentRegionId,
            visitedRegionsCount: visitedCount,
            completedEventsCount: events.completedOneTimeEvents.count,
            activeQuestsCount: quests.activeQuests.count,
            deckSize: player.totalCardCount,
            flagCount: getAllFlags().count
        )
    }
}

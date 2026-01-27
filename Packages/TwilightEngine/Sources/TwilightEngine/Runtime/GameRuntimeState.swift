import Foundation

// MARK: - Game Runtime State
// Reference: Docs/ENGINE_ARCHITECTURE.md, Section 4.2
// Reference: Docs/MIGRATION_PLAN.md, Feature A2

/// Combined runtime state for the entire game.
/// This is the single source of truth for game state.
/// All changes go through GameEngine.performAction().
public struct GameRuntimeState: Codable, Equatable {
    // MARK: - Component States

    /// World state (regions, anchors, flags, pressure, time)
    public var world: WorldRuntimeState

    /// Player state (resources, deck, balance, curses)
    public var player: PlayerRuntimeState

    /// Event state (completion tracking, cooldowns)
    public var events: EventRuntimeState

    /// Quest state (progress, completion)
    public var quests: QuestRuntimeState

    // MARK: - Game Meta

    /// Current game phase
    public var phase: EngineGamePhase

    /// Random seed for this playthrough
    public let playthroughSeed: UInt64

    /// Save slot identifier
    public var saveSlot: Int?

    // MARK: - Initialization

    public init(
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
    public var currentRegionId: String {
        return world.currentRegionId
    }

    /// Current time (days)
    public var currentTime: Int {
        return world.currentTime
    }

    /// Current pressure
    public var currentPressure: Int {
        return world.pressure
    }

    /// Check game over conditions
    public var isGameOver: Bool {
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
    public func getAllFlags() -> Set<String> {
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
    public static func newGame(
        startingRegionId: String,
        startingResources: [String: Int],
        startingDeck: [String],
        seed: UInt64
    ) -> GameRuntimeState {
        let actualSeed = seed

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

public extension GameRuntimeState {
    /// Create a snapshot for comparison
    struct Snapshot: Equatable {
        public let pressure: Int
        public let time: Int
        public let health: Int
        public let faith: Int
        public let balance: Int
        public let currentRegionId: String
        public let visitedRegionsCount: Int
        public let completedEventsCount: Int
        public let activeQuestsCount: Int
        public let deckSize: Int
        public let flagCount: Int
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

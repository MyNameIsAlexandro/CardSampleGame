import Foundation

// MARK: - Legacy Adapters
// Reference: Docs/MIGRATION_PLAN.md, Feature A2
// These adapters provide compatibility between old Models/* and new Engine/Runtime/*

/// Adapter to convert legacy WorldState to WorldRuntimeState
/// Used during migration - will be removed after Phase 3
struct WorldStateAdapter {
    /// Convert legacy WorldState to new WorldRuntimeState
    /// NOTE: This is a one-way conversion for migration
    static func toRuntime(
        from legacyWorld: LegacyWorldStateProtocol,
        contentProvider: ContentProvider
    ) -> WorldRuntimeState {
        // Build regions state
        var regionsState: [String: RegionRuntimeState] = [:]
        for region in contentProvider.getAllRegionDefinitions() {
            let legacyState = legacyWorld.getRegionState(region.id)
            regionsState[region.id] = RegionRuntimeState(
                definitionId: region.id,
                currentState: mapRegionState(legacyState?.stateString ?? region.initialState.rawValue),
                visitCount: legacyState?.visitCount ?? 0,
                isDiscovered: legacyState?.isDiscovered ?? region.initiallyDiscovered
            )
        }

        // Build anchors state
        var anchorsState: [String: AnchorRuntimeState] = [:]
        for anchor in contentProvider.getAllAnchorDefinitions() {
            let legacyIntegrity = legacyWorld.getAnchorIntegrity(anchor.id)
            anchorsState[anchor.id] = AnchorRuntimeState(
                definitionId: anchor.id,
                integrity: legacyIntegrity ?? anchor.initialIntegrity,
                isActive: (legacyIntegrity ?? anchor.initialIntegrity) > 0
            )
        }

        return WorldRuntimeState(
            currentRegionId: legacyWorld.currentRegionId,
            currentTime: legacyWorld.daysPassed,
            pressure: legacyWorld.worldTension,
            daysSinceEscalation: legacyWorld.daysPassed % 3, // Estimate
            regionsState: regionsState,
            anchorsState: anchorsState,
            flags: legacyWorld.flags
        )
    }

    private static func mapRegionState(_ stateString: String) -> RegionStateType {
        switch stateString.lowercased() {
        case "stable": return .stable
        case "borderland": return .borderland
        case "breach": return .breach
        default: return .stable
        }
    }
}

/// Adapter to convert legacy Player to PlayerRuntimeState
struct PlayerStateAdapter {
    static func toRuntime(from legacyPlayer: LegacyPlayerProtocol) -> PlayerRuntimeState {
        return PlayerRuntimeState(
            resources: [
                "health": legacyPlayer.health,
                "faith": legacyPlayer.faith
            ],
            balance: legacyPlayer.balance,
            drawPile: legacyPlayer.drawPileCardIds,
            hand: legacyPlayer.handCardIds,
            discardPile: legacyPlayer.discardPileCardIds,
            exilePile: [],
            activeCurses: Set(legacyPlayer.curseIds)
        )
    }
}

/// Adapter to convert legacy GameSave to GameRuntimeState
struct GameSaveAdapter {
    static func toRuntime(
        from legacySave: LegacyGameSaveProtocol,
        contentProvider: ContentProvider
    ) -> GameRuntimeState {
        let world = WorldStateAdapter.toRuntime(
            from: legacySave.worldState,
            contentProvider: contentProvider
        )

        let player = PlayerStateAdapter.toRuntime(from: legacySave.player)

        let events = EventRuntimeState(
            completedOneTimeEvents: legacySave.completedEventIds,
            eventOccurrenceCount: [:], // Not tracked in legacy
            eventCooldowns: [:] // Not tracked in legacy
        )

        let quests = QuestRuntimeState(
            questStates: legacySave.questStates.mapValues { legacyQuest in
                SingleQuestState(
                    definitionId: legacyQuest.questId,
                    status: mapQuestStatus(legacyQuest.statusString),
                    currentObjectiveId: legacyQuest.currentObjectiveId,
                    completedObjectiveIds: legacyQuest.completedObjectiveIds
                )
            }
        )

        return GameRuntimeState(
            world: world,
            player: player,
            events: events,
            quests: quests,
            phase: .playing,
            playthroughSeed: legacySave.seed ?? UInt64.random(in: 0...UInt64.max),
            saveSlot: legacySave.slotNumber
        )
    }

    private static func mapQuestStatus(_ statusString: String) -> QuestStatus {
        switch statusString.lowercased() {
        case "locked": return .locked
        case "available": return .available
        case "active", "in_progress": return .active
        case "completed", "done": return .completed
        case "failed": return .failed
        default: return .locked
        }
    }
}

// MARK: - Legacy Protocols
// These protocols define the interface expected from legacy Models/*
// Actual conformance is added via extensions in the Models files

/// Protocol for legacy WorldState
protocol LegacyWorldStateProtocol {
    var currentRegionId: String { get }
    var daysPassed: Int { get }
    var worldTension: Int { get }
    var flags: [String: Bool] { get }

    func getRegionState(_ regionId: String) -> LegacyRegionState?
    func getAnchorIntegrity(_ anchorId: String) -> Int?
}

/// Legacy region state data
struct LegacyRegionState {
    let stateString: String
    let visitCount: Int
    let isDiscovered: Bool
}

/// Protocol for legacy Player
protocol LegacyPlayerProtocol {
    var health: Int { get }
    var faith: Int { get }
    var balance: Int { get }
    var drawPileCardIds: [String] { get }
    var handCardIds: [String] { get }
    var discardPileCardIds: [String] { get }
    var curseIds: [String] { get }
}

/// Protocol for legacy GameSave
protocol LegacyGameSaveProtocol {
    var worldState: LegacyWorldStateProtocol { get }
    var player: LegacyPlayerProtocol { get }
    var completedEventIds: Set<String> { get }
    var questStates: [String: LegacyQuestState] { get }
    var seed: UInt64? { get }
    var slotNumber: Int? { get }
}

/// Legacy quest state data
struct LegacyQuestState {
    let questId: String
    let statusString: String
    let currentObjectiveId: String?
    let completedObjectiveIds: Set<String>
}

// MARK: - Reverse Adapter (for compatibility during migration)

/// Adapter to expose new RuntimeState through legacy interface
/// Allows gradual migration without breaking existing code
class RuntimeToLegacyAdapter {
    private var runtime: GameRuntimeState

    init(runtime: GameRuntimeState) {
        self.runtime = runtime
    }

    // MARK: - Legacy World Interface

    var currentRegionId: String {
        return runtime.world.currentRegionId
    }

    var daysPassed: Int {
        return runtime.world.currentTime
    }

    var worldTension: Int {
        return runtime.world.pressure
    }

    // MARK: - Legacy Player Interface

    var health: Int {
        return runtime.player.getResource("health")
    }

    var faith: Int {
        return runtime.player.getResource("faith")
    }

    // MARK: - Update from Engine (during migration)

    func updateFromRuntime(_ newRuntime: GameRuntimeState) {
        self.runtime = newRuntime
    }
}

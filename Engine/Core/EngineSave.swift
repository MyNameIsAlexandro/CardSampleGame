import Foundation

// MARK: - Engine Save Structure
// Сериализуемое состояние для save/load (Engine-First Architecture)

/// Полное состояние игры для сохранения
/// Engine сохраняет/загружает через эту структуру, а не через WorldState
struct EngineSave: Codable {
    // MARK: - Metadata
    let version: Int
    let savedAt: Date
    let gameDuration: TimeInterval

    // MARK: - Player State
    let playerName: String
    let playerHealth: Int
    let playerMaxHealth: Int
    let playerFaith: Int
    let playerMaxFaith: Int
    let playerBalance: Int

    // MARK: - Deck State
    let deckCardIds: [UUID]
    let handCardIds: [UUID]
    let discardCardIds: [UUID]

    // MARK: - World State
    let currentDay: Int
    let worldTension: Int
    let lightDarkBalance: Int
    let currentRegionId: UUID?

    // MARK: - Regions State
    let regions: [RegionSaveState]

    // MARK: - Quest State
    let mainQuestStage: Int
    let activeQuestIds: [String]
    let completedQuestIds: [String]
    let questStages: [String: Int]

    // MARK: - Events State
    let completedEventIds: [UUID]
    let eventLog: [EventLogEntrySave]

    // MARK: - World Flags
    let worldFlags: [String: Bool]

    // MARK: - RNG State
    let rngSeed: UInt64?

    // MARK: - Current Version
    static let currentVersion = 1
}

// MARK: - Region Save State

/// Состояние региона для сохранения
struct RegionSaveState: Codable {
    let id: UUID
    let name: String
    let type: String  // RegionType.rawValue
    let state: String  // RegionState.rawValue
    let anchor: AnchorSaveState?
    let neighborIds: [UUID]
    let canTrade: Bool
    let visited: Bool
    let reputation: Int

    init(from region: EngineRegionState) {
        self.id = region.id
        self.name = region.name
        self.type = region.type.rawValue
        self.state = region.state.rawValue
        self.anchor = region.anchor.map { AnchorSaveState(from: $0) }
        self.neighborIds = region.neighborIds
        self.canTrade = region.canTrade
        self.visited = region.visited
        self.reputation = region.reputation
    }

    func toEngineRegionState() -> EngineRegionState {
        EngineRegionState(
            id: id,
            name: name,
            type: RegionType(rawValue: type) ?? .wilderness,
            state: RegionState(rawValue: state) ?? .stable,
            anchor: anchor?.toEngineAnchorState(),
            neighborIds: neighborIds,
            canTrade: canTrade,
            visited: visited,
            reputation: reputation
        )
    }
}

// MARK: - Anchor Save State

/// Состояние якоря для сохранения
struct AnchorSaveState: Codable {
    let id: UUID
    let name: String
    let integrity: Int

    init(from anchor: EngineAnchorState) {
        self.id = anchor.id
        self.name = anchor.name
        self.integrity = anchor.integrity
    }

    func toEngineAnchorState() -> EngineAnchorState {
        EngineAnchorState(id: id, name: name, integrity: integrity)
    }
}

// MARK: - Event Log Entry Save

/// Запись лога событий для сохранения
struct EventLogEntrySave: Codable {
    let id: UUID
    let dayNumber: Int
    let timestamp: Date
    let regionName: String
    let eventTitle: String
    let choiceMade: String
    let outcome: String
    let type: String  // EventLogType.rawValue

    init(from entry: EventLogEntry) {
        self.id = entry.id
        self.dayNumber = entry.dayNumber
        self.timestamp = entry.timestamp
        self.regionName = entry.regionName
        self.eventTitle = entry.eventTitle
        self.choiceMade = entry.choiceMade
        self.outcome = entry.outcome
        self.type = entry.type.rawValue
    }

    func toEventLogEntry() -> EventLogEntry {
        EventLogEntry(
            id: id,
            dayNumber: dayNumber,
            timestamp: timestamp,
            regionName: regionName,
            eventTitle: eventTitle,
            choiceMade: choiceMade,
            outcome: outcome,
            type: EventLogType(rawValue: type) ?? .exploration
        )
    }
}

// MARK: - TwilightGameEngine Save/Load Extension

extension TwilightGameEngine {

    /// Create save state from current engine state
    func createSave(gameDuration: TimeInterval = 0) -> EngineSave {
        EngineSave(
            version: EngineSave.currentVersion,
            savedAt: Date(),
            gameDuration: gameDuration,
            playerName: playerName,
            playerHealth: playerHealth,
            playerMaxHealth: playerMaxHealth,
            playerFaith: playerFaith,
            playerMaxFaith: playerMaxFaith,
            playerBalance: playerBalance,
            deckCardIds: [],  // Phase 4: Card system migration
            handCardIds: [],
            discardCardIds: [],
            currentDay: currentDay,
            worldTension: worldTension,
            lightDarkBalance: lightDarkBalance,
            currentRegionId: currentRegionId,
            regions: publishedRegions.values.map { RegionSaveState(from: $0) },
            mainQuestStage: mainQuestStage,
            activeQuestIds: publishedActiveQuests.map { $0.id },
            completedQuestIds: Array(getCompletedQuestIds()),
            questStages: getQuestStages(),
            completedEventIds: Array(getCompletedEventIds()),
            eventLog: publishedEventLog.map { EventLogEntrySave(from: $0) },
            worldFlags: publishedWorldFlags,
            rngSeed: nil  // Phase 4: RNG state persistence
        )
    }

    /// Load state from save
    func loadFromSave(_ save: EngineSave) {
        // Player state
        playerName = save.playerName
        playerHealth = save.playerHealth
        playerMaxHealth = save.playerMaxHealth
        playerFaith = save.playerFaith
        playerMaxFaith = save.playerMaxFaith
        playerBalance = save.playerBalance

        // World state
        currentDay = save.currentDay
        worldTension = save.worldTension
        lightDarkBalance = save.lightDarkBalance
        currentRegionId = save.currentRegionId

        // Reset game state
        isGameOver = false
        gameResult = nil
        currentEventId = nil
        currentEvent = nil
        lastDayEvent = nil
        isInCombat = false

        // Load regions
        var newRegions: [UUID: EngineRegionState] = [:]
        for regionSave in save.regions {
            let region = regionSave.toEngineRegionState()
            newRegions[region.id] = region
        }
        setRegions(newRegions)

        // Load flags
        setWorldFlags(save.worldFlags)

        // Load completed events
        setCompletedEventIds(Set(save.completedEventIds))

        // Load event log
        setEventLog(save.eventLog.map { $0.toEventLogEntry() })

        // Load quest state
        setMainQuestStage(save.mainQuestStage)
        setCompletedQuestIds(Set(save.completedQuestIds))
        setQuestStages(save.questStages)

        // Sync pressure engine
        pressureEngine.setPressure(worldTension)
        pressureEngine.syncTriggeredThresholdsFromPressure()

        // Update published state
        updatePublishedStateAfterLoad()
    }
}

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

    // MARK: - Pack Compatibility (Audit 2.0 Requirement)
    /// Core engine version for compatibility checking
    let coreVersion: String
    /// Active pack set with versions (packId → version string)
    let activePackSet: [String: String]
    /// Save format version for migration
    let formatVersion: Int

    // MARK: - Player State
    let playerName: String
    let heroId: String?  // Hero definition ID for data-driven hero system
    let playerHealth: Int
    let playerMaxHealth: Int
    let playerFaith: Int
    let playerMaxFaith: Int
    let playerBalance: Int

    // MARK: - Deck State (String IDs for stable serialization - Epic 3)
    let deckCardIds: [String]
    let handCardIds: [String]
    let discardCardIds: [String]

    // MARK: - World State
    let currentDay: Int
    let worldTension: Int
    let lightDarkBalance: Int
    let currentRegionId: String?  // Definition ID, not UUID

    // MARK: - Regions State
    let regions: [RegionSaveState]

    // MARK: - Quest State
    let mainQuestStage: Int
    let activeQuestIds: [String]
    let completedQuestIds: [String]
    let questStages: [String: Int]

    // MARK: - Events State (String IDs for stable serialization - Epic 3)
    let completedEventIds: [String]  // Definition IDs, not UUIDs
    let eventLog: [EventLogEntrySave]

    // MARK: - World Flags
    let worldFlags: [String: Bool]

    // MARK: - RNG State
    let rngSeed: UInt64?

    // MARK: - Current Version
    static let currentVersion = 1
    static let currentFormatVersion = 1
    static let currentCoreVersion = "1.2.0"

    // MARK: - Pack Compatibility Validation

    /// Check if save is compatible with current engine and loaded packs
    func validateCompatibility(with registry: ContentRegistry) -> SaveCompatibilityResult {
        var warnings: [String] = []
        var errors: [String] = []

        // Check core version
        if coreVersion != EngineSave.currentCoreVersion {
            warnings.append("Save was created with core version \(coreVersion), current is \(EngineSave.currentCoreVersion)")
        }

        // Check format version
        if formatVersion > EngineSave.currentFormatVersion {
            errors.append("Save format version \(formatVersion) is newer than supported \(EngineSave.currentFormatVersion)")
        }

        // Check pack versions
        for (packId, savedVersion) in activePackSet {
            if let loadedPack = registry.loadedPacks[packId] {
                let loadedVersion = loadedPack.manifest.version.description
                if loadedVersion != savedVersion {
                    warnings.append("Pack '\(packId)' version mismatch: save has \(savedVersion), loaded is \(loadedVersion)")
                }
            } else {
                errors.append("Required pack '\(packId)' (version \(savedVersion)) is not loaded")
            }
        }

        if !errors.isEmpty {
            return .incompatible(errors: errors)
        } else if !warnings.isEmpty {
            return .compatible(warnings: warnings)
        } else {
            return .fullyCompatible
        }
    }
}

/// Result of save compatibility validation
enum SaveCompatibilityResult {
    case fullyCompatible
    case compatible(warnings: [String])
    case incompatible(errors: [String])

    var isLoadable: Bool {
        switch self {
        case .fullyCompatible, .compatible:
            return true
        case .incompatible:
            return false
        }
    }
}

// MARK: - Region Save State

/// Состояние региона для сохранения (String IDs - Epic 3)
struct RegionSaveState: Codable {
    let definitionId: String  // Stable definition ID
    let name: String
    let type: String  // RegionType.rawValue
    let state: String  // RegionState.rawValue
    let anchorDefinitionId: String?
    let anchorIntegrity: Int?
    let neighborDefinitionIds: [String]
    let canTrade: Bool
    let visited: Bool
    let reputation: Int

    init(from region: EngineRegionState) {
        self.definitionId = region.definitionId ?? region.id.uuidString
        self.name = region.name
        self.type = region.type.rawValue
        self.state = region.state.rawValue
        self.anchorDefinitionId = region.anchor?.definitionId
        self.anchorIntegrity = region.anchor?.integrity
        self.neighborDefinitionIds = region.neighborDefinitionIds ?? []
        self.canTrade = region.canTrade
        self.visited = region.visited
        self.reputation = region.reputation
    }

    func toEngineRegionState() -> EngineRegionState {
        var anchor: EngineAnchorState? = nil
        if let anchorId = anchorDefinitionId {
            anchor = EngineAnchorState(
                id: UUID(),
                definitionId: anchorId,
                name: anchorId,
                integrity: anchorIntegrity ?? 100
            )
        }

        return EngineRegionState(
            id: UUID(),
            definitionId: definitionId,
            name: name,
            type: RegionType(rawValue: type) ?? .settlement,
            state: RegionState(rawValue: state) ?? .stable,
            anchor: anchor,
            neighborIds: [],
            neighborDefinitionIds: neighborDefinitionIds,
            canTrade: canTrade,
            visited: visited,
            reputation: reputation
        )
    }
}

// MARK: - Anchor Save State (Deprecated - anchors now stored inline in RegionSaveState)

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

// MARK: - TwilightGameEngine Save/Load
// NOTE: Save/Load methods moved to TwilightGameEngine.swift for proper access to internal state
// See TwilightGameEngine+Persistence.swift for implementation

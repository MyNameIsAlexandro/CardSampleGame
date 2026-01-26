import Foundation

// MARK: - Engine Save Structure
// Сериализуемое состояние для save/load (Engine-First Architecture)

/// Full game state for saving
/// Engine saves/loads via this struct, not through WorldState
public struct EngineSave: Codable {
    // MARK: - Metadata
    public let version: Int
    public let savedAt: Date
    public let gameDuration: TimeInterval

    // MARK: - Pack Compatibility (Audit 2.0 Requirement)
    /// Core engine version for compatibility checking
    public let coreVersion: String
    /// Active pack set with versions (packId -> version string)
    public let activePackSet: [String: String]
    /// Save format version for migration
    public let formatVersion: Int
    /// Primary campaign pack ID (the main pack that defines the campaign)
    public let primaryCampaignPackId: String?

    // MARK: - Player State
    public let playerName: String
    public let heroId: String?  // Hero definition ID for data-driven hero system
    public let playerHealth: Int
    public let playerMaxHealth: Int
    public let playerFaith: Int
    public let playerMaxFaith: Int
    public let playerBalance: Int

    // MARK: - Deck State (String IDs for stable serialization - Epic 3)
    public let deckCardIds: [String]
    public let handCardIds: [String]
    public let discardCardIds: [String]

    // MARK: - World State
    public let currentDay: Int
    public let worldTension: Int
    public let lightDarkBalance: Int
    public let currentRegionId: String?  // Definition ID, not UUID

    // MARK: - Regions State
    public let regions: [RegionSaveState]

    // MARK: - Quest State
    public let mainQuestStage: Int
    public let activeQuestIds: [String]
    public let completedQuestIds: [String]
    public let questStages: [String: Int]

    // MARK: - Events State (String IDs for stable serialization - Epic 3)
    public let completedEventIds: [String]  // Definition IDs, not UUIDs
    public let eventLog: [EventLogEntrySave]

    // MARK: - World Flags
    public let worldFlags: [String: Bool]

    // MARK: - RNG State (Audit A2 - determinism after load)
    public let rngSeed: UInt64?
    public let rngState: UInt64?  // Current RNG state for exact restoration

    // MARK: - Current Version
    public static let currentVersion = 1
    public static let currentFormatVersion = 1
    public static let currentCoreVersion = "1.2.0"

    // MARK: - Initialization

    public init(
        version: Int = EngineSave.currentVersion,
        savedAt: Date = Date(),
        gameDuration: TimeInterval = 0,
        coreVersion: String = EngineSave.currentCoreVersion,
        activePackSet: [String: String] = [:],
        formatVersion: Int = EngineSave.currentFormatVersion,
        primaryCampaignPackId: String? = nil,
        playerName: String = "",
        heroId: String? = nil,
        playerHealth: Int = 10,
        playerMaxHealth: Int = 10,
        playerFaith: Int = 3,
        playerMaxFaith: Int = 10,
        playerBalance: Int = 50,
        deckCardIds: [String] = [],
        handCardIds: [String] = [],
        discardCardIds: [String] = [],
        currentDay: Int = 1,
        worldTension: Int = 0,
        lightDarkBalance: Int = 50,
        currentRegionId: String? = nil,
        regions: [RegionSaveState] = [],
        mainQuestStage: Int = 1,
        activeQuestIds: [String] = [],
        completedQuestIds: [String] = [],
        questStages: [String: Int] = [:],
        completedEventIds: [String] = [],
        eventLog: [EventLogEntrySave] = [],
        worldFlags: [String: Bool] = [:],
        rngSeed: UInt64? = nil,
        rngState: UInt64? = nil
    ) {
        self.version = version
        self.savedAt = savedAt
        self.gameDuration = gameDuration
        self.coreVersion = coreVersion
        self.activePackSet = activePackSet
        self.formatVersion = formatVersion
        self.primaryCampaignPackId = primaryCampaignPackId
        self.playerName = playerName
        self.heroId = heroId
        self.playerHealth = playerHealth
        self.playerMaxHealth = playerMaxHealth
        self.playerFaith = playerFaith
        self.playerMaxFaith = playerMaxFaith
        self.playerBalance = playerBalance
        self.deckCardIds = deckCardIds
        self.handCardIds = handCardIds
        self.discardCardIds = discardCardIds
        self.currentDay = currentDay
        self.worldTension = worldTension
        self.lightDarkBalance = lightDarkBalance
        self.currentRegionId = currentRegionId
        self.regions = regions
        self.mainQuestStage = mainQuestStage
        self.activeQuestIds = activeQuestIds
        self.completedQuestIds = completedQuestIds
        self.questStages = questStages
        self.completedEventIds = completedEventIds
        self.eventLog = eventLog
        self.worldFlags = worldFlags
        self.rngSeed = rngSeed
        self.rngState = rngState
    }

    // MARK: - Pack Compatibility Validation

    /// Check if save is compatible with current engine and loaded packs
    public func validateCompatibility(with registry: ContentRegistry) -> SaveCompatibilityResult {
        var warnings: [String] = []
        var errors: [String] = []

        // Check core version
        if coreVersion != EngineSave.currentCoreVersion {
            warnings.append("Save was created with core version \(coreVersion), current is \(EngineSave.currentCoreVersion)")
        }

        // Check format version - only fail if format is NEWER than supported
        if formatVersion > EngineSave.currentFormatVersion {
            errors.append("Save format version \(formatVersion) is newer than supported \(EngineSave.currentFormatVersion)")
        }

        // Check primary campaign pack - this is CRITICAL for save compatibility
        // If the primary campaign pack is missing, the save cannot be loaded properly
        if let primaryPackId = primaryCampaignPackId {
            if registry.loadedPacks[primaryPackId] == nil {
                errors.append("Primary campaign pack '\(primaryPackId)' is not loaded - this save requires it to continue")
            }
        }

        // Check pack versions - missing/mismatched packs are warnings, not errors
        // The game can still try to load with available content
        for (packId, savedVersion) in activePackSet {
            if let loadedPack = registry.loadedPacks[packId] {
                let loadedVersion = loadedPack.manifest.version.description
                if loadedVersion != savedVersion {
                    warnings.append("Pack '\(packId)' version mismatch: save has \(savedVersion), loaded is \(loadedVersion)")
                }
            } else if packId != primaryCampaignPackId {
                // Missing non-primary pack is a warning, not an error
                // The game can try to continue with whatever content is available
                warnings.append("Pack '\(packId)' (version \(savedVersion)) is not currently loaded - some content may be unavailable")
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
public enum SaveCompatibilityResult {
    case fullyCompatible
    case compatible(warnings: [String])
    case incompatible(errors: [String])

    public var isLoadable: Bool {
        switch self {
        case .fullyCompatible, .compatible:
            return true
        case .incompatible:
            return false
        }
    }

    /// Get error messages (for incompatible saves)
    public var errorMessages: [String] {
        switch self {
        case .incompatible(let errors):
            return errors
        default:
            return []
        }
    }

    /// Get warning messages (for compatible saves)
    public var warningMessages: [String] {
        switch self {
        case .compatible(let warnings):
            return warnings
        default:
            return []
        }
    }
}

// MARK: - Region Save State

/// Region state for saving (String IDs - Epic 3)
public struct RegionSaveState: Codable {
    public let definitionId: String  // Stable definition ID
    public let name: String
    public let type: String  // RegionType.rawValue
    public let state: String  // RegionState.rawValue
    public let anchorDefinitionId: String?
    public let anchorIntegrity: Int?
    public let neighborDefinitionIds: [String]
    public let canTrade: Bool
    public let visited: Bool
    public let reputation: Int

    public init(from region: EngineRegionState) {
        // definitionId is now required (Audit A1 - no UUID fallback)
        self.definitionId = region.definitionId
        self.name = region.name
        self.type = region.type.rawValue
        self.state = region.state.rawValue
        self.anchorDefinitionId = region.anchor?.definitionId
        self.anchorIntegrity = region.anchor?.integrity
        self.neighborDefinitionIds = region.neighborDefinitionIds
        self.canTrade = region.canTrade
        self.visited = region.visited
        self.reputation = region.reputation
    }

    public func toEngineRegionState() -> EngineRegionState {
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

/// Event log entry for saving
public struct EventLogEntrySave: Codable {
    public let id: UUID
    public let dayNumber: Int
    public let timestamp: Date
    public let regionName: String
    public let eventTitle: String
    public let choiceMade: String
    public let outcome: String
    public let type: String  // EventLogType.rawValue

    public init(from entry: EventLogEntry) {
        self.id = entry.id
        self.dayNumber = entry.dayNumber
        self.timestamp = entry.timestamp
        self.regionName = entry.regionName
        self.eventTitle = entry.eventTitle
        self.choiceMade = entry.choiceMade
        self.outcome = entry.outcome
        self.type = entry.type.rawValue
    }

    public func toEventLogEntry() -> EventLogEntry {
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

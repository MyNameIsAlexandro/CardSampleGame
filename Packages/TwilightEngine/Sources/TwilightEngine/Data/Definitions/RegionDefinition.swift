import Foundation

// MARK: - Region Definition
// Reference: Docs/ENGINE_ARCHITECTURE.md, Section 4.1
// Reference: Docs/EXPLORATION_CORE_DESIGN.md, Section 5

/// Immutable definition of a region in the game world.
/// Runtime state (visitCount, currentState, etc.) lives in RegionRuntimeState.
public struct RegionDefinition: GameDefinition {
    // MARK: - Identity

    /// Unique region identifier (e.g., "forest", "village_square")
    public let id: String

    // MARK: - Localized Content

    /// Region name (supports inline LocalizedString or StringKey)
    public let title: LocalizableText

    /// Region description (supports inline LocalizedString or StringKey)
    public let description: LocalizableText

    // MARK: - Type

    /// Region type string (e.g., "forest", "settlement", "swamp")
    /// This determines visual representation and gameplay effects
    public let regionType: String

    // MARK: - Connections

    /// IDs of neighboring regions (for travel)
    public let neighborIds: [String]

    /// Whether this region is initially discovered
    public let initiallyDiscovered: Bool

    // MARK: - Content

    /// ID of the anchor in this region (nil if no anchor)
    public let anchorId: String?

    /// Event pool IDs for this region
    public let eventPoolIds: [String]

    // MARK: - Initial State

    /// Initial region state: "stable", "borderland", or "breach"
    public let initialState: RegionStateType

    /// Weight for random degradation selection (higher = more likely to degrade)
    public let degradationWeight: Int

    // MARK: - Initialization

    public init(
        id: String,
        title: LocalizableText,
        description: LocalizableText,
        regionType: String = "forest",
        neighborIds: [String],
        initiallyDiscovered: Bool = false,
        anchorId: String? = nil,
        eventPoolIds: [String] = [],
        initialState: RegionStateType = .stable,
        degradationWeight: Int = 1
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.regionType = regionType
        self.neighborIds = neighborIds
        self.initiallyDiscovered = initiallyDiscovered
        self.anchorId = anchorId
        self.eventPoolIds = eventPoolIds
        self.initialState = initialState
        self.degradationWeight = degradationWeight
    }
}

// MARK: - Region State Types

/// Possible states for a region
public enum RegionStateType: String, Codable, Hashable, CaseIterable {
    case stable = "stable"
    case borderland = "borderland"
    case breach = "breach"

    /// Degradation order: stable -> borderland -> breach
    public var degraded: RegionStateType? {
        switch self {
        case .stable: return .borderland
        case .borderland: return .breach
        case .breach: return nil // Cannot degrade further
        }
    }

    /// Restoration order: breach -> borderland -> stable
    public var restored: RegionStateType? {
        switch self {
        case .stable: return nil // Cannot restore further
        case .borderland: return .stable
        case .breach: return .borderland
        }
    }

    /// Weight for random selection during degradation
    public var degradationSelectionWeight: Int {
        switch self {
        case .stable: return 0     // Stable regions not selected
        case .borderland: return 1
        case .breach: return 2     // Breach regions more likely
        }
    }
}

// MARK: - Region Type (Twilight Marches specific)

/// Specific region types for Twilight Marches setting
/// Note: This is game-specific, not engine-level
public enum TwilightMarchesRegionType: String, Codable, Hashable {
    case settlement = "settlement"
    case wilderness = "wilderness"
    case sacred = "sacred"
    case corrupted = "corrupted"
    case threshold = "threshold"
}

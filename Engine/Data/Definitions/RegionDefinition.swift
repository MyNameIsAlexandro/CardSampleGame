import Foundation

// MARK: - Region Definition
// Reference: Docs/ENGINE_ARCHITECTURE.md, Section 4.1
// Reference: Docs/EXPLORATION_CORE_DESIGN.md, Section 5

/// Immutable definition of a region in the game world.
/// Runtime state (visitCount, currentState, etc.) lives in RegionRuntimeState.
struct RegionDefinition: GameDefinition {
    // MARK: - Identity

    /// Unique region identifier (e.g., "forest", "village_square")
    let id: String

    // MARK: - Localized Content

    /// Region name with all language variants
    let title: LocalizedString

    /// Region description with all language variants
    let description: LocalizedString

    // MARK: - Type

    /// Region type string (e.g., "forest", "settlement", "swamp")
    /// This determines visual representation and gameplay effects
    let regionType: String

    // MARK: - Connections

    /// IDs of neighboring regions (for travel)
    let neighborIds: [String]

    /// Whether this region is initially discovered
    let initiallyDiscovered: Bool

    // MARK: - Content

    /// ID of the anchor in this region (nil if no anchor)
    let anchorId: String?

    /// Event pool IDs for this region
    let eventPoolIds: [String]

    // MARK: - Initial State

    /// Initial region state: "stable", "borderland", or "breach"
    let initialState: RegionStateType

    /// Weight for random degradation selection (higher = more likely to degrade)
    let degradationWeight: Int

    // MARK: - Initialization

    init(
        id: String,
        title: LocalizedString,
        description: LocalizedString,
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
enum RegionStateType: String, Codable, Hashable, CaseIterable {
    case stable = "stable"
    case borderland = "borderland"
    case breach = "breach"

    /// Degradation order: stable → borderland → breach
    var degraded: RegionStateType? {
        switch self {
        case .stable: return .borderland
        case .borderland: return .breach
        case .breach: return nil // Cannot degrade further
        }
    }

    /// Restoration order: breach → borderland → stable
    var restored: RegionStateType? {
        switch self {
        case .stable: return nil // Cannot restore further
        case .borderland: return .stable
        case .breach: return .borderland
        }
    }

    /// Weight for random selection during degradation
    var degradationSelectionWeight: Int {
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
enum TwilightMarchesRegionType: String, Codable, Hashable {
    case settlement = "settlement"
    case wilderness = "wilderness"
    case sacred = "sacred"
    case corrupted = "corrupted"
    case threshold = "threshold"
}

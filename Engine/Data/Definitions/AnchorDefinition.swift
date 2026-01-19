import Foundation

// MARK: - Anchor Influence

/// Influence alignment of an anchor (maps to CardBalance in legacy models)
enum AnchorInfluence: String, Codable, Hashable {
    case light
    case neutral
    case dark
}

// MARK: - Anchor Definition
// Reference: Docs/ENGINE_ARCHITECTURE.md, Section 4.1
// Reference: Docs/EXPLORATION_CORE_DESIGN.md, Section 6

/// Immutable definition of an anchor point.
/// Anchors provide resistance to regional degradation.
/// Runtime state (current integrity, etc.) lives in AnchorRuntimeState.
struct AnchorDefinition: GameDefinition {
    // MARK: - Identity

    /// Unique anchor identifier (e.g., "anchor_forest_shrine")
    let id: String

    // MARK: - Localized Content

    /// Anchor name with all language variants
    let title: LocalizedString

    /// Anchor description with all language variants
    let description: LocalizedString

    // MARK: - Location

    /// ID of the region where this anchor is located
    let regionId: String

    // MARK: - Type & Influence (Twilight Marches specific)

    /// Anchor type (e.g., "chapel", "shrine", "sacred_tree")
    let anchorType: String

    /// Initial influence: "light", "neutral", or "dark"
    let initialInfluence: AnchorInfluence

    /// Power level (radius of influence, 1-10)
    let power: Int

    // MARK: - Mechanics

    /// Maximum integrity value (0-100)
    let maxIntegrity: Int

    /// Initial integrity value
    let initialIntegrity: Int

    /// Integrity gained per "strengthen" action
    let strengthenAmount: Int

    /// Resource cost to strengthen (e.g., ["faith": 5])
    let strengthenCost: ResourceTransaction

    // MARK: - Effects

    /// Resistance chance calculation: integrity / resistanceDivisor
    /// Default: 100 (so 50 integrity = 50% resistance)
    let resistanceDivisor: Int

    // MARK: - Initialization

    init(
        id: String,
        title: LocalizedString,
        description: LocalizedString,
        regionId: String,
        anchorType: String = "shrine",
        initialInfluence: AnchorInfluence = .neutral,
        power: Int = 5,
        maxIntegrity: Int = 100,
        initialIntegrity: Int = 50,
        strengthenAmount: Int = 15,
        strengthenCost: ResourceTransaction = .spend("faith", amount: 5),
        resistanceDivisor: Int = 100
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.regionId = regionId
        self.anchorType = anchorType
        self.initialInfluence = initialInfluence
        self.power = power
        self.maxIntegrity = maxIntegrity
        self.initialIntegrity = initialIntegrity
        self.strengthenAmount = strengthenAmount
        self.strengthenCost = strengthenCost
        self.resistanceDivisor = resistanceDivisor
    }
}

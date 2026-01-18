import Foundation

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

    // MARK: - Localization Keys

    /// Localization key for anchor name
    let titleKey: String

    /// Localization key for anchor description
    let descriptionKey: String

    // MARK: - Location

    /// ID of the region where this anchor is located
    let regionId: String

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
        titleKey: String,
        descriptionKey: String,
        regionId: String,
        maxIntegrity: Int = 100,
        initialIntegrity: Int = 50,
        strengthenAmount: Int = 15,
        strengthenCost: ResourceTransaction = .spend("faith", amount: 5),
        resistanceDivisor: Int = 100
    ) {
        self.id = id
        self.titleKey = titleKey
        self.descriptionKey = descriptionKey
        self.regionId = regionId
        self.maxIntegrity = maxIntegrity
        self.initialIntegrity = initialIntegrity
        self.strengthenAmount = strengthenAmount
        self.strengthenCost = strengthenCost
        self.resistanceDivisor = resistanceDivisor
    }
}

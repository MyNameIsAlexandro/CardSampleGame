import Foundation

// MARK: - Anchor Influence

/// Influence alignment of an anchor (maps to CardBalance in legacy models)
public enum AnchorInfluence: String, Codable, Hashable {
    case light
    case neutral
    case dark
}

/// Alias for runtime context readability
public typealias AnchorAlignment = AnchorInfluence

// MARK: - Anchor Definition
// Reference: Docs/ENGINE_ARCHITECTURE.md, Section 4.1
// Reference: Docs/EXPLORATION_CORE_DESIGN.md, Section 6

/// Immutable definition of an anchor point.
/// Anchors provide resistance to regional degradation.
/// Runtime state (current integrity, etc.) lives in AnchorRuntimeState.
public struct AnchorDefinition: GameDefinition {
    // MARK: - Identity

    /// Unique anchor identifier (e.g., "anchor_forest_shrine")
    public var id: String

    // MARK: - Localized Content

    /// Anchor name (supports inline LocalizedString or StringKey)
    public var title: LocalizableText

    /// Anchor description (supports inline LocalizedString or StringKey)
    public var description: LocalizableText

    // MARK: - Location

    /// ID of the region where this anchor is located
    public var regionId: String

    // MARK: - Type & Influence

    /// Anchor type (e.g., "chapel", "shrine", "sacred_tree")
    public var anchorType: String

    /// Initial influence: "light", "neutral", or "dark"
    public var initialInfluence: AnchorInfluence

    /// Power level (radius of influence, 1-10)
    public var power: Int

    // MARK: - Mechanics

    /// Maximum integrity value (0-100)
    public var maxIntegrity: Int

    /// Initial integrity value
    public var initialIntegrity: Int

    /// Integrity gained per "strengthen" action
    public var strengthenAmount: Int

    /// Resource cost to strengthen (e.g., ["faith": 5])
    public var strengthenCost: ResourceTransaction

    // MARK: - Effects

    /// Resistance chance calculation: integrity / resistanceDivisor
    /// Default: 100 (so 50 integrity = 50% resistance)
    public var resistanceDivisor: Int

    // MARK: - Initialization

    public init(
        id: String,
        title: LocalizableText,
        description: LocalizableText,
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

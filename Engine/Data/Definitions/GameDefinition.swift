import Foundation

// MARK: - Base Definition Protocol
// Reference: Docs/ENGINE_ARCHITECTURE.md, Section 4.1
// Reference: Docs/MIGRATION_PLAN.md, Feature A1

/// Base protocol for all game content definitions.
/// Definitions are IMMUTABLE - they contain no runtime state.
/// All runtime data belongs in RuntimeState types.
///
/// **Invariants:**
/// - INV-D01: Definitions have no mutable properties
/// - INV-D02: All IDs are String (not UUID)
/// - INV-D03: All user-facing text uses localization keys (titleKey, bodyKey)
protocol GameDefinition: Codable, Identifiable, Hashable {
    /// Unique identifier for this definition.
    /// Must be unique within its type (regions, events, quests, etc.)
    var id: String { get }
}

// MARK: - Localization Key Validation

/// Helper to validate localization key format.
/// Keys should follow pattern: "type.id.field" (e.g., "region.forest.title")
enum LocalizationKeyValidator {
    static func isValidKey(_ key: String) -> Bool {
        // Key must contain at least one dot and no spaces
        return key.contains(".") && !key.contains(" ")
    }

    static func validateKeys(_ keys: [String]) -> [String] {
        return keys.filter { !isValidKey($0) }
    }
}

// MARK: - Common Types

/// Availability conditions for content (events, choices, etc.)
/// Reference: Docs/EVENT_MODULE_ARCHITECTURE.md, Section 2.3
struct Availability: Codable, Hashable {
    /// Required flags that must be set
    let requiredFlags: [String]

    /// Forbidden flags that must NOT be set
    let forbiddenFlags: [String]

    /// Minimum pressure/tension required
    let minPressure: Int?

    /// Maximum pressure/tension allowed
    let maxPressure: Int?

    /// Minimum balance value required
    let minBalance: Int?

    /// Maximum balance value allowed
    let maxBalance: Int?

    /// Specific region states where this is available
    let regionStates: [String]?

    /// Specific region IDs where this is available
    let regionIds: [String]?

    init(
        requiredFlags: [String] = [],
        forbiddenFlags: [String] = [],
        minPressure: Int? = nil,
        maxPressure: Int? = nil,
        minBalance: Int? = nil,
        maxBalance: Int? = nil,
        regionStates: [String]? = nil,
        regionIds: [String]? = nil
    ) {
        self.requiredFlags = requiredFlags
        self.forbiddenFlags = forbiddenFlags
        self.minPressure = minPressure
        self.maxPressure = maxPressure
        self.minBalance = minBalance
        self.maxBalance = maxBalance
        self.regionStates = regionStates
        self.regionIds = regionIds
    }

    /// Default availability (always available)
    static let always = Availability()
}

// MARK: - Resource Cost/Gain

/// Represents a resource change (cost or gain)
struct ResourceChange: Codable, Hashable {
    let resourceId: String
    let amount: Int

    /// Positive = gain, negative = cost
    var isGain: Bool { amount > 0 }
    var isCost: Bool { amount < 0 }
}

/// Collection of resource changes for a transaction
struct ResourceTransaction: Codable, Hashable {
    let changes: [ResourceChange]

    /// Convenience for single resource
    static func spend(_ resourceId: String, amount: Int) -> ResourceTransaction {
        ResourceTransaction(changes: [ResourceChange(resourceId: resourceId, amount: -abs(amount))])
    }

    static func gain(_ resourceId: String, amount: Int) -> ResourceTransaction {
        ResourceTransaction(changes: [ResourceChange(resourceId: resourceId, amount: abs(amount))])
    }

    static let none = ResourceTransaction(changes: [])
}

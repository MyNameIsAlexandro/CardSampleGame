import Foundation

// MARK: - World Runtime State
// Reference: Docs/ENGINE_ARCHITECTURE.md, Section 4.2
// Reference: Docs/MIGRATION_PLAN.md, Feature A2

/// Mutable runtime state of the game world.
/// References Definitions by ID, never stores Definition data.
public struct WorldRuntimeState: Codable, Equatable {
    // MARK: - Current Position

    /// Current region ID
    public var currentRegionId: String

    // MARK: - Time

    /// Current game time (days passed)
    public var currentTime: Int

    // MARK: - Resonance

    /// Global world resonance (-100..+100), Nav↔Prav axis
    public var resonance: Float

    // MARK: - Pressure

    /// Current world tension/pressure (0-100)
    public var pressure: Int

    /// Days since last pressure escalation
    public var daysSinceEscalation: Int

    // MARK: - Regions State

    /// Runtime state of each region (keyed by definition ID)
    public var regionsState: [String: RegionRuntimeState]

    // MARK: - Anchors State

    /// Runtime state of each anchor (keyed by definition ID)
    public var anchorsState: [String: AnchorRuntimeState]

    // MARK: - World Flags

    /// Global world flags
    public var flags: [String: Bool]

    // MARK: - Initialization

    public init(
        currentRegionId: String,
        currentTime: Int = 0,
        resonance: Float = 0.0,
        pressure: Int = 0,
        daysSinceEscalation: Int = 0,
        regionsState: [String: RegionRuntimeState] = [:],
        anchorsState: [String: AnchorRuntimeState] = [:],
        flags: [String: Bool] = [:]
    ) {
        self.currentRegionId = currentRegionId
        self.currentTime = currentTime
        self.resonance = resonance
        self.pressure = pressure
        self.daysSinceEscalation = daysSinceEscalation
        self.regionsState = regionsState
        self.anchorsState = anchorsState
        self.flags = flags
    }

    // MARK: - Codable (backward compatibility)

    enum CodingKeys: String, CodingKey {
        case currentRegionId, currentTime, resonance, pressure
        case daysSinceEscalation, regionsState, anchorsState, flags
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        currentRegionId = try c.decode(String.self, forKey: .currentRegionId)
        currentTime = try c.decode(Int.self, forKey: .currentTime)
        resonance = try c.decodeIfPresent(Float.self, forKey: .resonance) ?? 0.0
        pressure = try c.decode(Int.self, forKey: .pressure)
        daysSinceEscalation = try c.decode(Int.self, forKey: .daysSinceEscalation)
        regionsState = try c.decode([String: RegionRuntimeState].self, forKey: .regionsState)
        anchorsState = try c.decode([String: AnchorRuntimeState].self, forKey: .anchorsState)
        flags = try c.decode([String: Bool].self, forKey: .flags)
    }

    // MARK: - Flag Operations

    mutating func setFlag(_ flag: String, value: Bool = true) {
        flags[flag] = value
    }

    public func hasFlag(_ flag: String) -> Bool {
        return flags[flag] ?? false
    }

    // MARK: - Region Operations

    public func getRegionState(_ regionId: String) -> RegionRuntimeState? {
        return regionsState[regionId]
    }

    mutating func updateRegion(_ regionId: String, update: (inout RegionRuntimeState) -> Void) {
        if var state = regionsState[regionId] {
            update(&state)
            regionsState[regionId] = state
        }
    }

    // MARK: - Pressure Operations

    /// Check if pressure is at maximum (game over condition)
    public var isPressureMaximum: Bool {
        return pressure >= 100
    }
}

// MARK: - Region Runtime State

/// Mutable runtime state of a single region.
public struct RegionRuntimeState: Codable, Equatable {
    /// Reference to the region definition
    public let definitionId: String

    /// Current state (stable/borderland/breach)
    public var currentState: RegionStateType

    /// Number of times player has visited
    public var visitCount: Int

    /// Whether region is discovered/visible on map
    public var isDiscovered: Bool

    /// Region-specific flags
    public var flags: [String: Bool]

    public init(
        definitionId: String,
        currentState: RegionStateType = .stable,
        visitCount: Int = 0,
        isDiscovered: Bool = false,
        flags: [String: Bool] = [:]
    ) {
        self.definitionId = definitionId
        self.currentState = currentState
        self.visitCount = visitCount
        self.isDiscovered = isDiscovered
        self.flags = flags
    }

    // MARK: - Operations

    public mutating func visit() {
        visitCount += 1
        isDiscovered = true
    }

    public mutating func degrade() -> Bool {
        guard let newState = currentState.degraded else { return false }
        currentState = newState
        return true
    }

    public mutating func restore() -> Bool {
        guard let newState = currentState.restored else { return false }
        currentState = newState
        return true
    }
}

// MARK: - Anchor Runtime State

/// Mutable runtime state of a single anchor.
public struct AnchorRuntimeState: Codable, Equatable {
    /// Reference to the anchor definition
    public let definitionId: String

    /// Current integrity (0-100)
    public var integrity: Int

    /// Whether anchor is active/usable
    public var isActive: Bool

    /// Current alignment (light/neutral/dark), can change via defile/strengthen
    public var alignment: AnchorAlignment

    public init(
        definitionId: String,
        integrity: Int = 50,
        isActive: Bool = true,
        alignment: AnchorAlignment = .neutral
    ) {
        self.definitionId = definitionId
        self.integrity = integrity
        self.isActive = isActive
        self.alignment = alignment
    }

    // MARK: - Operations

    mutating func strengthen(amount: Int, maxIntegrity: Int) {
        integrity = min(maxIntegrity, integrity + amount)
    }

    mutating func weaken(amount: Int) {
        integrity = max(0, integrity - amount)
        if integrity == 0 {
            isActive = false
        }
    }

    /// Calculate resistance chance (0.0 to 1.0)
    public func resistanceChance(divisor: Int = 100) -> Double {
        guard isActive else { return 0 }
        return Double(integrity) / Double(divisor)
    }
}

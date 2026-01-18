import Foundation

// MARK: - World Runtime State
// Reference: Docs/ENGINE_ARCHITECTURE.md, Section 4.2
// Reference: Docs/MIGRATION_PLAN.md, Feature A2

/// Mutable runtime state of the game world.
/// References Definitions by ID, never stores Definition data.
struct WorldRuntimeState: Codable, Equatable {
    // MARK: - Current Position

    /// Current region ID
    var currentRegionId: String

    // MARK: - Time

    /// Current game time (days passed)
    var currentTime: Int

    // MARK: - Pressure

    /// Current world tension/pressure (0-100)
    var pressure: Int

    /// Days since last pressure escalation
    var daysSinceEscalation: Int

    // MARK: - Regions State

    /// Runtime state of each region (keyed by definition ID)
    var regionsState: [String: RegionRuntimeState]

    // MARK: - Anchors State

    /// Runtime state of each anchor (keyed by definition ID)
    var anchorsState: [String: AnchorRuntimeState]

    // MARK: - World Flags

    /// Global world flags
    var flags: [String: Bool]

    // MARK: - Initialization

    init(
        currentRegionId: String,
        currentTime: Int = 0,
        pressure: Int = 0,
        daysSinceEscalation: Int = 0,
        regionsState: [String: RegionRuntimeState] = [:],
        anchorsState: [String: AnchorRuntimeState] = [:],
        flags: [String: Bool] = [:]
    ) {
        self.currentRegionId = currentRegionId
        self.currentTime = currentTime
        self.pressure = pressure
        self.daysSinceEscalation = daysSinceEscalation
        self.regionsState = regionsState
        self.anchorsState = anchorsState
        self.flags = flags
    }

    // MARK: - Flag Operations

    mutating func setFlag(_ flag: String, value: Bool = true) {
        flags[flag] = value
    }

    func hasFlag(_ flag: String) -> Bool {
        return flags[flag] ?? false
    }

    // MARK: - Region Operations

    func getRegionState(_ regionId: String) -> RegionRuntimeState? {
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
    var isPressureMaximum: Bool {
        return pressure >= 100
    }
}

// MARK: - Region Runtime State

/// Mutable runtime state of a single region.
struct RegionRuntimeState: Codable, Equatable {
    /// Reference to the region definition
    let definitionId: String

    /// Current state (stable/borderland/breach)
    var currentState: RegionStateType

    /// Number of times player has visited
    var visitCount: Int

    /// Whether region is discovered/visible on map
    var isDiscovered: Bool

    /// Region-specific flags
    var flags: [String: Bool]

    init(
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

    mutating func visit() {
        visitCount += 1
        isDiscovered = true
    }

    mutating func degrade() -> Bool {
        guard let newState = currentState.degraded else { return false }
        currentState = newState
        return true
    }

    mutating func restore() -> Bool {
        guard let newState = currentState.restored else { return false }
        currentState = newState
        return true
    }
}

// MARK: - Anchor Runtime State

/// Mutable runtime state of a single anchor.
struct AnchorRuntimeState: Codable, Equatable {
    /// Reference to the anchor definition
    let definitionId: String

    /// Current integrity (0-100)
    var integrity: Int

    /// Whether anchor is active/usable
    var isActive: Bool

    init(
        definitionId: String,
        integrity: Int = 50,
        isActive: Bool = true
    ) {
        self.definitionId = definitionId
        self.integrity = integrity
        self.isActive = isActive
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
    func resistanceChance(divisor: Int = 100) -> Double {
        guard isActive else { return 0 }
        return Double(integrity) / Double(divisor)
    }
}

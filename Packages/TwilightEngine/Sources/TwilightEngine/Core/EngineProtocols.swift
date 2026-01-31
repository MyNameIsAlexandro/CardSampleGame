import Foundation

// MARK: - Game Engine v1.0 Core Protocols
// Setting-agnostic contracts for the game engine.
// The engine is the "processor", the game content is the "cartridge".

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Core Engine Types
// ═══════════════════════════════════════════════════════════════════════════════

/// Engine game phase enum
public enum EngineGamePhase: String, Codable {
    case setup
    case playing
    case paused
    case ended
}

/// Game end result
public enum GameEndResult: Equatable {
    case victory(endingId: String)
    case defeat(reason: String)
    case abandoned
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 1. Time System
// ═══════════════════════════════════════════════════════════════════════════════

/// Delegate for time progression events
public protocol TimeSystemDelegate: AnyObject {
    /// Called when time advances by one tick
    func onTimeTick(currentTime: Int, delta: Int)

    /// Called when a time threshold is crossed (e.g., every 3 days)
    func onTimeThreshold(currentTime: Int, threshold: Int)
}

/// Contract for time-consuming actions
public protocol TimedAction {
    /// Cost in time units (0 = instant)
    var timeCost: Int { get }
}

/// Time engine protocol - manages game time progression
public protocol TimeEngineProtocol {
    var currentTime: Int { get }
    var delegate: TimeSystemDelegate? { get set }

    /// Advance time by a cost. Invariant: cost > 0 (except instant actions)
    func advance(cost: Int)

    /// Check if a threshold interval has been reached
    func checkThreshold(_ interval: Int) -> Bool
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 2. Pressure System
// ═══════════════════════════════════════════════════════════════════════════════

/// Defines the rules for pressure/tension escalation
public protocol PressureRuleSet {
    var maxPressure: Int { get }
    var initialPressure: Int { get }

    /// Calculate pressure increase based on current state
    func calculateEscalation(currentPressure: Int, currentTime: Int) -> Int

    /// Check what effects trigger at current pressure level
    func checkThresholds(pressure: Int) -> [WorldEffect]

    /// Interval (in time units) for automatic pressure increase
    var escalationInterval: Int { get }

    /// Amount of pressure added per interval
    var escalationAmount: Int { get }
}

/// Effects that can be applied to the world
public enum WorldEffect: Equatable {
    case regionDegradation(probability: Double)
    case globalEvent(eventId: String)
    case phaseChange(newPhase: String)
    case anchorWeakening(amount: Int)
    case custom(id: String, parameters: [String: Any])

    public static func == (lhs: WorldEffect, rhs: WorldEffect) -> Bool {
        switch (lhs, rhs) {
        case (.regionDegradation(let p1), .regionDegradation(let p2)):
            return p1 == p2
        case (.globalEvent(let e1), .globalEvent(let e2)):
            return e1 == e2
        case (.phaseChange(let ph1), .phaseChange(let ph2)):
            return ph1 == ph2
        case (.anchorWeakening(let a1), .anchorWeakening(let a2)):
            return a1 == a2
        case (.custom(let id1, _), .custom(let id2, _)):
            return id1 == id2
        default:
            return false
        }
    }
}

/// Pressure engine protocol
public protocol PressureEngineProtocol {
    var currentPressure: Int { get }
    var rules: PressureRuleSet { get }

    /// Escalate pressure based on rules
    func escalate(at currentTime: Int)

    /// Manually adjust pressure
    func adjust(by delta: Int)

    /// Get current threshold effects
    func currentEffects() -> [WorldEffect]
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 3. Event System
// ═══════════════════════════════════════════════════════════════════════════════

/// Abstract event definition protocol (setting-agnostic)
/// Concrete implementation: Engine/Data/Definitions/EventDefinition.swift
public protocol EventDefinitionProtocol {
    associatedtype ChoiceType: ChoiceDefinitionProtocol

    var id: String { get }
    var title: String { get }
    var description: String { get }
    var choices: [ChoiceType] { get }

    /// Whether this event consumes time
    var isInstant: Bool { get }

    /// Whether this event can only occur once
    var isOneTime: Bool { get }

    /// Check if event can occur given current context
    func canOccur(in context: EventContext) -> Bool
}

/// Abstract choice definition protocol
/// Concrete implementation: Engine/Data/Definitions/EventDefinition.swift (ChoiceDefinition struct)
public protocol ChoiceDefinitionProtocol {
    associatedtype RequirementsType: RequirementsDefinitionProtocol
    associatedtype ConsequencesType: ConsequencesDefinitionProtocol

    var id: String { get }
    var text: String { get }
    var requirements: RequirementsType? { get }
    var consequences: ConsequencesType { get }
}

/// Abstract requirements protocol (gating conditions)
public protocol RequirementsDefinitionProtocol {
    func canMeet(with resources: ResourceProvider) -> Bool
}

/// Abstract consequences protocol (outcomes)
public protocol ConsequencesDefinitionProtocol {
    /// Resource changes (positive or negative)
    var resourceChanges: [String: Int] { get }

    /// Flags to set
    var flagsToSet: [String: Bool] { get }

    /// Custom effects
    var customEffects: [String] { get }
}

/// Context for event evaluation
public struct EventContext {
    public let currentLocation: String
    public let locationState: String
    public let pressure: Int
    public let flags: [String: Bool]
    public let resources: [String: Int]
    public let completedEvents: Set<String>

    public init(
        currentLocation: String,
        locationState: String,
        pressure: Int,
        flags: [String: Bool],
        resources: [String: Int],
        completedEvents: Set<String>
    ) {
        self.currentLocation = currentLocation
        self.locationState = locationState
        self.pressure = pressure
        self.flags = flags
        self.resources = resources
        self.completedEvents = completedEvents
    }
}

/// Provider for checking resources
public protocol ResourceProvider {
    func getValue(for resource: String) -> Int
    func hasFlag(_ flag: String) -> Bool
}

/// Event system protocol
public protocol EventSystemProtocol {
    associatedtype Event: EventDefinitionProtocol

    /// Get available events for current context
    func getAvailableEvents(in context: EventContext) -> [Event]

    /// Mark event as completed
    func markCompleted(eventId: String)

    /// Check if event was completed
    func isCompleted(eventId: String) -> Bool
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 4. Resolution System (Conflicts)
// ═══════════════════════════════════════════════════════════════════════════════

/// Types of challenges/conflicts
public enum ChallengeType: String, Codable {
    case combat
    case skillCheck
    case socialEncounter
    case puzzle
    case tradeOff
    case sacrifice
}

/// Abstract challenge definition
public protocol ChallengeDefinition {
    var type: ChallengeType { get }
    var difficulty: Int { get }
    var context: Any? { get }
}

/// Result of challenge resolution
public enum ResolutionResult<Reward, Penalty> {
    case success(Reward)
    case failure(Penalty)
    case partial(reward: Reward, penalty: Penalty)
    case cancelled
}

/// Conflict resolver protocol - pluggable resolution mechanics
public protocol ConflictResolverProtocol {
    associatedtype Challenge: ChallengeDefinition
    associatedtype Actor
    associatedtype Reward
    associatedtype Penalty

    /// Resolve a challenge. Can be async for animations/UI.
    func resolve(
        challenge: Challenge,
        actor: Actor
    ) async -> ResolutionResult<Reward, Penalty>
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 5. Progression System
// ═══════════════════════════════════════════════════════════════════════════════

/// Player path/alignment tracking
public protocol ProgressionPathProtocol {
    associatedtype PathType

    var currentPath: PathType { get }
    var pathValue: Int { get }

    /// Shift path by delta
    func shift(by delta: Int)

    /// Get unlocked capabilities for current path
    func unlockedCapabilities() -> [String]

    /// Get locked options for current path
    func lockedOptions() -> [String]
}

/// Progression tracker
public protocol ProgressionTrackerProtocol {
    /// Track capability unlock
    func unlock(capability: String)

    /// Track capability lock (path trade-off)
    func lock(capability: String)

    /// Check if capability is available
    func isUnlocked(_ capability: String) -> Bool
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 6. Victory/Defeat System
// ═══════════════════════════════════════════════════════════════════════════════

/// End condition types
public enum EndConditionType: String, Codable {
    case objectiveBased    // Complete specific goals
    case pressureBased     // Pressure reaches threshold
    case resourceBased     // Resource hits 0 or max
    case pathBased         // Player path determines ending
    case timeBased         // Time limit reached
}

/// End condition definition
public protocol EndConditionDefinition {
    var type: EndConditionType { get }
    var id: String { get }
    var isVictory: Bool { get }

    /// Check if condition is met
    func isMet(pressure: Int, resources: [String: Int], flags: [String: Bool], time: Int) -> Bool
}

/// Victory/Defeat checker protocol
public protocol EndGameCheckerProtocol {
    associatedtype Condition: EndConditionDefinition

    var conditions: [Condition] { get }

    /// Check all conditions, return first met (or nil)
    func checkConditions(
        pressure: Int,
        resources: [String: Int],
        flags: [String: Bool],
        time: Int
    ) -> Condition?
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 7. Economy System
// ═══════════════════════════════════════════════════════════════════════════════

/// Transaction for resource changes
public struct Transaction {
    let costs: [String: Int]
    let gains: [String: Int]
    let description: String

    init(costs: [String: Int] = [:], gains: [String: Int] = [:], description: String = "") {
        self.costs = costs
        self.gains = gains
        self.description = description
    }
}

/// Economy manager protocol
public protocol EconomyManagerProtocol {
    /// Check if transaction is affordable
    func canAfford(_ transaction: Transaction, resources: [String: Int]) -> Bool

    /// Process transaction, returns new resource values
    func process(_ transaction: Transaction, resources: inout [String: Int]) -> Bool
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 8. World State System
// ═══════════════════════════════════════════════════════════════════════════════

/// Location state (abstract)
public protocol LocationStateProtocol {
    var id: String { get }
    var name: String { get }
    var currentState: String { get }

    /// Can player rest here?
    var canRest: Bool { get }

    /// Can player trade here?
    var canTrade: Bool { get }

    /// Neighbor location IDs
    var neighborIds: [String] { get }
}

/// World state manager protocol
public protocol WorldStateManagerProtocol {
    associatedtype Location: LocationStateProtocol

    var locations: [Location] { get }
    var currentLocationId: String? { get }
    var flags: [String: Bool] { get }

    /// Move to location
    func moveTo(locationId: String) -> Int // Returns time cost

    /// Set flag
    func setFlag(_ flag: String, value: Bool)

    /// Get flag
    func hasFlag(_ flag: String) -> Bool

    /// Degrade location
    func degradeLocation(_ locationId: String)

    /// Improve location
    func improveLocation(_ locationId: String)
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 9. Quest System
// ═══════════════════════════════════════════════════════════════════════════════

/// Quest objective
public protocol QuestObjectiveProtocol {
    var id: String { get }
    var description: String { get }
    var isCompleted: Bool { get }

    /// Check if objective is complete based on flags
    func checkCompletion(flags: [String: Bool]) -> Bool
}

/// Quest definition
public protocol QuestDefinitionProtocol {
    associatedtype Objective: QuestObjectiveProtocol

    var id: String { get }
    var title: String { get }
    var isMain: Bool { get }
    var objectives: [Objective] { get }
    var isCompleted: Bool { get }

    /// Rewards on completion
    var rewardTransaction: Transaction { get }
}

/// Quest manager protocol
public protocol QuestManagerProtocol {
    associatedtype Quest: QuestDefinitionProtocol

    var activeQuests: [Quest] { get }
    var completedQuests: [String] { get }

    /// Check quest progress based on flags
    func checkProgress(flags: [String: Bool])

    /// Complete a quest
    func completeQuest(_ questId: String) -> Transaction?
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 10. Core Engine Protocol
// ═══════════════════════════════════════════════════════════════════════════════

/// Main game engine orchestrator protocol
public protocol GameEngineProtocol {
    associatedtype PlayerState
    associatedtype WorldManager: WorldStateManagerProtocol
    associatedtype EventSystem: EventSystemProtocol
    associatedtype Resolver: ConflictResolverProtocol
    associatedtype QuestManager: QuestManagerProtocol
    associatedtype EndChecker: EndGameCheckerProtocol

    // Subsystems
    var timeEngine: any TimeEngineProtocol { get }
    var pressureEngine: any PressureEngineProtocol { get }
    var worldManager: WorldManager { get }
    var eventSystem: EventSystem { get }
    var resolver: Resolver { get }
    var questManager: QuestManager { get }
    var endChecker: EndChecker { get }
    var economyManager: any EconomyManagerProtocol { get }

    // State
    var playerState: PlayerState { get }
    var isGameOver: Bool { get }
    var isVictory: Bool { get }

    // Core Loop
    func performAction(_ action: any TimedAction) async
    func worldTick()
    func checkEndConditions()
    func save()
}

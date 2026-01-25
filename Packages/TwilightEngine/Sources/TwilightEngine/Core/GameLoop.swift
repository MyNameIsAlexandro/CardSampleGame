import Foundation

// MARK: - Game Loop / Engine Orchestrator
// The central coordinator that runs the game engine.
// This is the "processor" - specific games are the "cartridge".

/// Engine game phase enum (distinct from legacy GamePhase in Models/GameState.swift)
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

// MARK: - Abstract Game Loop

/// Base class for game loop implementation
/// Subclass this for specific game implementations
open class GameLoopBase: ObservableObject {
    // MARK: - Published State

    @Published private(set) var currentPhase: EngineGamePhase = .setup
    @Published private(set) var isGameOver: Bool = false
    @Published private(set) var endResult: GameEndResult?

    // MARK: - Core Subsystems

    public let timeEngine: TimeEngine
    public let pressureEngine: PressureEngine
    public let economyManager: EconomyManager

    // MARK: - State

    /// Player resources (generic key-value store)
    @Published var playerResources: [String: Int] = [:]

    /// World flags
    @Published var worldFlags: [String: Bool] = [:]

    /// Completed event IDs
    private(set) var completedEvents: Set<String> = []

    // MARK: - Delegates

    weak var timeDelegate: TimeSystemDelegate? {
        didSet { timeEngine.delegate = timeDelegate }
    }

    // MARK: - Initialization

    public init(
        pressureRules: PressureRuleSet,
        timeThresholdInterval: Int = 3
    ) {
        self.timeEngine = TimeEngine(thresholdInterval: timeThresholdInterval)
        self.pressureEngine = PressureEngine(rules: pressureRules)
        self.economyManager = EconomyManager()
    }

    // MARK: - Core Loop Methods

    /// Start a new game
    public func startGame() {
        currentPhase = .playing
        isGameOver = false
        endResult = nil

        // Reset subsystems
        timeEngine.reset()
        pressureEngine.reset()
        economyManager.clearHistory()
        completedEvents.removeAll()

        // Subclass should override to set initial state
        setupInitialState()
    }

    /// Override in subclass to set initial player resources, world state, etc.
    open func setupInitialState() {
        // Subclass implementation
    }

    /// Main action execution - the canonical core loop
    public func performAction(_ action: any TimedAction) async {
        guard currentPhase == .playing else { return }

        // 1. Get time cost
        let cost = action.timeCost

        // 2. Advance time (triggers worldTick via delegate)
        timeEngine.advance(cost: cost)

        // 3. Check if time threshold crossed (every N days)
        if timeEngine.checkThreshold(pressureEngine.rules.escalationInterval) {
            // 4. Escalate pressure
            pressureEngine.escalate(at: timeEngine.currentTime)

            // 5. Apply world effects
            applyWorldEffects(pressureEngine.currentEffects())
        }

        // 6. Process action-specific logic (subclass)
        await processAction(action)

        // 7. Update quests (subclass)
        updateQuests()

        // 8. Check end conditions
        checkEndConditions()

        // 9. Auto-save (if configured)
        autoSave()
    }

    /// Override in subclass to handle specific actions
    public func processAction(_ action: any TimedAction) async {
        // Subclass implementation
    }

    /// Override in subclass to update quest progress
    public func updateQuests() {
        // Subclass implementation
    }

    /// Apply world effects from pressure thresholds
    public func applyWorldEffects(_ effects: [WorldEffect]) {
        for effect in effects {
            applyWorldEffect(effect)
        }
    }

    /// Apply a single world effect - override in subclass for custom effects
    public func applyWorldEffect(_ effect: WorldEffect) {
        switch effect {
        case .regionDegradation(let probability):
            // Subclass handles region degradation
            handleRegionDegradation(probability: probability)

        case .globalEvent(let eventId):
            // Trigger a global event
            triggerGlobalEvent(eventId)

        case .phaseChange(let newPhase):
            // Handle phase change
            handlePhaseChange(newPhase)

        case .anchorWeakening(let amount):
            // Weaken anchors
            weakenAnchors(amount: amount)

        case .custom(let id, let parameters):
            // Custom effect - subclass handles
            handleCustomEffect(id: id, parameters: parameters)
        }
    }

    // MARK: - Effect Handlers (Override in Subclass)

    public func handleRegionDegradation(probability: Double) {
        // Subclass implementation
    }

    public func triggerGlobalEvent(_ eventId: String) {
        // Subclass implementation
    }

    public func handlePhaseChange(_ newPhase: String) {
        // Subclass implementation
    }

    public func weakenAnchors(amount: Int) {
        // Subclass implementation
    }

    public func handleCustomEffect(id: String, parameters: [String: Any]) {
        // Subclass implementation
    }

    // MARK: - End Conditions

    /// Check victory and defeat conditions
    public func checkEndConditions() {
        // Check pressure-based defeat
        if pressureEngine.isAtMaximum {
            endGame(result: .defeat(reason: "pressure_maximum"))
            return
        }

        // Check resource-based defeat (e.g., health = 0)
        if let health = playerResources["health"], health <= 0 {
            endGame(result: .defeat(reason: "health_zero"))
            return
        }

        // Subclass should override for victory conditions
        checkVictoryConditions()
    }

    /// Override in subclass for game-specific victory conditions
    public func checkVictoryConditions() {
        // Subclass implementation
    }

    /// End the game
    public func endGame(result: GameEndResult) {
        currentPhase = .ended
        isGameOver = true
        endResult = result
    }

    // MARK: - Resource Management

    /// Get a resource value
    public func getResource(_ key: String) -> Int {
        return playerResources[key] ?? 0
    }

    /// Set a resource value
    public func setResource(_ key: String, value: Int) {
        playerResources[key] = value
    }

    /// Modify a resource by delta
    public func modifyResource(_ key: String, by delta: Int) {
        let current = playerResources[key] ?? 0
        playerResources[key] = current + delta
    }

    /// Process a transaction
    public func processTransaction(_ transaction: Transaction) -> Bool {
        return economyManager.process(transaction, resources: &playerResources)
    }

    // MARK: - Flag Management

    /// Set a world flag
    public func setFlag(_ flag: String, value: Bool = true) {
        worldFlags[flag] = value
    }

    /// Check a world flag
    public func hasFlag(_ flag: String) -> Bool {
        return worldFlags[flag] ?? false
    }

    // MARK: - Event Tracking

    /// Mark an event as completed
    public func markEventCompleted(_ eventId: String) {
        completedEvents.insert(eventId)
    }

    /// Check if event was completed
    public func isEventCompleted(_ eventId: String) -> Bool {
        return completedEvents.contains(eventId)
    }

    // MARK: - Save/Load

    public func autoSave() {
        // Subclass implementation
    }

    public func save() {
        // Subclass implementation
    }

    public func load() {
        // Subclass implementation
    }

    // MARK: - Context Building

    /// Build event context for event filtering
    public func buildEventContext(
        currentLocation: String,
        locationState: String
    ) -> EventContext {
        return EventContext(
            currentLocation: currentLocation,
            locationState: locationState,
            pressure: pressureEngine.currentPressure,
            flags: worldFlags,
            resources: playerResources,
            completedEvents: completedEvents
        )
    }
}

// MARK: - Action Types

/// Standard game actions
public enum StandardAction: TimedAction {
    case travel(from: String, to: String, isNeighbor: Bool)
    case rest
    case explore(instant: Bool)
    case trade
    case interact(targetId: String)
    case combat(enemyId: String)
    case useAbility(abilityId: String)
    case custom(id: String, cost: Int)

    public var timeCost: Int {
        switch self {
        case .travel(_, _, let isNeighbor):
            return isNeighbor ? 1 : 2
        case .rest:
            return 1
        case .explore(let instant):
            return instant ? 0 : 1
        case .trade:
            return 1
        case .interact:
            return 1
        case .combat:
            return 1
        case .useAbility:
            return 1
        case .custom(_, let cost):
            return cost
        }
    }
}

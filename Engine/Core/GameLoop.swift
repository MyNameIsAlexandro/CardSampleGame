import Foundation

// MARK: - Game Loop / Engine Orchestrator
// The central coordinator that runs the game engine.
// This is the "processor" - specific games are the "cartridge".

/// Game phase enum (generic)
enum GamePhase: String, Codable {
    case setup
    case playing
    case paused
    case ended
}

/// Game end result
enum GameEndResult: Equatable {
    case victory(endingId: String)
    case defeat(reason: String)
    case abandoned
}

// MARK: - Abstract Game Loop

/// Base class for game loop implementation
/// Subclass this for specific game implementations
class GameLoopBase: ObservableObject {
    // MARK: - Published State

    @Published private(set) var currentPhase: GamePhase = .setup
    @Published private(set) var isGameOver: Bool = false
    @Published private(set) var endResult: GameEndResult?

    // MARK: - Core Subsystems

    let timeEngine: TimeEngine
    let pressureEngine: PressureEngine
    let economyManager: EconomyManager

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

    init(
        pressureRules: PressureRuleSet,
        timeThresholdInterval: Int = 3
    ) {
        self.timeEngine = TimeEngine(thresholdInterval: timeThresholdInterval)
        self.pressureEngine = PressureEngine(rules: pressureRules)
        self.economyManager = EconomyManager()
    }

    // MARK: - Core Loop Methods

    /// Start a new game
    func startGame() {
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
    func setupInitialState() {
        // Subclass implementation
    }

    /// Main action execution - the canonical core loop
    func performAction(_ action: any TimedAction) async {
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
    func processAction(_ action: any TimedAction) async {
        // Subclass implementation
    }

    /// Override in subclass to update quest progress
    func updateQuests() {
        // Subclass implementation
    }

    /// Apply world effects from pressure thresholds
    func applyWorldEffects(_ effects: [WorldEffect]) {
        for effect in effects {
            applyWorldEffect(effect)
        }
    }

    /// Apply a single world effect - override in subclass for custom effects
    func applyWorldEffect(_ effect: WorldEffect) {
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

    func handleRegionDegradation(probability: Double) {
        // Subclass implementation
    }

    func triggerGlobalEvent(_ eventId: String) {
        // Subclass implementation
    }

    func handlePhaseChange(_ newPhase: String) {
        // Subclass implementation
    }

    func weakenAnchors(amount: Int) {
        // Subclass implementation
    }

    func handleCustomEffect(id: String, parameters: [String: Any]) {
        // Subclass implementation
    }

    // MARK: - End Conditions

    /// Check victory and defeat conditions
    func checkEndConditions() {
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
    func checkVictoryConditions() {
        // Subclass implementation
    }

    /// End the game
    func endGame(result: GameEndResult) {
        currentPhase = .ended
        isGameOver = true
        endResult = result
    }

    // MARK: - Resource Management

    /// Get a resource value
    func getResource(_ key: String) -> Int {
        return playerResources[key] ?? 0
    }

    /// Set a resource value
    func setResource(_ key: String, value: Int) {
        playerResources[key] = value
    }

    /// Modify a resource by delta
    func modifyResource(_ key: String, by delta: Int) {
        let current = playerResources[key] ?? 0
        playerResources[key] = current + delta
    }

    /// Process a transaction
    func processTransaction(_ transaction: Transaction) -> Bool {
        return economyManager.process(transaction, resources: &playerResources)
    }

    // MARK: - Flag Management

    /// Set a world flag
    func setFlag(_ flag: String, value: Bool = true) {
        worldFlags[flag] = value
    }

    /// Check a world flag
    func hasFlag(_ flag: String) -> Bool {
        return worldFlags[flag] ?? false
    }

    // MARK: - Event Tracking

    /// Mark an event as completed
    func markEventCompleted(_ eventId: String) {
        completedEvents.insert(eventId)
    }

    /// Check if event was completed
    func isEventCompleted(_ eventId: String) -> Bool {
        return completedEvents.contains(eventId)
    }

    // MARK: - Save/Load

    func autoSave() {
        // Subclass implementation
    }

    func save() {
        // Subclass implementation
    }

    func load() {
        // Subclass implementation
    }

    // MARK: - Context Building

    /// Build event context for event filtering
    func buildEventContext(
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
enum StandardAction: TimedAction {
    case travel(from: String, to: String, isNeighbor: Bool)
    case rest
    case explore(instant: Bool)
    case trade
    case interact(targetId: String)
    case combat(enemyId: String)
    case useAbility(abilityId: String)
    case custom(id: String, cost: Int)

    var timeCost: Int {
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

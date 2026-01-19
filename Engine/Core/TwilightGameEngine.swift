import Foundation
import Combine

// MARK: - Twilight Marches Game Engine
// The central game orchestrator - ALL game actions go through here

/// Main game engine for Twilight Marches
/// UI should NEVER mutate state directly - always go through performAction()
final class TwilightGameEngine: ObservableObject {

    // MARK: - Published State (for UI binding)
    // Audit v1.1 Issue #1, #8: UI reads directly from Engine, not WorldState

    @Published private(set) var currentDay: Int = 0
    @Published private(set) var worldTension: Int = 30
    @Published private(set) var currentRegionId: UUID?
    @Published private(set) var isGameOver: Bool = false
    @Published private(set) var gameResult: GameEndResult?

    @Published private(set) var currentEventId: UUID?
    @Published private(set) var isInCombat: Bool = false

    @Published private(set) var lastActionResult: ActionResult?

    // MARK: - Published State for UI (Audit v1.1)

    /// All regions with their current state - UI reads this directly
    @Published private(set) var publishedRegions: [UUID: EngineRegionState] = [:]

    /// Player stats - UI reads these directly instead of Player model
    @Published private(set) var playerHealth: Int = 10
    @Published private(set) var playerMaxHealth: Int = 10
    @Published private(set) var playerFaith: Int = 3
    @Published private(set) var playerBalance: Int = 50

    /// World flags - for quest/event conditions
    @Published private(set) var publishedWorldFlags: [String: Bool] = [:]

    // MARK: - UI Convenience Accessors (Audit v1.1)

    /// Get regions as sorted array for UI iteration
    var regionsArray: [EngineRegionState] {
        publishedRegions.values.sorted { $0.name < $1.name }
    }

    /// Get current region
    var currentRegion: EngineRegionState? {
        guard let id = currentRegionId else { return nil }
        return publishedRegions[id]
    }

    /// Check if player can afford faith cost
    func canAffordFaith(_ cost: Int) -> Bool {
        return playerFaith >= cost
    }

    /// Check if region is neighbor to current region
    func isNeighbor(regionId: UUID) -> Bool {
        guard let current = currentRegion else { return false }
        return current.neighborIds.contains(regionId)
    }

    // MARK: - Core Subsystems

    private let timeEngine: TimeEngine
    private let pressureEngine: PressureEngine
    private let economyManager: EconomyManager

    // MARK: - State Adapters

    /// Adapter to sync with legacy WorldState (during migration)
    /// Engine owns these adapters (not weak to prevent immediate deallocation)
    private var worldStateAdapter: WorldStateEngineAdapter?

    /// Player adapter
    private var playerAdapter: PlayerEngineAdapter?

    // MARK: - Internal State

    private var regions: [UUID: EngineRegionState] = [:]
    private var completedEventIds: Set<UUID> = []
    private var worldFlags: [String: Bool] = [:]
    private var questStages: [String: Int] = [:]

    // MARK: - Configuration Constants

    private let tensionTickInterval: Int = 3
    // baseTensionIncrease removed - using TwilightPressureRules.calculateTensionIncrease() (Audit v1.1 Issue #6)
    private let restHealAmount: Int = 3
    private let anchorStrengthenCost: Int = 5
    private let anchorStrengthenAmount: Int = 20

    // MARK: - Initialization

    init() {
        self.timeEngine = TimeEngine(thresholdInterval: tensionTickInterval)
        self.pressureEngine = PressureEngine(rules: TwilightPressureRules())
        self.economyManager = EconomyManager()
    }

    // MARK: - Setup

    /// Connect to legacy WorldState for bidirectional sync
    func connectToLegacy(worldState: WorldState, player: Player) {
        self.worldStateAdapter = WorldStateEngineAdapter(worldState: worldState, engine: self)
        self.playerAdapter = PlayerEngineAdapter(player: player, engine: self)

        // Initial sync from legacy
        syncFromLegacy()
    }

    /// Sync engine state from legacy models
    func syncFromLegacy() {
        guard let adapter = worldStateAdapter else { return }

        currentDay = adapter.worldState.daysPassed
        worldTension = adapter.worldState.worldTension
        currentRegionId = adapter.worldState.currentRegionId

        // Sync regions (both internal and published)
        var newRegions: [UUID: EngineRegionState] = [:]
        for region in adapter.worldState.regions {
            newRegions[region.id] = EngineRegionState(from: region)
        }
        regions = newRegions
        publishedRegions = newRegions  // Audit v1.1: publish for UI

        // Sync flags (both internal and published)
        worldFlags = adapter.worldState.worldFlags
        publishedWorldFlags = worldFlags  // Audit v1.1: publish for UI

        // Sync completed events from GameEvent.completed
        for event in adapter.worldState.allEvents where event.completed {
            completedEventIds.insert(event.id)
        }

        // Sync player stats (Audit v1.1: publish for UI)
        if let player = playerAdapter?.player {
            playerHealth = player.health
            playerMaxHealth = player.maxHealth
            playerFaith = player.faith
            playerBalance = player.balance
        }

        // CRITICAL: Sync pressure engine state to prevent duplicate threshold events
        // PressureEngine tracks which thresholds have fired to avoid repeats
        // After load, we reconstruct this from the current pressure value
        pressureEngine.setPressure(worldTension)
        pressureEngine.syncTriggeredThresholdsFromPressure()
    }

    // MARK: - Main Action Entry Point

    /// Perform a game action - THE ONLY WAY to change game state
    /// Returns result with all state changes
    @discardableResult
    func performAction(_ action: TwilightGameAction) -> ActionResult {
        // 0. Pre-validation
        guard !isGameOver else {
            return .failure(.gameNotInProgress)
        }

        // 1. Validate action
        let validationResult = validateAction(action)
        if let error = validationResult {
            return .failure(error)
        }

        // 2. Calculate actual time cost
        let timeCost = calculateTimeCost(for: action)

        // 3. Execute action and collect state changes
        var stateChanges: [StateChange] = []
        var triggeredEvents: [UUID] = []
        var newCurrentEvent: UUID? = nil
        var combatStarted = false

        // 4. Advance time (if action costs time)
        if timeCost > 0 {
            let timeChanges = advanceTime(by: timeCost)
            stateChanges.append(contentsOf: timeChanges)
        }

        // 5. Execute action-specific logic
        switch action {
        case .travel(let toRegionId):
            let (changes, events) = executeTravel(to: toRegionId)
            stateChanges.append(contentsOf: changes)
            triggeredEvents.append(contentsOf: events)
            if let event = events.first {
                newCurrentEvent = event
            }

        case .rest:
            let changes = executeRest()
            stateChanges.append(contentsOf: changes)

        case .explore:
            let (changes, events) = executeExplore()
            stateChanges.append(contentsOf: changes)
            triggeredEvents.append(contentsOf: events)
            if let event = events.first {
                newCurrentEvent = event
            }

        case .trade:
            // Trade handled by UI directly for now (market system)
            break

        case .strengthenAnchor:
            let changes = executeStrengthenAnchor()
            stateChanges.append(contentsOf: changes)

        case .chooseEventOption(let eventId, let choiceIndex):
            let changes = executeEventChoice(eventId: eventId, choiceIndex: choiceIndex)
            stateChanges.append(contentsOf: changes)
            currentEventId = nil

        case .resolveMiniGame(let input):
            let changes = executeMiniGameInput(input)
            stateChanges.append(contentsOf: changes)

        case .startCombat:
            combatStarted = true
            isInCombat = true
            // Combat initialization

        case .playCard, .endCombatTurn:
            // Combat actions - handled by combat subsystem
            break

        case .skipTurn:
            // Just time passes
            break

        case .custom:
            // Custom action handling
            break
        }

        // 6. Check quest progress
        let questChanges = checkQuestProgress()
        stateChanges.append(contentsOf: questChanges)

        // 7. Check end conditions
        if let endResult = checkEndConditions() {
            isGameOver = true
            gameResult = endResult
            return .gameOver(endResult)
        }

        // 8. Sync to legacy (during migration period)
        syncToLegacy(changes: stateChanges)

        // 9. Update published state for UI (Audit v1.1)
        updatePublishedState()

        // 10. Build and return result
        let result = ActionResult(
            success: true,
            error: nil,
            stateChanges: stateChanges,
            triggeredEvents: triggeredEvents,
            currentEvent: newCurrentEvent,
            combatStarted: combatStarted,
            gameEnded: nil
        )

        lastActionResult = result
        return result
    }

    // MARK: - Validation

    private func validateAction(_ action: TwilightGameAction) -> ActionError? {
        switch action {
        case .travel(let toRegionId):
            return validateTravel(to: toRegionId)

        case .rest:
            return validateRest()

        case .explore:
            if isInCombat { return .combatInProgress }
            return nil

        case .trade:
            return validateTrade()

        case .strengthenAnchor:
            return validateStrengthenAnchor()

        case .chooseEventOption(let eventId, let choiceIndex):
            return validateEventChoice(eventId: eventId, choiceIndex: choiceIndex)

        case .startCombat:
            if isInCombat { return .combatInProgress }
            return nil

        case .playCard, .endCombatTurn:
            if !isInCombat { return .noActiveCombat }
            return nil

        default:
            return nil
        }
    }

    private func validateTravel(to regionId: UUID) -> ActionError? {
        guard let currentId = currentRegionId,
              let currentRegion = regions[currentId] else {
            return .invalidAction(reason: "No current region")
        }

        // Check if target is neighbor
        if !currentRegion.neighborIds.contains(regionId) {
            return .regionNotNeighbor(regionId: regionId)
        }

        // Check if player can travel (health > 0, etc.)
        if let player = playerAdapter?.player, player.health <= 0 {
            return .healthTooLow
        }

        return nil
    }

    private func validateRest() -> ActionError? {
        guard let currentId = currentRegionId,
              let region = regions[currentId] else {
            return .invalidAction(reason: "No current region")
        }

        // Check if region allows rest
        if region.state == .breach {
            return .actionNotAvailableInRegion(action: "rest", regionType: "breach")
        }

        return nil
    }

    private func validateTrade() -> ActionError? {
        guard let currentId = currentRegionId,
              let region = regions[currentId] else {
            return .invalidAction(reason: "No current region")
        }

        if !region.canTrade {
            return .actionNotAvailableInRegion(action: "trade", regionType: region.type.rawValue)
        }

        return nil
    }

    private func validateStrengthenAnchor() -> ActionError? {
        guard let currentId = currentRegionId,
              let region = regions[currentId] else {
            return .invalidAction(reason: "No current region")
        }

        if region.anchor == nil {
            return .actionNotAvailableInRegion(action: "strengthen anchor", regionType: "no anchor")
        }

        // Check resource cost
        let cost = anchorStrengthenCost
        if let player = playerAdapter?.player, player.faith < cost {
            return .insufficientResources(resource: "faith", required: cost, available: player.faith)
        }

        return nil
    }

    private func validateEventChoice(eventId: UUID, choiceIndex: Int) -> ActionError? {
        guard currentEventId == eventId else {
            return .eventNotFound(eventId: eventId)
        }

        // Additional choice validation would go here
        return nil
    }

    // MARK: - Time Cost Calculation

    private func calculateTimeCost(for action: TwilightGameAction) -> Int {
        switch action {
        case .travel(let toRegionId):
            guard let currentId = currentRegionId,
                  let currentRegion = regions[currentId] else {
                return 1
            }
            // Neighbor = 1 day, far = 2 days
            return currentRegion.neighborIds.contains(toRegionId) ? 1 : 2

        default:
            return action.timeCost
        }
    }

    // MARK: - Time Advancement

    private func advanceTime(by days: Int) -> [StateChange] {
        var changes: [StateChange] = []

        for _ in 0..<days {
            currentDay += 1
            changes.append(.dayAdvanced(newDay: currentDay))

            // Check tension tick (every 3 days)
            if currentDay > 0 && currentDay % tensionTickInterval == 0 {
                let tensionIncrease = calculateTensionIncrease()
                worldTension = min(100, worldTension + tensionIncrease)
                changes.append(.tensionChanged(delta: tensionIncrease, newValue: worldTension))

                // World degradation
                let degradationChanges = processWorldDegradation()
                changes.append(contentsOf: degradationChanges)
            }
        }

        return changes
    }

    private func calculateTensionIncrease() -> Int {
        // Use TwilightPressureRules as single source of truth (Audit v1.1 Issue #6)
        return TwilightPressureRules.calculateTensionIncrease(daysPassed: currentDay)
    }

    private func processWorldDegradation() -> [StateChange] {
        var changes: [StateChange] = []

        // Degradation probability increases with world tension
        // (probability logic can be used when implementing random degradation checks)

        // Select region to degrade based on weights
        let degradableRegions = regions.values.filter {
            $0.state == .borderland || $0.state == .breach
        }

        guard !degradableRegions.isEmpty else { return changes }

        // Weighted selection using WorldRNG
        let weights = degradableRegions.map { DegradationRules.current.selectionWeight(for: $0.state) }
        let totalWeight = weights.reduce(0, +)

        if totalWeight > 0 {
            let roll = WorldRNG.shared.nextInt(in: 0..<totalWeight)
            var cumulative = 0
            for (index, weight) in weights.enumerated() {
                cumulative += weight
                if roll < cumulative {
                    let region = Array(degradableRegions)[index]

                    // Check anchor resistance using probability
                    let anchorIntegrity = region.anchor?.integrity ?? 0
                    let resistProb = DegradationRules.current.resistanceProbability(anchorIntegrity: anchorIntegrity)
                    let resistRoll = Double(WorldRNG.shared.nextInt(in: 0..<100)) / 100.0

                    if resistRoll >= resistProb {
                        // Anchor failed to resist - degrade region
                        if var mutableRegion = regions[region.id] {
                            let newState = degradeState(mutableRegion.state)
                            mutableRegion.state = newState
                            regions[region.id] = mutableRegion
                            changes.append(.regionStateChanged(regionId: region.id, newState: newState.rawValue))
                        }
                    }
                    break
                }
            }
        }

        return changes
    }

    private func degradeState(_ state: RegionState) -> RegionState {
        switch state {
        case .stable: return .borderland
        case .borderland: return .breach
        case .breach: return .breach  // Can't degrade further
        }
    }

    // MARK: - Action Execution

    private func executeTravel(to regionId: UUID) -> ([StateChange], [UUID]) {
        var changes: [StateChange] = []
        var events: [UUID] = []

        // Update current region
        currentRegionId = regionId
        changes.append(.regionChanged(regionId: regionId))

        // Generate travel event (if any)
        if let event = generateEvent(for: regionId, trigger: .arrival) {
            events.append(event)
            currentEventId = event
        }

        return (changes, events)
    }

    private func executeRest() -> [StateChange] {
        var changes: [StateChange] = []

        // Heal player
        if let player = playerAdapter?.player {
            let healAmount = restHealAmount
            let newHealth = min(player.maxHealth, player.health + healAmount)
            let delta = newHealth - player.health
            playerAdapter?.updateHealth(newHealth)
            changes.append(.healthChanged(delta: delta, newValue: newHealth))
        }

        return changes
    }

    private func executeExplore() -> ([StateChange], [UUID]) {
        let changes: [StateChange] = []
        var events: [UUID] = []

        guard let regionId = currentRegionId else {
            return (changes, events)
        }

        // Generate exploration event
        if let event = generateEvent(for: regionId, trigger: .exploration) {
            events.append(event)
            currentEventId = event
        }

        return (changes, events)
    }

    private func executeStrengthenAnchor() -> [StateChange] {
        var changes: [StateChange] = []

        guard let regionId = currentRegionId,
              var region = regions[regionId],
              var anchor = region.anchor else {
            return changes
        }

        // Spend faith
        let cost = anchorStrengthenCost
        if let player = playerAdapter?.player {
            let newFaith = player.faith - cost
            playerAdapter?.updateFaith(newFaith)
            changes.append(.faithChanged(delta: -cost, newValue: newFaith))
        }

        // Strengthen anchor
        let strengthAmount = anchorStrengthenAmount
        let newIntegrity = min(100, anchor.integrity + strengthAmount)
        let delta = newIntegrity - anchor.integrity
        anchor.integrity = newIntegrity
        region.anchor = anchor
        regions[regionId] = region

        changes.append(.anchorIntegrityChanged(anchorId: anchor.id, delta: delta, newValue: newIntegrity))

        return changes
    }

    private func executeEventChoice(eventId: UUID, choiceIndex: Int) -> [StateChange] {
        var changes: [StateChange] = []

        // Get event and choice consequences from adapter
        if let consequences = worldStateAdapter?.getEventConsequences(eventId: eventId, choiceIndex: choiceIndex) {
            // Apply consequences
            changes.append(contentsOf: applyConsequences(consequences))
        }

        // Mark event completed if oneTime
        completedEventIds.insert(eventId)
        changes.append(.eventCompleted(eventId: eventId))

        currentEventId = nil

        return changes
    }

    private func executeMiniGameInput(_ input: MiniGameInput) -> [StateChange] {
        var changes: [StateChange] = []

        // Apply bonus rewards
        for (resource, amount) in input.bonusRewards {
            switch resource {
            case "health":
                if let player = playerAdapter?.player {
                    let newHealth = min(player.maxHealth, player.health + amount)
                    playerAdapter?.updateHealth(newHealth)
                    changes.append(.healthChanged(delta: amount, newValue: newHealth))
                }
            case "faith":
                if let player = playerAdapter?.player {
                    let newFaith = player.faith + amount
                    playerAdapter?.updateFaith(newFaith)
                    changes.append(.faithChanged(delta: amount, newValue: newFaith))
                }
            default:
                break
            }
        }

        return changes
    }

    // MARK: - Consequences

    private func applyConsequences(_ consequences: EventConsequences) -> [StateChange] {
        var changes: [StateChange] = []

        if let player = playerAdapter?.player {
            // Health
            if let healthDelta = consequences.healthChange, healthDelta != 0 {
                let newHealth = max(0, min(player.maxHealth, player.health + healthDelta))
                playerAdapter?.updateHealth(newHealth)
                changes.append(.healthChanged(delta: healthDelta, newValue: newHealth))
            }

            // Faith
            if let faithDelta = consequences.faithChange, faithDelta != 0 {
                let newFaith = max(0, player.faith + faithDelta)
                playerAdapter?.updateFaith(newFaith)
                changes.append(.faithChanged(delta: faithDelta, newValue: newFaith))
            }

            // Balance
            if let balanceDelta = consequences.balanceChange, balanceDelta != 0 {
                let newBalance = max(0, min(100, player.balance + balanceDelta))
                playerAdapter?.updateBalance(newBalance)
                changes.append(.balanceChanged(delta: balanceDelta, newValue: newBalance))
            }
        }

        // Tension
        if let tensionDelta = consequences.tensionChange, tensionDelta != 0 {
            worldTension = max(0, min(100, worldTension + tensionDelta))
            changes.append(.tensionChanged(delta: tensionDelta, newValue: worldTension))
        }

        // Flags (setFlags is [String: Bool]?)
        if let flagsToSet = consequences.setFlags {
            for (flag, value) in flagsToSet {
                worldFlags[flag] = value
                changes.append(.flagSet(key: flag, value: value))
            }
        }

        return changes
    }

    // MARK: - Event Generation

    private func generateEvent(for regionId: UUID, trigger: EventTrigger) -> UUID? {
        // Delegate to WorldState adapter for now (uses existing event system)
        return worldStateAdapter?.generateEvent(for: regionId, trigger: trigger)
    }

    // MARK: - Quest Progress

    private func checkQuestProgress() -> [StateChange] {
        // Delegate to WorldState adapter
        return worldStateAdapter?.checkQuestProgress() ?? []
    }

    // MARK: - End Conditions

    private func checkEndConditions() -> GameEndResult? {
        // Defeat: tension 100%
        if worldTension >= 100 {
            return .defeat(reason: "Напряжение мира достигло максимума")
        }

        // Defeat: health 0
        if let player = playerAdapter?.player, player.health <= 0 {
            return .defeat(reason: "Герой погиб")
        }

        // Victory: main quest completed (check flags)
        if worldFlags["act1_completed"] == true {
            return .victory(endingId: "act1_standard")
        }

        return nil
    }

    // MARK: - Legacy Sync

    private func syncToLegacy(changes: [StateChange]) {
        worldStateAdapter?.applyChanges(changes)
        playerAdapter?.syncFromEngine()
    }

    // MARK: - Published State Update (Audit v1.1)

    /// Update all published properties from internal state
    /// Called after actions to keep UI in sync
    private func updatePublishedState() {
        // Update regions
        publishedRegions = regions

        // Update flags
        publishedWorldFlags = worldFlags

        // Update player stats from adapter
        if let player = playerAdapter?.player {
            playerHealth = player.health
            playerMaxHealth = player.maxHealth
            playerFaith = player.faith
            playerBalance = player.balance
        }
    }
}

// MARK: - Event Trigger

enum EventTrigger {
    case arrival
    case exploration
    case combat
    case quest
    case time
}

// MARK: - Engine Region State (Bridge from Legacy)

/// Объединённое состояние региона для UI (Audit v1.1 Issue #9)
///
/// Это ПРЕДПОЧТИТЕЛЬНАЯ модель для UI:
/// - Создаётся из legacy Region через TwilightGameEngine.syncFromLegacy()
/// - Публикуется через engine.publishedRegions
/// - UI должен использовать engine.regionsArray или engine.currentRegion
///
/// Архитектура моделей:
/// - `RegionDefinition` - статические данные (ContentProvider)
/// - `RegionRuntimeState` - изменяемое состояние (WorldRuntimeState)
/// - `EngineRegionState` - объединённое для UI (этот struct)
/// - `Region` (legacy) - persistence и совместимость
struct EngineRegionState {
    let id: UUID
    let name: String
    let type: RegionType
    var state: RegionState
    var anchor: EngineAnchorState?
    let neighborIds: [UUID]
    var canTrade: Bool

    init(from region: Region) {
        self.id = region.id
        self.name = region.name
        self.type = region.type
        self.state = region.state
        self.anchor = region.anchor.map { EngineAnchorState(from: $0) }
        self.neighborIds = region.neighborIds
        self.canTrade = region.canTrade
    }
}

// MARK: - Engine Anchor State (Bridge from Legacy)

/// Internal state for engine anchor tracking (bridges from legacy Anchor model)
struct EngineAnchorState {
    let id: UUID
    let name: String
    var integrity: Int

    init(from anchor: Anchor) {
        self.id = anchor.id
        self.name = anchor.name
        self.integrity = anchor.integrity
    }
}

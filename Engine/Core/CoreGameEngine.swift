import Foundation
import Combine

// MARK: - Core Game Engine

/// Content-agnostic game engine that loads all configuration from Content Packs
/// This is the generic engine that can run ANY content pack, not just Twilight Marches.
///
/// Usage:
/// 1. Load a content pack into ContentRegistry
/// 2. Create CoreGameEngine with the registry
/// 3. Initialize game with initializeNewGame()
///
/// All game-specific content (regions, events, balance) comes from the loaded pack.
final class CoreGameEngine: ObservableObject {

    // MARK: - Published State (for UI binding)

    @Published private(set) var currentDay: Int = 0
    @Published private(set) var worldTension: Int = 0
    @Published private(set) var currentRegionId: String?
    @Published private(set) var isGameOver: Bool = false
    @Published private(set) var gameResult: GameEndResult?

    @Published private(set) var currentEventId: String?
    @Published private(set) var isInCombat: Bool = false
    @Published private(set) var lastActionResult: ActionResult?

    /// All regions with their current state
    @Published private(set) var regions: [String: CoreRegionState] = [:]

    /// Player stats
    @Published private(set) var playerHealth: Int = 10
    @Published private(set) var playerMaxHealth: Int = 10
    @Published private(set) var playerFaith: Int = 3
    @Published private(set) var playerMaxFaith: Int = 10
    @Published private(set) var playerBalance: Int = 50
    @Published private(set) var playerName: String = "Hero"

    /// World flags for quest/event conditions
    @Published private(set) var worldFlags: [String: Bool] = [:]

    /// Current event being displayed
    @Published private(set) var currentEvent: EventDefinition?

    /// Active quests
    @Published private(set) var activeQuests: [QuestDefinition] = []

    /// Light/Dark balance of the world
    @Published private(set) var lightDarkBalance: Int = 50

    // MARK: - Content Source

    /// Content registry - source of all game content
    private let contentRegistry: ContentRegistry

    /// Balance configuration from loaded pack
    private var balanceConfig: BalanceConfiguration

    // MARK: - Internal State

    private var completedEventIds: Set<String> = []
    private var completedQuestIds: Set<String> = []
    private var questStages: [String: Int] = [:]
    private var eventLog: [CoreEventLogEntry] = []

    // MARK: - Computed Properties

    /// Get regions as sorted array for UI
    var regionsArray: [CoreRegionState] {
        regions.values.sorted { $0.name < $1.name }
    }

    /// Get current region
    var currentRegion: CoreRegionState? {
        guard let id = currentRegionId else { return nil }
        return regions[id]
    }

    /// Check if player can afford faith cost
    func canAffordFaith(_ cost: Int) -> Bool {
        return playerFaith >= cost
    }

    /// Check if region is neighbor to current region
    func isNeighbor(regionId: String) -> Bool {
        guard let current = currentRegion else { return false }
        return current.neighborIds.contains(regionId)
    }

    // MARK: - Initialization

    /// Create engine with content registry
    /// - Parameter registry: Content registry with loaded packs
    init(registry: ContentRegistry = .shared) {
        self.contentRegistry = registry
        self.balanceConfig = registry.getBalanceConfig() ?? .default
    }

    // MARK: - Game Initialization

    /// Initialize a new game from loaded content packs
    /// - Parameters:
    ///   - playerName: Name of the player character
    ///   - startingRegionId: Optional override for starting region
    func initializeNewGame(playerName: String = "Hero", startingRegionId: String? = nil) {
        // Reset state
        isGameOver = false
        gameResult = nil
        currentEventId = nil
        currentEvent = nil
        isInCombat = false

        // Load balance config from pack
        balanceConfig = contentRegistry.getBalanceConfig() ?? .default

        // Setup player from balance config
        self.playerName = playerName
        playerHealth = balanceConfig.resources.startingHealth
        playerMaxHealth = balanceConfig.resources.maxHealth
        playerFaith = balanceConfig.resources.startingFaith
        playerMaxFaith = balanceConfig.resources.maxFaith
        playerBalance = 50

        // Setup world from balance config
        currentDay = 0
        worldTension = balanceConfig.pressure.startingPressure
        lightDarkBalance = 50
        worldFlags = [:]
        completedEventIds = []
        completedQuestIds = []
        eventLog = []

        // Load regions from content registry
        setupRegionsFromRegistry(startingRegionId: startingRegionId)

        // Load initial quests
        setupInitialQuests()
    }

    /// Setup regions from content registry
    private func setupRegionsFromRegistry(startingRegionId: String?) {
        let regionDefs = contentRegistry.getAllRegions()
        var newRegions: [String: CoreRegionState] = [:]

        for def in regionDefs {
            let anchor = contentRegistry.getAnchor(forRegion: def.id)
            let anchorState: CoreAnchorState? = anchor.map {
                CoreAnchorState(
                    id: $0.id,
                    name: $0.title.localized,
                    integrity: $0.initialIntegrity
                )
            }

            let regionState = CoreRegionState(
                id: def.id,
                name: def.title.localized,
                state: def.initialState,
                anchor: anchorState,
                neighborIds: def.neighborIds,
                canTrade: def.initialState == .stable
            )
            newRegions[def.id] = regionState
        }

        regions = newRegions

        // Set starting region
        if let startId = startingRegionId, regions[startId] != nil {
            currentRegionId = startId
        } else {
            // Use first loaded pack's entry region or first available region
            currentRegionId = contentRegistry.loadedPacks.values.first?.manifest.entryRegionId
                ?? regions.keys.first
        }
    }

    /// Setup initial quests from content registry
    private func setupInitialQuests() {
        // Load quests marked as auto-start
        let allQuests = contentRegistry.getAllQuests()
        activeQuests = allQuests.filter { $0.autoStart }
    }

    // MARK: - Actions

    /// Perform a game action
    @discardableResult
    func performAction(_ action: CoreGameAction) -> CoreActionResult {
        guard !isGameOver else {
            return CoreActionResult(success: false, error: .gameNotInProgress)
        }

        // Validate action
        if let error = validateAction(action) {
            return CoreActionResult(success: false, error: error)
        }

        // Execute action
        var stateChanges: [CoreStateChange] = []

        // Advance time if action costs time
        let timeCost = action.timeCost
        if timeCost > 0 {
            let timeChanges = advanceTime(by: timeCost)
            stateChanges.append(contentsOf: timeChanges)
        }

        // Execute action-specific logic
        switch action {
        case .travel(let toRegionId):
            let changes = executeTravel(to: toRegionId)
            stateChanges.append(contentsOf: changes)

        case .rest:
            let changes = executeRest()
            stateChanges.append(contentsOf: changes)

        case .explore:
            let changes = executeExplore()
            stateChanges.append(contentsOf: changes)

        case .strengthenAnchor:
            let changes = executeStrengthenAnchor()
            stateChanges.append(contentsOf: changes)

        case .chooseEventOption(let eventId, let choiceIndex):
            let changes = executeEventChoice(eventId: eventId, choiceIndex: choiceIndex)
            stateChanges.append(contentsOf: changes)

        case .dismissEvent:
            currentEvent = nil
            currentEventId = nil

        case .skipTurn:
            break
        }

        // Check quest progress
        checkQuestProgress()

        // Check end conditions
        if let endResult = checkEndConditions() {
            isGameOver = true
            gameResult = endResult
            return CoreActionResult(success: true, stateChanges: stateChanges, gameEnded: endResult)
        }

        return CoreActionResult(success: true, stateChanges: stateChanges)
    }

    // MARK: - Validation

    private func validateAction(_ action: CoreGameAction) -> CoreActionError? {
        switch action {
        case .travel(let toRegionId):
            guard let current = currentRegion else {
                return .invalidAction(reason: "No current region")
            }
            if !current.neighborIds.contains(toRegionId) {
                return .regionNotNeighbor(regionId: toRegionId)
            }
            if playerHealth <= 0 {
                return .healthTooLow
            }

        case .rest:
            guard let region = currentRegion else {
                return .invalidAction(reason: "No current region")
            }
            if region.state == .breach {
                return .actionNotAvailableInRegion(action: "rest", regionState: "breach")
            }

        case .strengthenAnchor:
            guard let region = currentRegion else {
                return .invalidAction(reason: "No current region")
            }
            if region.anchor == nil {
                return .actionNotAvailableInRegion(action: "strengthen anchor", regionState: "no anchor")
            }
            let cost = balanceConfig.anchor.strengthenCost
            if playerFaith < cost {
                return .insufficientResources(resource: "faith", required: cost, available: playerFaith)
            }

        default:
            break
        }
        return nil
    }

    // MARK: - Time

    private func advanceTime(by days: Int) -> [CoreStateChange] {
        var changes: [CoreStateChange] = []

        for _ in 0..<days {
            currentDay += 1
            changes.append(.dayAdvanced(newDay: currentDay))

            // Check tension tick
            let interval = balanceConfig.pressure.thresholds.warning > 0 ? 3 : 1
            if currentDay > 0 && currentDay % interval == 0 {
                let tensionIncrease = calculateTensionIncrease()
                worldTension = min(balanceConfig.pressure.maxPressure, worldTension + tensionIncrease)
                changes.append(.tensionChanged(delta: tensionIncrease, newValue: worldTension))

                // World degradation
                let degradationChanges = processWorldDegradation()
                changes.append(contentsOf: degradationChanges)
            }
        }

        return changes
    }

    private func calculateTensionIncrease() -> Int {
        let base = balanceConfig.pressure.pressurePerTurn
        let escalationBonus = currentDay / 10
        return base + escalationBonus
    }

    private func processWorldDegradation() -> [CoreStateChange] {
        var changes: [CoreStateChange] = []

        // Get degradation chance based on tension level
        let degradationChance: Double
        if worldTension >= balanceConfig.pressure.thresholds.critical {
            degradationChance = balanceConfig.pressure.degradation.criticalChance
        } else if worldTension >= balanceConfig.pressure.thresholds.warning {
            degradationChance = balanceConfig.pressure.degradation.warningChance
        } else {
            return changes
        }

        // Find regions that can degrade
        let degradableRegions = regions.values.filter { $0.state != .breach }
        guard !degradableRegions.isEmpty else { return changes }

        // Random check for degradation
        let roll = Double.random(in: 0...1)
        if roll < degradationChance {
            // Pick a random borderland region to degrade
            let borderlands = degradableRegions.filter { $0.state == .borderland }
            if let regionToDemote = borderlands.randomElement() {
                if var region = regions[regionToDemote.id] {
                    region.state = .breach
                    regions[regionToDemote.id] = region
                    changes.append(.regionStateChanged(regionId: regionToDemote.id, newState: .breach))
                }
            }
        }

        return changes
    }

    // MARK: - Action Execution

    private func executeTravel(to regionId: String) -> [CoreStateChange] {
        var changes: [CoreStateChange] = []

        currentRegionId = regionId
        changes.append(.regionChanged(regionId: regionId))

        // Mark region as visited
        if var region = regions[regionId] {
            region.visited = true
            regions[regionId] = region
        }

        // Generate travel event
        if let event = generateEvent(for: regionId, trigger: .arrival) {
            currentEventId = event.id
            currentEvent = event
            changes.append(.eventTriggered(eventId: event.id))
        }

        return changes
    }

    private func executeRest() -> [CoreStateChange] {
        var changes: [CoreStateChange] = []

        let healAmount = 3  // Could come from balance config
        let newHealth = min(playerMaxHealth, playerHealth + healAmount)
        let delta = newHealth - playerHealth
        playerHealth = newHealth
        changes.append(.healthChanged(delta: delta, newValue: newHealth))

        return changes
    }

    private func executeExplore() -> [CoreStateChange] {
        var changes: [CoreStateChange] = []

        guard let regionId = currentRegionId else { return changes }

        // Generate exploration event
        if let event = generateEvent(for: regionId, trigger: .exploration) {
            currentEventId = event.id
            currentEvent = event
            changes.append(.eventTriggered(eventId: event.id))
        }

        return changes
    }

    private func executeStrengthenAnchor() -> [CoreStateChange] {
        var changes: [CoreStateChange] = []

        guard let regionId = currentRegionId,
              var region = regions[regionId],
              var anchor = region.anchor else {
            return changes
        }

        // Spend faith (from balance config)
        let cost = balanceConfig.anchor.strengthenCost
        playerFaith -= cost
        changes.append(.faithChanged(delta: -cost, newValue: playerFaith))

        // Strengthen anchor
        let strengthAmount = balanceConfig.anchor.strengthenAmount
        let newIntegrity = min(balanceConfig.anchor.maxIntegrity, anchor.integrity + strengthAmount)
        let delta = newIntegrity - anchor.integrity
        anchor.integrity = newIntegrity
        region.anchor = anchor
        regions[regionId] = region

        changes.append(.anchorIntegrityChanged(anchorId: anchor.id, delta: delta, newValue: newIntegrity))

        return changes
    }

    private func executeEventChoice(eventId: String, choiceIndex: Int) -> [CoreStateChange] {
        var changes: [CoreStateChange] = []

        guard let event = currentEvent,
              choiceIndex < event.choices.count else {
            return changes
        }

        let choice = event.choices[choiceIndex]

        // Apply resource changes
        for (resource, delta) in choice.consequences.resourceChanges {
            switch resource {
            case "health":
                playerHealth = max(0, min(playerMaxHealth, playerHealth + delta))
                changes.append(.healthChanged(delta: delta, newValue: playerHealth))
            case "faith":
                playerFaith = max(0, playerFaith + delta)
                changes.append(.faithChanged(delta: delta, newValue: playerFaith))
            case "tension":
                worldTension = max(0, min(100, worldTension + delta))
                changes.append(.tensionChanged(delta: delta, newValue: worldTension))
            default:
                break
            }
        }

        // Apply balance change
        if choice.consequences.balanceDelta != 0 {
            lightDarkBalance = max(0, min(100, lightDarkBalance + choice.consequences.balanceDelta))
            changes.append(.balanceChanged(delta: choice.consequences.balanceDelta, newValue: lightDarkBalance))
        }

        // Set flags (setFlags is an array of flag names, all set to true)
        for flag in choice.consequences.setFlags {
            worldFlags[flag] = true
            changes.append(.flagSet(key: flag, value: true))
        }

        // Clear flags
        for flag in choice.consequences.clearFlags {
            worldFlags[flag] = false
            changes.append(.flagSet(key: flag, value: false))
        }

        // Mark event completed if one-time
        if event.isOneTime {
            completedEventIds.insert(eventId)
        }

        currentEventId = nil
        currentEvent = nil
        changes.append(.eventCompleted(eventId: eventId))

        return changes
    }

    // MARK: - Event Generation

    private func generateEvent(for regionId: String, trigger: CoreEventTrigger) -> EventDefinition? {
        let availableEvents = contentRegistry.getAvailableEvents(
            forRegion: regionId,
            pressure: worldTension
        ).filter { event in
            // Filter out completed one-time events
            if event.isOneTime && completedEventIds.contains(event.id) {
                return false
            }
            return true
        }

        return availableEvents.randomElement()
    }

    // MARK: - Quest Progress

    private func checkQuestProgress() {
        // Check quest conditions and update stages
        for quest in activeQuests {
            // Check if quest objectives are completed
            // For simplicity, check if all objectives with flagSet condition have their flags set
            var allObjectivesComplete = true
            for objective in quest.objectives {
                switch objective.completionCondition {
                case .flagSet(let flagName):
                    if worldFlags[flagName] != true {
                        allObjectivesComplete = false
                    }
                case .visitRegion(let regionId):
                    // Would need to track visited regions
                    if regions[regionId]?.visited != true {
                        allObjectivesComplete = false
                    }
                default:
                    // For other conditions, assume incomplete unless explicitly marked
                    break
                }
            }

            if allObjectivesComplete && !quest.objectives.isEmpty {
                completedQuestIds.insert(quest.id)
            }
        }

        // Remove completed quests from active
        activeQuests = activeQuests.filter { !completedQuestIds.contains($0.id) }
    }

    // MARK: - End Conditions

    private func checkEndConditions() -> GameEndResult? {
        // Defeat: tension at max
        if let pressureLoss = balanceConfig.endConditions.pressureLoss,
           worldTension >= pressureLoss {
            return .defeat(reason: "World tension reached maximum")
        }

        // Defeat: health 0
        if playerHealth <= 0 {
            return .defeat(reason: "Hero died")
        }

        // Victory: check victory quests
        for questId in balanceConfig.endConditions.victoryQuests {
            if completedQuestIds.contains(questId) {
                return .victory(endingId: "standard")
            }
        }

        return nil
    }
}

// MARK: - Core Game Action

/// Actions that can be performed in the game
enum CoreGameAction {
    case travel(toRegionId: String)
    case rest
    case explore
    case strengthenAnchor
    case chooseEventOption(eventId: String, choiceIndex: Int)
    case dismissEvent
    case skipTurn

    var timeCost: Int {
        switch self {
        case .travel: return 1
        case .rest: return 1
        case .explore: return 1
        case .strengthenAnchor: return 1
        case .chooseEventOption, .dismissEvent, .skipTurn: return 0
        }
    }
}

// MARK: - Core Action Result

struct CoreActionResult {
    let success: Bool
    let error: CoreActionError?
    let stateChanges: [CoreStateChange]
    let gameEnded: GameEndResult?

    init(success: Bool, error: CoreActionError? = nil, stateChanges: [CoreStateChange] = [], gameEnded: GameEndResult? = nil) {
        self.success = success
        self.error = error
        self.stateChanges = stateChanges
        self.gameEnded = gameEnded
    }
}

// MARK: - Core Action Error

enum CoreActionError: Error {
    case gameNotInProgress
    case regionNotNeighbor(regionId: String)
    case healthTooLow
    case actionNotAvailableInRegion(action: String, regionState: String)
    case insufficientResources(resource: String, required: Int, available: Int)
    case invalidAction(reason: String)
}

// MARK: - Core State Change

enum CoreStateChange {
    case dayAdvanced(newDay: Int)
    case tensionChanged(delta: Int, newValue: Int)
    case regionChanged(regionId: String)
    case regionStateChanged(regionId: String, newState: RegionStateType)
    case healthChanged(delta: Int, newValue: Int)
    case faithChanged(delta: Int, newValue: Int)
    case balanceChanged(delta: Int, newValue: Int)
    case anchorIntegrityChanged(anchorId: String, delta: Int, newValue: Int)
    case flagSet(key: String, value: Bool)
    case eventTriggered(eventId: String)
    case eventCompleted(eventId: String)
    case questCompleted(questId: String)
}

// MARK: - Core Event Trigger

enum CoreEventTrigger {
    case arrival
    case exploration
    case combat
    case quest
    case time
}

// MARK: - Core Region State

/// Runtime state of a region (combines definition + runtime data)
struct CoreRegionState {
    let id: String
    let name: String
    var state: RegionStateType
    var anchor: CoreAnchorState?
    let neighborIds: [String]
    var canTrade: Bool
    var visited: Bool = false
    var reputation: Int = 0

    var canRest: Bool {
        state == .stable
    }
}

// MARK: - Core Anchor State

/// Runtime state of an anchor
struct CoreAnchorState {
    let id: String
    let name: String
    var integrity: Int
}

// MARK: - Core Event Log Entry

struct CoreEventLogEntry {
    let dayNumber: Int
    let regionName: String
    let eventTitle: String
    let choiceMade: String
    let outcome: String
}

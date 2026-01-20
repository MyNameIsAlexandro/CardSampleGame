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

    // MARK: - Published State for UI (Engine-First Architecture)

    /// All regions with their current state - UI reads this directly
    @Published private(set) var publishedRegions: [UUID: EngineRegionState] = [:]

    /// Player stats - UI reads these directly instead of Player model
    @Published private(set) var playerHealth: Int = 10
    @Published private(set) var playerMaxHealth: Int = 10
    @Published private(set) var playerFaith: Int = 3
    @Published private(set) var playerMaxFaith: Int = 10
    @Published private(set) var playerBalance: Int = 50
    @Published private(set) var playerName: String = "Герой"

    /// World flags - for quest/event conditions
    @Published private(set) var publishedWorldFlags: [String: Bool] = [:]

    /// Current event being displayed to player
    @Published private(set) var currentEvent: GameEvent?

    /// Day event notification (tension increase, degradation, etc.)
    @Published private(set) var lastDayEvent: DayEvent?

    /// Active quests
    @Published private(set) var publishedActiveQuests: [Quest] = []

    /// Event log (last 100 entries)
    @Published private(set) var publishedEventLog: [EventLogEntry] = []

    /// Light/Dark balance of the world
    @Published private(set) var lightDarkBalance: Int = 50

    /// Main quest stage (1-5)
    @Published private(set) var mainQuestStage: Int = 1

    // MARK: - UI Convenience Accessors (Engine-First Architecture)

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

    /// Player balance description for UI
    var playerBalanceDescription: String {
        switch playerBalance {
        case 70...100: return "Свет"
        case 31..<70: return "Равновесие"
        default: return "Тьма"
        }
    }

    /// World balance description
    var worldBalanceDescription: String {
        switch lightDarkBalance {
        case 70...100: return "Явь сильна"
        case 31..<70: return "Сумрак"
        default: return "Навь наступает"
        }
    }

    /// Check if region can rest
    func canRestInCurrentRegion() -> Bool {
        guard let region = currentRegion else { return false }
        return region.state == .stable
    }

    /// Check if region can trade
    func canTradeInCurrentRegion() -> Bool {
        guard let region = currentRegion else { return false }
        return region.canTrade
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

    /// All events in the game (from ContentProvider)
    private var allEvents: [GameEvent] = []

    /// Active quests
    private var activeQuests: [Quest] = []

    /// Completed quest IDs
    private var completedQuestIds: Set<String> = []

    /// Event log
    private var eventLog: [EventLogEntry] = []

    /// Player deck (for save/load)
    private var playerDeck: [Card] = []
    private var playerHand: [Card] = []
    private var playerDiscard: [Card] = []

    // MARK: - Combat State

    /// Current enemy card in combat
    @Published private(set) var combatEnemy: Card?

    /// Enemy current health
    @Published private(set) var combatEnemyHealth: Int = 0

    /// Combat actions remaining this turn
    @Published private(set) var combatActionsRemaining: Int = 3

    /// Combat turn number
    @Published private(set) var combatTurnNumber: Int = 1

    /// Bonus dice for next attack (from cards)
    private var combatBonusDice: Int = 0

    /// Bonus damage for next attack (from cards)
    private var combatBonusDamage: Int = 0

    /// Is this the first attack in this combat (for abilities)
    private var combatIsFirstAttack: Bool = true

    // MARK: - Content Registry

    /// Content registry for loading content packs
    private let contentRegistry: ContentRegistry

    /// Balance configuration from content pack
    private var balanceConfig: BalanceConfiguration

    // MARK: - Configuration Constants (Legacy - migrate to balanceConfig)

    private var tensionTickInterval: Int { 3 }  // Could come from balanceConfig.pressure
    private var restHealAmount: Int { 3 }  // Could come from balanceConfig
    private var anchorStrengthenCost: Int { balanceConfig.anchor.strengthenCost }
    private var anchorStrengthenAmount: Int { balanceConfig.anchor.strengthenAmount }

    // MARK: - Initialization

    init(registry: ContentRegistry = .shared) {
        self.contentRegistry = registry
        self.balanceConfig = registry.getBalanceConfig() ?? .default
        self.timeEngine = TimeEngine(thresholdInterval: 3)
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

        // Sync additional state for Engine-First architecture
        lightDarkBalance = adapter.worldState.lightDarkBalance
        mainQuestStage = adapter.worldState.mainQuestStage
        allEvents = adapter.worldState.allEvents
        activeQuests = adapter.worldState.activeQuests
        eventLog = adapter.worldState.eventLog
        publishedActiveQuests = activeQuests
        publishedEventLog = eventLog
    }

    // MARK: - Engine-First Initialization

    /// Initialize a new game without legacy WorldState
    /// This is the Engine-First way to start a game
    func initializeNewGame(playerName: String = "Герой") {
        // Reset state
        isGameOver = false
        gameResult = nil
        currentEventId = nil
        currentEvent = nil
        lastDayEvent = nil
        isInCombat = false

        // Load balance config from content registry
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
        mainQuestStage = 1
        worldFlags = [:]
        completedEventIds = []
        completedQuestIds = []
        eventLog = []

        // Load regions from ContentRegistry
        setupRegionsFromRegistry()

        // Load events
        allEvents = createInitialEvents()

        // Load quests and start main quest
        let initialQuests = createInitialQuests()
        if let mainQuest = initialQuests.first(where: { $0.questType == .main }) {
            activeQuests = [mainQuest]
        }

        // Setup pressure engine
        pressureEngine.setPressure(worldTension)
        pressureEngine.syncTriggeredThresholdsFromPressure()

        // Update all published state
        updatePublishedState()
    }

    /// Setup regions from ContentProvider
    private func setupRegionsFromProvider(_ provider: ContentProvider) {
        let regionDefs = provider.getAllRegionDefinitions()
        var newRegions: [UUID: EngineRegionState] = [:]
        var stringToUUID: [String: UUID] = [:]  // Map string IDs to UUIDs

        // First pass: create regions and map IDs
        for def in regionDefs {
            let regionUUID = UUID()
            stringToUUID[def.id] = regionUUID

            let anchor = createEngineAnchor(from: provider.getAnchorDefinition(forRegion: def.id))
            let regionType = mapRegionType(def.id)
            let regionState = mapRegionState(def.initialState)

            let engineRegion = EngineRegionState(
                id: regionUUID,
                name: TwilightMarchesCodeContentProvider.regionName(for: def.id),
                type: regionType,
                state: regionState,
                anchor: anchor,
                neighborIds: [],  // Will be set in second pass
                canTrade: regionState == .stable && regionType == .settlement
            )
            newRegions[regionUUID] = engineRegion

            // Set starting region
            if def.id == "village" {
                currentRegionId = regionUUID
            }
        }

        // Second pass: resolve neighbor IDs
        for def in regionDefs {
            guard let regionUUID = stringToUUID[def.id],
                  var region = newRegions[regionUUID] else { continue }

            let neighborUUIDs = def.neighborIds.compactMap { stringToUUID[$0] }
            region = EngineRegionState(
                id: region.id,
                name: region.name,
                type: region.type,
                state: region.state,
                anchor: region.anchor,
                neighborIds: neighborUUIDs,
                canTrade: region.canTrade,
                visited: region.visited,
                reputation: region.reputation
            )
            newRegions[regionUUID] = region
        }

        regions = newRegions
        publishedRegions = newRegions
    }

    /// Setup regions from ContentRegistry (Engine-First architecture)
    private func setupRegionsFromRegistry() {
        let regionDefs = contentRegistry.getAllRegions()
        var newRegions: [UUID: EngineRegionState] = [:]
        var stringToUUID: [String: UUID] = [:]  // Map string IDs to UUIDs

        // Determine entry region from loaded pack
        let entryRegionId = contentRegistry.loadedPacks.values.first?.manifest.entryRegionId ?? "village"

        // First pass: create regions and map IDs
        for def in regionDefs {
            let regionUUID = UUID()
            stringToUUID[def.id] = regionUUID

            let anchor = contentRegistry.getAnchor(forRegion: def.id).map { anchorDef in
                EngineAnchorState(
                    id: UUID(),
                    name: anchorDef.title.localized,
                    integrity: anchorDef.initialIntegrity
                )
            }

            let regionType = mapRegionType(def.id)
            let regionState = mapRegionState(def.initialState)

            let engineRegion = EngineRegionState(
                id: regionUUID,
                name: def.title.localized,
                type: regionType,
                state: regionState,
                anchor: anchor,
                neighborIds: [],  // Will be set in second pass
                canTrade: regionState == .stable && regionType == .settlement
            )
            newRegions[regionUUID] = engineRegion

            // Set starting region
            if def.id == entryRegionId {
                currentRegionId = regionUUID
            }
        }

        // Second pass: resolve neighbor IDs
        for def in regionDefs {
            guard let regionUUID = stringToUUID[def.id],
                  var region = newRegions[regionUUID] else { continue }

            let neighborUUIDs = def.neighborIds.compactMap { stringToUUID[$0] }
            region = EngineRegionState(
                id: region.id,
                name: region.name,
                type: region.type,
                state: region.state,
                anchor: region.anchor,
                neighborIds: neighborUUIDs,
                canTrade: region.canTrade,
                visited: region.visited,
                reputation: region.reputation
            )
            newRegions[regionUUID] = region
        }

        regions = newRegions
        publishedRegions = newRegions

        // Set first region as current if none set
        if currentRegionId == nil {
            currentRegionId = newRegions.keys.first
        }
    }

    /// Create EngineAnchorState from AnchorDefinition
    private func createEngineAnchor(from def: AnchorDefinition?) -> EngineAnchorState? {
        guard let def = def else { return nil }
        return EngineAnchorState(
            id: UUID(),
            name: TwilightMarchesCodeContentProvider.anchorName(for: def.id),
            integrity: def.initialIntegrity
        )
    }

    /// Resolve neighbor region IDs from string IDs to UUIDs
    private func resolveNeighborIds(_ neighborStringIds: [String], from defs: [RegionDefinition]) -> [UUID] {
        // This would need to be implemented properly with a mapping
        // For now, return empty - neighbors will be set up separately
        return []
    }

    /// Map region ID to RegionType
    private func mapRegionType(_ id: String) -> RegionType {
        switch id {
        case "village", "temple", "fortress": return .settlement
        case "forest": return .forest
        case "swamp": return .swamp
        case "ruins", "wasteland": return .wasteland
        case "sanctuary": return .sacred
        case "mountain": return .mountain
        default: return .forest
        }
    }

    /// Map RegionStateType to RegionState
    private func mapRegionState(_ stateType: RegionStateType) -> RegionState {
        switch stateType {
        case .stable: return .stable
        case .borderland: return .borderland
        case .breach: return .breach
        }
    }

    /// Create initial events (simplified - would load from ContentProvider)
    private func createInitialEvents() -> [GameEvent] {
        // Phase 5: Load from ContentProvider/JSON
        return []
    }

    /// Create initial quests (simplified - would load from ContentProvider)
    private func createInitialQuests() -> [Quest] {
        // Phase 5: Load from ContentProvider/JSON
        return []
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
            combatTurnNumber = 1
            combatActionsRemaining = 3
            combatBonusDice = 0
            combatBonusDamage = 0
            combatIsFirstAttack = true
            // Enemy setup done when combat view appears

        case .combatInitialize:
            // Shuffle deck and draw initial hand
            if let player = playerAdapter?.player {
                player.shuffleDeck()
                player.drawCards(count: player.maxHandSize)
                playerHand = player.hand
            }
            combatActionsRemaining = 3

        case .combatAttack(let bonusDice, let bonusDamage, let isFirstAttack):
            guard combatActionsRemaining > 0 else { break }
            combatActionsRemaining -= 1
            let changes = executeCombatAttack(bonusDice: bonusDice, bonusDamage: bonusDamage, isFirstAttack: isFirstAttack)
            stateChanges.append(contentsOf: changes)
            combatIsFirstAttack = false
            // Check if enemy defeated
            if combatEnemyHealth <= 0 {
                // Victory will be handled by combatFinish
            }

        case .playCard(let cardId, _):
            guard combatActionsRemaining > 0 else { break }
            if let player = playerAdapter?.player,
               let cardIndex = player.hand.firstIndex(where: { $0.id == cardId }) {
                let card = player.hand[cardIndex]
                // Check faith cost
                if let cost = card.cost, cost > 0 {
                    guard player.faith >= cost else { break }
                    _ = player.spendFaith(cost)
                    playerFaith = player.faith
                    stateChanges.append(.faithChanged(delta: -cost, newValue: playerFaith))
                }
                combatActionsRemaining -= 1
                player.playCard(card)
                playerHand = player.hand
            }

        case .combatApplyEffect(let effect):
            let changes = executeCombatEffect(effect)
            stateChanges.append(contentsOf: changes)

        case .endCombatTurn:
            // Player ended their turn, enemy attacks next
            break

        case .combatEnemyAttack(let damage):
            // Enemy deals damage to player
            if let player = playerAdapter?.player {
                let healthBefore = player.health
                player.takeDamageWithCurses(damage)
                let actualDamage = healthBefore - player.health
                playerHealth = player.health
                stateChanges.append(.healthChanged(delta: -actualDamage, newValue: playerHealth))
            }

        case .combatEndTurnPhase:
            // End of turn: discard hand, draw new cards, restore faith
            if let player = playerAdapter?.player {
                // Discard hand
                while !player.hand.isEmpty {
                    player.playCard(player.hand[0])
                }
                // Draw new hand
                player.drawCards(count: player.maxHandSize)
                playerHand = player.hand
                // Restore faith
                player.gainFaith(1)
                playerFaith = player.faith
                stateChanges.append(.faithChanged(delta: 1, newValue: playerFaith))
                // Ability: extra faith at end of turn
                if player.shouldGainFaithEndOfTurn {
                    player.gainFaith(1)
                    playerFaith = player.faith
                    stateChanges.append(.faithChanged(delta: 1, newValue: playerFaith))
                }
            }
            // Reset for next turn
            combatTurnNumber += 1
            combatActionsRemaining = 3
            combatBonusDice = 0
            combatBonusDamage = 0

        case .combatFlee:
            isInCombat = false
            combatEnemy = nil
            stateChanges.append(.combatEnded(victory: false))

        case .combatFinish(let victory):
            isInCombat = false
            combatEnemy = nil
            stateChanges.append(.combatEnded(victory: victory))
            if victory {
                stateChanges.append(.enemyDefeated(enemyId: UUID()))
            }

        case .dismissCurrentEvent:
            currentEvent = nil
            currentEventId = nil

        case .dismissDayEvent:
            lastDayEvent = nil

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

    // MARK: - Published State Update (Engine-First Architecture)

    /// Update all published properties from internal state
    /// Called after actions to keep UI in sync
    private func updatePublishedState() {
        // Update regions
        publishedRegions = regions

        // Update flags
        publishedWorldFlags = worldFlags

        // Update quests and log
        publishedActiveQuests = activeQuests
        publishedEventLog = Array(eventLog.suffix(100))

        // Update current event from ID (Bridge UUID to GameEvent object)
        if let eventId = currentEventId,
           let event = worldStateAdapter?.worldState.allEvents.first(where: { $0.id == eventId }) {
            currentEvent = event
        } else if currentEventId == nil {
            currentEvent = nil
        }

        // Update player stats from adapter (legacy mode)
        if let player = playerAdapter?.player {
            playerHealth = player.health
            playerMaxHealth = player.maxHealth
            playerFaith = player.faith
            playerBalance = player.balance
        }
        // In Engine-First mode, player stats are updated directly
    }

    // MARK: - Event Log

    /// Add entry to event log
    func addLogEntry(
        regionName: String,
        eventTitle: String,
        choiceMade: String,
        outcome: String,
        type: EventLogType
    ) {
        let entry = EventLogEntry(
            dayNumber: currentDay,
            regionName: regionName,
            eventTitle: eventTitle,
            choiceMade: choiceMade,
            outcome: outcome,
            type: type
        )
        eventLog.append(entry)

        // Trim log to 100 entries
        if eventLog.count > 100 {
            eventLog.removeFirst(eventLog.count - 100)
        }

        publishedEventLog = eventLog
    }

    // MARK: - Day Events

    /// Trigger day event (tension increase, degradation, etc.)
    private func triggerDayEvent(_ event: DayEvent) {
        lastDayEvent = event
    }

    // MARK: - Combat Helper Methods

    /// Execute a combat attack with bonus dice and damage
    private func executeCombatAttack(bonusDice: Int, bonusDamage: Int, isFirstAttack: Bool) -> [StateChange] {
        var changes: [StateChange] = []

        guard let enemy = combatEnemy,
              let player = playerAdapter?.player else {
            return changes
        }

        let monsterDef = enemy.defense ?? 10
        let monsterCurrentHP = combatEnemyHealth
        let monsterMaxHP = enemy.health ?? 10

        // Use CombatCalculator for attack calculation
        let result = CombatCalculator.calculatePlayerAttack(
            player: player,
            monsterDefense: monsterDef,
            monsterCurrentHP: monsterCurrentHP,
            monsterMaxHP: monsterMaxHP,
            bonusDice: bonusDice + combatBonusDice,
            bonusDamage: bonusDamage + combatBonusDamage,
            isFirstAttack: isFirstAttack
        )

        if result.isHit, let damageCalc = result.damageCalculation {
            let damage = damageCalc.total
            combatEnemyHealth = max(0, combatEnemyHealth - damage)
            changes.append(.enemyDamaged(enemyId: enemy.id, damage: damage, newHealth: combatEnemyHealth))
        }

        // Reset bonuses after attack
        combatBonusDice = 0
        combatBonusDamage = 0

        return changes
    }

    /// Execute a combat effect from card or ability
    private func executeCombatEffect(_ effect: CombatActionEffect) -> [StateChange] {
        var changes: [StateChange] = []

        switch effect {
        case .heal(let amount):
            if let player = playerAdapter?.player {
                let newHealth = min(player.maxHealth, player.health + amount)
                let delta = newHealth - player.health
                playerAdapter?.updateHealth(newHealth)
                playerHealth = newHealth
                changes.append(.healthChanged(delta: delta, newValue: newHealth))
            }

        case .damageEnemy(let amount):
            if let player = playerAdapter?.player, let enemy = combatEnemy {
                let actualDamage = player.calculateDamageDealt(amount)
                combatEnemyHealth = max(0, combatEnemyHealth - actualDamage)
                changes.append(.enemyDamaged(enemyId: enemy.id, damage: actualDamage, newHealth: combatEnemyHealth))
            }

        case .drawCards(let count):
            if let player = playerAdapter?.player {
                player.drawCards(count: count)
                playerHand = player.hand
            }

        case .gainFaith(let amount):
            if let player = playerAdapter?.player {
                player.gainFaith(amount)
                playerFaith = player.faith
                changes.append(.faithChanged(delta: amount, newValue: playerFaith))
            }

        case .spendFaith(let amount):
            if let player = playerAdapter?.player {
                _ = player.spendFaith(amount)
                playerFaith = player.faith
                changes.append(.faithChanged(delta: -amount, newValue: playerFaith))
            }

        case .takeDamage(let amount):
            if let player = playerAdapter?.player {
                let healthBefore = player.health
                player.takeDamage(amount)
                let actualDamage = healthBefore - player.health
                playerHealth = player.health
                changes.append(.healthChanged(delta: -actualDamage, newValue: playerHealth))
            }

        case .removeCurse(let type):
            if let player = playerAdapter?.player {
                // Convert String to CurseType
                let curseType: CurseType? = type.flatMap { CurseType(rawValue: $0) }
                player.removeCurse(type: curseType)
            }

        case .shiftBalance(let towards, let amount):
            if let player = playerAdapter?.player {
                let direction: CardBalance
                switch towards.lowercased() {
                case "light", "свет": direction = .light
                case "dark", "тьма": direction = .dark
                default: direction = .neutral
                }
                player.shiftBalance(towards: direction, amount: amount)
                playerBalance = player.balance
                changes.append(.balanceChanged(delta: amount, newValue: playerBalance))
            }

        case .addBonusDice(let count):
            combatBonusDice += count

        case .addBonusDamage(let amount):
            combatBonusDamage += amount

        case .summonSpirit(let power, _):
            // Spirit attacks enemy immediately
            if let enemy = combatEnemy {
                combatEnemyHealth = max(0, combatEnemyHealth - power)
                changes.append(.enemyDamaged(enemyId: enemy.id, damage: power, newHealth: combatEnemyHealth))
            }
        }

        return changes
    }

    // MARK: - Combat Setup Methods

    /// Setup enemy for combat
    func setupCombatEnemy(_ enemy: Card) {
        combatEnemy = enemy
        combatEnemyHealth = enemy.health ?? 10
        combatTurnNumber = 1
        combatActionsRemaining = 3
        combatBonusDice = 0
        combatBonusDamage = 0
        combatIsFirstAttack = true
        isInCombat = true
    }

    /// Get current combat state for UI
    var combatState: CombatState? {
        guard isInCombat, let enemy = combatEnemy else { return nil }
        return CombatState(
            enemy: enemy,
            enemyHealth: combatEnemyHealth,
            turnNumber: combatTurnNumber,
            actionsRemaining: combatActionsRemaining,
            bonusDice: combatBonusDice,
            bonusDamage: combatBonusDamage,
            isFirstAttack: combatIsFirstAttack
        )
    }

    // MARK: - Save/Load Support Methods

    /// Get completed quest IDs for save
    func getCompletedQuestIds() -> Set<String> {
        return completedQuestIds
    }

    /// Get quest stages for save
    func getQuestStages() -> [String: Int] {
        return questStages
    }

    /// Get completed event IDs for save
    func getCompletedEventIds() -> Set<UUID> {
        return completedEventIds
    }

    /// Set regions from save
    func setRegions(_ newRegions: [UUID: EngineRegionState]) {
        regions = newRegions
        publishedRegions = newRegions
    }

    /// Set world flags from save
    func setWorldFlags(_ newFlags: [String: Bool]) {
        worldFlags = newFlags
        publishedWorldFlags = newFlags
    }

    /// Set completed event IDs from save
    func setCompletedEventIds(_ ids: Set<UUID>) {
        completedEventIds = ids
    }

    /// Set event log from save
    func setEventLog(_ log: [EventLogEntry]) {
        eventLog = log
        publishedEventLog = Array(log.suffix(100))
    }

    /// Set main quest stage from save
    func setMainQuestStage(_ stage: Int) {
        mainQuestStage = stage
    }

    /// Set completed quest IDs from save
    func setCompletedQuestIds(_ ids: Set<String>) {
        completedQuestIds = ids
    }

    /// Set quest stages from save
    func setQuestStages(_ stages: [String: Int]) {
        questStages = stages
    }

    /// Update published state after loading
    func updatePublishedStateAfterLoad() {
        updatePublishedState()
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
struct EngineRegionState: Identifiable {
    let id: UUID
    let name: String
    let type: RegionType
    var state: RegionState
    var anchor: EngineAnchorState?
    let neighborIds: [UUID]
    var canTrade: Bool
    var visited: Bool = false
    var reputation: Int = 0

    /// Create from legacy Region (for migration)
    init(from region: Region) {
        self.id = region.id
        self.name = region.name
        self.type = region.type
        self.state = region.state
        self.anchor = region.anchor.map { EngineAnchorState(from: $0) }
        self.neighborIds = region.neighborIds
        self.canTrade = region.canTrade
        self.visited = region.visited
        self.reputation = region.reputation
    }

    /// Create directly (Engine-First)
    init(
        id: UUID = UUID(),
        name: String,
        type: RegionType,
        state: RegionState,
        anchor: EngineAnchorState? = nil,
        neighborIds: [UUID] = [],
        canTrade: Bool = false,
        visited: Bool = false,
        reputation: Int = 0
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.state = state
        self.anchor = anchor
        self.neighborIds = neighborIds
        self.canTrade = canTrade
        self.visited = visited
        self.reputation = reputation
    }

    /// Can rest in this region
    var canRest: Bool {
        state == .stable && (type == .settlement || type == .sacred)
    }
}

// MARK: - Engine Anchor State (Bridge from Legacy)

/// Internal state for engine anchor tracking (bridges from legacy Anchor model)
struct EngineAnchorState {
    let id: UUID
    let name: String
    var integrity: Int

    /// Create from legacy Anchor (for migration)
    init(from anchor: Anchor) {
        self.id = anchor.id
        self.name = anchor.name
        self.integrity = anchor.integrity
    }

    /// Create directly (Engine-First)
    init(id: UUID = UUID(), name: String, integrity: Int) {
        self.id = id
        self.name = name
        self.integrity = max(0, min(100, integrity))
    }
}

// MARK: - Combat State (for UI)

/// Read-only combat state for UI binding
struct CombatState {
    let enemy: Card
    let enemyHealth: Int
    let turnNumber: Int
    let actionsRemaining: Int
    let bonusDice: Int
    let bonusDamage: Int
    let isFirstAttack: Bool

    var enemyMaxHealth: Int {
        enemy.health ?? 10
    }

    var enemyDefense: Int {
        enemy.defense ?? 10
    }

    var enemyPower: Int {
        enemy.power ?? 3
    }
}

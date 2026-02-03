import Foundation

// MARK: - Game Engine
// The central game orchestrator - ALL game actions go through here

/// Main game engine — the central orchestrator for all game actions
/// UI should NEVER mutate state directly - always go through performAction()
///
/// Architecture: Engine is pure logic (no Combine/SwiftUI). App layer wraps
/// this in `GameEngineObservable` for SwiftUI binding via `onStateChanged`.
public final class TwilightGameEngine {

    // MARK: - State Change Callback

    /// Called after state mutations so App-layer wrapper can notify SwiftUI.
    public var onStateChanged: (() -> Void)?

    // MARK: - State (for UI binding via App-layer wrapper)

    /// Current in-game day number
    public private(set) var currentDay: Int = 0
    /// World tension level (0-100), drives degradation and difficulty
    public internal(set) var worldTension: Int = 30
    /// ID of the region the player is currently in
    public private(set) var currentRegionId: String?
    /// Whether the game has ended (victory or defeat)
    public private(set) var isGameOver: Bool = false
    /// Result of the game if it has ended
    public private(set) var gameResult: GameEndResult?

    /// ID of the event currently being presented to the player
    public private(set) var currentEventId: String?
    /// Whether the player is currently in combat
    public internal(set) var isInCombat: Bool = false

    /// Result of the last performed action
    public private(set) var lastActionResult: ActionResult?

    // MARK: - State for UI (Engine-First Architecture)

    /// All regions with their current state - UI reads this directly
    public private(set) var publishedRegions: [String: EngineRegionState] = [:]

    /// World resonance value (-100..+100), drives Navi/Prav world state
    public internal(set) var resonanceValue: Float = 0.0

    /// World flags - for quest/event conditions
    public private(set) var publishedWorldFlags: [String: Bool] = [:]

    /// Current event being displayed to player
    public private(set) var currentEvent: GameEvent?

    /// Day event notification (tension increase, degradation, etc.)
    public private(set) var lastDayEvent: DayEvent?

    /// Active quests
    public private(set) var publishedActiveQuests: [Quest] = []

    /// Event log (last 100 entries)
    public private(set) var publishedEventLog: [EventLogEntry] = []

    /// Light/Dark balance of the world
    public private(set) var lightDarkBalance: Int = 50

    /// Main quest stage (1-5)
    public private(set) var mainQuestStage: Int = 1

    /// Tracks when the current session started, for computing total game duration
    private var gameStartDate: Date = Date()

    /// Accumulated game duration from previous sessions (seconds)
    private var previousSessionsDuration: TimeInterval = 0

    // MARK: - UI Convenience Accessors (Engine-First Architecture)

    /// Get regions as sorted array for UI iteration
    public var regionsArray: [EngineRegionState] {
        publishedRegions.values.sorted { $0.name < $1.name }
    }

    /// Get current region
    public var currentRegion: EngineRegionState? {
        guard let id = currentRegionId else { return nil }
        return publishedRegions[id]
    }

    /// Check if region is neighbor to current region
    public func isNeighbor(regionId: String) -> Bool {
        guard let current = currentRegion else { return false }
        return current.neighborIds.contains(regionId)
    }

    /// Calculate travel cost to target region (1 = neighbor, 2 = distant)
    public func calculateTravelCost(to targetId: String) -> Int {
        return isNeighbor(regionId: targetId) ? 1 : 2
    }

    /// Check if travel to region is allowed (only neighbors allowed)
    public func canTravelTo(regionId: String) -> Bool {
        guard regionId != currentRegionId else { return false }
        return isNeighbor(regionId: regionId)
    }

    /// Get neighboring region names that connect to target (for routing hints)
    public func getRoutingHint(to targetId: String) -> [String] {
        guard let current = currentRegion else { return [] }

        // If already neighbor, no hint needed
        if current.neighborIds.contains(targetId) { return [] }

        // Find which neighbors connect to target
        var connectingNeighbors: [String] = []
        for neighborId in current.neighborIds {
            guard let neighbor = regions[neighborId] else { continue }
            if neighbor.neighborIds.contains(targetId) {
                connectingNeighbors.append(neighbor.name)
            }
        }

        return connectingNeighbors
    }

    /// World balance description
    public var worldBalanceDescription: String {
        switch lightDarkBalance {
        case 70...100: return "Явь сильна"
        case 31..<70: return "Сумрак"
        default: return "Навь наступает"
        }
    }

    /// Check if region can rest
    public func canRestInCurrentRegion() -> Bool {
        guard let region = currentRegion else { return false }
        return region.state == .stable
    }

    /// Check if region can trade
    public func canTradeInCurrentRegion() -> Bool {
        guard let region = currentRegion else { return false }
        return region.canTrade
    }

    /// Check if exploration can find events in current region
    public func hasAvailableEventsInCurrentRegion() -> Bool {
        guard let regionId = currentRegionId,
              let region = publishedRegions[regionId] else { return false }

        // Engine-First: check content registry for events in this region
        let regionDefId = region.id

        // Map region state to string for content registry
        let regionStateString = mapRegionStateToString(region.state)

        let events = contentRegistry.getAvailableEvents(
            forRegion: regionDefId,
            pressure: worldTension,
            regionState: regionStateString
        )

        // Also filter out completed one-time events (by definition ID)
        let availableEvents = events.filter { eventDef in
            if eventDef.isOneTime {
                return !completedEventIds.contains(eventDef.id)
            }
            return true
        }

        if !availableEvents.isEmpty { return true }

        // Random encounters are always possible if enemies exist
        return !contentRegistry.getAllEnemies().isEmpty
    }

    /// Map RegionState to string for ContentRegistry queries
    private func mapRegionStateToString(_ state: RegionState) -> String {
        switch state {
        case .stable: return "stable"
        case .borderland: return "borderland"
        case .breach: return "breach"
        }
    }

    // MARK: - Sub-Managers

    /// Combat sub-manager — Views access via engine.combat.X
    public private(set) var combat: EngineCombatManager!

    /// Deck sub-manager — Views access via engine.deck.X
    public private(set) var deck: EngineDeckManager!

    /// Player sub-manager — Views access via engine.player.X
    public private(set) var player: EnginePlayerManager!

    // MARK: - Core Subsystems

    private let timeEngine: TimeEngine
    private let pressureEngine: PressureEngine
    private let economyManager: EconomyManager
    private let questTriggerEngine: QuestTriggerEngine

    // MARK: - Internal State

    private var regions: [String: EngineRegionState] = [:]
    private var completedEventIds: Set<String> = []  // Definition IDs (Epic 3: Stable IDs)
    #if DEBUG
    /// Test-only flag: blocks scripted event generation to isolate random encounters.
    internal var _blockScriptedEvents = false
    #endif
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

    // MARK: - Fate Deck

    /// Fate Deck manager for skill checks and event resolution
    public private(set) var fateDeck: FateDeckManager?
    /// Mid-combat encounter state for save/resume (SAV-03)
    public var pendingEncounterState: EncounterSaveState?

    /// Number of cards remaining in the fate draw pile
    public var fateDeckDrawCount: Int { fateDeck?.drawPile.count ?? 0 }

    /// Number of cards in the fate discard pile
    public var fateDeckDiscardCount: Int { fateDeck?.discardPile.count ?? 0 }

    /// Cards in the fate discard pile (for card-counting UI)
    public var fateDeckDiscardCards: [FateCard] { fateDeck?.discardPile ?? [] }

    // MARK: - Services

    /// Injected dependencies (RNG, content, degradation rules).
    public let services: EngineServices

    /// Content registry for loading content packs
    private var contentRegistry: ContentRegistry { services.contentRegistry }

    /// Balance configuration from content pack
    private var balanceConfig: BalanceConfiguration

    // MARK: - Configuration Constants (from BalanceConfiguration)

    private var tensionTickInterval: Int { balanceConfig.pressure.effectiveTickInterval }
    private var restHealAmount: Int { balanceConfig.resources.restHealAmount ?? 3 }
    private var anchorStrengthenCost: Int { balanceConfig.anchor.strengthenCost }
    private var anchorStrengthenAmount: Int { balanceConfig.anchor.strengthenAmount }
    private var anchorDefileCostHP: Int { balanceConfig.anchor.defileCostHP ?? 5 }
    private var anchorDarkStrengthenCostHP: Int { balanceConfig.anchor.darkStrengthenCostHP ?? 3 }

    /// Player's current alignment derived from balance
    private var playerAlignment: BalanceAlignment {
        if player.balance < 30 { return .nav }
        if player.balance > 70 { return .prav }
        return .neutral
    }

    // MARK: - Initialization

    /// Initialize engine with injected services.
    public init(services: EngineServices = .default) {
        self.services = services
        self.balanceConfig = services.contentRegistry.getBalanceConfig() ?? .default
        self.timeEngine = TimeEngine(thresholdInterval: 3)
        self.pressureEngine = PressureEngine(rules: TwilightPressureRules(from: balanceConfig.pressure))
        self.economyManager = EconomyManager()
        self.questTriggerEngine = QuestTriggerEngine(contentRegistry: services.contentRegistry)
        self.combat = nil // set after super.init
        self.deck = nil
        self.player = nil
        self.combat = EngineCombatManager(engine: self)
        self.deck = EngineDeckManager(engine: self)
        self.player = EnginePlayerManager(engine: self)
    }

    /// Convenience init for backward compatibility.
    public convenience init(registry: ContentRegistry) {
        self.init(services: EngineServices(contentRegistry: registry))
    }

    // MARK: - Setup

    /// Reset critical game state flags (called when starting new game or loading save)
    public func resetGameState() {
        isGameOver = false
        gameResult = nil
        currentEventId = nil
        currentEvent = nil
        lastDayEvent = nil
        isInCombat = false
        combat.resetState()
        onStateChanged?()
    }

    /// Initialize the Fate Deck with a set of cards
    public func setupFateDeck(cards: [FateCard]) {
        fateDeck = FateDeckManager(cards: cards)
    }

    // MARK: - Engine-First Initialization

    /// Initialize a new game without legacy WorldState
    /// This is the Engine-First way to start a game
    /// - Parameters:
    ///   - playerName: Character name for display
    ///   - heroId: Hero definition ID from HeroRegistry (data-driven hero system)
    ///   - startingDeck: Starting deck of cards (from CardRegistry.startingDeck)
    public func initializeNewGame(playerName: String = "Герой", heroId: String? = nil, startingDeck: [Card] = []) {
        // Reset state
        isGameOver = false
        gameResult = nil
        currentEventId = nil
        currentEvent = nil
        lastDayEvent = nil
        isInCombat = false

        // Load balance config from content registry
        balanceConfig = contentRegistry.getBalanceConfig() ?? .default

        // Setup player from balance config and hero definition
        player.initializeFromHero(heroId, name: playerName, balanceConfig: balanceConfig)

        // Setup starting deck
        if !startingDeck.isEmpty {
            deck.setupStartingDeck(startingDeck)
        }

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

        // Setup fate deck from content registry
        let allFateCards = contentRegistry.getAllFateCards()
        if !allFateCards.isEmpty {
            setupFateDeck(cards: allFateCards)
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
        var newRegions: [String: EngineRegionState] = [:]

        // CRITICAL: Reset currentRegionId before creating new regions
        currentRegionId = nil

        // Determine entry region from manifest (no hardcoded entry point)
        let entryRegionId = contentRegistry.loadedPacks.values.first(where: { $0.manifest.entryRegionId != nil })?.manifest.entryRegionId

        for def in regionDefs {
            let anchor = createEngineAnchor(from: provider.getAnchorDefinition(forRegion: def.id))
            let regionType = mapRegionType(fromString: def.regionType)
            let regionState = mapRegionState(def.initialState)

            let engineRegion = EngineRegionState(
                id: def.id,
                name: def.title.localized,
                type: regionType,
                state: regionState,
                anchor: anchor,
                neighborIds: def.neighborIds,
                canTrade: regionState == .stable && regionType == .settlement
            )
            newRegions[def.id] = engineRegion

            if def.id == entryRegionId {
                currentRegionId = def.id
            }
        }

        regions = newRegions
        publishedRegions = newRegions
    }

    /// Setup regions from ContentRegistry (Engine-First architecture)
    private func setupRegionsFromRegistry() {
        let regionDefs = contentRegistry.getAllRegions()
        var newRegions: [String: EngineRegionState] = [:]

        // CRITICAL: Reset currentRegionId before creating new regions
        currentRegionId = nil

        // Determine entry region from loaded pack manifest (no hardcoded fallback)
        let entryRegionId = contentRegistry.loadedPacks.values.first(where: { $0.manifest.entryRegionId != nil })?.manifest.entryRegionId

        for def in regionDefs {
            let anchor = contentRegistry.getAnchor(forRegion: def.id).map { anchorDef in
                EngineAnchorState(
                    id: anchorDef.id,
                    name: anchorDef.title.localized,
                    integrity: anchorDef.initialIntegrity,
                    alignment: anchorDef.initialInfluence
                )
            }

            let regionType = mapRegionType(fromString: def.regionType)
            let regionState = mapRegionState(def.initialState)

            let engineRegion = EngineRegionState(
                id: def.id,
                name: def.title.localized,
                type: regionType,
                state: regionState,
                anchor: anchor,
                neighborIds: def.neighborIds,
                canTrade: regionState == .stable && regionType == .settlement
            )
            newRegions[def.id] = engineRegion

            if def.id == entryRegionId {
                currentRegionId = def.id
            }
        }

        regions = newRegions
        publishedRegions = newRegions

        // Set first region as current if none set — prefer stable region
        if currentRegionId == nil {
            currentRegionId = newRegions.values.first(where: { $0.state == .stable })?.id
                ?? newRegions.values.first(where: { $0.state != .breach })?.id
                ?? newRegions.keys.first
        }
    }

    /// Create EngineAnchorState from AnchorDefinition
    private func createEngineAnchor(from def: AnchorDefinition?) -> EngineAnchorState? {
        guard let def = def else { return nil }
        return EngineAnchorState(
            id: def.id,
            name: def.title.localized,
            integrity: def.initialIntegrity,
            alignment: def.initialInfluence
        )
    }

    /// Map region type string from ContentPack to RegionType enum
    /// Uses RegionType(rawValue:) — no hardcoded game-specific strings in Engine
    private func mapRegionType(fromString typeString: String) -> RegionType {
        RegionType(rawValue: typeString.lowercased()) ?? .settlement
    }

    /// Map RegionStateType to RegionState
    private func mapRegionState(_ stateType: RegionStateType) -> RegionState {
        switch stateType {
        case .stable: return .stable
        case .borderland: return .borderland
        case .breach: return .breach
        }
    }

    /// Create initial events from ContentRegistry
    private func createInitialEvents() -> [GameEvent] {
        return contentRegistry.getAllEvents().map { $0.toGameEvent() }
    }

    /// Create initial quests from ContentRegistry
    private func createInitialQuests() -> [Quest] {
        return contentRegistry.getAllQuests().map { $0.toQuest() }
    }

    // MARK: - Main Action Entry Point

    /// Perform a game action - THE ONLY WAY to change game state
    /// Returns result with all state changes
    @discardableResult
    public func performAction(_ action: TwilightGameAction) -> ActionResult {
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
        var triggeredEvents: [String] = []
        var newCurrentEvent: String? = nil
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

        case .defileAnchor:
            let changes = executeDefileAnchor()
            stateChanges.append(contentsOf: changes)

        case .chooseEventOption(let eventId, let choiceIndex):
            let changes = executeEventChoice(eventId: eventId, choiceIndex: choiceIndex)
            stateChanges.append(contentsOf: changes)
            currentEventId = nil

        case .resolveMiniGame(let input):
            let changes = executeMiniGameInput(input)
            stateChanges.append(contentsOf: changes)

        case .startCombat, .combatInitialize,
             // Active Defense actions
             .combatMulligan, .combatGenerateIntent, .combatPlayerAttackWithFate,
             .combatSkipAttack, .combatEnemyResolveWithFate:
            let result = combat.handleCombatAction(action)
            stateChanges.append(contentsOf: result.changes)
            if result.combatStarted { combatStarted = true }

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

        // 8. Update published state for UI
        updatePublishedState()

        // 9. Build and return result
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

        case .defileAnchor:
            return validateDefileAnchor()

        case .chooseEventOption(let eventId, let choiceIndex):
            return validateEventChoice(eventId: eventId, choiceIndex: choiceIndex)

        case .startCombat:
            if isInCombat { return .combatInProgress }
            return nil

        default:
            return nil
        }
    }

    private func validateTravel(to regionId: String) -> ActionError? {
        guard let currentId = currentRegionId,
              let currentRegion = regions[currentId] else {
            return .invalidAction(reason: "No current region")
        }

        // Check if target is neighbor
        if !currentRegion.neighborIds.contains(regionId) {
            return .regionNotNeighbor(regionId: regionId)
        }

        // Check if player can travel (health > 0, etc.)
        if player.health <= 0 {
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

        // Dark heroes pay HP, light/neutral heroes pay faith
        if playerAlignment == .nav {
            let cost = anchorDarkStrengthenCostHP
            if player.health <= cost {
                return .insufficientResources(resource: "health", required: cost, available: player.health)
            }
        } else {
            let cost = anchorStrengthenCost
            if player.faith < cost {
                return .insufficientResources(resource: "faith", required: cost, available: player.faith)
            }
        }

        return nil
    }

    private func validateDefileAnchor() -> ActionError? {
        guard let currentId = currentRegionId,
              let region = regions[currentId] else {
            return .invalidAction(reason: "No current region")
        }

        guard let anchor = region.anchor else {
            return .actionNotAvailableInRegion(action: "defile anchor", regionType: "no anchor")
        }

        // Only dark-aligned heroes can defile
        if playerAlignment != .nav {
            return .invalidAction(reason: "Only dark-aligned heroes can defile anchors")
        }

        // Cannot defile already dark anchor
        if anchor.alignment == .dark {
            return .invalidAction(reason: "Anchor is already dark")
        }

        // Check HP cost
        let cost = anchorDefileCostHP
        if player.health <= cost {
            return .insufficientResources(resource: "health", required: cost, available: player.health)
        }

        return nil
    }

    private func validateEventChoice(eventId: String, choiceIndex: Int) -> ActionError? {
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
        return TwilightPressureRules.calculateTensionIncrease(
            daysPassed: currentDay,
            base: balanceConfig.pressure.pressurePerTurn
        )
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
        let weights = degradableRegions.map { services.degradationRules.selectionWeight(for: $0.state) }
        let totalWeight = weights.reduce(0, +)

        if totalWeight > 0 {
            let roll = services.rng.nextInt(in: 0...(totalWeight - 1))
            var cumulative = 0
            for (index, weight) in weights.enumerated() {
                cumulative += weight
                if roll < cumulative {
                    let region = Array(degradableRegions)[index]

                    // Check anchor resistance using probability
                    let anchorIntegrity = region.anchor?.integrity ?? 0
                    let resistProb = services.degradationRules.resistanceProbability(anchorIntegrity: anchorIntegrity)
                    let resistRoll = Double(services.rng.nextInt(in: 0...99)) / 100.0

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

    private func executeTravel(to regionId: String) -> ([StateChange], [String]) {
        var changes: [StateChange] = []
        let events: [String] = []

        // Clear any leftover event from the previous region
        currentEventId = nil
        currentEvent = nil

        // Update current region
        currentRegionId = regionId
        changes.append(.regionChanged(regionId: regionId))

        // Note: Events are NOT auto-generated on arrival.
        // Player must explicitly choose to Explore to trigger events.
        // This allows player to Rest, Trade, or Strengthen Anchor first.

        return (changes, events)
    }

    private func executeRest() -> [StateChange] {
        var changes: [StateChange] = []

        // Heal player
        let healAmount = restHealAmount
        let newHealth = min(player.maxHealth, player.health + healAmount)
        let delta = newHealth - player.health
        player.health = newHealth
        changes.append(.healthChanged(delta: delta, newValue: newHealth))

        return changes
    }

    private func executeExplore() -> ([StateChange], [String]) {
        let changes: [StateChange] = []
        var events: [String] = []

        guard let regionId = currentRegionId else {
            return (changes, events)
        }

        // Generate exploration event
        if let event = generateEvent(for: regionId, trigger: .exploration) {
            events.append(event)
            currentEventId = event
        } else if let encounter = generateRandomEncounter(regionId: regionId) {
            // No scripted event — try random combat encounter
            events.append(encounter)
            currentEventId = encounter
        }

        return (changes, events)
    }

    /// Generate a random combat encounter when no scripted event fires.
    /// Chance scales with worldTension (0–100). At tension 30 → ~15%, at 80 → ~40%.
    private func generateRandomEncounter(regionId: String) -> String? {
        let encounterChance = max(5, worldTension / 2) // 5..50%
        let roll = services.rng.nextInt(in: 0...99)
        guard roll < encounterChance else { return nil }

        let allEnemies = services.contentRegistry.getAllEnemies()
        guard !allEnemies.isEmpty else { return nil }

        let enemy = allEnemies[services.rng.nextInt(in: 0...(allEnemies.count - 1))]

        let monsterCard = enemy.toCard()
        let combatEvent = GameEvent(
            id: "random_encounter_\(currentDay)_\(regionId)",
            eventType: .combat,
            title: enemy.name.resolved,
            description: enemy.description.resolved,
            choices: [
                EventChoice(
                    id: "fight",
                    text: NSLocalizedString("encounter.action.attack", comment: ""),
                    consequences: EventConsequences(message: "")
                ),
                EventChoice(
                    id: "flee",
                    text: NSLocalizedString("encounter.action.flee", comment: ""),
                    consequences: EventConsequences(healthChange: -2, message: "")
                )
            ],
            monsterCard: monsterCard
        )

        currentEvent = combatEvent
        return combatEvent.id
    }

    private func executeStrengthenAnchor() -> [StateChange] {
        var changes: [StateChange] = []

        guard let regionId = currentRegionId,
              var region = regions[regionId],
              var anchor = region.anchor else {
            return changes
        }

        // Dark heroes pay HP and shift alignment toward dark
        if playerAlignment == .nav {
            let cost = anchorDarkStrengthenCostHP
            player.health -= cost
            changes.append(.healthChanged(delta: -cost, newValue: player.health))

            // Shift alignment toward dark
            if anchor.alignment != .dark {
                let oldAlignment = anchor.alignment
                anchor.alignment = (oldAlignment == .light) ? .neutral : .dark
                changes.append(.anchorAlignmentChanged(anchorId: anchor.id, newAlignment: anchor.alignment.rawValue))
            }
        } else {
            // Light/neutral heroes pay faith
            let cost = anchorStrengthenCost
            player.faith -= cost
            changes.append(.faithChanged(delta: -cost, newValue: player.faith))
        }

        // Strengthen anchor integrity
        let strengthAmount = anchorStrengthenAmount
        let newIntegrity = min(100, anchor.integrity + strengthAmount)
        let delta = newIntegrity - anchor.integrity
        anchor.integrity = newIntegrity
        region.anchor = anchor
        regions[regionId] = region

        changes.append(.anchorIntegrityChanged(anchorId: anchor.id, delta: delta, newValue: newIntegrity))

        return changes
    }

    private func executeDefileAnchor() -> [StateChange] {
        var changes: [StateChange] = []

        guard let regionId = currentRegionId,
              var region = regions[regionId],
              var anchor = region.anchor else {
            return changes
        }

        // Spend HP
        let cost = anchorDefileCostHP
        player.health -= cost
        changes.append(.healthChanged(delta: -cost, newValue: player.health))

        // Shift alignment to dark
        anchor.alignment = .dark
        region.anchor = anchor
        regions[regionId] = region

        changes.append(.anchorAlignmentChanged(anchorId: anchor.id, newAlignment: AnchorAlignment.dark.rawValue))

        return changes
    }

    private func executeEventChoice(eventId: String, choiceIndex: Int) -> [StateChange] {
        var changes: [StateChange] = []

        // Get consequences from current event
        if let event = currentEvent,
           choiceIndex < event.choices.count {
            let choice = event.choices[choiceIndex]
            changes.append(contentsOf: applyConsequences(choice.consequences))
        }

        // Mark event completed if oneTime (using definition ID for persistence)
        if let eventId = currentEvent?.id {
            completedEventIds.insert(eventId)
        }
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
                let newHealth = min(player.maxHealth, player.health + amount)
                player.health = newHealth
                changes.append(.healthChanged(delta: amount, newValue: newHealth))
            case "faith":
                let newFaith = player.faith + amount
                player.faith = newFaith
                changes.append(.faithChanged(delta: amount, newValue: newFaith))
            default:
                break
            }
        }

        return changes
    }

    // MARK: - Consequences

    private func applyConsequences(_ consequences: EventConsequences) -> [StateChange] {
        var changes: [StateChange] = []

        // Health
        if let healthDelta = consequences.healthChange, healthDelta != 0 {
            let newHealth = max(0, min(player.maxHealth, player.health + healthDelta))
            player.health = newHealth
            changes.append(.healthChanged(delta: healthDelta, newValue: newHealth))
        }

        // Faith
        if let faithDelta = consequences.faithChange, faithDelta != 0 {
            let newFaith = max(0, player.faith + faithDelta)
            player.faith = newFaith
            changes.append(.faithChanged(delta: faithDelta, newValue: newFaith))
        }

        // Balance
        if let balanceDelta = consequences.balanceChange, balanceDelta != 0 {
            let newBalance = max(0, min(100, player.balance + balanceDelta))
            player.balance = newBalance
            changes.append(.balanceChanged(delta: balanceDelta, newValue: newBalance))
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

    private func generateEvent(for regionId: String, trigger: EventTrigger) -> String? {
        #if DEBUG
        if _blockScriptedEvents { return nil }
        #endif
        // Engine-First: generate event from ContentRegistry
        guard let region = publishedRegions[regionId] else {
            return nil
        }
        let regionDefId = region.id

        // Map region state to string for content registry
        let regionStateString = mapRegionStateToString(region.state)

        // Get available events from ContentRegistry
        let availableDefinitions = contentRegistry.getAvailableEvents(
            forRegion: regionDefId,
            pressure: worldTension,
            regionState: regionStateString
        )

        // Filter by flags, balance, and one-time completion
        let activeFlags = Set(worldFlags.filter { $0.value }.map { $0.key })
        let currentBalance = Int(resonanceValue)

        let filteredDefinitions = availableDefinitions.filter { eventDef in
            // One-time events already completed
            if eventDef.isOneTime && completedEventIds.contains(eventDef.id) {
                return false
            }
            // Required flags
            let avail = eventDef.availability
            for flag in avail.requiredFlags {
                if !activeFlags.contains(flag) { return false }
            }
            // Forbidden flags
            for flag in avail.forbiddenFlags {
                if activeFlags.contains(flag) { return false }
            }
            // Balance range
            if let min = avail.minBalance, currentBalance < min { return false }
            if let max = avail.maxBalance, currentBalance > max { return false }
            return true
        }

        guard !filteredDefinitions.isEmpty else { return nil }

        // Weighted random selection
        let totalWeight = filteredDefinitions.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else {
            // If all weights are 0, select randomly
            let selectedDef = filteredDefinitions[services.rng.nextInt(in: 0...(filteredDefinitions.count - 1))]
            let gameEvent = selectedDef.toGameEvent(forRegion: regionDefId)
            currentEvent = gameEvent
            return gameEvent.id
        }

        let roll = services.rng.nextInt(in: 0...(totalWeight - 1))
        var cumulative = 0
        for eventDef in filteredDefinitions {
            cumulative += eventDef.weight
            if roll < cumulative {
                let gameEvent = eventDef.toGameEvent(forRegion: regionDefId)
                currentEvent = gameEvent
                return gameEvent.id
            }
        }

        // Fallback — weighted loop should always select, but guard defensively
        let selectedDef = filteredDefinitions[services.rng.nextInt(in: 0...(filteredDefinitions.count - 1))]
        let gameEvent = selectedDef.toGameEvent(forRegion: regionDefId)
        currentEvent = gameEvent
        return gameEvent.id
    }

    // MARK: - Quest Progress

    private func checkQuestProgress() -> [StateChange] {
        // Engine-First: quest progress is now managed by QuestTriggerEngine
        // This is called after each action to check for auto-complete conditions
        return []
    }

    /// Process a quest trigger action through the new data-driven QuestTriggerEngine
    private func processQuestTriggerAction(_ action: QuestTriggerAction) -> [StateChange] {
        var changes: [StateChange] = []

        // Build context from current state
        let context = buildQuestTriggerContext()

        // Process through quest trigger engine
        let updates = questTriggerEngine.processAction(action, context: context)

        // Apply updates
        for update in updates {
            switch update.type {
            case .questStarted:
                // Start new quest
                if let questDef = contentRegistry.getQuest(id: update.questId) {
                    let quest = questDef.toQuest()
                    activeQuests.append(quest)
                    publishedActiveQuests = activeQuests
                    changes.append(.questStarted(questId: update.questId))
                }

            case .objectiveCompleted:
                // Update quest progress
                if let index = activeQuests.firstIndex(where: { $0.id == update.questId }),
                   let objectiveId = update.objectiveId {
                    // Mark objective as completed
                    changes.append(.objectiveCompleted(questId: update.questId, objectiveId: objectiveId))

                    // Set flags
                    for flag in update.flagsToSet {
                        worldFlags[flag] = true
                        publishedWorldFlags = worldFlags
                        changes.append(.flagSet(key: flag, value: true))
                    }

                    // Check if quest completed (no next objective)
                    if update.nextObjectiveId == nil {
                        activeQuests[index].completed = true
                        completedQuestIds.insert(update.questId)
                        changes.append(.questCompleted(questId: update.questId))
                    }
                }

            case .questCompleted:
                // Quest fully completed
                completedQuestIds.insert(update.questId)
                changes.append(.questCompleted(questId: update.questId))

            case .questFailed:
                // Quest failed
                changes.append(.questFailed(questId: update.questId))
            }
        }

        return changes
    }

    /// Build QuestTriggerContext from current engine state
    private func buildQuestTriggerContext() -> QuestTriggerContext {
        // Build active quest states
        let questStates = activeQuests.compactMap { quest -> QuestState? in
            guard let questDef = contentRegistry.getQuest(id: quest.id) else {
                return nil
            }

            // Determine current objective (simplified - uses stage)
            let currentObjectiveId = questDef.objectives.indices.contains(quest.stage - 1)
                ? questDef.objectives[quest.stage - 1].id
                : questDef.objectives.first?.id

            // Completed objectives are those before current stage
            let completedIds = Set(questDef.objectives.prefix(max(0, quest.stage - 1)).map { $0.id })

            return QuestState(
                definitionId: questDef.id,
                currentObjectiveId: currentObjectiveId,
                completedObjectiveIds: completedIds
            )
        }

        // Build resources dictionary
        let resources: [String: Int] = [
            "health": player.health,
            "faith": player.faith,
            "balance": player.balance,
            "tension": worldTension
        ]

        // Get current region ID (already a String definition ID)
        let currentRegionStringId: String = currentRegionId ?? ""

        return QuestTriggerContext(
            activeQuests: questStates,
            completedQuestIds: completedQuestIds,
            worldFlags: worldFlags,
            resources: resources,
            currentDay: currentDay,
            currentRegionId: currentRegionStringId
        )
    }

    // MARK: - End Conditions

    private func checkEndConditions() -> GameEndResult? {
        // Defeat: tension 100%
        if worldTension >= 100 {
            return .defeat(reason: "Напряжение мира достигло максимума")
        }

        // Defeat: health 0
        if player.health <= 0 {
            return .defeat(reason: "Герой погиб")
        }

        // Victory: main quest completed (flag from BalanceConfiguration)
        if let victoryFlag = balanceConfig.endConditions.mainQuestCompleteFlag,
           worldFlags[victoryFlag] == true {
            return .victory(endingId: "main_quest_complete")
        }

        return nil
    }

    // syncToLegacy removed - Engine-First architecture

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

        // Clear current event if currentEventId is nil
        if currentEventId == nil {
            currentEvent = nil
        }
        // Note: currentEvent is set directly when generating events
        // Player stats are managed directly by the engine

        onStateChanged?()
    }

    // MARK: - Event Log

    /// Add entry to event log
    public func addLogEntry(
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
        onStateChanged?()
    }

    // MARK: - Day Events

    /// Trigger day event (tension increase, degradation, etc.)
    private func triggerDayEvent(_ event: DayEvent) {
        lastDayEvent = event
    }

    // MARK: - Combat Helpers (for EngineCombatManager)

    /// Mulligan: return cards to deck and draw replacements
    func performCombatMulligan(cardIds: [String]) {
        deck.performMulligan(cardIds: cardIds)
    }

    /// Initialize combat deck: shuffle all cards, draw 5
    func performCombatInitialize() {
        deck.initializeCombat()
    }

    // MARK: - Save/Load Support Methods

    /// Get completed quest IDs for save
    public func getCompletedQuestIds() -> Set<String> {
        return completedQuestIds
    }

    /// Get quest stages for save
    public func getQuestStages() -> [String: Int] {
        return questStages
    }

    /// Get completed event IDs for save (definition IDs)
    public func getCompletedEventIds() -> Set<String> {
        return completedEventIds
    }

    /// Set regions from save
    public func setRegions(_ newRegions: [String: EngineRegionState]) {
        regions = newRegions
        publishedRegions = newRegions
    }

    /// Set world flags from save
    public func setWorldFlags(_ newFlags: [String: Bool]) {
        worldFlags = newFlags
        publishedWorldFlags = newFlags
    }

    /// Merge world flags (add or update individual keys)
    public func mergeWorldFlags(_ flags: [String: Bool]) {
        for (key, value) in flags {
            worldFlags[key] = value
        }
        publishedWorldFlags = worldFlags
    }

    /// Adjust resonance by delta, clamped to -100..+100
    public func adjustResonance(by delta: Float) {
        resonanceValue = max(-100, min(100, resonanceValue + delta))
    }

    /// Set completed event IDs from save (definition IDs)
    public func setCompletedEventIds(_ ids: Set<String>) {
        completedEventIds = ids
    }

    /// Set event log from save
    public func setEventLog(_ log: [EventLogEntry]) {
        eventLog = log
        publishedEventLog = Array(log.suffix(100))
    }

    /// Set main quest stage from save
    public func setMainQuestStage(_ stage: Int) {
        mainQuestStage = stage
    }

    /// Set completed quest IDs from save
    public func setCompletedQuestIds(_ ids: Set<String>) {
        completedQuestIds = ids
    }

    /// Set quest stages from save
    public func setQuestStages(_ stages: [String: Int]) {
        questStages = stages
    }

    /// Update published state after loading
    public func updatePublishedStateAfterLoad() {
        updatePublishedState()
    }
}

// MARK: - Event Trigger

/// Trigger type that causes an event to fire
public enum EventTrigger {
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
public struct EngineRegionState: Identifiable {
    /// Stable definition ID (serves as both identity and definition reference)
    public let id: String
    /// Localized display name
    public let name: String
    /// Region type (settlement, sacred, etc.)
    public let type: RegionType
    /// Current state (stable, borderland, breach)
    public var state: RegionState
    /// Anchor protecting this region, if any
    public var anchor: EngineAnchorState?
    /// Definition IDs of neighboring regions
    public let neighborIds: [String]
    /// Whether trading is available in this region
    public var canTrade: Bool
    /// Whether the player has visited this region
    public var visited: Bool = false
    /// Player reputation in this region
    public var reputation: Int = 0

    /// Create directly (Engine-First) - id is the definition ID
    public init(
        id: String,
        name: String,
        type: RegionType,
        state: RegionState,
        anchor: EngineAnchorState? = nil,
        neighborIds: [String] = [],
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
    public var canRest: Bool {
        state == .stable && (type == .settlement || type == .sacred)
    }

    /// Region alignment derived from anchor (neutral if no anchor)
    public var alignment: AnchorAlignment {
        anchor?.alignment ?? .neutral
    }
}

// MARK: - Engine Anchor State (Bridge from Legacy)

/// Internal state for engine anchor tracking (REQUIRED definitionId - Audit A1)
public struct EngineAnchorState {
    /// Stable definition ID (serves as both identity and definition reference)
    public let id: String
    /// Localized display name
    public let name: String
    /// Current integrity level (0-100)
    public var integrity: Int
    /// Anchor alignment (light/neutral/dark)
    public var alignment: AnchorAlignment

    /// Create directly (Engine-First) - id is the definition ID
    public init(id: String, name: String, integrity: Int, alignment: AnchorAlignment = .neutral) {
        self.id = id
        self.name = name
        self.integrity = max(0, min(100, integrity))
        self.alignment = alignment
    }
}

// MARK: - Combat State (for UI)

/// Read-only combat state for UI binding
public struct CombatState {
    /// The enemy card being fought
    public let enemy: Card
    /// Enemy's current health points
    public let enemyHealth: Int
    /// Enemy's current will/resolve (Spirit track)
    public let enemyWill: Int
    /// Enemy's maximum will/resolve
    public let enemyMaxWill: Int
    /// Current combat turn number
    public let turnNumber: Int
    /// Actions remaining this turn
    public let actionsRemaining: Int
    /// Bonus dice accumulated for next attack
    public let bonusDice: Int
    /// Bonus damage accumulated for next attack
    public let bonusDamage: Int
    /// Whether the next attack is the first in this combat
    public let isFirstAttack: Bool
    /// Cards currently in the player's hand
    public let playerHand: [Card]

    /// Whether this enemy has a Spirit track (will > 0)
    public var hasSpiritTrack: Bool {
        enemyMaxWill > 0
    }

    /// Enemy's maximum health from card definition
    public var enemyMaxHealth: Int {
        enemy.health ?? 10
    }

    /// Enemy's defense value from card definition
    public var enemyDefense: Int {
        enemy.defense ?? 10
    }

    /// Enemy's attack power from card definition
    public var enemyPower: Int {
        enemy.power ?? 3
    }

    /// Initialize combat state with all required fields
    public init(
        enemy: Card,
        enemyHealth: Int,
        enemyWill: Int = 0,
        enemyMaxWill: Int = 0,
        turnNumber: Int,
        actionsRemaining: Int,
        bonusDice: Int,
        bonusDamage: Int,
        isFirstAttack: Bool,
        playerHand: [Card]
    ) {
        self.enemy = enemy
        self.enemyHealth = enemyHealth
        self.enemyWill = enemyWill
        self.enemyMaxWill = enemyMaxWill
        self.turnNumber = turnNumber
        self.actionsRemaining = actionsRemaining
        self.bonusDice = bonusDice
        self.bonusDamage = bonusDamage
        self.isFirstAttack = isFirstAttack
        self.playerHand = playerHand
    }
}

// MARK: - Engine Persistence (Engine-First Save/Load)

public extension TwilightGameEngine {

    /// Create a save state from current engine state (Engine-First Architecture)
    /// This replaces GameState-based saves
    func createEngineSave() -> EngineSave {
        // Collect active pack versions
        var activePackSet: [String: String] = [:]
        var primaryCampaignPackId: String? = nil

        for (packId, pack) in services.contentRegistry.loadedPacks {
            activePackSet[packId] = pack.manifest.version.description

            // First campaign/full pack becomes the primary campaign pack
            if primaryCampaignPackId == nil &&
               (pack.manifest.packType == .campaign || pack.manifest.packType == .full) {
                primaryCampaignPackId = packId
            }
        }

        // Convert regions to save state
        let regionSaves = regions.values.map { RegionSaveState(from: $0) }

        // Convert event log
        let eventLogSaves = publishedEventLog.map { EventLogEntrySave(from: $0) }

        // Get current region definition ID
        var currentRegionDefId: String? = nil
        if let currentId = currentRegionId,
           let region = regions[currentId] {
            currentRegionDefId = region.id
        }

        return EngineSave(
            version: EngineSave.currentVersion,
            savedAt: Date(),
            gameDuration: previousSessionsDuration + Date().timeIntervalSince(gameStartDate),

            // Pack compatibility
            coreVersion: EngineSave.currentCoreVersion,
            activePackSet: activePackSet,
            formatVersion: EngineSave.currentFormatVersion,
            primaryCampaignPackId: primaryCampaignPackId,

            // Player state
            playerName: player.name,
            heroId: player.heroId,
            playerHealth: player.health,
            playerMaxHealth: player.maxHealth,
            playerFaith: player.faith,
            playerMaxFaith: player.maxFaith,
            playerBalance: player.balance,

            // Deck state (card IDs for stable serialization)
            deckCardIds: deck.playerDeck.map { $0.id },
            handCardIds: deck.playerHand.map { $0.id },
            discardCardIds: deck.playerDiscard.map { $0.id },

            // World state
            currentDay: currentDay,
            worldTension: worldTension,
            lightDarkBalance: lightDarkBalance,
            currentRegionId: currentRegionDefId,

            // Regions
            regions: regionSaves,

            // Quest state (using definitionId for stable serialization - Audit A1)
            mainQuestStage: mainQuestStage,
            activeQuestIds: publishedActiveQuests.map { $0.id },
            completedQuestIds: Array(completedQuestIds),
            questStages: Dictionary(uniqueKeysWithValues: publishedActiveQuests.map { ($0.id, $0.stage) }),

            // Events (already String definition IDs)
            completedEventIds: Array(completedEventIds),
            eventLog: eventLogSaves,

            // World flags
            worldFlags: publishedWorldFlags,

            // Fate deck state (SAV-02)
            fateDeckState: fateDeck?.getState(),
            encounterState: pendingEncounterState,

            // RNG state (Audit A2 - save for deterministic replay)
            rngSeed: services.rng.currentSeed(),
            rngState: services.rng.currentState()
        )
    }

    /// Restore engine state from a save (Engine-First Architecture)
    /// This replaces GameState-based loads
    func restoreFromEngineSave(_ save: EngineSave) {
        // Validate compatibility
        let compatibility = save.validateCompatibility(with: services.contentRegistry)

        // Log compatibility result
        #if DEBUG
        switch compatibility {
        case .fullyCompatible:
            print("✅ Save is fully compatible")
        case .compatible(let warnings):
            print("⚠️ Save is compatible with warnings:")
            warnings.forEach { print("   - \($0)") }
        case .incompatible(let errors):
            print("❌ Save is incompatible:")
            errors.forEach { print("   - \($0)") }
        }
        #endif

        if !compatibility.isLoadable {
            #if DEBUG
            print("❌ Save cannot be loaded due to incompatibility")
            #endif
            // Even if incompatible, try to initialize a fallback state
            // so the user doesn't see a blank screen
            initializeFallbackState()
            return
        }

        // Restore player state
        player.restoreFromSave(save)

        // Restore deck (convert card IDs back to cards)
        deck.setDeck(save.deckCardIds.compactMap { CardFactory(contentRegistry: services.contentRegistry).getCard(id: $0) })
        deck.setHand(save.handCardIds.compactMap { CardFactory(contentRegistry: services.contentRegistry).getCard(id: $0) })
        deck.setDiscard(save.discardCardIds.compactMap { CardFactory(contentRegistry: services.contentRegistry).getCard(id: $0) })

        // Restore world state
        currentDay = save.currentDay
        worldTension = save.worldTension
        lightDarkBalance = save.lightDarkBalance

        // Create regions from save data
        var newRegions: [String: EngineRegionState] = [:]
        for regionSave in save.regions {
            var anchor: EngineAnchorState? = nil
            if let anchorId = regionSave.anchorDefinitionId {
                let anchorDef = contentRegistry.getAnchor(id: anchorId)
                let anchorName = anchorDef?.title.localized ?? anchorId
                anchor = EngineAnchorState(
                    id: anchorId,
                    name: anchorName,
                    integrity: regionSave.anchorIntegrity ?? 100
                )
            }

            let region = EngineRegionState(
                id: regionSave.definitionId,
                name: regionSave.name,
                type: RegionType(rawValue: regionSave.type) ?? .settlement,
                state: RegionState(rawValue: regionSave.state) ?? .stable,
                anchor: anchor,
                neighborIds: regionSave.neighborDefinitionIds,
                canTrade: regionSave.canTrade,
                visited: regionSave.visited,
                reputation: regionSave.reputation
            )
            newRegions[regionSave.definitionId] = region
        }

        regions = newRegions
        publishedRegions = newRegions

        // Restore current region
        if let currentDefId = save.currentRegionId {
            currentRegionId = currentDefId
        }

        // Restore quest state
        mainQuestStage = save.mainQuestStage
        completedQuestIds = Set(save.completedQuestIds)

        // Restore active quests from definitionIds (using ContentRegistry)
        var restoredQuests: [Quest] = []
        for questDefId in save.activeQuestIds {
            if let questDef = contentRegistry.getQuest(id: questDefId) {
                var quest = questDef.toQuest()
                // Restore stage from saved data
                if let savedStage = save.questStages[questDefId] {
                    quest.stage = savedStage
                }
                restoredQuests.append(quest)
            }
        }
        activeQuests = restoredQuests
        publishedActiveQuests = restoredQuests

        // Restore completed events (already String definition IDs)
        completedEventIds = Set(save.completedEventIds)

        // Restore event log
        publishedEventLog = save.eventLog.map { $0.toEventLogEntry() }

        // Restore world flags
        publishedWorldFlags = save.worldFlags
        worldFlags = save.worldFlags

        // Restore fate deck state (SAV-02)
        if let deckState = save.fateDeckState {
            fateDeck?.restoreState(deckState)
        }

        // Restore mid-combat state (SAV-03)
        pendingEncounterState = save.encounterState

        // Restore game duration tracking
        previousSessionsDuration = save.gameDuration
        gameStartDate = Date()

        // Restore RNG state (Audit 1.5 - determinism after load)
        services.rng.restoreState(save.rngState)

        // Clear game over state
        isGameOver = false
        gameResult = nil
    }

    // MARK: - Fallback Initialization

    /// Initialize a minimal fallback state when save loading fails
    /// This prevents the user from seeing a blank/white screen
    private func initializeFallbackState() {
        #if DEBUG
        print("⚠️ Initializing fallback state due to save incompatibility")
        #endif

        // Initialize with minimal default values
        isGameOver = false
        gameResult = nil
        currentEventId = nil
        currentEvent = nil
        lastDayEvent = nil
        isInCombat = false

        player.setName("Герой")
        player.setMaxHealth(20)
        player.setHealth(20)
        player.setFaith(10)
        player.maxFaith = 15
        player.setBalance(50)
        player.strength = 5

        currentDay = 1
        worldTension = 30
        lightDarkBalance = 50

        // Try to setup regions from registry (this is the critical part)
        setupRegionsFromRegistry()

        // If still no regions, this is a critical error
        if publishedRegions.isEmpty {
            #if DEBUG
            print("❌ CRITICAL: No regions available even in fallback state!")
            print("   ContentRegistry has \(contentRegistry.getAllRegions().count) regions")
            #endif
        }
    }

    // MARK: - Test Helpers (Engine-First Architecture)

    /// Initialize engine from ContentRegistry for testing
    /// Note: Uses the already-configured contentRegistry, just sets up regions
    func initializeFromContentRegistry(_ registry: ContentRegistry) {
        // ContentRegistry is set in init, just setup regions
        setupRegionsFromRegistry()
    }


    /// Set world tension directly (for testing)
    func setWorldTension(_ tension: Int) {
        worldTension = min(100, max(0, tension))
    }

    /// Set current region directly (for testing)
    func setCurrentRegion(_ regionId: String) {
        currentRegionId = regionId
    }

    /// Set resonance value directly (for testing)
    func setResonance(_ value: Float) {
        resonanceValue = max(-100, min(100, value))
    }

    #if DEBUG
    /// Block all scripted events from generating (for testing random encounters)
    func blockAllScriptedEvents() {
        let allEvents = contentRegistry.getAllEventDefinitions()
        for event in allEvents {
            completedEventIds.insert(event.id)
        }
        _blockScriptedEvents = true
    }
    #endif
}

import Foundation
import Combine

// MARK: - Game Engine
// The central game orchestrator - ALL game actions go through here

/// Main game engine — the central orchestrator for all game actions
/// UI should NEVER mutate state directly - always go through performAction()
public final class TwilightGameEngine: ObservableObject {

    // MARK: - Published State (for UI binding)
    // Audit v1.1 Issue #1, #8: UI reads directly from Engine, not WorldState

    /// Current in-game day number
    @Published public private(set) var currentDay: Int = 0
    /// World tension level (0-100), drives degradation and difficulty
    @Published public private(set) var worldTension: Int = 30
    /// ID of the region the player is currently in
    @Published public private(set) var currentRegionId: String?
    /// Whether the game has ended (victory or defeat)
    @Published public private(set) var isGameOver: Bool = false
    /// Result of the game if it has ended
    @Published public private(set) var gameResult: GameEndResult?

    /// ID of the event currently being presented to the player
    @Published public private(set) var currentEventId: String?
    /// Whether the player is currently in combat
    @Published public private(set) var isInCombat: Bool = false

    /// Result of the last performed action
    @Published public private(set) var lastActionResult: ActionResult?

    // MARK: - Published State for UI (Engine-First Architecture)

    /// All regions with their current state - UI reads this directly
    @Published public private(set) var publishedRegions: [String: EngineRegionState] = [:]

    /// Player stats - UI reads these directly instead of Player model
    @Published public private(set) var playerHealth: Int = 10
    @Published public private(set) var playerMaxHealth: Int = 10
    @Published public private(set) var playerFaith: Int = 3
    @Published public private(set) var playerMaxFaith: Int = 10
    @Published public private(set) var playerBalance: Int = 50
    @Published public private(set) var playerName: String = "Герой"
    @Published public private(set) var heroId: String?  // Hero definition ID for data-driven hero system

    /// Character stats (Engine-First) - used for combat calculations
    @Published public private(set) var playerStrength: Int = 5
    @Published public private(set) var playerDexterity: Int = 0
    @Published public private(set) var playerConstitution: Int = 0
    @Published public private(set) var playerIntelligence: Int = 0
    @Published public private(set) var playerWisdom: Int = 0
    @Published public private(set) var playerCharisma: Int = 0

    /// World resonance value (-100..+100), drives Navi/Prav world state
    @Published public private(set) var resonanceValue: Float = 0.0

    /// Active curses on player (Engine-First)
    @Published public private(set) var playerActiveCurses: [ActiveCurse] = []

    /// World flags - for quest/event conditions
    @Published public private(set) var publishedWorldFlags: [String: Bool] = [:]

    /// Current event being displayed to player
    @Published public private(set) var currentEvent: GameEvent?

    /// Day event notification (tension increase, degradation, etc.)
    @Published public private(set) var lastDayEvent: DayEvent?

    /// Active quests
    @Published public private(set) var publishedActiveQuests: [Quest] = []

    /// Event log (last 100 entries)
    @Published public private(set) var publishedEventLog: [EventLogEntry] = []

    /// Light/Dark balance of the world
    @Published public private(set) var lightDarkBalance: Int = 50

    /// Main quest stage (1-5)
    @Published public private(set) var mainQuestStage: Int = 1

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

    /// Check if player can afford faith cost
    public func canAffordFaith(_ cost: Int) -> Bool {
        return playerFaith >= cost
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

    /// Player balance description for UI
    public var playerBalanceDescription: String {
        switch playerBalance {
        case 70...100: return "Свет"
        case 31..<70: return "Равновесие"
        default: return "Тьма"
        }
    }

    // MARK: - Hero Abilities (Engine-First)

    /// Get hero definition from registry
    public var heroDefinition: HeroDefinition? {
        guard let heroId = heroId else { return nil }
        return HeroRegistry.shared.hero(id: heroId)
    }

    /// Get hero's special ability
    private var heroAbility: HeroAbility? {
        return heroDefinition?.specialAbility
    }

    /// Check if player has a specific curse (Engine-First)
    public func hasCurse(_ type: CurseType) -> Bool {
        return playerActiveCurses.contains { $0.type == type }
    }

    /// Get damage modifier from curses (weakness: -1, shadowOfNav: +3)
    public func getCurseDamageDealtModifier() -> Int {
        var modifier = 0
        if hasCurse(.weakness) { modifier -= 1 }
        if hasCurse(.shadowOfNav) { modifier += 3 }
        return modifier
    }

    /// Get damage taken modifier from curses (fear: +1)
    public func getCurseDamageTakenModifier() -> Int {
        var modifier = 0
        if hasCurse(.fear) { modifier += 1 }
        return modifier
    }

    /// Get bonus dice from hero ability (e.g., Tracker on first attack)
    public func getHeroBonusDice(isFirstAttack: Bool) -> Int {
        guard let ability = heroAbility,
              ability.trigger == .onAttack else { return 0 }

        // Check ability condition
        if let condition = ability.condition {
            switch condition.type {
            case .firstAttack:
                guard isFirstAttack else { return 0 }
            default:
                break
            }
        }

        return ability.effects.first { $0.type == .bonusDice }?.value ?? 0
    }

    /// Get bonus damage from hero ability (e.g., Berserker when HP < 50%)
    public func getHeroDamageBonus(targetFullHP: Bool = false) -> Int {
        guard let ability = heroAbility,
              ability.trigger == .onDamageDealt else { return 0 }

        // Check ability condition
        if let condition = ability.condition {
            switch condition.type {
            case .hpBelowPercent:
                let threshold = condition.value ?? 50
                guard playerHealth < playerMaxHealth * threshold / 100 else { return 0 }
            case .targetFullHP:
                guard targetFullHP else { return 0 }
            default:
                break
            }
        }

        return ability.effects.first { $0.type == .bonusDamage }?.value ?? 0
    }

    /// Get damage reduction from hero ability (e.g., Priest vs dark sources)
    public func getHeroDamageReduction(fromDarkSource: Bool = false) -> Int {
        guard let ability = heroAbility,
              ability.trigger == .onDamageReceived else { return 0 }

        // Check ability condition
        if let condition = ability.condition {
            switch condition.type {
            case .damageSourceDark:
                guard fromDarkSource else { return 0 }
            default:
                break
            }
        }

        return ability.effects.first { $0.type == .damageReduction }?.value ?? 0
    }

    /// Check if hero gains faith at end of turn (e.g., Mage meditation)
    public var shouldGainFaithEndOfTurn: Bool {
        guard let ability = heroAbility,
              ability.trigger == .turnEnd else { return false }
        return ability.effects.contains { $0.type == .gainFaith }
    }

    /// Calculate total damage dealt with curses and hero abilities
    public func calculateDamageDealt(_ baseDamage: Int, targetFullHP: Bool = false) -> Int {
        let curseModifier = getCurseDamageDealtModifier()
        let heroBonus = getHeroDamageBonus(targetFullHP: targetFullHP)
        return max(0, baseDamage + curseModifier + heroBonus)
    }

    /// Take damage with curse modifiers and hero abilities
    public func takeDamageWithModifiers(_ baseDamage: Int, fromDarkSource: Bool = false) {
        let curseModifier = getCurseDamageTakenModifier()
        let heroReduction = getHeroDamageReduction(fromDarkSource: fromDarkSource)
        let actualDamage = max(0, baseDamage + curseModifier - heroReduction)
        playerHealth = max(0, playerHealth - actualDamage)
    }

    /// Apply curse to player (Engine-First)
    public func applyCurse(type: CurseType, duration: Int, sourceCard: String? = nil) {
        let curse = ActiveCurse(type: type, duration: duration, sourceCard: sourceCard)
        playerActiveCurses.append(curse)
    }

    /// Remove curse from player (Engine-First)
    public func removeCurse(type: CurseType? = nil) {
        if let specificType = type {
            playerActiveCurses.removeAll { $0.type == specificType }
        } else if !playerActiveCurses.isEmpty {
            playerActiveCurses.removeFirst()
        }
    }

    /// Tick curses at end of turn (reduce duration, remove expired)
    public func tickCurses() {
        for i in (0..<playerActiveCurses.count).reversed() {
            playerActiveCurses[i].duration -= 1
            if playerActiveCurses[i].duration <= 0 {
                playerActiveCurses.remove(at: i)
            }
        }
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

        return !availableEvents.isEmpty
    }

    /// Map RegionState to string for ContentRegistry queries
    private func mapRegionStateToString(_ state: RegionState) -> String {
        switch state {
        case .stable: return "stable"
        case .borderland: return "borderland"
        case .breach: return "breach"
        }
    }

    // MARK: - Core Subsystems

    private let timeEngine: TimeEngine
    private let pressureEngine: PressureEngine
    private let economyManager: EconomyManager
    private let questTriggerEngine: QuestTriggerEngine

    // MARK: - Internal State

    private var regions: [String: EngineRegionState] = [:]
    private var completedEventIds: Set<String> = []  // Definition IDs (Epic 3: Stable IDs)
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
    private var _playerDeck: [Card] = []
    /// Public read-only accessor for deck (for testing/UI)
    public var playerDeck: [Card] { _playerDeck }

    /// Player's hand cards (Published for UI binding)
    @Published public private(set) var playerHand: [Card] = []

    private var _playerDiscard: [Card] = []
    /// Public read-only accessor for discard pile (for testing/UI)
    public var playerDiscard: [Card] { _playerDiscard }

    // MARK: - Combat State

    /// Current enemy card in combat
    @Published public private(set) var combatEnemy: Card?

    /// Enemy current health
    @Published public private(set) var combatEnemyHealth: Int = 0

    /// Enemy current will/resolve (Spirit track, 0 if enemy has no will)
    @Published public private(set) var combatEnemyWill: Int = 0

    /// Enemy maximum will/resolve for UI progress bars
    @Published public private(set) var combatEnemyMaxWill: Int = 0

    /// Combat actions remaining this turn
    @Published public private(set) var combatActionsRemaining: Int = 3

    /// Combat turn number
    @Published public private(set) var combatTurnNumber: Int = 1

    /// Bonus dice for next attack (from cards)
    private var combatBonusDice: Int = 0

    /// Bonus damage for next attack (from cards)
    private var combatBonusDamage: Int = 0

    /// Is this the first attack in this combat (for abilities)
    private var combatIsFirstAttack: Bool = true

    // MARK: - Fate Deck

    /// Fate Deck manager for skill checks and event resolution
    public private(set) var fateDeck: FateDeckManager?

    /// Last fate attack result for UI display
    @Published public private(set) var lastFateAttackResult: FateAttackResult?

    // MARK: - Active Defense System (Fate-based combat)

    /// Last attack fate card result (player attacking enemy)
    @Published public private(set) var lastAttackFateResult: FateDrawResult?

    /// Last defense fate card result (player defending from enemy)
    @Published public private(set) var lastDefenseFateResult: FateDrawResult?

    /// Current enemy intent for this turn (shown before player acts)
    @Published public private(set) var currentEnemyIntent: EnemyIntent?

    /// Whether mulligan has been done this combat
    @Published public private(set) var combatMulliganDone: Bool = false

    /// Whether player has attacked this turn
    @Published public private(set) var combatPlayerAttackedThisTurn: Bool = false

    /// Number of cards remaining in the fate draw pile
    public var fateDeckDrawCount: Int { fateDeck?.drawPile.count ?? 0 }

    /// Number of cards in the fate discard pile
    public var fateDeckDiscardCount: Int { fateDeck?.discardPile.count ?? 0 }

    /// Cards in the fate discard pile (for card-counting UI)
    public var fateDeckDiscardCards: [FateCard] { fateDeck?.discardPile ?? [] }

    // MARK: - Content Registry

    /// Content registry for loading content packs
    private let contentRegistry: ContentRegistry

    /// Balance configuration from content pack
    private var balanceConfig: BalanceConfiguration

    // MARK: - Configuration Constants (from BalanceConfiguration)

    private var tensionTickInterval: Int { balanceConfig.pressure.effectiveTickInterval }
    private var restHealAmount: Int { balanceConfig.resources.restHealAmount ?? 3 }
    private var anchorStrengthenCost: Int { balanceConfig.anchor.strengthenCost }
    private var anchorStrengthenAmount: Int { balanceConfig.anchor.strengthenAmount }

    // MARK: - Initialization

    /// Initialize engine with a content registry for loading game data
    public init(registry: ContentRegistry = .shared) {
        self.contentRegistry = registry
        self.balanceConfig = registry.getBalanceConfig() ?? .default
        self.timeEngine = TimeEngine(thresholdInterval: 3)
        self.pressureEngine = PressureEngine(rules: TwilightPressureRules())
        self.economyManager = EconomyManager()
        self.questTriggerEngine = QuestTriggerEngine(contentRegistry: registry)
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
        combatEnemy = nil
        combatEnemyHealth = 0
        combatEnemyWill = 0
        combatEnemyMaxWill = 0
        combatTurnNumber = 0
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
        self.playerName = playerName
        self.heroId = heroId

        // Get hero stats from HeroRegistry if available
        if let heroId = heroId,
           let heroDef = HeroRegistry.shared.hero(id: heroId) {
            let stats = heroDef.baseStats
            playerHealth = stats.health
            playerMaxHealth = stats.maxHealth
            playerFaith = stats.faith
            playerMaxFaith = stats.maxFaith
            playerBalance = stats.startingBalance
            playerStrength = stats.strength
            playerDexterity = stats.dexterity
            playerConstitution = stats.constitution
            playerIntelligence = stats.intelligence
            playerWisdom = stats.wisdom
            playerCharisma = stats.charisma
        } else {
            // Default values from balance config
            playerHealth = balanceConfig.resources.startingHealth
            playerMaxHealth = balanceConfig.resources.maxHealth
            playerFaith = balanceConfig.resources.startingFaith
            playerMaxFaith = balanceConfig.resources.maxFaith
            playerBalance = 50
            playerStrength = 5
            playerDexterity = 0
            playerConstitution = 0
            playerIntelligence = 0
            playerWisdom = 0
            playerCharisma = 0
        }

        // Clear curses
        playerActiveCurses = []

        // Setup starting deck
        if !startingDeck.isEmpty {
            _playerDeck = startingDeck
            WorldRNG.shared.shuffle(&_playerDeck)
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
                    integrity: anchorDef.initialIntegrity
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
            integrity: def.initialIntegrity
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

        case .chooseEventOption(let eventId, let choiceIndex):
            let changes = executeEventChoice(eventId: eventId, choiceIndex: choiceIndex)
            stateChanges.append(contentsOf: changes)
            currentEventId = nil

        case .resolveMiniGame(let input):
            let changes = executeMiniGameInput(input)
            stateChanges.append(contentsOf: changes)

        case .startCombat, .combatInitialize, .combatAttack, .combatSpiritAttack,
             .playCard, .combatApplyEffect, .endCombatTurn, .combatEnemyAttack,
             .combatEndTurnPhase, .combatFlee, .combatFinish,
             // Active Defense actions
             .combatMulligan, .combatGenerateIntent, .combatPlayerAttackWithFate,
             .combatSkipAttack, .combatEnemyResolveWithFate:
            let result = handleCombatAction(action)
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
        if playerHealth <= 0 {
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
        if playerFaith < cost {
            return .insufficientResources(resource: "faith", required: cost, available: playerFaith)
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
            let roll = WorldRNG.shared.nextInt(in: 0...(totalWeight - 1))
            var cumulative = 0
            for (index, weight) in weights.enumerated() {
                cumulative += weight
                if roll < cumulative {
                    let region = Array(degradableRegions)[index]

                    // Check anchor resistance using probability
                    let anchorIntegrity = region.anchor?.integrity ?? 0
                    let resistProb = DegradationRules.current.resistanceProbability(anchorIntegrity: anchorIntegrity)
                    let resistRoll = Double(WorldRNG.shared.nextInt(in: 0...99)) / 100.0

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
        let newHealth = min(playerMaxHealth, playerHealth + healAmount)
        let delta = newHealth - playerHealth
        playerHealth = newHealth
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
        playerFaith -= cost
        changes.append(.faithChanged(delta: -cost, newValue: playerFaith))

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
                let newHealth = min(playerMaxHealth, playerHealth + amount)
                playerHealth = newHealth
                changes.append(.healthChanged(delta: amount, newValue: newHealth))
            case "faith":
                let newFaith = playerFaith + amount
                playerFaith = newFaith
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
            let newHealth = max(0, min(playerMaxHealth, playerHealth + healthDelta))
            playerHealth = newHealth
            changes.append(.healthChanged(delta: healthDelta, newValue: newHealth))
        }

        // Faith
        if let faithDelta = consequences.faithChange, faithDelta != 0 {
            let newFaith = max(0, playerFaith + faithDelta)
            playerFaith = newFaith
            changes.append(.faithChanged(delta: faithDelta, newValue: newFaith))
        }

        // Balance
        if let balanceDelta = consequences.balanceChange, balanceDelta != 0 {
            let newBalance = max(0, min(100, playerBalance + balanceDelta))
            playerBalance = newBalance
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
            let selectedDef = filteredDefinitions[WorldRNG.shared.nextInt(in: 0...(filteredDefinitions.count - 1))]
            let gameEvent = selectedDef.toGameEvent(forRegion: regionDefId)
            currentEvent = gameEvent
            return gameEvent.id
        }

        let roll = WorldRNG.shared.nextInt(in: 0...(totalWeight - 1))
        var cumulative = 0
        for eventDef in filteredDefinitions {
            cumulative += eventDef.weight
            if roll < cumulative {
                let gameEvent = eventDef.toGameEvent(forRegion: regionDefId)
                currentEvent = gameEvent
                return gameEvent.id
            }
        }

        // Fallback to first event
        let selectedDef = filteredDefinitions[0]
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
            "health": playerHealth,
            "faith": playerFaith,
            "balance": playerBalance,
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
        if playerHealth <= 0 {
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
    }

    // MARK: - Day Events

    /// Trigger day event (tension increase, degradation, etc.)
    private func triggerDayEvent(_ event: DayEvent) {
        lastDayEvent = event
    }

    // MARK: - Combat Action Handler

    /// Handle all combat-related actions, extracted from performAction to reduce switch size
    private func handleCombatAction(_ action: TwilightGameAction) -> (changes: [StateChange], combatStarted: Bool) {
        var stateChanges: [StateChange] = []
        var didStartCombat = false

        switch action {
        case .startCombat:
            didStartCombat = true
            isInCombat = true
            combatTurnNumber = 1
            combatActionsRemaining = 3
            combatBonusDice = 0
            combatBonusDamage = 0
            combatIsFirstAttack = true
            // Reset Active Defense state
            combatMulliganDone = false
            combatPlayerAttackedThisTurn = false
            currentEnemyIntent = nil
            lastAttackFateResult = nil
            lastDefenseFateResult = nil

        // MARK: Active Defense Actions

        case .combatMulligan(let cardIds):
            // Mulligan: return selected cards to deck, draw replacements
            guard !combatMulliganDone else { break }

            var cardsToReturn: [Card] = []
            for cardId in cardIds {
                if let index = playerHand.firstIndex(where: { $0.id == cardId }) {
                    cardsToReturn.append(playerHand.remove(at: index))
                }
            }

            if !cardsToReturn.isEmpty {
                _playerDeck.append(contentsOf: cardsToReturn)
                WorldRNG.shared.shuffle(&_playerDeck)

                // Draw replacement cards
                let drawCount = min(cardsToReturn.count, _playerDeck.count)
                let newCards = Array(_playerDeck.prefix(drawCount))
                _playerDeck.removeFirst(drawCount)
                playerHand.append(contentsOf: newCards)
            }

            combatMulliganDone = true

        case .combatGenerateIntent:
            // Generate enemy intent for this turn
            guard let enemy = combatEnemy else { break }

            let enemyPower = enemy.power ?? 3
            currentEnemyIntent = EnemyIntentGenerator.generateIntent(
                enemyPower: enemyPower,
                enemyHealth: combatEnemyHealth,
                enemyMaxHealth: enemy.health ?? 10,
                turnNumber: combatTurnNumber
            )

        case .combatPlayerAttackWithFate(let bonusDamage):
            // Player attack with automatic Fate card draw
            guard let enemy = combatEnemy else { break }

            combatPlayerAttackedThisTurn = true

            // Draw fate card for attack
            if let fateResult = fateDeck?.drawAndResolve(worldResonance: resonanceValue) {
                lastAttackFateResult = fateResult

                // Calculate damage: PlayerStrength + WeaponBonus + FateCard + bonusDamage
                let baseDamage = playerStrength + combatBonusDamage + bonusDamage
                let fateBonus = fateResult.effectiveValue
                let totalAttack = baseDamage + fateBonus

                // Check if hit (attack >= enemy defense)
                let enemyDefense = enemy.defense ?? 10
                if totalAttack >= enemyDefense {
                    let damage = max(1, totalAttack - enemyDefense + 1)
                    combatEnemyHealth = max(0, combatEnemyHealth - damage)
                    stateChanges.append(.enemyDamaged(
                        enemyId: enemy.id,
                        damage: damage,
                        newHealth: combatEnemyHealth
                    ))

                    if combatEnemyHealth <= 0 {
                        stateChanges.append(.enemyDefeated(enemyId: enemy.id))
                    }
                }

                // Apply fate draw effects (resonance/tension shifts)
                let fateChanges = applyFateDrawEffects(fateResult.drawEffects)
                stateChanges.append(contentsOf: fateChanges)
            }

            combatBonusDice = 0
            combatBonusDamage = 0

        case .combatSkipAttack:
            // Player skips attack, proceeds to enemy resolution
            combatPlayerAttackedThisTurn = false
            lastAttackFateResult = nil

        case .combatEnemyResolveWithFate:
            // Enemy resolves their intent, player defends with Fate card
            guard let intent = currentEnemyIntent else { break }

            switch intent.type {
            case .attack:
                // Draw fate card for defense
                if let fateResult = fateDeck?.drawAndResolve(worldResonance: resonanceValue) {
                    lastDefenseFateResult = fateResult

                    // Calculate damage: EnemyAttack - (PlayerArmor + FateCard)
                    // High fate card = less damage to player
                    let fateBonus = fateResult.effectiveValue
                    let playerArmor = 0  // TODO: Get from equipment
                    let damageReduction = playerArmor + fateBonus
                    let actualDamage = max(0, intent.value - damageReduction)

                    if actualDamage > 0 {
                        playerHealth = max(0, playerHealth - actualDamage)
                        stateChanges.append(.healthChanged(
                            delta: -actualDamage,
                            newValue: playerHealth
                        ))
                    }

                    // Apply fate draw effects
                    let fateChanges = applyFateDrawEffects(fateResult.drawEffects)
                    stateChanges.append(contentsOf: fateChanges)
                } else {
                    // No fate deck available, take full damage
                    playerHealth = max(0, playerHealth - intent.value)
                    stateChanges.append(.healthChanged(
                        delta: -intent.value,
                        newValue: playerHealth
                    ))
                }

            case .ritual:
                // Ritual shifts resonance toward Nav
                let shift = Float(intent.secondaryValue ?? -5)
                resonanceValue = max(-100, min(100, resonanceValue + shift))
                stateChanges.append(.resonanceChanged(delta: shift, newValue: resonanceValue))

            case .block:
                // Enemy is blocking - will take less damage next turn
                // For now, just note it (could add a state variable for enemy block)
                break

            case .buff:
                // Enemy buffs themselves
                // For now, no effect (could increase enemy power/defense)
                break

            case .heal:
                // Enemy heals
                if let enemy = combatEnemy {
                    let maxHealth = enemy.health ?? 10
                    combatEnemyHealth = min(maxHealth, combatEnemyHealth + intent.value)
                    // No state change needed for enemy heal
                }

            case .summon:
                // Not implemented yet
                break
            }

            // Reset for next turn
            combatPlayerAttackedThisTurn = false
            currentEnemyIntent = nil

        case .combatInitialize:
            _playerDeck.append(contentsOf: playerHand)
            _playerDeck.append(contentsOf: _playerDiscard)
            playerHand.removeAll()
            _playerDiscard.removeAll()
            WorldRNG.shared.shuffle(&_playerDeck)
            let drawCount = min(5, _playerDeck.count)
            playerHand = Array(_playerDeck.prefix(drawCount))
            _playerDeck.removeFirst(drawCount)
            combatActionsRemaining = 3

        case .combatAttack(let effortCards, let bonusDamage):
            guard combatActionsRemaining > 0 else { break }
            combatActionsRemaining -= 1
            let changes = executeCombatAttack(effortCards: effortCards, bonusDamage: bonusDamage + combatBonusDamage)
            stateChanges.append(contentsOf: changes)
            combatBonusDice = 0
            combatBonusDamage = 0

        case .combatSpiritAttack:
            guard combatActionsRemaining > 0 else { break }
            guard combatEnemyMaxWill > 0 else { break }
            combatActionsRemaining -= 1

            let context = CombatPlayerContext.from(engine: self)
            let spiritResult = CombatCalculator.calculateSpiritAttack(
                context: context,
                enemyCurrentWill: combatEnemyWill,
                fateDeck: fateDeck,
                worldResonance: resonanceValue
            )

            let actualDamage = min(spiritResult.damage, combatEnemyWill)
            combatEnemyWill = max(0, combatEnemyWill - actualDamage)
            stateChanges.append(.enemyWillDamaged(
                enemyId: combatEnemy?.id ?? "unknown",
                damage: actualDamage,
                newWill: combatEnemyWill
            ))

            let fateChanges = applyFateDrawEffects(spiritResult.fateDrawEffects)
            stateChanges.append(contentsOf: fateChanges)

            if combatEnemyWill <= 0 {
                stateChanges.append(.enemyPacified(enemyId: combatEnemy?.id ?? "unknown"))
            }

        case .playCard(let cardId, _):
            guard combatActionsRemaining > 0 else { break }
            if let cardIndex = playerHand.firstIndex(where: { $0.id == cardId }) {
                let card = playerHand[cardIndex]
                if let cost = card.cost, cost > 0 {
                    guard playerFaith >= cost else { break }
                    playerFaith -= cost
                    stateChanges.append(.faithChanged(delta: -cost, newValue: playerFaith))
                }
                combatActionsRemaining -= 1
                playerHand.remove(at: cardIndex)
                _playerDiscard.append(card)
            }

        case .combatApplyEffect(let effect):
            let changes = executeCombatEffect(effect)
            stateChanges.append(contentsOf: changes)

        case .endCombatTurn:
            break

        case .combatEnemyAttack(let damage):
            let actualDamage = min(damage, playerHealth)
            playerHealth = max(0, playerHealth - damage)
            stateChanges.append(.healthChanged(delta: -actualDamage, newValue: playerHealth))

        case .combatEndTurnPhase:
            _playerDiscard.append(contentsOf: playerHand)
            playerHand.removeAll()

            if _playerDeck.isEmpty && !_playerDiscard.isEmpty {
                _playerDeck = _playerDiscard
                _playerDiscard.removeAll()
                WorldRNG.shared.shuffle(&_playerDeck)
            }

            let drawCount = min(5, _playerDeck.count)
            playerHand = Array(_playerDeck.prefix(drawCount))
            _playerDeck.removeFirst(drawCount)

            playerFaith = min(playerFaith + 1, playerMaxFaith)
            stateChanges.append(.faithChanged(delta: 1, newValue: playerFaith))

            combatTurnNumber += 1
            combatActionsRemaining = 3
            combatBonusDice = 0
            combatBonusDamage = 0

            // Reset Active Defense state for new turn
            combatPlayerAttackedThisTurn = false
            lastAttackFateResult = nil
            lastDefenseFateResult = nil
            currentEnemyIntent = nil

        case .combatFlee:
            isInCombat = false
            combatEnemy = nil
            // Reset Active Defense state
            combatMulliganDone = false
            combatPlayerAttackedThisTurn = false
            currentEnemyIntent = nil
            lastAttackFateResult = nil
            lastDefenseFateResult = nil
            stateChanges.append(.combatEnded(victory: false))

        case .combatFinish(let victory):
            isInCombat = false
            combatEnemy = nil
            // Reset Active Defense state
            combatMulliganDone = false
            combatPlayerAttackedThisTurn = false
            currentEnemyIntent = nil
            lastAttackFateResult = nil
            lastDefenseFateResult = nil
            stateChanges.append(.combatEnded(victory: victory))
            if victory {
                stateChanges.append(.enemyDefeated(enemyId: combatEnemy?.id ?? "unknown"))
            }

        default:
            break
        }

        return (stateChanges, didStartCombat)
    }

    // MARK: - Fate Draw Effects

    /// Apply side effects from a fate card draw (resonance shift, tension shift)
    private func applyFateDrawEffects(_ effects: [FateDrawEffect]) -> [StateChange] {
        var changes: [StateChange] = []
        for effect in effects {
            switch effect.type {
            case .shiftResonance:
                let delta = Float(effect.value)
                resonanceValue = max(-100, min(100, resonanceValue + delta))
                changes.append(.resonanceChanged(delta: delta, newValue: resonanceValue))
            case .shiftTension:
                let oldTension = worldTension
                worldTension = max(0, min(100, worldTension + effect.value))
                let actualDelta = worldTension - oldTension
                if actualDelta != 0 {
                    changes.append(.tensionChanged(delta: actualDelta, newValue: worldTension))
                }
            }
        }
        return changes
    }

    // MARK: - Combat Helper Methods

    /// Execute a combat attack via Fate Deck (Unified Resolution System)
    private func executeCombatAttack(effortCards: Int, bonusDamage: Int) -> [StateChange] {
        var changes: [StateChange] = []

        guard let enemy = combatEnemy else {
            return changes
        }

        // Discard effort cards from hand
        let actualEffort = min(effortCards, playerHand.count)
        if actualEffort > 0 {
            let discarded = playerHand.suffix(actualEffort)
            _playerDiscard.append(contentsOf: discarded)
            playerHand.removeLast(actualEffort)
        }

        let monsterDef = enemy.defense ?? 10
        let context = CombatPlayerContext.from(engine: self)

        let result = CombatCalculator.calculateAttackWithFate(
            context: context,
            fateDeck: fateDeck,
            worldResonance: resonanceValue,
            effortCards: actualEffort,
            monsterDefense: monsterDef,
            bonusDamage: bonusDamage
        )

        // Store result for UI display
        lastFateAttackResult = result

        if result.isHit && result.damage > 0 {
            combatEnemyHealth = max(0, combatEnemyHealth - result.damage)
            changes.append(.enemyDamaged(enemyId: enemy.id, damage: result.damage, newHealth: combatEnemyHealth))
        }

        // Apply fate draw side effects (resonance/tension shifts)
        let fateChanges = applyFateDrawEffects(result.fateDrawEffects)
        changes.append(contentsOf: fateChanges)

        return changes
    }

    /// Execute a combat effect from card or ability
    private func executeCombatEffect(_ effect: CombatActionEffect) -> [StateChange] {
        var changes: [StateChange] = []

        switch effect {
        case .heal(let amount):
            let newHealth = min(playerMaxHealth, playerHealth + amount)
            let delta = newHealth - playerHealth
            playerHealth = newHealth
            changes.append(.healthChanged(delta: delta, newValue: newHealth))

        case .damageEnemy(let amount):
            if let enemy = combatEnemy {
                let actualDamage = calculateDamageDealt(amount)
                combatEnemyHealth = max(0, combatEnemyHealth - actualDamage)
                changes.append(.enemyDamaged(enemyId: enemy.id, damage: actualDamage, newHealth: combatEnemyHealth))
            }

        case .drawCards(let count):
            drawCardsEngineFirst(count: count)

        case .gainFaith(let amount):
            playerFaith = min(playerFaith + amount, playerMaxFaith)
            changes.append(.faithChanged(delta: amount, newValue: playerFaith))

        case .spendFaith(let amount):
            playerFaith = max(0, playerFaith - amount)
            changes.append(.faithChanged(delta: -amount, newValue: playerFaith))

        case .takeDamage(let amount):
            let actualDamage = min(amount, playerHealth)
            playerHealth = max(0, playerHealth - amount)
            changes.append(.healthChanged(delta: -actualDamage, newValue: playerHealth))

        case .removeCurse(let type):
            let curseType: CurseType? = type.flatMap { CurseType(rawValue: $0) }
            removeCurse(type: curseType)

        case .shiftBalance(let towards, let amount):
            let direction: CardBalance
            switch towards.lowercased() {
            case "light", "свет": direction = .light
            case "dark", "тьма": direction = .dark
            default: direction = .neutral
            }

            let delta: Int
            switch direction {
            case .light: delta = amount
            case .dark: delta = -amount
            case .neutral: delta = 0
            }
            playerBalance = max(0, min(100, playerBalance + delta))
            changes.append(.balanceChanged(delta: amount, newValue: playerBalance))

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
    public func setupCombatEnemy(_ enemy: Card) {
        combatEnemy = enemy
        combatEnemyHealth = enemy.health ?? 10
        combatEnemyWill = enemy.will ?? 0
        combatEnemyMaxWill = enemy.will ?? 0
        combatTurnNumber = 1
        combatActionsRemaining = 3
        combatBonusDice = 0
        combatBonusDamage = 0
        combatIsFirstAttack = true
        isInCombat = true
    }

    /// End combat mode so a new battle can be started
    public func endCombat() {
        isInCombat = false
        combatEnemy = nil
    }

    /// Get current combat state for UI
    public var combatState: CombatState? {
        guard isInCombat, let enemy = combatEnemy else { return nil }
        return CombatState(
            enemy: enemy,
            enemyHealth: combatEnemyHealth,
            enemyWill: combatEnemyWill,
            enemyMaxWill: combatEnemyMaxWill,
            turnNumber: combatTurnNumber,
            actionsRemaining: combatActionsRemaining,
            bonusDice: combatBonusDice,
            bonusDamage: combatBonusDamage,
            isFirstAttack: combatIsFirstAttack,
            playerHand: playerHand
        )
    }

    // MARK: - Engine-First Card Management

    /// Draw cards in Engine-First mode with deck recycling
    private func drawCardsEngineFirst(count: Int) {
        var remaining = count
        while remaining > 0 {
            // Recycle discard into deck if needed
            if _playerDeck.isEmpty && !_playerDiscard.isEmpty {
                _playerDeck = _playerDiscard
                _playerDiscard.removeAll()
                WorldRNG.shared.shuffle(&_playerDeck)
            }

            // If still empty, stop
            if _playerDeck.isEmpty { break }

            // Draw one card
            playerHand.append(_playerDeck.removeFirst())
            remaining -= 1
        }
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

    /// Create directly (Engine-First) - id is the definition ID
    public init(id: String, name: String, integrity: Int) {
        self.id = id
        self.name = name
        self.integrity = max(0, min(100, integrity))
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

        for (packId, pack) in ContentRegistry.shared.loadedPacks {
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
            gameDuration: 0,  // TODO: Track game duration

            // Pack compatibility
            coreVersion: EngineSave.currentCoreVersion,
            activePackSet: activePackSet,
            formatVersion: EngineSave.currentFormatVersion,
            primaryCampaignPackId: primaryCampaignPackId,

            // Player state
            playerName: playerName,
            heroId: heroId,
            playerHealth: playerHealth,
            playerMaxHealth: playerMaxHealth,
            playerFaith: playerFaith,
            playerMaxFaith: playerMaxFaith,
            playerBalance: playerBalance,

            // Deck state (card IDs for stable serialization)
            deckCardIds: _playerDeck.map { $0.id },
            handCardIds: playerHand.map { $0.id },
            discardCardIds: _playerDiscard.map { $0.id },

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

            // RNG state (Audit A2 - save for deterministic replay)
            rngSeed: WorldRNG.shared.currentSeed(),
            rngState: WorldRNG.shared.currentState()
        )
    }

    /// Restore engine state from a save (Engine-First Architecture)
    /// This replaces GameState-based loads
    func restoreFromEngineSave(_ save: EngineSave) {
        // Validate compatibility
        let compatibility = save.validateCompatibility(with: ContentRegistry.shared)

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
        playerName = save.playerName
        heroId = save.heroId
        playerHealth = save.playerHealth
        playerMaxHealth = save.playerMaxHealth
        playerFaith = save.playerFaith
        playerMaxFaith = save.playerMaxFaith
        playerBalance = save.playerBalance

        // Restore hero stats from heroId (stats that don't change during gameplay)
        if let heroId = save.heroId,
           let heroDef = HeroRegistry.shared.hero(id: heroId) {
            let stats = heroDef.baseStats
            playerStrength = stats.strength
            playerDexterity = stats.dexterity
            playerConstitution = stats.constitution
            playerIntelligence = stats.intelligence
            playerWisdom = stats.wisdom
            playerCharisma = stats.charisma
        }

        // Restore deck (convert card IDs back to cards)
        _playerDeck = save.deckCardIds.compactMap { CardFactory.shared.getCard(id: $0) }
        playerHand = save.handCardIds.compactMap { CardFactory.shared.getCard(id: $0) }
        _playerDiscard = save.discardCardIds.compactMap { CardFactory.shared.getCard(id: $0) }

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

        // Restore RNG state (Audit 1.5 - determinism after load)
        WorldRNG.shared.restoreState(save.rngState)

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

        playerName = "Герой"
        playerHealth = 20
        playerMaxHealth = 20
        playerFaith = 10
        playerMaxFaith = 15
        playerBalance = 50
        playerStrength = 5

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

    /// Set player health directly
    func setPlayerHealth(_ health: Int) {
        playerHealth = min(playerMaxHealth, max(0, health))
    }

    /// Set player max health directly (for testing)
    func setPlayerMaxHealth(_ maxHealth: Int) {
        playerMaxHealth = max(1, maxHealth)
        playerHealth = min(playerHealth, playerMaxHealth)
    }

    /// Set player faith directly (for testing)
    func setPlayerFaith(_ faith: Int) {
        playerFaith = min(playerMaxFaith, max(0, faith))
    }

    /// Set player balance directly (for testing)
    func setPlayerBalance(_ balance: Int) {
        playerBalance = min(100, max(0, balance))
    }

    /// Set player name directly (for testing)
    func setPlayerName(_ name: String) {
        playerName = name
    }

    /// Set hero ID directly (for testing)
    func setHeroId(_ id: String) {
        heroId = id
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
}

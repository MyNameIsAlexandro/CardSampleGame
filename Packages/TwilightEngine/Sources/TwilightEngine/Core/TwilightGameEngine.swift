/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/TwilightGameEngine.swift
/// Назначение: Содержит реализацию файла TwilightGameEngine.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

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
    public internal(set) var currentDay: Int = 0
    /// World tension level (0-100), drives degradation and difficulty
    public internal(set) var worldTension: Int = 30
    /// ID of the region the player is currently in
    public internal(set) var currentRegionId: String?
    /// Whether the game has ended (victory or defeat)
    public internal(set) var isGameOver: Bool = false
    /// Result of the game if it has ended
    public internal(set) var gameResult: GameEndResult?

    /// ID of the event currently being presented to the player
    public internal(set) var currentEventId: String?
    /// Whether the player is currently in combat
    public internal(set) var isInCombat: Bool = false

    /// Result of the last performed action
    public private(set) var lastActionResult: ActionResult?

    // MARK: - State for UI (Engine-First Architecture)

    /// All regions with their current state - UI reads this directly
    public internal(set) var publishedRegions: [String: EngineRegionState] = [:]

    /// World resonance value (-100..+100), drives Navi/Prav world state
    public internal(set) var resonanceValue: Float = 0.0

    /// World flags - for quest/event conditions
    public internal(set) var publishedWorldFlags: [String: Bool] = [:]

    /// Current event being displayed to player
    public internal(set) var currentEvent: GameEvent?

    /// Day event notification (tension increase, degradation, etc.)
    public internal(set) var lastDayEvent: DayEvent?

    /// Active quests
    public internal(set) var publishedActiveQuests: [Quest] = []

    /// Event log (last 100 entries)
    public internal(set) var publishedEventLog: [EventLogEntry] = []

    /// Light/Dark balance of the world
    public internal(set) var lightDarkBalance: Int = 50

    /// Main quest stage (1-5)
    public internal(set) var mainQuestStage: Int = 1

    /// Tracks when the current session started, for computing total game duration
    internal var gameStartDate: Date = Date()

    /// Accumulated game duration from previous sessions (seconds)
    internal var previousSessionsDuration: TimeInterval = 0

    /// Total accumulated game duration at a given timestamp.
    func totalGameDuration(at referenceDate: Date = Date()) -> TimeInterval {
        previousSessionsDuration + referenceDate.timeIntervalSince(gameStartDate)
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

    internal var regions: [String: EngineRegionState] = [:]
    internal var completedEventIds: Set<String> = []  // Definition IDs (Epic 3: Stable IDs)
    #if DEBUG
    /// Test-only flag: blocks scripted event generation to isolate random encounters.
    internal var _blockScriptedEvents = false
    #endif
    internal var worldFlags: [String: Bool] = [:]
    internal var questStages: [String: Int] = [:]

    /// All events in the game (from ContentProvider)
    internal var allEvents: [GameEvent] = []

    /// Active quests
    internal var activeQuests: [Quest] = []

    /// Completed quest IDs
    internal var completedQuestIds: Set<String> = []

    /// Event log
    internal var eventLog: [EventLogEntry] = []

    // MARK: - Fate Deck

    /// Fate Deck manager for skill checks and event resolution
    public internal(set) var fateDeck: FateDeckManager?
    /// Mid-combat encounter state for save/resume (SAV-03)
    public private(set) var pendingEncounterState: EncounterSaveState?
    /// Deterministic seed reserved for external combat snapshot/bridge path.
    public private(set) var pendingExternalCombatSeed: UInt64?
    /// Active external combat enemy tracking for quest/event follow-ups.
    internal var activeCombatEnemyId: String?

    /// Persisted market state (SAV-05).
    internal var marketState: MarketSaveState = MarketSaveState()
    /// Published market cards for UI.
    public internal(set) var publishedMarketCards: [Card] = []

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
    internal var contentRegistry: ContentRegistry { services.contentRegistry }

    /// Balance configuration from content pack
    internal var balanceConfig: BalanceConfiguration

    // MARK: - Configuration Constants (from BalanceConfiguration)

    internal var tensionTickInterval: Int { balanceConfig.pressure.effectiveTickInterval }
    internal var restHealAmount: Int { balanceConfig.resources.restHealAmount ?? 3 }
    internal var anchorStrengthenCost: Int { balanceConfig.anchor.strengthenCost }
    internal var anchorStrengthenAmount: Int { balanceConfig.anchor.strengthenAmount }
    internal var anchorDefileCostHP: Int { balanceConfig.anchor.defileCostHP ?? 5 }
    internal var anchorDarkStrengthenCostHP: Int { balanceConfig.anchor.darkStrengthenCostHP ?? 3 }

    /// Player's current alignment derived from balance
    internal var playerAlignment: BalanceAlignment {
        if player.balance < 30 { return .nav }
        if player.balance > 70 { return .prav }
        return .neutral
    }

    // MARK: - Initialization

    /// Initialize engine with injected services.
    public init(services: EngineServices = EngineServices.makeDefault()) {
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
        self.init(services: EngineServices(
            rng: WorldRNG(),
            contentRegistry: registry,
            localizationManager: LocalizationManager()
        ))
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
        pendingEncounterState = nil
        pendingExternalCombatSeed = nil
        activeCombatEnemyId = nil
        marketState = MarketSaveState()
        publishedMarketCards = []
        combat.resetState()
        onStateChanged?()
    }

    /// Initialize the Fate Deck with a set of cards
    public func setupFateDeck(cards: [FateCard]) {
        fateDeck = FateDeckManager(cards: cards, rng: services.rng)
    }

    // MARK: - Engine-First Initialization

    /// Initialize a new game without legacy WorldState
    /// This is the Engine-First way to start a game
    /// - Parameters:
    ///   - playerName: Character name for display
    ///   - heroId: Hero definition ID from HeroRegistry (data-driven hero system)
    ///   - startingDeck: Starting deck of cards (from CardRegistry.startingDeck)
    public func initializeNewGame(playerName: String = L10n.playerDefaultName.localized, heroId: String? = nil, startingDeck: [Card] = []) {
        // Reset state
        isGameOver = false
        gameResult = nil
        currentEventId = nil
        currentEvent = nil
        lastDayEvent = nil
        isInCombat = false
        pendingEncounterState = nil
        pendingExternalCombatSeed = nil
        activeCombatEnemyId = nil
        marketState = MarketSaveState()
        publishedMarketCards = []

        // Load balance config from content registry
        balanceConfig = contentRegistry.getBalanceConfig() ?? .default

        // Setup player from balance config and hero definition
        player.initializeFromHero(heroId, name: playerName, balanceConfig: balanceConfig)

        // Setup starting deck
        if !startingDeck.isEmpty {
            deck.setupStartingDeck(startingDeck)
        } else if let heroId {
            let deckDefs = contentRegistry.getStartingDeck(forHero: heroId)
            if !deckDefs.isEmpty {
                let cards = deckDefs.map { $0.toCard(localizationManager: services.localizationManager) }
                deck.setupStartingDeck(cards)
            }
        }

        // Setup world from balance config
        let bootstrapState = EngineWorldBootstrapState.from(balanceConfig: balanceConfig)
        currentDay = bootstrapState.day
        worldTension = bootstrapState.tension
        lightDarkBalance = bootstrapState.lightDarkBalance
        mainQuestStage = bootstrapState.mainQuestStage
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
            let changes = executeTrade()
            stateChanges.append(contentsOf: changes)

        case .marketBuy(let cardId):
            let changes = executeMarketBuy(cardId: cardId)
            stateChanges.append(contentsOf: changes)

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

        case .drawFateCard:
            let changes = executeDrawFateCard()
            stateChanges.append(contentsOf: changes)

        case .combatFinish(let outcome, let transaction, let updatedFateDeck):
            let changes = executeCombatFinish(
                outcome: outcome,
                transaction: transaction,
                updatedFateDeck: updatedFateDeck
            )
            stateChanges.append(contentsOf: changes)

        case .combatStoreEncounterState(let state):
            pendingEncounterState = state
            pendingExternalCombatSeed = state?.rngState
            activeCombatEnemyId = state?.context.enemies.first?.id

        case .startCombat, .combatInitialize,
             // Active Defense actions
             .combatMulligan, .combatGenerateIntent, .combatPlayerAttackWithFate,
             .combatSkipAttack, .combatEnemyResolveWithFate:
            if case .startCombat = action {
                if pendingExternalCombatSeed == nil {
                    pendingExternalCombatSeed = services.rng.nextSeed()
                }
                if fateDeck == nil {
                    let cards = services.contentRegistry.getAllFateCards()
                    if !cards.isEmpty {
                        setupFateDeck(cards: cards)
                    }
                }
                if let monster = currentEvent?.monsterCard {
                    let combatContext = CombatContext(
                        regionState: currentRegion?.state ?? .stable,
                        playerCurses: player.activeCurses.map(\.type)
                    )
                    var adjustedMonster = monster
                    if let value = monster.health {
                        adjustedMonster.health = combatContext.adjustedEnemyHealth(value)
                    }
                    if let value = monster.power {
                        adjustedMonster.power = combatContext.adjustedEnemyPower(value)
                    }
                    if let value = monster.defense {
                        adjustedMonster.defense = combatContext.adjustedEnemyDefense(value)
                    }
                    combat.setupCombatEnemy(adjustedMonster)
                }
                if activeCombatEnemyId == nil {
                    activeCombatEnemyId = currentEvent?.monsterCard?.id ?? combat.combatEnemy?.id
                }
            }
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

        // Keep external-combat lock clean after canonical commit.
        if case .combatFinish = action {
            currentEventId = nil
            currentEvent = nil
            activeCombatEnemyId = nil
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

    // MARK: - Action Pipeline Helpers
    // Validation/time/execution/event-generation helpers are split into:
    // `TwilightGameEngine+ActionPipeline.swift`

    /// Mutate current event pointer through a centralized core helper.
    func assignCurrentEventId(_ eventId: String?) {
        currentEventId = eventId
    }

    /// Clear both event id and event payload through one mutation point.
    func clearCurrentEventSelection() {
        currentEventId = nil
        currentEvent = nil
    }

    /// Clear external-combat persistence fields after canonical commit.
    func clearPendingExternalCombatPersistence() {
        pendingEncounterState = nil
        pendingExternalCombatSeed = nil
        activeCombatEnemyId = nil
    }

    /// Assign pending external-combat snapshot through a core-owned mutation point.
    func assignPendingEncounterState(_ state: EncounterSaveState?) {
        pendingEncounterState = state
        pendingExternalCombatSeed = state?.rngState
        activeCombatEnemyId = state?.context.enemies.first?.id
    }

}

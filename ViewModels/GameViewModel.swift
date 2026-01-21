import Foundation
import Combine
import SwiftUI

// MARK: - Game View Model
// Central ViewModel that bridges UI with TwilightGameEngine
// All UI actions should go through this ViewModel

/// Main ViewModel for game UI
/// Replaces direct WorldState/Player mutations with Engine-based actions
@MainActor
final class GameViewModel: ObservableObject {
    // MARK: - Published State (for UI binding)

    /// Game engine (source of truth)
    @Published private(set) var engine: TwilightGameEngine

    /// Legacy models (for backward compatibility during migration)
    @Published var gameState: GameState
    @Published var player: Player
    @Published var worldState: WorldState

    // MARK: - UI State

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false

    @Published var currentEvent: GameEvent?
    @Published var showEventSheet: Bool = false

    @Published var showCombatView: Bool = false

    // MARK: - Last Action Result

    @Published private(set) var lastResult: ActionResult?

    // MARK: - Cancellables

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(gameState: GameState) {
        self.gameState = gameState
        self.player = gameState.players.first ?? Player(name: "Default")
        self.worldState = gameState.worldState
        self.engine = TwilightGameEngine()

        // Connect engine to legacy models
        engine.connectToLegacy(worldState: worldState, player: player)

        setupBindings()
    }

    /// Convenience initializer for new game
    convenience init(playerName: String = L10n.defaultPlayerName.localized) {
        let player = Player(name: playerName)
        let gameState = GameState(players: [player])
        self.init(gameState: gameState)
    }

    // MARK: - Setup

    private func setupBindings() {
        // Sync engine state to legacy models
        engine.$currentDay
            .sink { [weak self] day in
                self?.worldState.daysPassed = day
            }
            .store(in: &cancellables)

        engine.$worldTension
            .sink { [weak self] tension in
                self?.worldState.worldTension = tension
            }
            .store(in: &cancellables)

        engine.$currentRegionId
            .sink { [weak self] regionId in
                self?.worldState.currentRegionId = regionId
            }
            .store(in: &cancellables)

        // Note: gameState.isGameOver is computed from isVictory || isDefeat
        // Engine game result already handles setting these via $gameResult subscriber below

        engine.$gameResult
            .compactMap { $0 }
            .sink { [weak self] result in
                switch result {
                case .victory:
                    self?.gameState.isVictory = true
                case .defeat:
                    self?.gameState.isDefeat = true
                case .abandoned:
                    break
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Game Actions (Through Engine)

    /// Travel to a region
    func travel(to regionId: UUID) {
        let result = engine.performAction(.travel(toRegionId: regionId))
        handleResult(result)

        // Log travel in legacy
        if result.success {
            let fromRegion = worldState.getCurrentRegion()?.name ?? L10n.regionUnknown.localized
            let toRegion = worldState.getRegion(byId: regionId)?.name ?? L10n.regionUnknown.localized
            let cost = worldState.calculateTravelCost(to: regionId)
            worldState.logTravel(from: fromRegion, to: toRegion, days: cost)
        }
    }

    /// Rest in current region
    func rest() {
        let result = engine.performAction(.rest)
        handleResult(result)

        // Log in legacy
        if result.success, let region = worldState.getCurrentRegion() {
            worldState.logEvent(
                regionName: region.name,
                eventTitle: L10n.journalRestTitle.localized,
                choiceMade: L10n.journalRestChoice.localized,
                outcome: L10n.journalRestOutcome.localized,
                type: .exploration
            )
        }
    }

    /// Explore current region
    func explore() {
        let result = engine.performAction(.explore)
        handleResult(result)

        // Show event if triggered
        if let eventId = result.currentEvent {
            showEventForId(eventId)
        }
    }

    /// Trade at market
    func trade() {
        let result = engine.performAction(.trade)
        handleResult(result)
        // Market UI handled separately
    }

    /// Strengthen anchor in current region
    func strengthenAnchor() {
        let result = engine.performAction(.strengthenAnchor)
        handleResult(result)

        // Log in legacy
        if result.success, let region = worldState.getCurrentRegion() {
            worldState.logEvent(
                regionName: region.name,
                eventTitle: L10n.journalAnchorTitle.localized,
                choiceMade: L10n.journalAnchorChoice.localized,
                outcome: L10n.journalAnchorOutcome.localized,
                type: .worldChange
            )
        }
    }

    /// Choose an option in current event
    func chooseEventOption(_ choiceIndex: Int) {
        guard let event = currentEvent else { return }

        let result = engine.performAction(.chooseEventOption(eventId: event.id, choiceIndex: choiceIndex))
        handleResult(result)

        // Apply consequences to legacy
        if result.success {
            let choice = event.choices[choiceIndex]
            worldState.applyConsequences(choice.consequences, to: player, in: worldState.currentRegionId ?? UUID())

            // Log event
            if let region = worldState.getCurrentRegion() {
                worldState.logEvent(
                    regionName: region.name,
                    eventTitle: event.title,
                    choiceMade: choice.text,
                    outcome: choice.consequences.message ?? L10n.journalChoiceMade.localized,
                    type: .exploration
                )
            }

            // Mark oneTime event as completed
            if event.oneTime {
                worldState.markEventCompleted(event.id)
            }
        }

        // Close event sheet
        currentEvent = nil
        showEventSheet = false

        // Check for triggered combat
        if result.combatStarted {
            showCombatView = true
        }
    }

    /// Skip turn (just advance time)
    func skipTurn() {
        let result = engine.performAction(.skipTurn)
        handleResult(result)
    }

    // MARK: - Legacy Action Bridge

    /// Perform legacy action through Engine
    /// Used during migration to gradually replace direct mutations
    func performLegacyAction(_ action: RegionAction, for region: Region) {
        switch action {
        case .travel:
            travel(to: region.id)

        case .rest:
            rest()

        case .trade:
            trade()

        case .strengthenAnchor:
            strengthenAnchor()

        case .explore:
            explore()
        }
    }

    // MARK: - Event Handling

    private func showEventForId(_ eventId: UUID) {
        // Find event in worldState
        guard let region = worldState.getCurrentRegion() else { return }

        let events = worldState.getAvailableEvents(for: region)
        if let event = events.first(where: { $0.id == eventId }) {
            currentEvent = event
            showEventSheet = true
        }
    }

    /// Trigger exploration and show event
    func triggerExploration() {
        guard let region = worldState.getCurrentRegion() else { return }

        // Get available events
        let events = worldState.getAvailableEvents(for: region)

        // Weighted selection from available events
        if let event = selectWeightedEvent(from: events) {
            currentEvent = event
            showEventSheet = true
        }
    }

    /// Select event using weighted random selection
    private func selectWeightedEvent(from events: [GameEvent]) -> GameEvent? {
        guard !events.isEmpty else { return nil }

        let totalWeight = events.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return events.first }

        let roll = WorldRNG.shared.nextInt(in: 0..<totalWeight)
        var cumulative = 0

        for event in events {
            cumulative += event.weight
            if roll < cumulative {
                return event
            }
        }

        return events.first
    }

    // MARK: - Result Handling

    private func handleResult(_ result: ActionResult) {
        lastResult = result

        if !result.success, let error = result.error {
            errorMessage = error.localizedDescription
            showError = true
        }

        // Sync legacy models after engine action
        objectWillChange.send()
    }

    // MARK: - Validation Helpers

    /// Check if action is available
    func canPerformAction(_ action: TwilightGameAction) -> Bool {
        // Quick validation without executing
        switch action {
        case .travel(let toRegionId):
            guard let currentId = worldState.currentRegionId,
                  let currentRegion = worldState.getRegion(byId: currentId) else {
                return false
            }
            return currentRegion.neighborIds.contains(toRegionId)

        case .rest:
            guard let region = worldState.getCurrentRegion() else { return false }
            return region.canRest

        case .trade:
            guard let region = worldState.getCurrentRegion() else { return false }
            return region.canTrade

        case .strengthenAnchor:
            guard let region = worldState.getCurrentRegion(),
                  region.anchor != nil else { return false }
            return player.faith >= 10

        case .explore:
            return !engine.isInCombat

        default:
            return true
        }
    }

    // MARK: - State Queries

    var currentRegion: Region? {
        worldState.getCurrentRegion()
    }

    var currentDay: Int {
        engine.currentDay
    }

    var tension: Int {
        engine.worldTension
    }

    var isGameOver: Bool {
        engine.isGameOver
    }
}

// MARK: - Region Action

/// Actions available in a region (for ViewModel bridge)
/// Mirrors WorldMapView.RegionAction for migration compatibility
enum RegionAction {
    case travel
    case rest
    case trade
    case strengthenAnchor
    case explore

    /// Convert to TwilightGameAction
    func toEngineAction(for region: Region) -> TwilightGameAction {
        switch self {
        case .travel:
            return .travel(toRegionId: region.id)
        case .rest:
            return .rest
        case .trade:
            return .trade
        case .strengthenAnchor:
            return .strengthenAnchor
        case .explore:
            return .explore
        }
    }
}

/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/TwilightGameActionResult.swift
/// Назначение: Содержит реализацию файла TwilightGameActionResult.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Action Result

/// Result of performing a game action
public struct ActionResult: Equatable {
    /// Whether the action succeeded
    public let success: Bool

    /// Error if action failed
    public let error: ActionError?

    /// State changes that occurred
    public let stateChanges: [StateChange]

    /// Events triggered by this action
    public let triggeredEvents: [String]

    /// New current event (if any)
    public let currentEvent: String?

    /// Combat started (if any)
    public let combatStarted: Bool

    /// Game ended (if any)
    public let gameEnded: GameEndResult?

    // MARK: - Convenience Initializers

    public init(
        success: Bool,
        error: ActionError?,
        stateChanges: [StateChange],
        triggeredEvents: [String],
        currentEvent: String?,
        combatStarted: Bool,
        gameEnded: GameEndResult?
    ) {
        self.success = success
        self.error = error
        self.stateChanges = stateChanges
        self.triggeredEvents = triggeredEvents
        self.currentEvent = currentEvent
        self.combatStarted = combatStarted
        self.gameEnded = gameEnded
    }

    public static func success(
        changes: [StateChange] = [],
        triggeredEvents: [String] = [],
        currentEvent: String? = nil,
        combatStarted: Bool = false
    ) -> ActionResult {
        ActionResult(
            success: true,
            error: nil,
            stateChanges: changes,
            triggeredEvents: triggeredEvents,
            currentEvent: currentEvent,
            combatStarted: combatStarted,
            gameEnded: nil
        )
    }

    public static func failure(_ error: ActionError) -> ActionResult {
        ActionResult(
            success: false,
            error: error,
            stateChanges: [],
            triggeredEvents: [],
            currentEvent: nil,
            combatStarted: false,
            gameEnded: nil
        )
    }

    public static func gameOver(_ result: GameEndResult) -> ActionResult {
        ActionResult(
            success: true,
            error: nil,
            stateChanges: [],
            triggeredEvents: [],
            currentEvent: nil,
            combatStarted: false,
            gameEnded: result
        )
    }
}

// MARK: - Action Error

public enum InvalidActionReason: Equatable, Sendable {
    case noCurrentRegion
    case marketNotInitialized
    case cardNotInMarket
    case unknownCard(cardId: String)
    case defileRequiresDarkAlignment
    case anchorAlreadyDark
    case eventNotCombatEncounter
    case fateDeckUnavailable
    case miniGameUnavailable
    case eventNotMiniGame
    case miniGameChallengeMismatch

    public var localizedDescription: String {
        switch self {
        case .noCurrentRegion:
            return L10n.errorInvalidActionNoCurrentRegion.localized
        case .marketNotInitialized:
            return L10n.errorInvalidActionMarketNotInitialized.localized
        case .cardNotInMarket:
            return L10n.errorInvalidActionCardNotInMarket.localized
        case .unknownCard(let cardId):
            return L10n.errorInvalidActionUnknownCard.localized(with: cardId)
        case .defileRequiresDarkAlignment:
            return L10n.errorInvalidActionDefileRequiresDarkAlignment.localized
        case .anchorAlreadyDark:
            return L10n.errorInvalidActionAnchorAlreadyDark.localized
        case .eventNotCombatEncounter:
            return L10n.errorInvalidActionEventNotCombatEncounter.localized
        case .fateDeckUnavailable:
            return L10n.errorInvalidActionFateDeckUnavailable.localized
        case .miniGameUnavailable:
            return L10n.errorInvalidActionMiniGameUnavailable.localized
        case .eventNotMiniGame:
            return L10n.errorInvalidActionEventNotMiniGame.localized
        case .miniGameChallengeMismatch:
            return L10n.errorInvalidActionMiniGameChallengeMismatch.localized
        }
    }
}

/// Errors that can occur when performing actions
public enum ActionError: Error, Equatable {
    // Validation errors
    case invalidAction(reason: InvalidActionReason)
    case regionNotAccessible(regionId: String)
    case regionNotNeighbor(regionId: String)
    case actionNotAvailableInRegion(action: String, regionType: String)

    // Resource errors
    case insufficientResources(resource: String, required: Int, available: Int)
    case healthTooLow

    // State errors
    case gameNotInProgress
    case combatInProgress
    case eventInProgress
    case noActiveEvent
    case noActiveCombat

    // Event errors
    case eventNotFound(eventId: String)
    case invalidChoiceIndex(index: Int, maxIndex: Int)
    case choiceRequirementsNotMet(reason: String)

    // Combat errors
    case cardNotInHand(cardId: String)
    case notEnoughActions
    case invalidTarget

    public var localizedDescription: String {
        switch self {
        case .invalidAction(let reason):
            return L10n.errorInvalidAction.localized(with: reason.localizedDescription)
        case .regionNotAccessible(let id):
            return L10n.errorRegionNotAccessible.localized(with: id)
        case .regionNotNeighbor(let id):
            return L10n.errorRegionNotNeighbor.localized(with: id)
        case .actionNotAvailableInRegion(let action, let type):
            return L10n.errorActionNotAvailable.localized(with: action, type)
        case .insufficientResources(let resource, let required, let available):
            return L10n.errorInsufficientResources.localized(with: resource, required, available)
        case .healthTooLow:
            return L10n.errorHealthTooLow.localized
        case .gameNotInProgress:
            return L10n.errorGameNotInProgress.localized
        case .combatInProgress:
            return L10n.errorCombatInProgress.localized
        case .eventInProgress:
            return L10n.errorEventInProgress.localized
        case .noActiveEvent:
            return L10n.errorNoActiveEvent.localized
        case .noActiveCombat:
            return L10n.errorNoActiveCombat.localized
        case .eventNotFound(let id):
            return L10n.errorEventNotFound.localized(with: id)
        case .invalidChoiceIndex(let index, let max):
            return L10n.errorInvalidChoiceIndex.localized(with: index, max)
        case .choiceRequirementsNotMet(let reason):
            return L10n.errorChoiceRequirementsNotMet.localized(with: reason)
        case .cardNotInHand(let id):
            return L10n.errorCardNotInHand.localized(with: id)
        case .notEnoughActions:
            return L10n.errorNotEnoughActions.localized
        case .invalidTarget:
            return L10n.errorInvalidTarget.localized
        }
    }
}

// MARK: - State Change

/// A single state change from an action
public enum StateChange: Equatable {
    // Player changes
    case healthChanged(delta: Int, newValue: Int)
    case faithChanged(delta: Int, newValue: Int)
    case balanceChanged(delta: Int, newValue: Int)
    case strengthChanged(delta: Int, newValue: Int)

    // World changes
    case resonanceChanged(delta: Float, newValue: Float)
    case tensionChanged(delta: Int, newValue: Int)
    case dayAdvanced(newDay: Int)
    case regionChanged(regionId: String)
    case regionStateChanged(regionId: String, newState: String)
    case anchorIntegrityChanged(anchorId: String, delta: Int, newValue: Int)
    case anchorAlignmentChanged(anchorId: String, newAlignment: String)

    // Flags and progress
    case flagSet(key: String, value: Bool)
    case questProgressed(questId: String, newStage: Int)
    case eventCompleted(eventId: String)
    case questStarted(questId: String)
    case objectiveCompleted(questId: String, objectiveId: String)
    case questCompleted(questId: String)
    case questFailed(questId: String)

    // Cards and deck
    case cardAdded(cardId: String, zone: String)
    case cardRemoved(cardId: String, zone: String)
    case cardMoved(cardId: String, fromZone: String, toZone: String)

    // Combat
    case enemyDamaged(enemyId: String, damage: Int, newHealth: Int)
    case enemyWillDamaged(enemyId: String, damage: Int, newWill: Int)
    case enemyDefeated(enemyId: String)
    case enemyPacified(enemyId: String)
    case combatEnded(victory: Bool)

    // Custom
    case custom(key: String, description: String)
}

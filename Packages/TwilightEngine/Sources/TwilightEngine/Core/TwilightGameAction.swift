import Foundation

// MARK: - Game Actions
// All player actions go through these - UI never mutates state directly

/// All possible player actions in the game engine
public enum TwilightGameAction: TimedAction, Equatable {
    // MARK: - Movement
    /// Travel to another region
    case travel(toRegionId: String)

    // MARK: - Region Actions
    /// Rest in current region (heals, costs time)
    case rest

    /// Explore current region (triggers events)
    case explore

    /// Trade at market (if available)
    case trade

    /// Strengthen anchor in current region
    case strengthenAnchor

    // MARK: - Event Handling
    /// Choose an option in an event
    case chooseEventOption(eventId: String, choiceIndex: Int)

    /// Resolve a mini-game result
    case resolveMiniGame(input: MiniGameInput)

    // MARK: - Combat Setup
    /// Start combat with encounter
    case startCombat(encounterId: String)

    /// Initialize combat: shuffle deck and draw initial hand
    case combatInitialize

    // MARK: - Combat Actions
    /// Perform basic attack in combat
    case combatAttack(bonusDice: Int, bonusDamage: Int, isFirstAttack: Bool)

    /// Play a card in combat
    case playCard(cardId: String, targetId: String?)

    /// Apply card ability effect
    case combatApplyEffect(effect: CombatActionEffect)

    /// End combat turn (goes to enemy phase)
    case endCombatTurn

    /// Perform enemy attack
    case combatEnemyAttack(damage: Int)

    /// End turn phase: discard hand, draw new cards, restore faith
    case combatEndTurnPhase

    /// Flee from combat
    case combatFlee

    /// Finish combat with result
    case combatFinish(victory: Bool)

    // MARK: - UI Actions
    /// Dismiss current event (after UI handles it)
    case dismissCurrentEvent

    /// Dismiss day event notification
    case dismissDayEvent

    // MARK: - Special
    /// Skip/pass turn
    case skipTurn

    /// Custom action for extensibility
    case custom(id: String, timeCost: Int)

    // MARK: - TimedAction Conformance

    public var timeCost: Int {
        switch self {
        case .travel:
            // Travel cost determined by engine based on distance
            // Default to 1, actual cost calculated in engine
            return 1

        case .rest:
            return 1

        case .explore:
            return 1

        case .trade:
            return 0  // Trading doesn't cost time

        case .strengthenAnchor:
            return 1

        case .chooseEventOption:
            return 0  // Events are part of explore/travel

        case .resolveMiniGame:
            return 0  // Mini-game is part of event

        case .startCombat:
            return 0  // Combat is part of event

        case .combatInitialize:
            return 0  // Setup, no time cost

        case .combatAttack:
            return 0  // Within combat turn

        case .playCard:
            return 0  // Cards are within combat turn

        case .combatApplyEffect:
            return 0  // Effect application

        case .endCombatTurn:
            return 0  // Turn management

        case .combatEnemyAttack:
            return 0  // Enemy phase

        case .combatEndTurnPhase:
            return 0  // End of turn

        case .combatFlee:
            return 0  // Escape

        case .combatFinish:
            return 0  // Combat end

        case .dismissCurrentEvent:
            return 0  // UI action, no time cost

        case .dismissDayEvent:
            return 0  // UI action, no time cost

        case .skipTurn:
            return 1

        case .custom(_, let cost):
            return cost
        }
    }
}

// MARK: - Mini-Game Input

/// Input data for resolving a mini-game action
/// Different from MiniGameResult in MiniGameChallengeDefinition.swift (serializable state diff)
public struct MiniGameInput: Equatable {
    public let challengeId: String
    public let success: Bool
    public let score: Int?
    public let bonusRewards: [String: Int]

    public init(challengeId: String, success: Bool, score: Int? = nil, bonusRewards: [String: Int] = [:]) {
        self.challengeId = challengeId
        self.success = success
        self.score = score
        self.bonusRewards = bonusRewards
    }
}

// MARK: - Combat Effect

/// Effect to apply during combat (from cards or abilities)
public enum CombatActionEffect: Equatable {
    /// Heal player
    case heal(amount: Int)

    /// Deal damage to enemy
    case damageEnemy(amount: Int)

    /// Draw cards
    case drawCards(count: Int)

    /// Gain faith
    case gainFaith(amount: Int)

    /// Spend faith
    case spendFaith(amount: Int)

    /// Take damage (sacrifice)
    case takeDamage(amount: Int)

    /// Remove curse
    case removeCurse(type: String?)

    /// Shift balance
    case shiftBalance(towards: String, amount: Int)

    /// Add bonus dice for next attack
    case addBonusDice(count: Int)

    /// Add bonus damage for next attack
    case addBonusDamage(amount: Int)

    /// Summon spirit to attack enemy
    case summonSpirit(power: Int, realm: String)
}

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

/// Errors that can occur when performing actions
public enum ActionError: Error, Equatable {
    // Validation errors
    case invalidAction(reason: String)
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
            return L10n.errorInvalidAction.localized(with: reason)
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
    case tensionChanged(delta: Int, newValue: Int)
    case dayAdvanced(newDay: Int)
    case regionChanged(regionId: String)
    case regionStateChanged(regionId: String, newState: String)
    case anchorIntegrityChanged(anchorId: String, delta: Int, newValue: Int)

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
    case enemyDefeated(enemyId: String)
    case combatEnded(victory: Bool)

    // Custom
    case custom(key: String, description: String)
}

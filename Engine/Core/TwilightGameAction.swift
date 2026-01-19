import Foundation

// MARK: - Twilight Marches Game Actions
// All player actions go through these - UI never mutates state directly

/// All possible player actions in Twilight Marches
enum TwilightGameAction: TimedAction, Equatable {
    // MARK: - Movement
    /// Travel to another region
    case travel(toRegionId: UUID)

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
    case chooseEventOption(eventId: UUID, choiceIndex: Int)

    /// Resolve a mini-game result
    case resolveMiniGame(input: MiniGameInput)

    // MARK: - Combat Setup
    /// Start combat with encounter
    case startCombat(encounterId: UUID)

    /// Initialize combat: shuffle deck and draw initial hand
    case combatInitialize

    // MARK: - Combat Actions
    /// Perform basic attack in combat
    case combatAttack(bonusDice: Int, bonusDamage: Int, isFirstAttack: Bool)

    /// Play a card in combat
    case playCard(cardId: UUID, targetId: UUID?)

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

    var timeCost: Int {
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
struct MiniGameInput: Equatable {
    let challengeId: UUID
    let success: Bool
    let score: Int?
    let bonusRewards: [String: Int]

    init(challengeId: UUID, success: Bool, score: Int? = nil, bonusRewards: [String: Int] = [:]) {
        self.challengeId = challengeId
        self.success = success
        self.score = score
        self.bonusRewards = bonusRewards
    }
}

// MARK: - Combat Effect

/// Effect to apply during combat (from cards or abilities)
enum CombatActionEffect: Equatable {
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
struct ActionResult: Equatable {
    /// Whether the action succeeded
    let success: Bool

    /// Error if action failed
    let error: ActionError?

    /// State changes that occurred
    let stateChanges: [StateChange]

    /// Events triggered by this action
    let triggeredEvents: [UUID]

    /// New current event (if any)
    let currentEvent: UUID?

    /// Combat started (if any)
    let combatStarted: Bool

    /// Game ended (if any)
    let gameEnded: GameEndResult?

    // MARK: - Convenience Initializers

    static func success(
        changes: [StateChange] = [],
        triggeredEvents: [UUID] = [],
        currentEvent: UUID? = nil,
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

    static func failure(_ error: ActionError) -> ActionResult {
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

    static func gameOver(_ result: GameEndResult) -> ActionResult {
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
enum ActionError: Error, Equatable {
    // Validation errors
    case invalidAction(reason: String)
    case regionNotAccessible(regionId: UUID)
    case regionNotNeighbor(regionId: UUID)
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
    case eventNotFound(eventId: UUID)
    case invalidChoiceIndex(index: Int, maxIndex: Int)
    case choiceRequirementsNotMet(reason: String)

    // Combat errors
    case cardNotInHand(cardId: UUID)
    case notEnoughActions
    case invalidTarget

    var localizedDescription: String {
        switch self {
        case .invalidAction(let reason):
            return "Invalid action: \(reason)"
        case .regionNotAccessible(let id):
            return "Region \(id) is not accessible"
        case .regionNotNeighbor(let id):
            return "Region \(id) is not a neighbor"
        case .actionNotAvailableInRegion(let action, let type):
            return "\(action) not available in \(type) region"
        case .insufficientResources(let resource, let required, let available):
            return "Need \(required) \(resource), have \(available)"
        case .healthTooLow:
            return "Health too low for this action"
        case .gameNotInProgress:
            return "Game is not in progress"
        case .combatInProgress:
            return "Cannot perform this action during combat"
        case .eventInProgress:
            return "Must resolve current event first"
        case .noActiveEvent:
            return "No active event"
        case .noActiveCombat:
            return "No active combat"
        case .eventNotFound(let id):
            return "Event \(id) not found"
        case .invalidChoiceIndex(let index, let max):
            return "Choice \(index) invalid (max: \(max))"
        case .choiceRequirementsNotMet(let reason):
            return "Cannot choose: \(reason)"
        case .cardNotInHand(let id):
            return "Card \(id) not in hand"
        case .notEnoughActions:
            return "Not enough actions remaining"
        case .invalidTarget:
            return "Invalid target"
        }
    }
}

// MARK: - State Change

/// A single state change from an action
enum StateChange: Equatable {
    // Player changes
    case healthChanged(delta: Int, newValue: Int)
    case faithChanged(delta: Int, newValue: Int)
    case balanceChanged(delta: Int, newValue: Int)
    case strengthChanged(delta: Int, newValue: Int)

    // World changes
    case tensionChanged(delta: Int, newValue: Int)
    case dayAdvanced(newDay: Int)
    case regionChanged(regionId: UUID)
    case regionStateChanged(regionId: UUID, newState: String)
    case anchorIntegrityChanged(anchorId: UUID, delta: Int, newValue: Int)

    // Flags and progress
    case flagSet(key: String, value: Bool)
    case questProgressed(questId: String, newStage: Int)
    case eventCompleted(eventId: UUID)

    // Cards and deck
    case cardAdded(cardId: UUID, zone: String)
    case cardRemoved(cardId: UUID, zone: String)
    case cardMoved(cardId: UUID, fromZone: String, toZone: String)

    // Combat
    case enemyDamaged(enemyId: UUID, damage: Int, newHealth: Int)
    case enemyDefeated(enemyId: UUID)
    case combatEnded(victory: Bool)

    // Custom
    case custom(key: String, description: String)
}

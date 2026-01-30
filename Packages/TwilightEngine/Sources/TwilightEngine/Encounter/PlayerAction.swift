import Foundation

/// Actions a player can take during an encounter
public enum PlayerAction: Equatable {
    case attack(targetId: String)
    case spiritAttack(targetId: String)
    case defend
    case flee
    case wait
    case mulligan(cardIds: [String])
    case useCard(cardId: String, targetId: String?)
    case resolveFateChoice(optionIndex: Int)
}

/// Result of performing an action within the encounter
public struct EncounterActionResult: Equatable {
    public let success: Bool
    public let error: EncounterError?
    public let stateChanges: [EncounterStateChange]

    public init(success: Bool, error: EncounterError? = nil, stateChanges: [EncounterStateChange] = []) {
        self.success = success
        self.error = error
        self.stateChanges = stateChanges
    }

    public static func ok(_ changes: [EncounterStateChange] = []) -> EncounterActionResult {
        EncounterActionResult(success: true, stateChanges: changes)
    }

    public static func fail(_ error: EncounterError) -> EncounterActionResult {
        EncounterActionResult(success: false, error: error)
    }
}

/// Errors from encounter actions
public enum EncounterError: String, Equatable, Error {
    case invalidPhaseOrder
    case actionNotAllowed
    case invalidTarget
    case mulliganAlreadyDone
    case encounterOver
    case insufficientFaith
}

/// State changes emitted by encounter actions
public enum EncounterStateChange: Equatable {
    case enemyHPChanged(enemyId: String, delta: Int, newValue: Int)
    case enemyWPChanged(enemyId: String, delta: Int, newValue: Int)
    case playerHPChanged(delta: Int, newValue: Int)
    case enemyKilled(enemyId: String)
    case enemyPacified(enemyId: String)
    case resonanceShifted(delta: Float, newValue: Float)
    case rageShieldApplied(enemyId: String, value: Int)
    case fateDraw(cardId: String, value: Int)
    case cardPlayed(cardId: String, name: String)
    case cardDrawn(cardId: String)
    case faithChanged(delta: Int, newValue: Int)
    case fateChoicePending(cardId: String)
    case encounterEnded(outcome: EncounterOutcome)
}

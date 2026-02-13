/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/TwilightGameAction.swift
/// Назначение: Содержит реализацию файла TwilightGameAction.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

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

    /// Buy a card from market (if market initialized for current region/day)
    case marketBuy(cardId: String)

    /// Strengthen anchor in current region
    case strengthenAnchor

    /// Defile anchor in current region (dark heroes: shift alignment to dark)
    case defileAnchor

    // MARK: - Event Handling
    /// Choose an option in an event
    case chooseEventOption(eventId: String, choiceIndex: Int)

    /// Resolve a mini-game result
    case resolveMiniGame(input: MiniGameInput)

    /// Draw and resolve Fate card outside combat
    case drawFateCard

    // MARK: - Combat Setup
    /// Start combat with encounter
    case startCombat(encounterId: String)

    /// Commit external combat result into world state
    case combatFinish(
        outcome: CombatEndOutcome,
        transaction: EncounterTransaction,
        updatedFateDeck: FateDeckState?
    )

    /// Store/clear pending external combat snapshot for save-resume
    case combatStoreEncounterState(EncounterSaveState?)

    /// Initialize combat: shuffle deck and draw initial hand
    case combatInitialize

    // MARK: - Combat Actions (Active Defense System)

    /// Mulligan: replace selected cards at combat start
    case combatMulligan(cardIds: [String])

    /// Generate and show enemy intent for this turn
    case combatGenerateIntent

    /// Player attack with automatic Fate card draw (Active Defense)
    /// bonusDamage: extra damage from played cards
    case combatPlayerAttackWithFate(bonusDamage: Int)

    /// Player skips attack phase (saves resources, still defends)
    case combatSkipAttack

    /// Enemy resolves their intent with automatic Defense Fate card
    case combatEnemyResolveWithFate

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

        case .marketBuy:
            return 0  // Market interactions are instant

        case .strengthenAnchor:
            return 1

        case .defileAnchor:
            return 1

        case .chooseEventOption:
            return 0  // Events are part of explore/travel

        case .resolveMiniGame:
            return 0  // Mini-game is part of event

        case .drawFateCard:
            return 0

        case .startCombat:
            return 0  // Combat is part of event

        case .combatFinish:
            return 0

        case .combatStoreEncounterState:
            return 0

        case .combatInitialize:
            return 0  // Setup, no time cost

        case .combatMulligan:
            return 0  // Part of combat setup

        case .combatGenerateIntent:
            return 0  // Intent generation

        case .combatPlayerAttackWithFate:
            return 0  // Within combat turn

        case .combatSkipAttack:
            return 0  // Within combat turn

        case .combatEnemyResolveWithFate:
            return 0  // Enemy phase

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

/// Canonical outcome for committing external combat result into engine state.
public enum CombatEndOutcome: Codable, Equatable {
    case victory
    case defeat
    case escaped
}

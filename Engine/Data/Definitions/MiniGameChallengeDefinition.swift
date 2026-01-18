import Foundation

// MARK: - Mini-Game Challenge Definition
// Reference: Docs/EVENT_MODULE_ARCHITECTURE.md, Section 4

/// Immutable definition of a mini-game challenge.
/// Describes what gets dispatched to external mini-game modules.
struct MiniGameChallengeDefinition: Codable, Hashable, Identifiable {
    // MARK: - Identity

    /// Unique challenge identifier
    let id: String

    // MARK: - Type

    /// Type of mini-game
    let challengeType: ChallengeType

    // MARK: - Difficulty

    /// Base difficulty level (1-10)
    let difficulty: Int

    /// Difficulty scaling based on pressure
    let pressureScaling: Double

    // MARK: - Content Reference

    /// Enemy ID for combat challenges
    let enemyId: String?

    /// Puzzle ID for puzzle challenges
    let puzzleId: String?

    /// Dialogue tree ID for dialogue challenges
    let dialogueId: String?

    // MARK: - Outcomes

    /// Consequences on victory
    let victoryConsequences: ChoiceConsequences

    /// Consequences on defeat
    let defeatConsequences: ChoiceConsequences

    /// Consequences on retreat/escape (if allowed)
    let retreatConsequences: ChoiceConsequences?

    // MARK: - Options

    /// Whether retreat/escape is allowed
    let canRetreat: Bool

    /// Time limit in turns (0 = no limit)
    let turnLimit: Int

    // MARK: - Initialization

    init(
        id: String,
        challengeType: ChallengeType,
        difficulty: Int = 5,
        pressureScaling: Double = 0.1,
        enemyId: String? = nil,
        puzzleId: String? = nil,
        dialogueId: String? = nil,
        victoryConsequences: ChoiceConsequences = .none,
        defeatConsequences: ChoiceConsequences = .none,
        retreatConsequences: ChoiceConsequences? = nil,
        canRetreat: Bool = true,
        turnLimit: Int = 0
    ) {
        self.id = id
        self.challengeType = challengeType
        self.difficulty = difficulty
        self.pressureScaling = pressureScaling
        self.enemyId = enemyId
        self.puzzleId = puzzleId
        self.dialogueId = dialogueId
        self.victoryConsequences = victoryConsequences
        self.defeatConsequences = defeatConsequences
        self.retreatConsequences = retreatConsequences
        self.canRetreat = canRetreat
        self.turnLimit = turnLimit
    }

    /// Calculate effective difficulty based on current pressure
    func effectiveDifficulty(at pressure: Int) -> Int {
        let scaled = Double(difficulty) + (Double(pressure) * pressureScaling)
        return Int(scaled.rounded())
    }
}

// MARK: - Challenge Type

/// Types of mini-game challenges
enum ChallengeType: String, Codable, Hashable, CaseIterable {
    /// Combat encounter with deck-building mechanics
    case combat

    /// Ritual/prayer challenge (faith-based)
    case ritual

    /// Exploration challenge (resource management)
    case exploration

    /// Dialogue/negotiation challenge
    case dialogue

    /// Puzzle challenge
    case puzzle
}

// MARK: - Mini-Game Result

/// Result returned by a mini-game module
/// Reference: EVENT_MODULE_ARCHITECTURE.md, Section 4.2
struct MiniGameResult: Codable, Hashable {
    /// Outcome of the mini-game
    let outcome: MiniGameOutcome

    /// State diff to apply
    let diff: MiniGameDiff

    /// Additional data from the mini-game
    let metadata: [String: String]

    init(
        outcome: MiniGameOutcome,
        diff: MiniGameDiff,
        metadata: [String: String] = [:]
    ) {
        self.outcome = outcome
        self.diff = diff
        self.metadata = metadata
    }
}

/// Possible outcomes of a mini-game
enum MiniGameOutcome: String, Codable, Hashable {
    case victory
    case defeat
    case retreat
    case timeout
}

/// State changes from a mini-game (diff-only, no direct mutation)
/// Reference: EVENT_MODULE_ARCHITECTURE.md, Invariant #2
struct MiniGameDiff: Codable, Hashable {
    /// Resource changes
    let resourceChanges: [String: Int]

    /// Flags to set
    let flagsToSet: [String: Bool]

    /// Cards to add to deck
    let cardsToAdd: [String]

    /// Cards to remove from deck
    let cardsToRemove: [String]

    /// Balance change
    let balanceDelta: Int

    init(
        resourceChanges: [String: Int] = [:],
        flagsToSet: [String: Bool] = [:],
        cardsToAdd: [String] = [],
        cardsToRemove: [String] = [],
        balanceDelta: Int = 0
    ) {
        self.resourceChanges = resourceChanges
        self.flagsToSet = flagsToSet
        self.cardsToAdd = cardsToAdd
        self.cardsToRemove = cardsToRemove
        self.balanceDelta = balanceDelta
    }

    /// Empty diff (no changes)
    static let empty = MiniGameDiff()
}

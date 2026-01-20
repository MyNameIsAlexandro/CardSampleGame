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

    /// Type of mini-game challenge
    let challengeKind: MiniGameChallengeKind

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
        challengeKind: MiniGameChallengeKind,
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
        self.challengeKind = challengeKind
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

    // MARK: - Custom Codable

    /// Coding keys for simplified JSON format from events.json
    private enum CodingKeys: String, CodingKey {
        case id
        case challengeKind = "challenge_kind"
        case difficulty
        case pressureScaling = "pressure_scaling"
        case enemyId = "enemy_id"
        case puzzleId = "puzzle_id"
        case dialogueId = "dialogue_id"
        case victoryConsequences = "victory_consequences"
        case defeatConsequences = "defeat_consequences"
        case retreatConsequences = "retreat_consequences"
        case canRetreat = "can_retreat"
        case turnLimit = "turn_limit"
        // Simplified format keys
        case rewards
        case penalties
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Try full format first, then simplified format
        if let id = try container.decodeIfPresent(String.self, forKey: .id) {
            self.id = id
        } else if let enemyId = try container.decodeIfPresent(String.self, forKey: .enemyId) {
            // Generate ID from enemy ID for simplified format
            self.id = "challenge_\(enemyId)"
        } else {
            self.id = "challenge_unknown"
        }

        // Challenge kind - default to combat for simplified format
        self.challengeKind = try container.decodeIfPresent(MiniGameChallengeKind.self, forKey: .challengeKind) ?? .combat

        // Difficulty
        self.difficulty = try container.decodeIfPresent(Int.self, forKey: .difficulty) ?? 5

        // Pressure scaling
        self.pressureScaling = try container.decodeIfPresent(Double.self, forKey: .pressureScaling) ?? 0.1

        // Content references
        self.enemyId = try container.decodeIfPresent(String.self, forKey: .enemyId)
        self.puzzleId = try container.decodeIfPresent(String.self, forKey: .puzzleId)
        self.dialogueId = try container.decodeIfPresent(String.self, forKey: .dialogueId)

        // Consequences - try full format first, then simplified
        if let victory = try container.decodeIfPresent(ChoiceConsequences.self, forKey: .victoryConsequences) {
            self.victoryConsequences = victory
        } else if let rewards = try container.decodeIfPresent(ChoiceConsequences.self, forKey: .rewards) {
            self.victoryConsequences = rewards
        } else {
            self.victoryConsequences = .none
        }

        if let defeat = try container.decodeIfPresent(ChoiceConsequences.self, forKey: .defeatConsequences) {
            self.defeatConsequences = defeat
        } else if let penalties = try container.decodeIfPresent(ChoiceConsequences.self, forKey: .penalties) {
            self.defeatConsequences = penalties
        } else {
            self.defeatConsequences = .none
        }

        self.retreatConsequences = try container.decodeIfPresent(ChoiceConsequences.self, forKey: .retreatConsequences)

        // Options
        self.canRetreat = try container.decodeIfPresent(Bool.self, forKey: .canRetreat) ?? true
        self.turnLimit = try container.decodeIfPresent(Int.self, forKey: .turnLimit) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(challengeKind, forKey: .challengeKind)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(pressureScaling, forKey: .pressureScaling)
        try container.encodeIfPresent(enemyId, forKey: .enemyId)
        try container.encodeIfPresent(puzzleId, forKey: .puzzleId)
        try container.encodeIfPresent(dialogueId, forKey: .dialogueId)
        try container.encode(victoryConsequences, forKey: .victoryConsequences)
        try container.encode(defeatConsequences, forKey: .defeatConsequences)
        try container.encodeIfPresent(retreatConsequences, forKey: .retreatConsequences)
        try container.encode(canRetreat, forKey: .canRetreat)
        try container.encode(turnLimit, forKey: .turnLimit)
    }
}

// MARK: - Mini-Game Challenge Kind

/// Types of mini-game challenges (Engine-specific, distinct from ChallengeType in EngineProtocols)
enum MiniGameChallengeKind: String, Codable, Hashable, CaseIterable {
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

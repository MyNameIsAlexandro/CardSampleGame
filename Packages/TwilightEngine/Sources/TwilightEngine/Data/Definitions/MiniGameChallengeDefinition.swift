/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Data/Definitions/MiniGameChallengeDefinition.swift
/// Назначение: Содержит реализацию файла MiniGameChallengeDefinition.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Mini-Game Challenge Definition
// Reference: Docs/EVENT_MODULE_ARCHITECTURE.md, Section 4

/// Immutable definition of a mini-game challenge.
/// Describes what gets dispatched to external mini-game modules.
public struct MiniGameChallengeDefinition: Codable, Hashable, Identifiable {
    // MARK: - Identity

    /// Unique challenge identifier
    public let id: String

    // MARK: - Type

    /// Type of mini-game challenge
    public let challengeKind: MiniGameChallengeKind

    // MARK: - Difficulty

    /// Base difficulty level (1-10)
    public let difficulty: Int

    /// Difficulty scaling based on pressure
    public let pressureScaling: Double

    // MARK: - Content Reference

    /// Enemy ID for combat challenges
    public let enemyId: String?

    /// Puzzle ID for puzzle challenges
    public let puzzleId: String?

    /// Dialogue tree ID for dialogue challenges
    public let dialogueId: String?

    // MARK: - Outcomes

    /// Consequences on victory
    public let victoryConsequences: ChoiceConsequences

    /// Consequences on defeat
    public let defeatConsequences: ChoiceConsequences

    /// Consequences on retreat/escape (if allowed)
    public let retreatConsequences: ChoiceConsequences?

    // MARK: - Options

    /// Whether retreat/escape is allowed
    public let canRetreat: Bool

    /// Time limit in turns (0 = no limit)
    public let turnLimit: Int

    // MARK: - Initialization

    public init(
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
    public func effectiveDifficulty(at pressure: Int) -> Int {
        let scaled = Double(difficulty) + (Double(pressure) * pressureScaling)
        return Int(scaled.rounded())
    }

    // MARK: - Custom Codable

    /// Coding keys for JSON format from events.json
    /// Supports both camelCase (when convertFromSnakeCase is used) and snake_case (explicit)
    private enum CodingKeys: String, CodingKey {
        case id
        // camelCase keys (for when convertFromSnakeCase converts them)
        case challengeKind
        case pressureScaling
        case enemyId
        case puzzleId
        case dialogueId
        case victoryConsequences
        case defeatConsequences
        case retreatConsequences
        case canRetreat
        case turnLimit
        case difficulty
        // Simplified format keys (always used as-is)
        case rewards
        case penalties
    }

    /// Helper to decode a value trying both camelCase and snake_case keys
    private static func decodeOptional<T: Decodable>(
        _ type: T.Type,
        from container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) throws -> T? {
        // With convertFromSnakeCase, keys are already converted, so just use camelCase key
        return try container.decodeIfPresent(type, forKey: key)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Try full format first, then simplified format
        if let id = try container.decodeIfPresent(String.self, forKey: .id) {
            self.id = id
        } else if let enemyIdValue = try container.decodeIfPresent(String.self, forKey: .enemyId) {
            // Generate ID from enemy ID for simplified format
            self.id = "challenge_\(enemyIdValue)"
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

    public func encode(to encoder: Encoder) throws {
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
public enum MiniGameChallengeKind: String, Codable, Hashable, CaseIterable {
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
public struct MiniGameResult: Codable, Hashable {
    /// Outcome of the mini-game
    public let outcome: MiniGameOutcome

    /// State diff to apply
    public let diff: MiniGameDiff

    /// Additional data from the mini-game
    public let metadata: [String: String]

    public init(
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
public enum MiniGameOutcome: String, Codable, Hashable {
    case victory
    case defeat
    case retreat
    case timeout
}

/// State changes from a mini-game (diff-only, no direct mutation)
/// Reference: EVENT_MODULE_ARCHITECTURE.md, Invariant #2
public struct MiniGameDiff: Codable, Hashable, Sendable {
    /// Resource changes
    public let resourceChanges: [String: Int]

    /// Flags to set
    public let flagsToSet: [String: Bool]

    /// Cards to add to deck
    public let cardsToAdd: [String]

    /// Cards to remove from deck
    public let cardsToRemove: [String]

    /// Balance change
    public let balanceDelta: Int

    public init(
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
    public static let empty = MiniGameDiff()
}

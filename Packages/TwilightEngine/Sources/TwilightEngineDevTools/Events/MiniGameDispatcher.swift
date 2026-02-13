/// Файл: Packages/TwilightEngine/Sources/TwilightEngineDevTools/Events/MiniGameDispatcher.swift
/// Назначение: Содержит реализацию файла MiniGameDispatcher.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation
import TwilightEngine

// MARK: - MiniGame Dispatcher
// Routes mini-game challenges to appropriate resolvers
// Returns result as StateChange diff (no direct state mutation)

/// Dispatches mini-game challenges to resolvers
public final class MiniGameDispatcher {
    // MARK: - Resolvers

    private let combatResolver: CombatMiniGameResolver
    private let puzzleResolver: PuzzleMiniGameResolver
    private let skillCheckResolver: SkillCheckResolver
    private let rng: WorldRNG

    // MARK: - Initialization

    public init(rng: WorldRNG = WorldRNG()) {
        self.combatResolver = CombatMiniGameResolver()
        self.puzzleResolver = PuzzleMiniGameResolver()
        self.skillCheckResolver = SkillCheckResolver()
        self.rng = rng
    }

    /// Connect a Fate Deck to the skill check resolver
    public func setFateDeck(_ deck: FateDeckManager?) {
        skillCheckResolver.fateDeck = deck
    }

    // MARK: - Dispatch

    /// Dispatch a mini-game challenge and return result
    public func dispatch(
        challenge: MiniGameChallenge,
        context: MiniGameContext
    ) -> MiniGameDispatchResult {

        switch challenge.type {
        case .combat:
            return combatResolver.resolve(challenge: challenge, context: context, rng: rng)

        case .puzzle:
            return puzzleResolver.resolve(challenge: challenge, context: context, rng: rng)

        case .skillCheck:
            return skillCheckResolver.resolve(challenge: challenge, context: context, rng: rng)

        case .cardGame:
            // Card-based mini-game (future)
            return MiniGameDispatchResult.notImplemented(type: "cardGame")

        case .custom(let type):
            // Custom mini-game type
            return MiniGameDispatchResult.notImplemented(type: type)
        }
    }

    /// Check if challenge can be started
    public func canStartChallenge(
        _ challenge: MiniGameChallenge,
        context: MiniGameContext
    ) -> (canStart: Bool, reason: String?) {

        // Check health minimum
        if context.playerHealth <= 0 {
            return (false, "Player health too low")
        }

        // Check type-specific requirements
        switch challenge.type {
        case .combat:
            // Combat requires health > 0
            return (true, nil)

        case .skillCheck:
            // Skill checks may require specific resources
            if let requiredResource = challenge.requirements["resource"],
               let required = challenge.requirements["amount"] as? Int,
               (context.playerResources[requiredResource as? String ?? ""] ?? 0) < required {
                return (false, "Insufficient \(requiredResource)")
            }
            return (true, nil)

        default:
            return (true, nil)
        }
    }
}

// MARK: - Mini-Game Challenge

/// Definition of a mini-game challenge
public struct MiniGameChallenge {
    public let id: String
    public let type: MiniGameType
    public let difficulty: Int
    public let requirements: [String: Any]
    public let rewards: MiniGameRewards
    public let penalties: MiniGamePenalties

    public init(
        id: String,
        type: MiniGameType,
        difficulty: Int = 1,
        requirements: [String: Any] = [:],
        rewards: MiniGameRewards = MiniGameRewards(),
        penalties: MiniGamePenalties = MiniGamePenalties()
    ) {
        self.id = id
        self.type = type
        self.difficulty = difficulty
        self.requirements = requirements
        self.rewards = rewards
        self.penalties = penalties
    }
}

/// Types of mini-games
public enum MiniGameType: Equatable {
    case combat
    case puzzle
    case skillCheck
    case cardGame
    case custom(String)
}

/// Rewards for completing mini-game
public struct MiniGameRewards {
    public var healthGain: Int = 0
    public var faithGain: Int = 0
    public var tensionReduction: Int = 0
    public var flagsToSet: [String] = []
    public var cardsToGain: [String] = []

    public init(
        healthGain: Int = 0,
        faithGain: Int = 0,
        tensionReduction: Int = 0,
        flagsToSet: [String] = [],
        cardsToGain: [String] = []
    ) {
        self.healthGain = healthGain
        self.faithGain = faithGain
        self.tensionReduction = tensionReduction
        self.flagsToSet = flagsToSet
        self.cardsToGain = cardsToGain
    }
}

/// Penalties for failing mini-game
public struct MiniGamePenalties {
    public var healthLoss: Int = 0
    public var faithLoss: Int = 0
    public var tensionIncrease: Int = 0
    public var balanceShift: Int = 0

    public init(
        healthLoss: Int = 0,
        faithLoss: Int = 0,
        tensionIncrease: Int = 0,
        balanceShift: Int = 0
    ) {
        self.healthLoss = healthLoss
        self.faithLoss = faithLoss
        self.tensionIncrease = tensionIncrease
        self.balanceShift = balanceShift
    }
}

// MARK: - Mini-Game Context

/// Context for mini-game resolution
public struct MiniGameContext {
    public let playerHealth: Int
    public let playerMaxHealth: Int
    public let playerStrength: Int
    public let playerFaith: Int
    public let playerBalance: Int
    public let playerResources: [String: Int]
    public let worldTension: Int
    public let currentFlags: [String: Bool]

    /// Build from engine properties directly (Engine-First Architecture)
    /// - Parameters:
    ///   - engine: The TwilightGameEngine instance
    /// - Returns: MiniGameContext with values from engine
    public static func from(engine: TwilightGameEngine) -> MiniGameContext {
        MiniGameContext(
            playerHealth: engine.player.health,
            playerMaxHealth: engine.player.maxHealth,
            playerStrength: engine.player.strength,
            playerFaith: engine.player.faith,
            playerBalance: engine.player.balance,
            playerResources: ["faith": engine.player.faith, "health": engine.player.health],
            worldTension: engine.worldTension,
            currentFlags: engine.publishedWorldFlags
        )
    }

    /// Direct initializer for testing or manual construction
    public init(
        playerHealth: Int,
        playerMaxHealth: Int,
        playerStrength: Int,
        playerFaith: Int,
        playerBalance: Int,
        playerResources: [String: Int],
        worldTension: Int,
        currentFlags: [String: Bool]
    ) {
        self.playerHealth = playerHealth
        self.playerMaxHealth = playerMaxHealth
        self.playerStrength = playerStrength
        self.playerFaith = playerFaith
        self.playerBalance = playerBalance
        self.playerResources = playerResources
        self.worldTension = worldTension
        self.currentFlags = currentFlags
    }
}

// MARK: - Mini-Game Dispatch Result

/// Result of mini-game dispatch
public struct MiniGameDispatchResult {
    public let success: Bool
    public let completed: Bool
    public let outcome: MiniGameOutcome?
    public let stateChanges: [StateChange]
    public let narrativeText: String?
    public let error: String?

    public static func victory(changes: [StateChange], narrative: String? = nil) -> MiniGameDispatchResult {
        MiniGameDispatchResult(
            success: true,
            completed: true,
            outcome: .victory,
            stateChanges: changes,
            narrativeText: narrative,
            error: nil
        )
    }

    public static func defeat(changes: [StateChange], narrative: String? = nil) -> MiniGameDispatchResult {
        MiniGameDispatchResult(
            success: true,
            completed: true,
            outcome: .defeat,
            stateChanges: changes,
            narrativeText: narrative,
            error: nil
        )
    }

    public static func inProgress(changes: [StateChange]) -> MiniGameDispatchResult {
        MiniGameDispatchResult(
            success: true,
            completed: false,
            outcome: nil,
            stateChanges: changes,
            narrativeText: nil,
            error: nil
        )
    }

    public static func notImplemented(type: String) -> MiniGameDispatchResult {
        MiniGameDispatchResult(
            success: false,
            completed: false,
            outcome: nil,
            stateChanges: [],
            narrativeText: nil,
            error: "Mini-game type '\(type)' not implemented"
        )
    }

    public static func failure(_ error: String) -> MiniGameDispatchResult {
        MiniGameDispatchResult(
            success: false,
            completed: false,
            outcome: nil,
            stateChanges: [],
            narrativeText: nil,
            error: error
        )
    }
}

// MARK: - Combat Mini-Game Resolver

/// Resolves combat mini-games
public final class CombatMiniGameResolver {
    public init() {}

    public func resolve(
        challenge: MiniGameChallenge,
        context: MiniGameContext,
        rng: WorldRNG
    ) -> MiniGameDispatchResult {

        var changes: [StateChange] = []

        // Simple combat resolution
        let playerRoll = rng.nextInt(in: 1...6) + context.playerStrength
        let enemyRoll = rng.nextInt(in: 1...6) + challenge.difficulty

        if playerRoll >= enemyRoll {
            // Victory
            // Apply rewards
            if challenge.rewards.healthGain > 0 {
                let newHealth = min(context.playerMaxHealth, context.playerHealth + challenge.rewards.healthGain)
                changes.append(.healthChanged(delta: challenge.rewards.healthGain, newValue: newHealth))
            }

            if challenge.rewards.faithGain > 0 {
                let newFaith = context.playerFaith + challenge.rewards.faithGain
                changes.append(.faithChanged(delta: challenge.rewards.faithGain, newValue: newFaith))
            }

            for flag in challenge.rewards.flagsToSet {
                changes.append(.flagSet(key: flag, value: true))
            }

            return .victory(changes: changes, narrative: L10n.miniGameCombatVictory.localized)
        } else {
            // Defeat
            // Apply penalties
            if challenge.penalties.healthLoss > 0 {
                let newHealth = max(0, context.playerHealth - challenge.penalties.healthLoss)
                changes.append(.healthChanged(delta: -challenge.penalties.healthLoss, newValue: newHealth))
            }

            if challenge.penalties.balanceShift != 0 {
                let newBalance = max(0, min(100, context.playerBalance + challenge.penalties.balanceShift))
                changes.append(.balanceChanged(delta: challenge.penalties.balanceShift, newValue: newBalance))
            }

            return .defeat(changes: changes, narrative: L10n.miniGameCombatDefeat.localized)
        }
    }
}

// MARK: - Puzzle Mini-Game Resolver

/// Resolves puzzle mini-games
public final class PuzzleMiniGameResolver {
    public init() {}

    public func resolve(
        challenge: MiniGameChallenge,
        context: MiniGameContext,
        rng: WorldRNG
    ) -> MiniGameDispatchResult {

        var changes: [StateChange] = []

        // Simple puzzle resolution based on faith/wisdom
        let successChance = min(90, 50 + context.playerFaith * 5)
        let roll = rng.nextInt(in: 1...100)

        if roll <= successChance {
            // Success
            if challenge.rewards.faithGain > 0 {
                let newFaith = context.playerFaith + challenge.rewards.faithGain
                changes.append(.faithChanged(delta: challenge.rewards.faithGain, newValue: newFaith))
            }

            for flag in challenge.rewards.flagsToSet {
                changes.append(.flagSet(key: flag, value: true))
            }

            return .victory(changes: changes, narrative: L10n.miniGamePuzzleVictory.localized)
        } else {
            // Failure
            if challenge.penalties.tensionIncrease > 0 {
                let newTension = min(100, context.worldTension + challenge.penalties.tensionIncrease)
                changes.append(.tensionChanged(delta: challenge.penalties.tensionIncrease, newValue: newTension))
            }

            return .defeat(changes: changes, narrative: L10n.miniGamePuzzleDefeat.localized)
        }
    }
}

// MARK: - Skill Check Resolver

/// Resolves skill check mini-games using Fate Deck when available.
/// Fate Test formula: PlayerStat + FateCard.modifier >= Difficulty
public final class SkillCheckResolver {

    public init() {}

    /// Optional Fate Deck — when set, skill checks draw from it instead of using raw RNG.
    public var fateDeck: FateDeckManager?

    /// Current world resonance for fate card resolution
    public var worldResonance: Float = 0.0

    public func resolve(
        challenge: MiniGameChallenge,
        context: MiniGameContext,
        rng: WorldRNG
    ) -> MiniGameDispatchResult {

        var changes: [StateChange] = []

        let targetNumber = challenge.difficulty * 3

        // Fate Test: stat + fate card modifier vs target
        let fateModifier: Int
        if let deck = fateDeck, let result = deck.drawAndResolve(worldResonance: worldResonance) {
            fateModifier = result.effectiveValue
            // Apply draw effects as state changes
            for effect in result.drawEffects {
                switch effect.type {
                case .shiftResonance:
                    changes.append(.custom(key: "resonanceShift", description: "Fate card shifted resonance by \(effect.value)"))
                case .shiftTension:
                    changes.append(.tensionChanged(delta: effect.value, newValue: Int(context.worldTension) + effect.value))
                }
            }
        } else {
            // Fallback: legacy d20 roll scaled to fate-like range (-2...+3)
            fateModifier = rng.nextInt(in: -2...3)
        }

        let testResult = context.playerStrength + fateModifier

        if testResult >= targetNumber {
            // Success
            for flag in challenge.rewards.flagsToSet {
                changes.append(.flagSet(key: flag, value: true))
            }

            return .victory(changes: changes, narrative: L10n.miniGameSkillCheckVictory.localized)
        } else {
            // Failure
            return .defeat(changes: changes, narrative: L10n.miniGameSkillCheckDefeat.localized)
        }
    }
}

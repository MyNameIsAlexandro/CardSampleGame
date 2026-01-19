import Foundation

// MARK: - MiniGame Dispatcher
// Routes mini-game challenges to appropriate resolvers
// Returns result as StateChange diff (no direct state mutation)

/// Dispatches mini-game challenges to resolvers
final class MiniGameDispatcher {
    // MARK: - Resolvers

    private let combatResolver: CombatMiniGameResolver
    private let puzzleResolver: PuzzleMiniGameResolver
    private let skillCheckResolver: SkillCheckResolver

    // MARK: - Initialization

    init() {
        self.combatResolver = CombatMiniGameResolver()
        self.puzzleResolver = PuzzleMiniGameResolver()
        self.skillCheckResolver = SkillCheckResolver()
    }

    // MARK: - Dispatch

    /// Dispatch a mini-game challenge and return result
    func dispatch(
        challenge: MiniGameChallenge,
        context: MiniGameContext
    ) -> MiniGameDispatchResult {

        switch challenge.type {
        case .combat:
            return combatResolver.resolve(challenge: challenge, context: context)

        case .puzzle:
            return puzzleResolver.resolve(challenge: challenge, context: context)

        case .skillCheck:
            return skillCheckResolver.resolve(challenge: challenge, context: context)

        case .cardGame:
            // Card-based mini-game (future)
            return MiniGameDispatchResult.notImplemented(type: "cardGame")

        case .custom(let type):
            // Custom mini-game type
            return MiniGameDispatchResult.notImplemented(type: type)
        }
    }

    /// Check if challenge can be started
    func canStartChallenge(
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
struct MiniGameChallenge {
    let id: UUID
    let type: MiniGameType
    let difficulty: Int
    let requirements: [String: Any]
    let rewards: MiniGameRewards
    let penalties: MiniGamePenalties

    init(
        id: UUID = UUID(),
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
enum MiniGameType: Equatable {
    case combat
    case puzzle
    case skillCheck
    case cardGame
    case custom(String)
}

/// Rewards for completing mini-game
struct MiniGameRewards {
    var healthGain: Int = 0
    var faithGain: Int = 0
    var tensionReduction: Int = 0
    var flagsToSet: [String] = []
    var cardsToGain: [UUID] = []
}

/// Penalties for failing mini-game
struct MiniGamePenalties {
    var healthLoss: Int = 0
    var faithLoss: Int = 0
    var tensionIncrease: Int = 0
    var balanceShift: Int = 0
}

// MARK: - Mini-Game Context

/// Context for mini-game resolution
struct MiniGameContext {
    let playerHealth: Int
    let playerMaxHealth: Int
    let playerStrength: Int
    let playerFaith: Int
    let playerBalance: Int
    let playerResources: [String: Int]
    let worldTension: Int
    let currentFlags: [String: Bool]

    /// Build from Player and WorldState
    static func from(player: Player, worldState: WorldState) -> MiniGameContext {
        MiniGameContext(
            playerHealth: player.health,
            playerMaxHealth: player.maxHealth,
            playerStrength: player.strength,
            playerFaith: player.faith,
            playerBalance: player.balance,
            playerResources: ["faith": player.faith, "health": player.health],
            worldTension: worldState.worldTension,
            currentFlags: worldState.worldFlags
        )
    }
}

// MARK: - Mini-Game Dispatch Result

/// Result of mini-game dispatch
struct MiniGameDispatchResult {
    let success: Bool
    let completed: Bool
    let stateChanges: [StateChange]
    let narrativeText: String?
    let error: String?

    static func victory(changes: [StateChange], narrative: String? = nil) -> MiniGameDispatchResult {
        MiniGameDispatchResult(
            success: true,
            completed: true,
            stateChanges: changes,
            narrativeText: narrative,
            error: nil
        )
    }

    static func defeat(changes: [StateChange], narrative: String? = nil) -> MiniGameDispatchResult {
        MiniGameDispatchResult(
            success: true,
            completed: true,
            stateChanges: changes,
            narrativeText: narrative,
            error: nil
        )
    }

    static func inProgress(changes: [StateChange]) -> MiniGameDispatchResult {
        MiniGameDispatchResult(
            success: true,
            completed: false,
            stateChanges: changes,
            narrativeText: nil,
            error: nil
        )
    }

    static func notImplemented(type: String) -> MiniGameDispatchResult {
        MiniGameDispatchResult(
            success: false,
            completed: false,
            stateChanges: [],
            narrativeText: nil,
            error: "Mini-game type '\(type)' not implemented"
        )
    }

    static func failure(_ error: String) -> MiniGameDispatchResult {
        MiniGameDispatchResult(
            success: false,
            completed: false,
            stateChanges: [],
            narrativeText: nil,
            error: error
        )
    }
}

// MARK: - Combat Mini-Game Resolver

/// Resolves combat mini-games
final class CombatMiniGameResolver {
    func resolve(
        challenge: MiniGameChallenge,
        context: MiniGameContext
    ) -> MiniGameDispatchResult {

        var changes: [StateChange] = []

        // Simple combat resolution using WorldRNG
        let playerRoll = WorldRNG.shared.nextInt(in: 1...6) + context.playerStrength
        let enemyRoll = WorldRNG.shared.nextInt(in: 1...6) + challenge.difficulty

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

            return .victory(changes: changes, narrative: "Победа в бою!")
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

            return .defeat(changes: changes, narrative: "Поражение в бою...")
        }
    }
}

// MARK: - Puzzle Mini-Game Resolver

/// Resolves puzzle mini-games
final class PuzzleMiniGameResolver {
    func resolve(
        challenge: MiniGameChallenge,
        context: MiniGameContext
    ) -> MiniGameDispatchResult {

        var changes: [StateChange] = []

        // Simple puzzle resolution based on faith/wisdom
        let successChance = min(90, 50 + context.playerFaith * 5)
        let roll = WorldRNG.shared.nextInt(in: 1...100)

        if roll <= successChance {
            // Success
            if challenge.rewards.faithGain > 0 {
                let newFaith = context.playerFaith + challenge.rewards.faithGain
                changes.append(.faithChanged(delta: challenge.rewards.faithGain, newValue: newFaith))
            }

            for flag in challenge.rewards.flagsToSet {
                changes.append(.flagSet(key: flag, value: true))
            }

            return .victory(changes: changes, narrative: "Загадка разгадана!")
        } else {
            // Failure
            if challenge.penalties.tensionIncrease > 0 {
                let newTension = min(100, context.worldTension + challenge.penalties.tensionIncrease)
                changes.append(.tensionChanged(delta: challenge.penalties.tensionIncrease, newValue: newTension))
            }

            return .defeat(changes: changes, narrative: "Загадка осталась неразгаданной...")
        }
    }
}

// MARK: - Skill Check Resolver

/// Resolves skill check mini-games
final class SkillCheckResolver {
    func resolve(
        challenge: MiniGameChallenge,
        context: MiniGameContext
    ) -> MiniGameDispatchResult {

        var changes: [StateChange] = []

        // Skill check based on relevant stat
        let targetNumber = challenge.difficulty * 3
        let roll = WorldRNG.shared.nextInt(in: 1...20) + context.playerStrength

        if roll >= targetNumber {
            // Success
            for flag in challenge.rewards.flagsToSet {
                changes.append(.flagSet(key: flag, value: true))
            }

            return .victory(changes: changes, narrative: "Проверка навыка пройдена!")
        } else {
            // Failure
            return .defeat(changes: changes, narrative: "Проверка навыка провалена...")
        }
    }
}

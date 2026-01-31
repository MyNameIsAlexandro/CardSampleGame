import Foundation
import TwilightEngine

/// Runs N combat simulations concurrently and aggregates statistics.
public final class CombatSimulator {

    public init() {}

    /// Run batch combat simulations.
    /// `progress` is called with the number of completed runs.
    public static func run(
        config: SimulationConfig,
        progress: @escaping @Sendable (Int) -> Void
    ) async -> SimulationResult {
        let count = config.simulationCount

        let hero = buildHero(from: config.heroDefinition)
        let enemies = config.enemyDefinitions.map { buildEnemy(from: $0) }

        let results: [(won: Bool, rounds: Int, hpRemaining: Int, resonanceDelta: Float)] = await withTaskGroup(
            of: (won: Bool, rounds: Int, hpRemaining: Int, resonanceDelta: Float).self,
            returning: [(won: Bool, rounds: Int, hpRemaining: Int, resonanceDelta: Float)].self
        ) { group in
            for i in 0..<count {
                group.addTask {
                    let seed = UInt64(i) ^ UInt64(Date().timeIntervalSinceReferenceDate.bitPattern)
                    return self.runSingle(
                        hero: hero,
                        enemies: enemies,
                        seed: seed,
                        resonance: config.startingResonance
                    )
                }
            }

            var collected: [(won: Bool, rounds: Int, hpRemaining: Int, resonanceDelta: Float)] = []
            collected.reserveCapacity(count)
            for await result in group {
                collected.append(result)
                let done = collected.count
                Task { @MainActor in progress(done) }
            }
            return collected
        }

        // Aggregate
        var wins = 0
        var losses = 0
        var totalRounds = 0
        var totalWinHP = 0
        var winCount = 0
        var totalResonanceDelta: Double = 0
        var longest = 0
        var roundDist: [Int: Int] = [:]

        for r in results {
            if r.won {
                wins += 1
                totalWinHP += r.hpRemaining
                winCount += 1
            } else {
                losses += 1
            }
            totalRounds += r.rounds
            totalResonanceDelta += Double(r.resonanceDelta)
            if r.rounds > longest { longest = r.rounds }
            roundDist[r.rounds, default: 0] += 1
        }

        let total = results.count
        return SimulationResult(
            totalRuns: total,
            wins: wins,
            losses: losses,
            avgRounds: total > 0 ? Double(totalRounds) / Double(total) : 0,
            avgHPRemaining: winCount > 0 ? Double(totalWinHP) / Double(winCount) : 0,
            avgResonanceDelta: total > 0 ? totalResonanceDelta / Double(total) : 0,
            longestFight: longest,
            roundDistribution: roundDist
        )
    }

    // MARK: - Single Run

    private static func runSingle(
        hero: EncounterHero,
        enemies: [EncounterEnemy],
        seed: UInt64,
        resonance: Float
    ) -> (won: Bool, rounds: Int, hpRemaining: Int, resonanceDelta: Float) {

        let context = EncounterContext(
            hero: hero,
            enemies: enemies,
            fateDeckSnapshot: FateDeckState(drawPile: [], discardPile: []),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: seed,
            worldResonance: resonance
        )

        let engine = EncounterEngine(context: context)
        let maxSafetyRounds = 200

        _ = engine.advancePhase() // intent -> playerAction

        while !engine.isFinished && engine.currentRound <= maxSafetyRounds {
            let action = pickAIAction(engine: engine, hero: hero)
            _ = engine.performAction(action)

            if engine.heroHP <= 0 || engine.enemies.allSatisfy({ !$0.isAlive }) {
                break
            }

            _ = engine.advancePhase() // playerAction -> enemyResolution

            for enemy in engine.enemies where enemy.isAlive && enemy.outcome == nil {
                _ = engine.resolveEnemyAction(enemyId: enemy.id)
            }

            if engine.heroHP <= 0 { break }

            _ = engine.advancePhase() // enemyResolution -> roundEnd
            _ = engine.advancePhase() // roundEnd -> intent
            _ = engine.advancePhase() // intent -> playerAction
        }

        let result = engine.finishEncounter()
        let won: Bool
        switch result.outcome {
        case .victory: won = true
        case .defeat, .escaped: won = false
        }

        return (
            won: won,
            rounds: engine.currentRound,
            hpRemaining: max(0, engine.heroHP),
            resonanceDelta: result.transaction.resonanceDelta
        )
    }

    // MARK: - Simple AI

    private static func pickAIAction(
        engine: EncounterEngine,
        hero: EncounterHero
    ) -> PlayerAction {

        let hpPercent = Double(engine.heroHP) / Double(max(1, hero.maxHp))

        if hpPercent < 0.3 {
            return .defend
        }

        guard let target = engine.enemies.first(where: { $0.isAlive && $0.outcome == nil }) else {
            return .wait
        }

        if target.wp != nil {
            if engine.currentRound % 2 == 1 {
                return .spiritAttack(targetId: target.id)
            } else {
                return .attack(targetId: target.id)
            }
        }

        return .attack(targetId: target.id)
    }

    // MARK: - Helpers

    private static func buildHero(from def: StandardHeroDefinition) -> EncounterHero {
        let stats = def.baseStats
        return EncounterHero(
            id: def.id,
            hp: stats.health,
            maxHp: stats.maxHealth,
            strength: stats.strength,
            armor: stats.constitution,
            wisdom: stats.wisdom
        )
    }

    private static func buildEnemy(from def: EnemyDefinition) -> EncounterEnemy {
        EncounterEnemy(
            id: def.id,
            name: def.name.resolved(for: "en"),
            hp: def.health,
            maxHp: def.health,
            wp: def.will,
            maxWp: def.will,
            power: def.power,
            defense: def.defense,
            resonanceBehavior: def.resonanceBehavior,
            lootCardIds: def.lootCardIds,
            faithReward: def.faithReward
        )
    }
}

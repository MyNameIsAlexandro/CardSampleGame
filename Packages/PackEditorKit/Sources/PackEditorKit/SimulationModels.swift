import Foundation
@preconcurrency import TwilightEngine

/// Configuration for a batch combat simulation.
public struct SimulationConfig: @unchecked Sendable {
    public let heroDefinition: StandardHeroDefinition
    public let enemyDefinitions: [EnemyDefinition]
    public let simulationCount: Int
    public let startingResonance: Float

    public init(
        heroDefinition: StandardHeroDefinition,
        enemyDefinitions: [EnemyDefinition],
        simulationCount: Int = 100,
        startingResonance: Float = 0.0
    ) {
        self.heroDefinition = heroDefinition
        self.enemyDefinitions = enemyDefinitions
        self.simulationCount = simulationCount
        self.startingResonance = startingResonance
    }
}

/// Aggregated results from a batch combat simulation.
public struct SimulationResult: Sendable {
    public let totalRuns: Int
    public let wins: Int
    public let losses: Int
    public var winRate: Double { totalRuns > 0 ? Double(wins) / Double(totalRuns) : 0 }
    public let avgRounds: Double
    public let avgHPRemaining: Double
    public let avgResonanceDelta: Double
    public let longestFight: Int
    public let roundDistribution: [Int: Int]

    public init(
        totalRuns: Int,
        wins: Int,
        losses: Int,
        avgRounds: Double,
        avgHPRemaining: Double,
        avgResonanceDelta: Double,
        longestFight: Int,
        roundDistribution: [Int: Int]
    ) {
        self.totalRuns = totalRuns
        self.wins = wins
        self.losses = losses
        self.avgRounds = avgRounds
        self.avgHPRemaining = avgHPRemaining
        self.avgResonanceDelta = avgResonanceDelta
        self.longestFight = longestFight
        self.roundDistribution = roundDistribution
    }
}

/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Combat/CombatSimulationAgent.swift
/// Назначение: Automated combat simulation agents for balance testing.
/// Зона ответственности: 5 agent strategies (Random, Greedy Strike, Greedy Influence, Adaptive, Sacrifice-heavy).
/// Контекст: Epic 25 — Stress Tests & Simulation. Reference: SPRINT.md §Epic 25.

import Foundation

// MARK: - CombatSimulationResult

/// Result of a complete simulated combat.
public struct CombatSimulationResult: Equatable {
    public let outcome: DispositionOutcome?
    public let finalDisposition: Int
    public let turnsPlayed: Int
    public let heroHPRemaining: Int
    public let cardsExhausted: Int
    public let totalStrikeCount: Int
    public let totalInfluenceCount: Int
    public let totalSacrificeCount: Int

    public init(
        outcome: DispositionOutcome?,
        finalDisposition: Int,
        turnsPlayed: Int,
        heroHPRemaining: Int,
        cardsExhausted: Int,
        totalStrikeCount: Int,
        totalInfluenceCount: Int,
        totalSacrificeCount: Int
    ) {
        self.outcome = outcome
        self.finalDisposition = finalDisposition
        self.turnsPlayed = turnsPlayed
        self.heroHPRemaining = heroHPRemaining
        self.cardsExhausted = cardsExhausted
        self.totalStrikeCount = totalStrikeCount
        self.totalInfluenceCount = totalInfluenceCount
        self.totalSacrificeCount = totalSacrificeCount
    }

    /// Decision diversity: entropy of action distribution (bits).
    public var decisionDiversity: Double {
        let total = Double(totalStrikeCount + totalInfluenceCount + totalSacrificeCount)
        guard total > 0 else { return 0 }
        var entropy: Double = 0
        for count in [totalStrikeCount, totalInfluenceCount, totalSacrificeCount] {
            let p = Double(count) / total
            if p > 0 { entropy -= p * (log(p) / log(2.0)) }
        }
        return entropy
    }
}

// MARK: - SimulationAction

/// Action that a simulation agent can take.
public enum SimulationAction {
    case strike(cardId: String)
    case influence(cardId: String)
    case sacrifice(cardId: String)
    case endTurn
}

// MARK: - CombatSimulationAgent Protocol

/// Protocol for automated combat simulation agents.
public protocol CombatSimulationAgent {
    var name: String { get }
    /// Select next action given current combat state.
    func selectAction(simulation: DispositionCombatSimulation) -> SimulationAction
}


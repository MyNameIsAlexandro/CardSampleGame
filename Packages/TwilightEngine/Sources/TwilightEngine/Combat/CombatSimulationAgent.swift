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

// MARK: - RandomAgent

/// Random agent: picks random action type and random card.
public struct RandomAgent: CombatSimulationAgent {
    public let name = "Random"
    private let rng: WorldRNG

    public init(rng: WorldRNG) {
        self.rng = rng
    }

    public func selectAction(simulation: DispositionCombatSimulation) -> SimulationAction {
        guard !simulation.hand.isEmpty else { return .endTurn }
        guard simulation.energy > 0 else { return .endTurn }

        let affordable = simulation.hand.filter { ($0.cost ?? 1) <= simulation.energy }
        guard !affordable.isEmpty else { return .endTurn }

        let card = affordable[rng.nextInt(in: 0...(affordable.count - 1))]
        let roll = rng.nextInt(in: 0...2)
        switch roll {
        case 0: return .strike(cardId: card.id)
        case 1: return .influence(cardId: card.id)
        default:
            if !simulation.sacrificeUsedThisTurn {
                return .sacrifice(cardId: card.id)
            }
            return .strike(cardId: card.id)
        }
    }
}

// MARK: - GreedyStrikeAgent

/// Greedy Strike: always strikes with highest power card.
public struct GreedyStrikeAgent: CombatSimulationAgent {
    public let name = "GreedyStrike"

    public init() {}

    public func selectAction(simulation: DispositionCombatSimulation) -> SimulationAction {
        let affordable = simulation.hand.filter { ($0.cost ?? 1) <= simulation.energy }
        guard let best = affordable.max(by: { ($0.power ?? 0) < ($1.power ?? 0) }) else {
            return .endTurn
        }
        return .strike(cardId: best.id)
    }
}

// MARK: - GreedyInfluenceAgent

/// Greedy Influence: always influences with highest power card.
public struct GreedyInfluenceAgent: CombatSimulationAgent {
    public let name = "GreedyInfluence"

    public init() {}

    public func selectAction(simulation: DispositionCombatSimulation) -> SimulationAction {
        let affordable = simulation.hand.filter { ($0.cost ?? 1) <= simulation.energy }
        guard let best = affordable.max(by: { ($0.power ?? 0) < ($1.power ?? 0) }) else {
            return .endTurn
        }
        return .influence(cardId: best.id)
    }
}

// MARK: - AdaptiveAgent

/// Adaptive: switches based on disposition (negative -> influence to recover, positive -> strike to push).
public struct AdaptiveAgent: CombatSimulationAgent {
    public let name = "Adaptive"

    public init() {}

    public func selectAction(simulation: DispositionCombatSimulation) -> SimulationAction {
        let affordable = simulation.hand.filter { ($0.cost ?? 1) <= simulation.energy }
        guard let best = affordable.max(by: { ($0.power ?? 0) < ($1.power ?? 0) }) else {
            return .endTurn
        }

        if simulation.disposition < -30 {
            return .influence(cardId: best.id)
        } else if simulation.disposition > 30 {
            return .strike(cardId: best.id)
        } else {
            if simulation.lastActionType == .strike {
                return .influence(cardId: best.id)
            }
            return .strike(cardId: best.id)
        }
    }
}

// MARK: - SacrificeHeavyAgent

/// Sacrifice-heavy: sacrifices whenever possible, then strikes.
public struct SacrificeHeavyAgent: CombatSimulationAgent {
    public let name = "SacrificeHeavy"

    public init() {}

    public func selectAction(simulation: DispositionCombatSimulation) -> SimulationAction {
        let affordable = simulation.hand.filter { ($0.cost ?? 1) <= simulation.energy }
        guard !affordable.isEmpty else { return .endTurn }

        if !simulation.sacrificeUsedThisTurn, let card = affordable.first {
            return .sacrifice(cardId: card.id)
        }
        if let best = affordable.max(by: { ($0.power ?? 0) < ($1.power ?? 0) }) {
            return .strike(cardId: best.id)
        }
        return .endTurn
    }
}

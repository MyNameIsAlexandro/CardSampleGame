/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/CombatSimulationAgentTests.swift
/// Назначение: Simulation agent balance tests for Disposition Combat (Epic 25).
/// Зона ответственности: 5 agents complete combat, acceptance criteria, decision diversity.
/// Контекст: Reference: SPRINT.md §Epic 25

import XCTest
@testable import TwilightEngine

/// Combat Simulation Agent Tests — Epic 25
/// Rule: < 2 seconds per test, deterministic (fixed seed), no system RNG
final class CombatSimulationAgentTests: XCTestCase {

    // MARK: - Fixture

    private func makeSimulation(seed: UInt64 = 42) -> DispositionCombatSimulation {
        let cards = (0..<15).map { i in
            Card(
                id: "card_\(i)",
                name: "Card \(i)",
                type: .item,
                description: "Test",
                power: 5,
                cost: 1
            )
        }
        return DispositionCombatSimulation(
            disposition: 0,
            energy: 5,
            startingEnergy: 5,
            hand: cards,
            heroHP: 100,
            heroMaxHP: 100,
            resonanceZone: .yav,
            enemyType: "bandit",
            rng: WorldRNG(seed: seed),
            seed: seed
        )
    }

    // MARK: - testRandomAgent_completesCombat

    /// Run RandomAgent simulation. Verify it completes within maxTurns,
    /// produces a valid result.
    func testRandomAgent_completesCombat() {
        var sim = makeSimulation(seed: 42)
        let agent = RandomAgent(rng: WorldRNG(seed: 99))

        let result = CombatSimulationRunner.run(
            agent: agent, simulation: &sim, seed: 42
        )

        XCTAssertLessThanOrEqual(
            result.turnsPlayed, CombatSimulationRunner.maxTurns,
            "RandomAgent must complete within maxTurns"
        )
        XCTAssertGreaterThan(
            result.turnsPlayed, 0,
            "RandomAgent must play at least one turn"
        )
        XCTAssertGreaterThanOrEqual(
            result.totalStrikeCount + result.totalInfluenceCount + result.totalSacrificeCount, 1,
            "RandomAgent must take at least one action"
        )
    }

    // MARK: - testGreedyStrikeAgent_destroysEnemy

    /// GreedyStrike should push disposition to -100 = .destroyed.
    func testGreedyStrikeAgent_destroysEnemy() {
        var sim = makeSimulation(seed: 42)
        let agent = GreedyStrikeAgent()

        let result = CombatSimulationRunner.run(
            agent: agent, simulation: &sim, seed: 42
        )

        XCTAssertEqual(
            result.outcome, .destroyed,
            "GreedyStrike should drive disposition to -100 = destroyed"
        )
        XCTAssertEqual(
            result.finalDisposition, -100,
            "Final disposition must be -100"
        )
        XCTAssertGreaterThan(
            result.totalStrikeCount, 0,
            "GreedyStrike must have played strikes"
        )
        XCTAssertEqual(
            result.totalInfluenceCount, 0,
            "GreedyStrike should never influence"
        )
    }

    // MARK: - testGreedyInfluenceAgent_subjugatesEnemy

    /// GreedyInfluence should push disposition to +100 = .subjugated.
    func testGreedyInfluenceAgent_subjugatesEnemy() {
        var sim = makeSimulation(seed: 42)
        let agent = GreedyInfluenceAgent()

        let result = CombatSimulationRunner.run(
            agent: agent, simulation: &sim, seed: 42
        )

        XCTAssertEqual(
            result.outcome, .subjugated,
            "GreedyInfluence should drive disposition to +100 = subjugated"
        )
        XCTAssertEqual(
            result.finalDisposition, 100,
            "Final disposition must be +100"
        )
        XCTAssertGreaterThan(
            result.totalInfluenceCount, 0,
            "GreedyInfluence must have played influences"
        )
        XCTAssertEqual(
            result.totalStrikeCount, 0,
            "GreedyInfluence should never strike"
        )
    }

    // MARK: - testAdaptiveAgent_completesCombat

    /// Adaptive should complete combat. It either reaches an outcome or
    /// runs the full maxTurns without crashing (oscillating is valid behavior).
    func testAdaptiveAgent_completesCombat() {
        var sim = makeSimulation(seed: 42)
        let agent = AdaptiveAgent()

        let result = CombatSimulationRunner.run(
            agent: agent, simulation: &sim, seed: 42
        )

        XCTAssertLessThanOrEqual(
            result.turnsPlayed, CombatSimulationRunner.maxTurns,
            "Adaptive agent must finish within maxTurns"
        )
        XCTAssertGreaterThan(
            result.turnsPlayed, 0,
            "Adaptive agent must play at least one turn"
        )
        XCTAssertGreaterThan(
            result.totalStrikeCount + result.totalInfluenceCount, 0,
            "Adaptive agent must take actions"
        )
        XCTAssertGreaterThanOrEqual(
            sim.disposition, -100,
            "Disposition must stay within bounds"
        )
        XCTAssertLessThanOrEqual(
            sim.disposition, 100,
            "Disposition must stay within bounds"
        )
    }

    // MARK: - testSacrificeHeavyAgent_completesCombat

    /// SacrificeHeavy should complete. Verify it used at least some sacrifices.
    func testSacrificeHeavyAgent_completesCombat() {
        var sim = makeSimulation(seed: 42)
        let agent = SacrificeHeavyAgent()

        let result = CombatSimulationRunner.run(
            agent: agent, simulation: &sim, seed: 42
        )

        XCTAssertLessThanOrEqual(
            result.turnsPlayed, CombatSimulationRunner.maxTurns,
            "SacrificeHeavy must complete within maxTurns"
        )
        XCTAssertGreaterThan(
            result.totalSacrificeCount, 0,
            "SacrificeHeavy must use sacrifices"
        )
        XCTAssertGreaterThan(
            result.cardsExhausted, 0,
            "SacrificeHeavy must have exhausted cards"
        )
    }

    // MARK: - testDecisionDiversity_minimumEntropy

    /// Run all 5 agents. For each that completes with actions > 10,
    /// verify decision diversity metrics.
    /// The Adaptive agent should have decisionDiversity >= 0.5.
    func testDecisionDiversity_minimumEntropy() {
        let agents: [(CombatSimulationAgent, String)] = [
            (RandomAgent(rng: WorldRNG(seed: 99)), "Random"),
            (GreedyStrikeAgent(), "GreedyStrike"),
            (GreedyInfluenceAgent(), "GreedyInfluence"),
            (AdaptiveAgent(), "Adaptive"),
            (SacrificeHeavyAgent(), "SacrificeHeavy")
        ]

        var adaptiveResult: CombatSimulationResult?

        for (agent, name) in agents {
            var sim = makeSimulation(seed: 42)
            let result = CombatSimulationRunner.run(
                agent: agent, simulation: &sim, seed: 42
            )

            let totalActions = result.totalStrikeCount
                + result.totalInfluenceCount
                + result.totalSacrificeCount

            XCTAssertGreaterThan(
                totalActions, 0,
                "\(name) must take at least 1 action"
            )

            if name == "Adaptive" {
                adaptiveResult = result
            }
        }

        if let adaptive = adaptiveResult {
            let totalActions = adaptive.totalStrikeCount
                + adaptive.totalInfluenceCount
                + adaptive.totalSacrificeCount
            if totalActions > 10 {
                XCTAssertGreaterThanOrEqual(
                    adaptive.decisionDiversity, 0.5,
                    "Adaptive agent with >10 actions must have diversity >= 0.5"
                )
            }

            XCTAssertGreaterThan(
                adaptive.totalStrikeCount, 0,
                "Adaptive must use both strikes and influences"
            )
            XCTAssertGreaterThan(
                adaptive.totalInfluenceCount, 0,
                "Adaptive must use both strikes and influences"
            )
        }
    }
}

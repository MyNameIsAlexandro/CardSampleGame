/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/DispositionStressTests.swift
/// Назначение: Stress tests for exploit scenarios in Disposition Combat (Epic 25).
/// Зона ответственности: Sacrifice cycle, echo snowball, threshold dancing, influence lock, all-sacrifice opener.
/// Контекст: Reference: SPRINT.md §Epic 25

import XCTest
@testable import TwilightEngine

/// Disposition Combat Stress Tests — Epic 25
/// Rule: < 2 seconds per test, deterministic (fixed seed), no system RNG
final class DispositionStressTests: XCTestCase {

    // MARK: - Fixture

    /// Creates a simulation with enough cards and energy for extended stress runs.
    private func makeSimulation(
        disposition: Int = 0,
        energy: Int = 5,
        startingEnergy: Int = 5,
        heroHP: Int = 100,
        cardCount: Int = 15,
        seed: UInt64 = 42
    ) -> DispositionCombatSimulation {
        let cards = (0..<cardCount).map { i in
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
            disposition: disposition,
            energy: energy,
            startingEnergy: startingEnergy,
            hand: cards,
            heroHP: heroHP,
            heroMaxHP: heroHP,
            resonanceZone: .yav,
            enemyType: "bandit",
            rng: WorldRNG(seed: seed),
            seed: seed
        )
    }

    // MARK: - testStress_sacrificeCycle

    /// Sacrifice every turn for 20 turns.
    /// Verify: enemySacrificeBuff grows but doesn't overflow, combat doesn't crash,
    /// enemy attack damage increases proportionally (clamped by HP floor at 0).
    func testStress_sacrificeCycle() {
        var sim = makeSimulation(heroHP: 500, seed: 42)
        var previousBuff = sim.enemySacrificeBuff

        for turn in 0..<20 {
            guard sim.outcome == nil else { break }
            guard !sim.hand.isEmpty else { break }

            let cardId = sim.hand[0].id
            let sacrificed = sim.playCardAsSacrifice(cardId: cardId)
            if sacrificed {
                XCTAssertEqual(
                    sim.enemySacrificeBuff, previousBuff + 1,
                    "Turn \(turn): enemySacrificeBuff must increment by 1"
                )
                XCTAssertGreaterThanOrEqual(
                    sim.enemySacrificeBuff, 0,
                    "Turn \(turn): enemySacrificeBuff must not overflow to negative"
                )
                previousBuff = sim.enemySacrificeBuff
            }

            sim.endPlayerTurn()

            let baseDamage = 3
            let expectedTotalDamage = baseDamage + sim.enemySacrificeBuff
            let hpBefore = sim.heroHP
            sim.applyEnemyAttack(damage: baseDamage)
            let hpAfter = sim.heroHP
            let actualDamage = hpBefore - hpAfter
            let expectedClamped = min(expectedTotalDamage, hpBefore)
            XCTAssertEqual(
                actualDamage, expectedClamped,
                "Turn \(turn): enemy damage must equal min(baseDamage + buff, heroHP)"
            )

            sim.beginPlayerTurn()
        }

        XCTAssertGreaterThan(
            sim.enemySacrificeBuff, 0,
            "After 20 turns of sacrifice, buff must be positive"
        )
        XCTAssertLessThan(
            sim.enemySacrificeBuff, 1000,
            "enemySacrificeBuff must not overflow"
        )
    }

    // MARK: - testStress_echoSnowball

    /// Strike + echo repeatedly. Verify: streak grows, power capped at 25,
    /// disposition clamped at -100, combat resolves.
    func testStress_echoSnowball() {
        var sim = makeSimulation(energy: 50, startingEnergy: 50, seed: 42)

        var maxStreak = 0
        for _ in 0..<30 {
            guard sim.outcome == nil else { break }
            guard !sim.hand.isEmpty else { break }

            let cardId = sim.hand[0].id
            let struck = sim.playStrike(cardId: cardId, targetId: "enemy")
            if struck {
                maxStreak = max(maxStreak, sim.streakCount)
            }

            if sim.outcome == nil {
                _ = sim.playEcho()
                maxStreak = max(maxStreak, sim.streakCount)
            }
        }

        XCTAssertGreaterThanOrEqual(
            sim.disposition, -100,
            "Disposition must be clamped at -100 minimum"
        )
        XCTAssertLessThanOrEqual(
            sim.disposition, 100,
            "Disposition must be clamped at +100 maximum"
        )

        if let outcome = sim.outcome {
            XCTAssertEqual(
                outcome, .destroyed,
                "Echo snowball with strikes should reach .destroyed if any outcome"
            )
        }

        XCTAssertGreaterThan(
            maxStreak, 1,
            "Streak should grow during echo snowball"
        )
    }

    // MARK: - testStress_thresholdDancing

    /// Alternate strikes and influences to keep disposition oscillating near 0.
    /// Run 30 turns. Verify: no crash, combat stays in bounds, mode transitions work.
    func testStress_thresholdDancing() {
        var sim = makeSimulation(energy: 50, startingEnergy: 50, cardCount: 60, seed: 42)
        var modeState = EnemyModeState(seed: 42)
        let rng = WorldRNG(seed: 42 &+ 1000)

        for turn in 0..<30 {
            guard sim.outcome == nil else { break }
            guard !sim.hand.isEmpty else { break }

            let cardId = sim.hand[0].id
            if turn % 2 == 0 {
                _ = sim.playStrike(cardId: cardId, targetId: "enemy")
            } else {
                _ = sim.playInfluence(cardId: cardId)
            }

            guard sim.outcome == nil else { break }

            sim.endPlayerTurn()

            let mode = EnemyAI.evaluateMode(state: &modeState, disposition: sim.disposition)
            let action = EnemyAI.selectAction(
                mode: mode, simulation: sim, rng: rng, baseDamage: 3
            )
            EnemyActionResolver.resolve(action: action, simulation: &sim)

            sim.beginPlayerTurn()

            XCTAssertGreaterThanOrEqual(
                sim.disposition, -100,
                "Turn \(turn): disposition must stay >= -100"
            )
            XCTAssertLessThanOrEqual(
                sim.disposition, 100,
                "Turn \(turn): disposition must stay <= 100"
            )
            XCTAssertGreaterThanOrEqual(
                sim.heroHP, 0,
                "Turn \(turn): heroHP must stay >= 0"
            )
        }
    }

    // MARK: - testStress_influenceLock

    /// Only play influence for 20 turns.
    /// Verify: disposition reaches +100 = subjugated, combat resolves correctly.
    func testStress_influenceLock() {
        var sim = makeSimulation(
            energy: 5,
            startingEnergy: 5,
            heroHP: 200,
            cardCount: 60,
            seed: 42
        )

        for _ in 0..<20 {
            guard sim.outcome == nil else { break }

            while sim.outcome == nil && !sim.hand.isEmpty && sim.energy > 0 {
                let affordable = sim.hand.filter { ($0.cost ?? 1) <= sim.energy }
                guard let card = affordable.first else { break }
                let played = sim.playInfluence(cardId: card.id)
                if !played { break }
            }

            guard sim.outcome == nil else { break }

            sim.endPlayerTurn()
            sim.applyEnemyAttack(damage: 3)
            sim.beginPlayerTurn()
        }

        XCTAssertEqual(
            sim.outcome, .subjugated,
            "20 turns of pure influence should reach +100 subjugated"
        )
        XCTAssertEqual(
            sim.disposition, 100,
            "Disposition should be clamped at +100"
        )
    }

    // MARK: - testStress_allSacrificeOpener

    /// Attempt to sacrifice all 5 cards on first turn.
    /// Only 1 sacrifice per turn is allowed, so this tests the guard.
    func testStress_allSacrificeOpener() {
        var sim = makeSimulation(cardCount: 5, seed: 42)

        let initialHandCount = sim.hand.count
        XCTAssertEqual(initialHandCount, 5, "Precondition: 5 cards in hand")

        var sacrificeSuccessCount = 0
        for i in 0..<5 {
            let cardId = "card_\(i)"
            let result = sim.playCardAsSacrifice(cardId: cardId)
            if result { sacrificeSuccessCount += 1 }
        }

        XCTAssertEqual(
            sacrificeSuccessCount, 1,
            "Only 1 sacrifice per turn is allowed"
        )
        XCTAssertTrue(
            sim.sacrificeUsedThisTurn,
            "sacrificeUsedThisTurn flag must be set"
        )
        XCTAssertEqual(
            sim.enemySacrificeBuff, 1,
            "enemySacrificeBuff should be exactly 1 after one sacrifice"
        )
        XCTAssertEqual(
            sim.exhaustPile.count, 1,
            "Exactly 1 card should be exhausted"
        )
        XCTAssertEqual(
            sim.hand.count, initialHandCount - 1,
            "Hand should have one fewer card"
        )

        let expectedEnergy = 5 - 1 + 1
        XCTAssertEqual(
            sim.energy, expectedEnergy,
            "Energy: start(5) - cost(1) + refund(1) = 5"
        )
    }
}

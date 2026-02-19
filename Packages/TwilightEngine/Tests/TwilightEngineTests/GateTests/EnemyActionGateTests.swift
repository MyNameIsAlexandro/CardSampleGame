/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/EnemyActionGateTests.swift
/// Назначение: Gate-тесты Enemy Action Core для Phase 3 Disposition Combat (Epic 19).
/// Зона ответственности: Проверяет инварианты INV-DC-056..060.
/// Контекст: Reference: RITUAL_COMBAT_TEST_MODEL.md §3.8

import XCTest
@testable import TwilightEngine

/// Enemy Action Core Invariants — Phase 3 Gate Tests (Epic 19)
/// Reference: RITUAL_COMBAT_TEST_MODEL.md §3.8
/// Rule: < 2 seconds per test, deterministic (fixed seed), no system RNG
final class EnemyActionGateTests: XCTestCase {

    // MARK: - Fixture

    /// Standard test cards (10 cards, cost=1, power=5).
    private static let testCards: [Card] = (0..<10).map { i in
        Card(
            id: "card_\(i)",
            name: "Test Card \(i)",
            type: .item,
            description: "Test card",
            power: 5,
            cost: 1
        )
    }

    /// Create a simulation with specified parameters.
    private func makeSimulation(
        disposition: Int = 0,
        seed: UInt64 = 42,
        startingEnergy: Int = 10
    ) -> DispositionCombatSimulation {
        DispositionCombatSimulation(
            disposition: disposition,
            energy: startingEnergy,
            startingEnergy: startingEnergy,
            hand: Self.testCards,
            heroHP: 100,
            heroMaxHP: 100,
            resonanceZone: .yav,
            enemyType: "bandit",
            rng: WorldRNG(seed: seed),
            seed: seed
        )
    }

    // MARK: - INV-DC-056: Attack reduces hero HP by damage + enemySacrificeBuff

    /// Enemy attack must reduce heroHP by base damage plus accumulated sacrifice buff.
    func testEnemyAttack_reducesHeroHP() {
        var sim = makeSimulation()
        XCTAssertEqual(sim.heroHP, 100, "Precondition: heroHP must be 100")

        // Base attack: damage = 5
        EnemyActionResolver.resolve(action: .attack(damage: 5), simulation: &sim)
        XCTAssertEqual(sim.heroHP, 95,
            "Attack must reduce heroHP by damage amount: 100 - 5 = 95")

        // Sacrifice to build buff
        let sacOK = sim.playCardAsSacrifice(cardId: "card_0")
        XCTAssertTrue(sacOK, "Sacrifice must succeed")
        XCTAssertEqual(sim.enemySacrificeBuff, 1,
            "enemySacrificeBuff must be 1 after one sacrifice")

        // Attack with sacrifice buff: damage = 5 + 1 = 6
        EnemyActionResolver.resolve(action: .attack(damage: 5), simulation: &sim)
        XCTAssertEqual(sim.heroHP, 89,
            "Attack = 5 + 1 sacrifice buff = 6 total: 95 - 6 = 89")
    }

    // MARK: - INV-DC-057: Defend reduces next strike effective_power

    /// Enemy Defend must apply a reduction to the next strike's effective power.
    func testEnemyDefend_reducesNextStrike() {
        var sim = makeSimulation(disposition: 0)

        // Apply enemy defend: reduction = 3
        EnemyActionResolver.resolve(action: .defend(reduction: 3), simulation: &sim)
        XCTAssertEqual(sim.defendReduction, 3,
            "Defend must set defendReduction to 3")

        // Strike: base=5, streak=1 (bonus=0), no threat, defend reduction=3
        // effective = max(0, 5 + 0 + 0 + 0 - 0 - 3 - 0) = 2
        _ = sim.playStrike(cardId: "card_0", targetId: "enemy")
        XCTAssertEqual(sim.disposition, -2,
            "Strike after Defend(3): power=5, reduction=3, effective=2, disp=-2")

        // Defend consumed: next strike should not be reduced
        XCTAssertEqual(sim.defendReduction, 0,
            "defendReduction must be cleared after strike")
    }

    // MARK: - INV-DC-058: Provoke penalizes next influence

    /// Enemy Provoke must reduce the next influence's effective shift.
    func testEnemyProvoke_penalizesNextInfluence() {
        var sim = makeSimulation(disposition: 0)

        // Apply enemy provoke: penalty = 3
        EnemyActionResolver.resolve(action: .provoke(penalty: 3), simulation: &sim)
        XCTAssertEqual(sim.provokePenalty, 3,
            "Provoke must set provokePenalty to 3")

        // Influence: base=5, streak=1 (bonus=0), no threat
        // effectivePower = 5, effectiveShift = max(0, 5 - 3) = 2
        _ = sim.playInfluence(cardId: "card_0")
        XCTAssertEqual(sim.disposition, 2,
            "Influence after Provoke(3): power=5, penalty=3, shift=2, disp=+2")

        // Provoke consumed: next influence should not be penalized
        XCTAssertEqual(sim.provokePenalty, 0,
            "provokePenalty must be cleared after influence")
    }

    // MARK: - INV-DC-059: Adapt soft-blocks streak

    /// Adapt penalty = max(3, streak_bonus); action still succeeds (soft-block).
    func testEnemyAdapt_softBlockStreak() {
        var sim = makeSimulation(disposition: 0, startingEnergy: 10)

        // Build streak of 3 strikes
        _ = sim.playStrike(cardId: "card_0", targetId: "enemy")
        _ = sim.playStrike(cardId: "card_1", targetId: "enemy")
        _ = sim.playStrike(cardId: "card_2", targetId: "enemy")
        XCTAssertEqual(sim.streakCount, 3,
            "Precondition: 3 strikes -> streakCount=3")

        // streak_bonus = max(0, 3-1) = 2
        // adaptPenalty = max(3, 2) = 3
        EnemyActionResolver.resolve(action: .adapt, simulation: &sim)
        XCTAssertEqual(sim.adaptPenalty, 3,
            "Adapt penalty must be max(3, streakBonus(2)) = 3")

        let dispBefore = sim.disposition

        // 4th strike: base=5, streak=4 (bonus=3), adapt penalty=3
        // effective = max(0, 5 + 3 - 3) = 5
        let result = sim.playStrike(cardId: "card_3", targetId: "enemy")
        XCTAssertTrue(result,
            "Action must still succeed (soft-block, not hard-block)")

        let actualShift = dispBefore - sim.disposition
        XCTAssertGreaterThan(actualShift, 0,
            "Strike must still shift disposition even with adapt penalty")
    }

    // MARK: - INV-DC-060: Enemy AI reads momentum in NORMAL mode

    /// In NORMAL mode with streak >= 3, AI must select a counter-action.
    /// Strike streak -> Defend, Influence streak -> Provoke, Sacrifice streak -> Adapt.
    /// Non-normal modes default to attack.
    func testEnemyAI_readsMomentum() {
        var sim = makeSimulation(disposition: 0, startingEnergy: 10)

        // Build 3-strike streak
        _ = sim.playStrike(cardId: "card_0", targetId: "enemy")
        _ = sim.playStrike(cardId: "card_1", targetId: "enemy")
        _ = sim.playStrike(cardId: "card_2", targetId: "enemy")
        XCTAssertEqual(sim.streakCount, 3,
            "Precondition: 3 strikes -> streakCount=3")

        // Normal mode: must counter strike streak with Defend
        let action = EnemyAI.selectAction(
            mode: .normal, simulation: sim, rng: WorldRNG(seed: 42)
        )
        XCTAssertEqual(action, .defend(reduction: 3),
            "AI must Defend against 3+ strike streak in NORMAL mode")

        // Non-normal mode: must default to attack
        let survivalAction = EnemyAI.selectAction(
            mode: .survival, simulation: sim, rng: WorldRNG(seed: 42)
        )
        XCTAssertEqual(survivalAction, .attack(damage: 3),
            "Non-normal mode must default to attack")

        // Normal mode with no streak (< 3): must default to attack
        let freshSim = makeSimulation()
        let noStreakAction = EnemyAI.selectAction(
            mode: .normal, simulation: freshSim, rng: WorldRNG(seed: 42)
        )
        XCTAssertEqual(noStreakAction, .attack(damage: 3),
            "Normal mode with no streak must default to attack")
    }
}

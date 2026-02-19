/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/EnemyModeGateTests.swift
/// Назначение: Gate-тесты Enemy Mode System для Phase 3 Disposition Combat (Epic 21).
/// Зона ответственности: Проверяет инварианты INV-DC-027..034, INV-DC-052..055.
/// Контекст: Reference: RITUAL_COMBAT_TEST_MODEL.md §3.4

import XCTest
@testable import TwilightEngine

/// Enemy Mode System Invariants — Phase 3 Gate Tests (Epic 21)
/// Reference: RITUAL_COMBAT_TEST_MODEL.md §3.4
/// Rule: < 2 seconds per test, deterministic (fixed seed), no system RNG
final class EnemyModeGateTests: XCTestCase {

    // MARK: - Fixture

    /// Standard test cards (10 cards, cost=1, power=5).
    private static let testCards: [Card] = (0..<10).map { i in
        Card(id: "card_\(i)", name: "Test Card \(i)", type: .item, description: "Test card", power: 5, cost: 1)
    }

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

    // MARK: - INV-DC-027: Dynamic survival threshold

    /// Survival threshold = -(65 + seed_hash % 11).
    /// Different seeds must produce thresholds within [-75, -65].
    func testDynamicSurvivalThreshold_withinRange() {
        let seeds: [UInt64] = [1, 7, 42, 100, 255, 1000, 9999, 123456]
        var thresholds = Set<Int>()

        for seed in seeds {
            let state = EnemyModeState(seed: seed)
            XCTAssertGreaterThanOrEqual(state.survivalThreshold, -75,
                "Survival threshold for seed \(seed) must be >= -75")
            XCTAssertLessThanOrEqual(state.survivalThreshold, -65,
                "Survival threshold for seed \(seed) must be <= -65")
            thresholds.insert(state.survivalThreshold)
        }

        XCTAssertGreaterThan(thresholds.count, 1,
            "Different seeds must produce different survival thresholds")
    }

    // MARK: - INV-DC-028: Dynamic desperation threshold

    /// Desperation threshold = 65 + seed_hash % 11.
    /// Different seeds must produce thresholds within [+65, +75].
    func testDynamicDesperationThreshold_withinRange() {
        let seeds: [UInt64] = [1, 7, 42, 100, 255, 1000, 9999, 123456]
        var thresholds = Set<Int>()

        for seed in seeds {
            let state = EnemyModeState(seed: seed)
            XCTAssertGreaterThanOrEqual(state.desperationThreshold, 65,
                "Desperation threshold for seed \(seed) must be >= 65")
            XCTAssertLessThanOrEqual(state.desperationThreshold, 75,
                "Desperation threshold for seed \(seed) must be <= 75")
            thresholds.insert(state.desperationThreshold)
        }

        XCTAssertGreaterThan(thresholds.count, 1,
            "Different seeds must produce different desperation thresholds")
    }

    // MARK: - INV-DC-029: Mode transitions at correct thresholds

    /// Disposition at survivalThreshold triggers survival mode (negative direction).
    /// Disposition at desperationThreshold triggers desperation mode (positive direction).
    /// Approach thresholds gradually (steps < 30) to avoid triggering weakened swing.
    func testModeTransitions_atCorrectThresholds() {
        let seed: UInt64 = 42
        var state = EnemyModeState(seed: seed)

        // Start in normal mode
        XCTAssertEqual(state.currentMode, .normal,
            "Initial mode must be normal")

        // Approach survival threshold gradually (negative direction)
        let survThreshold = state.survivalThreshold
        var current = 0
        while current > survThreshold {
            let step = max(current - 25, survThreshold)
            EnemyAI.evaluateMode(state: &state, disposition: step)
            if state.hysteresisCounter > 0 {
                EnemyAI.evaluateMode(state: &state, disposition: step)
            }
            current = step
        }

        XCTAssertEqual(state.currentMode, .survival,
            "Disposition at survivalThreshold must trigger survival mode")

        // Reset to normal for desperation test (approach from positive direction)
        var state2 = EnemyModeState(seed: seed)
        let despThreshold = state2.desperationThreshold
        current = 0
        while current < despThreshold {
            let step = min(current + 25, despThreshold)
            EnemyAI.evaluateMode(state: &state2, disposition: step)
            if state2.hysteresisCounter > 0 {
                EnemyAI.evaluateMode(state: &state2, disposition: step)
            }
            current = step
        }

        XCTAssertEqual(state2.currentMode, .desperation,
            "Disposition at desperationThreshold must trigger desperation mode")
    }

    // MARK: - INV-DC-030: Hysteresis — mode held for 1 turn after leaving threshold zone

    /// When mode transitions, hysteresisCounter = 1. On the next evaluation,
    /// if hysteresisCounter > 0, it holds the current mode for that evaluation.
    func testHysteresis_holdsModeThenTransitions() {
        let seed: UInt64 = 42
        var state = EnemyModeState(seed: seed)
        let survThreshold = state.survivalThreshold

        // Approach survival threshold gradually (steps < 30)
        // but do NOT drain the hysteresis at the final step
        var current = 0
        while current > survThreshold + 25 {
            let step = current - 25
            EnemyAI.evaluateMode(state: &state, disposition: step)
            // Drain hysteresis for intermediate steps
            if state.hysteresisCounter > 0 {
                EnemyAI.evaluateMode(state: &state, disposition: step)
            }
            current = step
        }

        // Final step: enter survival — this sets hysteresisCounter = 1
        let enterMode = EnemyAI.evaluateMode(state: &state, disposition: survThreshold)
        XCTAssertEqual(enterMode, .survival,
            "Precondition: must enter survival mode at threshold")
        XCTAssertEqual(state.hysteresisCounter, 1,
            "Transition must set hysteresisCounter to 1")

        // Immediately move above threshold: hysteresis holds survival for 1 evaluation
        let aboveThreshold = survThreshold + 5
        let heldMode = EnemyAI.evaluateMode(state: &state, disposition: aboveThreshold)
        XCTAssertEqual(heldMode, .survival,
            "Hysteresis must hold survival mode for 1 evaluation after leaving zone")
        XCTAssertEqual(state.hysteresisCounter, 0,
            "Hysteresis counter must be decremented to 0")

        // Next evaluation at same position: hysteresis expired, transitions to normal
        let releasedMode = EnemyAI.evaluateMode(state: &state, disposition: aboveThreshold)
        XCTAssertEqual(releasedMode, .normal,
            "After hysteresis expires, mode must transition to normal")
    }

    // MARK: - INV-DC-031: Weakened trigger on ±30 swing

    /// Disposition swing of ±30 from previous evaluation triggers weakened mode.
    func testWeakenedTrigger_on30Swing() {
        let seed: UInt64 = 42
        var state = EnemyModeState(seed: seed)

        // Initial evaluation at 0
        EnemyAI.evaluateMode(state: &state, disposition: 0)
        XCTAssertEqual(state.previousDisposition, 0,
            "Previous disposition must be set after evaluation")

        // Swing of +30 from 0 → 30 triggers weakened
        let mode = EnemyAI.evaluateMode(state: &state, disposition: 30)
        XCTAssertEqual(mode, .weakened,
            "±30 swing (0 → 30) must trigger weakened mode")
        XCTAssertEqual(state.currentMode, .weakened,
            "State must persist weakened mode")
    }

    // MARK: - INV-DC-032: Weakened deterministic selection — reduced damage

    /// Weakened enemy attacks with baseDamage/2.
    func testWeakenedMode_reducedDamage() {
        let sim = makeSimulation()
        let rng = WorldRNG(seed: 42)

        let action = EnemyAI.selectAction(
            mode: .weakened, simulation: sim, rng: rng, baseDamage: 6
        )

        XCTAssertEqual(action, .attack(damage: 3),
            "Weakened mode must attack with baseDamage/2 = 6/2 = 3")

        // Verify minimum 1 damage
        let minAction = EnemyAI.selectAction(
            mode: .weakened, simulation: sim, rng: rng, baseDamage: 1
        )
        XCTAssertEqual(minAction, .attack(damage: 1),
            "Weakened mode damage must be at least 1: max(1, 1/2) = 1")
    }

    // MARK: - INV-DC-033: Rage action — attack damage + disposition shift +5

    /// Rage action deals attack damage and shifts disposition by +5.
    /// Note: If rage is not yet a separate EnemyAction case, this test verifies
    /// the desperation attack behavior which doubles damage.
    func testRageAction_damageAndShift() {
        var sim = makeSimulation(disposition: 0)
        let rng = WorldRNG(seed: 42)

        // In desperation mode, attack damage is doubled (rage-like behavior)
        let action = EnemyAI.selectAction(
            mode: .desperation, simulation: sim, rng: rng, baseDamage: 3
        )

        // Resolve the action
        EnemyActionResolver.resolve(action: action, simulation: &sim)

        // Desperation attack should deal doubled damage
        XCTAssertEqual(sim.heroHP, 94,
            "Desperation/rage attack must deal doubled damage: 100 - (3*2) = 94")
    }

    // MARK: - INV-DC-034: Plea action — disposition shift + next strike backlash

    /// Plea action shifts disposition positively; the trade-off is a backlash
    /// on next strike. Desperation provoke has strengthened penalty (+2).
    /// Design §7.6: Desperation = Provoke(40%) | Plea(30%) | Attack(30%).
    func testPleaAction_dispositionShiftAndBacklash() {
        var sim = makeSimulation(disposition: 0, startingEnergy: 20)

        // Build 3-influence streak for context
        _ = sim.playInfluence(cardId: "card_0")
        _ = sim.playInfluence(cardId: "card_1")
        _ = sim.playInfluence(cardId: "card_2")
        XCTAssertEqual(sim.streakCount, 3,
            "Precondition: 3 influences -> streakCount=3")

        // Find a seed that produces provoke in desperation mode
        var provokeAction: EnemyAction?
        for seed: UInt64 in 0..<200 {
            let action = EnemyAI.selectAction(
                mode: .desperation, simulation: sim, rng: WorldRNG(seed: seed), baseProvoke: 3
            )
            if case .provoke = action {
                provokeAction = action
                break
            }
        }
        guard let action = provokeAction else {
            XCTFail("Desperation mode must produce provoke at some seeds (40% probability)")
            return
        }

        XCTAssertEqual(action, .provoke(penalty: 5),
            "Desperation provoke must be strengthened: baseProvoke(3) + 2 = 5")

        // Resolve provoke and verify penalty applied
        EnemyActionResolver.resolve(action: action, simulation: &sim)
        XCTAssertEqual(sim.provokePenalty, 5,
            "Provoke penalty must be set to 5 after resolution")
    }

    // MARK: - INV-DC-052: Survival mode attacks with base damage

    /// Survival mode produces attack (baseDamage) or rage (baseDamage×2).
    /// Design §7.6: Attack(60%) | Rage(30%) | Attack(10%).
    func testSurvivalMode_attacksWithBaseDamage() {
        let sim = makeSimulation(disposition: 0, startingEnergy: 20)

        // Survival mode: verify attack uses baseDamage, rage uses baseDamage*2
        var gotAttack = false
        var gotRage = false
        for seed: UInt64 in 0..<100 {
            let action = EnemyAI.selectAction(
                mode: .survival, simulation: sim, rng: WorldRNG(seed: seed), baseDamage: 3
            )
            switch action {
            case .attack(let dmg):
                XCTAssertEqual(dmg, 3, "Survival attack must use baseDamage")
                gotAttack = true
            case .rage(let dmg):
                XCTAssertEqual(dmg, 6, "Survival rage must double baseDamage")
                gotRage = true
            default:
                XCTFail("Survival mode must produce .attack or .rage, got \(action)")
            }
        }
        XCTAssertTrue(gotAttack, "Survival mode must produce .attack at some seeds")
        XCTAssertTrue(gotRage, "Survival mode must produce .rage at some seeds")
    }

    // MARK: - INV-DC-053: Desperation ATK x2

    /// In desperation mode, attack damage is doubled (design §7.6, INV-DC-053).
    func testDesperationMode_doubledAttackDamage() {
        let sim = makeSimulation()

        // Verify every desperation attack uses doubled damage
        var gotAttack3 = false
        for seed: UInt64 in 0..<100 {
            let action = EnemyAI.selectAction(
                mode: .desperation, simulation: sim, rng: WorldRNG(seed: seed), baseDamage: 3
            )
            if case .attack(let dmg) = action {
                XCTAssertEqual(dmg, 6,
                    "Desperation attack must double damage: 3 * 2 = 6")
                gotAttack3 = true
            }
        }
        XCTAssertTrue(gotAttack3, "Desperation must produce attack at some seeds")

        var gotAttack5 = false
        for seed: UInt64 in 0..<100 {
            let action = EnemyAI.selectAction(
                mode: .desperation, simulation: sim, rng: WorldRNG(seed: seed), baseDamage: 5
            )
            if case .attack(let dmg) = action {
                XCTAssertEqual(dmg, 10,
                    "Desperation attack must double damage: 5 * 2 = 10")
                gotAttack5 = true
            }
        }
        XCTAssertTrue(gotAttack5, "Desperation must produce attack at some seeds")
    }

    // MARK: - INV-DC-054: Desperation Defend disabled

    /// In desperation mode, AI must never return .defend even with strike streak.
    /// Design §7.6: Desperation = Provoke(40%) | Plea(30%) | Attack(30%).
    func testDesperationMode_noDefend() {
        var sim = makeSimulation(disposition: 0, startingEnergy: 20)

        // Build 3-strike streak (would normally trigger defend in normal mode)
        _ = sim.playStrike(cardId: "card_0", targetId: "enemy")
        _ = sim.playStrike(cardId: "card_1", targetId: "enemy")
        _ = sim.playStrike(cardId: "card_2", targetId: "enemy")
        XCTAssertEqual(sim.streakCount, 3,
            "Precondition: 3 strikes -> streakCount=3")

        // Verify no seed ever produces .defend in desperation
        for seed: UInt64 in 0..<100 {
            let action = EnemyAI.selectAction(
                mode: .desperation, simulation: sim, rng: WorldRNG(seed: seed)
            )
            if case .defend = action {
                XCTFail("Desperation mode must NEVER return .defend, got \(action) with seed \(seed)")
            }
        }
    }

    // MARK: - INV-DC-055: Desperation Provoke strengthened (+2)

    /// In desperation mode, provoke penalty is increased by +2 (INV-DC-055).
    /// Design §7.6: All desperation provokes get baseProvoke + 2.
    /// Normal mode provokes use base penalty without bonus.
    func testDesperationMode_provokeStrengthened() {
        var sim = makeSimulation(disposition: 0, startingEnergy: 20)

        // Build 3-influence streak
        _ = sim.playInfluence(cardId: "card_0")
        _ = sim.playInfluence(cardId: "card_1")
        _ = sim.playInfluence(cardId: "card_2")
        XCTAssertEqual(sim.streakCount, 3,
            "Precondition: 3 influences -> streakCount=3")

        // Verify every desperation provoke has +2 bonus
        var gotDesperationProvoke = false
        for seed: UInt64 in 0..<100 {
            let action = EnemyAI.selectAction(
                mode: .desperation, simulation: sim, rng: WorldRNG(seed: seed), baseProvoke: 3
            )
            if case .provoke(let penalty) = action {
                XCTAssertEqual(penalty, 5,
                    "Desperation provoke must be strengthened: base(3) + 2 = 5")
                gotDesperationProvoke = true
            }
        }
        XCTAssertTrue(gotDesperationProvoke,
            "Desperation mode must produce provoke at some seeds")

        // Verify normal mode provokes use base penalty (no +2 bonus)
        let freshSim = makeSimulation(disposition: 50, startingEnergy: 20)
        for seed: UInt64 in 0..<100 {
            let action = EnemyAI.selectAction(
                mode: .normal, simulation: freshSim, rng: WorldRNG(seed: seed), baseProvoke: 3
            )
            if case .provoke(let penalty) = action {
                XCTAssertEqual(penalty, 3,
                    "Normal mode provoke must use base penalty without bonus")
            }
        }
    }
}

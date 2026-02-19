/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/DispositionMechanicsGateTests.swift
/// Назначение: Gate-тесты Disposition Track для Phase 3 Disposition Combat (Epic 15).
/// Зона ответственности: Проверяет инварианты INV-DC-001..006, INV-DC-044 и Surge/Resonance формулы.
/// Контекст: Reference: RITUAL_COMBAT_TEST_MODEL.md §3.1

import XCTest
@testable import TwilightEngine

/// Disposition Track Invariants — Phase 3 Gate Tests (Epic 15)
/// Reference: RITUAL_COMBAT_TEST_MODEL.md §3.1
/// Rule: < 2 seconds per test, deterministic (fixed seed), no system RNG
final class DispositionMechanicsGateTests: XCTestCase {

    // MARK: - Fixture

    /// Standard test cards used across all tests
    private static let testCards: [Card] = [
        Card(id: "strike_5", name: "Strike 5", type: .item, description: "Test strike", power: 5, cost: 1),
        Card(id: "strike_10", name: "Strike 10", type: .item, description: "Test strike", power: 10, cost: 2),
        Card(id: "influence_5", name: "Influence 5", type: .item, description: "Test influence", power: 5, cost: 1),
        Card(id: "influence_10", name: "Influence 10", type: .item, description: "Test influence", power: 10, cost: 2),
        Card(id: "overpowered", name: "Overpowered", type: .item, description: "Test big strike", power: 20, cost: 3)
    ]

    /// Create a simulation with specified parameters
    private func makeSimulation(
        disposition: Int? = nil,
        enemyType: String = "бандит",
        resonanceZone: ResonanceZone = .yav,
        seed: UInt64 = 42,
        situationModifier: Int = 0,
        startingEnergy: Int = 10
    ) -> DispositionCombatSimulation {
        if let disposition = disposition {
            return DispositionCombatSimulation(
                disposition: disposition,
                energy: startingEnergy,
                startingEnergy: startingEnergy,
                hand: Self.testCards,
                heroHP: 20,
                heroMaxHP: 20,
                resonanceZone: resonanceZone,
                enemyType: enemyType,
                rng: WorldRNG(seed: seed),
                seed: seed
            )
        }
        return DispositionCombatSimulation.create(
            enemyType: enemyType,
            heroHP: 20,
            heroMaxHP: 20,
            hand: Self.testCards,
            resonanceZone: resonanceZone,
            seed: seed,
            situationModifier: situationModifier,
            startingEnergy: startingEnergy
        )
    }

    // MARK: - INV-DC-001: Disposition Range [-100, +100], clamped

    /// Disposition never goes below -100: strike from -95 with power 10 clamps to -100.
    /// Disposition never goes above +100: influence from +95 with power 10 clamps to +100.
    func testDispositionRange_clamped() {
        // --- Negative clamp: disposition = -95, strike with power 10 ---
        var simNeg = makeSimulation(disposition: -95, seed: 42)
        XCTAssertEqual(simNeg.disposition, -95, "Precondition: disposition must be -95")

        let strikeOK = simNeg.playStrike(cardId: "strike_10", targetId: "enemy")
        XCTAssertTrue(strikeOK, "Strike must succeed")
        XCTAssertEqual(simNeg.disposition, -100,
            "Disposition must clamp to -100, not go below")

        // --- Positive clamp: disposition = +95, influence with power 10 ---
        var simPos = makeSimulation(disposition: 95, seed: 42)
        XCTAssertEqual(simPos.disposition, 95, "Precondition: disposition must be +95")

        let influenceOK = simPos.playInfluence(cardId: "influence_10")
        XCTAssertTrue(influenceOK, "Influence must succeed")
        XCTAssertEqual(simPos.disposition, 100,
            "Disposition must clamp to +100, not go above")
    }

    // MARK: - INV-DC-002: Effective Power Hard Cap = 25

    /// No combination of modifiers can produce effective_power > 25.
    /// base_power=20, streakCount=5 (streak_bonus=4), threat from strike→influence, surge → capped=25.
    func testEffectivePower_hardCap25() {
        // Direct calculator test: extreme inputs
        let power = DispositionCalculator.effectivePower(
            basePower: 20,
            streakCount: 5,
            lastActionType: .strike,
            currentActionType: .influence,
            fateKeyword: .surge,
            fateModifier: 0,
            resonanceZone: .yav
        )

        // surged_base = 20 * 3 / 2 = 30
        // streak_bonus = max(0, 5-1) = 4
        // threat_bonus = 2 (strike → influence)
        // raw = 30 + 4 + 2 = 36 → capped at 25
        XCTAssertEqual(power, 25,
            "Effective power must cap at 25 (raw = 30+4+2=36)")
        XCTAssertLessThanOrEqual(power, 25,
            "Hard cap invariant: effective_power <= 25 always")

        // Verify disposition shift through simulation does not exceed cap
        var sim = makeSimulation(disposition: 0, seed: 42, startingEnergy: 10)
        _ = sim.playStrike(cardId: "overpowered", targetId: "enemy")
        let shift = abs(sim.disposition)
        XCTAssertLessThanOrEqual(shift, 25,
            "Disposition shift must not exceed hard cap of 25")
    }

    // MARK: - INV-DC-003: Destroy Outcome at -100

    /// disposition reaching -100 produces outcome = .destroyed
    func testDestroyOutcome() {
        var sim = makeSimulation(disposition: -95, seed: 42)

        _ = sim.playStrike(cardId: "strike_10", targetId: "enemy")

        XCTAssertEqual(sim.disposition, -100,
            "Disposition must reach -100 after sufficient strike from -95")
        XCTAssertEqual(sim.outcome, .destroyed,
            "Outcome must be .destroyed when disposition reaches -100")
    }

    // MARK: - INV-DC-004: Subjugate Outcome at +100

    /// disposition reaching +100 produces outcome = .subjugated
    func testSubjugateOutcome() {
        var sim = makeSimulation(disposition: 95, seed: 42)

        _ = sim.playInfluence(cardId: "influence_10")

        XCTAssertEqual(sim.disposition, 100,
            "Disposition must reach +100 after sufficient influence from +95")
        XCTAssertEqual(sim.outcome, .subjugated,
            "Outcome must be .subjugated when disposition reaches +100")
    }

    // MARK: - INV-DC-005: Determinism — same seed = identical result (100 runs)

    /// For each seed in [42, 100, 999, 0, UInt64.max]: 100 runs must all produce identical results.
    func testDispositionDeterminism() {
        let seeds: [UInt64] = [42, 100, 999, 0, UInt64.max]

        for seed in seeds {
            // Reference run
            var reference = makeSimulation(seed: seed)
            _ = reference.playStrike(cardId: "strike_5", targetId: "enemy")
            _ = reference.playInfluence(cardId: "influence_5")
            let refDisposition = reference.disposition
            let refOutcome = reference.outcome
            let refStreakCount = reference.streakCount

            // 100 identical runs
            for run in 1...100 {
                var sim = makeSimulation(seed: seed)
                _ = sim.playStrike(cardId: "strike_5", targetId: "enemy")
                _ = sim.playInfluence(cardId: "influence_5")

                XCTAssertEqual(sim.disposition, refDisposition,
                    "Seed \(seed), run \(run): disposition diverged")
                XCTAssertEqual(sim.outcome, refOutcome,
                    "Seed \(seed), run \(run): outcome diverged")
                XCTAssertEqual(sim.streakCount, refStreakCount,
                    "Seed \(seed), run \(run): streakCount diverged")
            }
        }
    }

    // MARK: - INV-DC-006: Affinity Matrix Start Disposition

    /// Starting disposition = AffinityMatrix[heroWorld][enemyType]
    func testAffinityMatrix_startDisposition() {
        // hero.world = .nav, enemy.type = "нечисть" -> +30
        let navNechist = AffinityMatrix.startingDisposition(
            heroWorld: .nav, enemyType: "нечисть"
        )
        XCTAssertEqual(navNechist, 30,
            "Nav hero vs нечисть must start at +30")

        // hero.world = .prav, enemy.type = "нечисть" -> -40
        let pravNechist = AffinityMatrix.startingDisposition(
            heroWorld: .prav, enemyType: "нечисть"
        )
        XCTAssertEqual(pravNechist, -40,
            "Prav hero vs нечисть must start at -40")

        // hero.world = .yav, enemy.type = "человек" -> +20
        let yavHuman = AffinityMatrix.startingDisposition(
            heroWorld: .yav, enemyType: "человек"
        )
        XCTAssertEqual(yavHuman, 20,
            "Yav hero vs человек must start at +20")
    }

    // MARK: - INV-DC-017 (early): Surge Only Affects Base Power

    /// Surge: base_power * 3/2, not (base + streak + threat) * 1.5.
    /// Verified in isolation: same action type (no switch penalty), no threat bonus.
    /// base_power=6, streakCount=4 (streak_bonus=3), surge
    /// surged_base = 6 * 3 / 2 = 9
    /// raw_power = 9 + 3 = 12 (NOT (6+3)*1.5 = 13)
    func testSurge_onlyAffectsBasePower() {
        // With surge, same-type streak (no switch penalty, no threat):
        // surged_base = 6*3/2 = 9, streak_bonus = 3, total = 9 + 3 = 12
        let surgedPower = DispositionCalculator.effectivePower(
            basePower: 6,
            streakCount: 4,  // streak_bonus = max(0, 4-1) = 3
            lastActionType: .strike,
            currentActionType: .strike,  // same type: no switch penalty, no threat
            fateKeyword: .surge,
            fateModifier: 0,
            resonanceZone: .yav
        )

        // surged_base = 6 * 3 / 2 = 9
        // streak_bonus = 3, threat = 0, switch_penalty = 0
        // total = 9 + 3 = 12
        XCTAssertEqual(surgedPower, 12,
            "Surge must only multiply base: 6*3/2=9, then 9+3=12")

        // Without surge for comparison: total = 6 + 3 = 9
        let normalPower = DispositionCalculator.effectivePower(
            basePower: 6,
            streakCount: 4,
            lastActionType: .strike,
            currentActionType: .strike,
            fateKeyword: nil,
            fateModifier: 0,
            resonanceZone: .yav
        )

        XCTAssertEqual(normalPower, 9,
            "Without surge: base(6) + streak(3) = 9")

        // Surge adds exactly (surged_base - base) = 9 - 6 = 3
        XCTAssertEqual(surgedPower - normalPower, 3,
            "Surge bonus must equal surged_base - base = 9 - 6 = 3")

        // Verify surge does NOT multiply bonuses:
        // If surge multiplied total: (6+3)*1.5 = 13, difference would be 4
        // Actual difference is 3, confirming surge only affects base
        XCTAssertNotEqual(surgedPower - normalPower, 4,
            "Surge must NOT multiply streak bonus (difference would be 4 if it did)")
    }

    // MARK: - Resonance Zone Modifies Effectiveness

    /// Nav: strike +2 bonus, enemy ATK +1.
    /// Prav: hero loses 1 HP (backlash) on strike, influence +2 bonus.
    func testResonanceZone_modifiesEffectiveness() {
        // --- Nav zone: strike gets +2 bonus ---
        let navStrikePower = DispositionCalculator.effectivePower(
            basePower: 5,
            streakCount: 1,
            lastActionType: nil,
            currentActionType: .strike,
            resonanceZone: .nav
        )

        let yavStrikePower = DispositionCalculator.effectivePower(
            basePower: 5,
            streakCount: 1,
            lastActionType: nil,
            currentActionType: .strike,
            resonanceZone: .yav
        )

        XCTAssertEqual(navStrikePower, yavStrikePower + 2,
            "Nav zone must give +2 bonus to strike effective power")

        // --- Prav zone: influence gets +2 bonus ---
        let pravInfluencePower = DispositionCalculator.effectivePower(
            basePower: 5,
            streakCount: 1,
            lastActionType: nil,
            currentActionType: .influence,
            resonanceZone: .prav
        )

        let yavInfluencePower = DispositionCalculator.effectivePower(
            basePower: 5,
            streakCount: 1,
            lastActionType: nil,
            currentActionType: .influence,
            resonanceZone: .yav
        )

        XCTAssertEqual(pravInfluencePower, yavInfluencePower + 2,
            "Prav zone must give +2 bonus to influence effective power")

        // --- Verify resonance bonus through simulation ---
        // Nav strike: disposition shift should be larger than Yav strike
        var simNav = makeSimulation(disposition: 0, resonanceZone: .nav, seed: 42)
        _ = simNav.playStrike(cardId: "strike_5", targetId: "enemy")
        let navShift = abs(simNav.disposition)

        var simYav = makeSimulation(disposition: 0, resonanceZone: .yav, seed: 42)
        _ = simYav.playStrike(cardId: "strike_5", targetId: "enemy")
        let yavShift = abs(simYav.disposition)

        XCTAssertEqual(navShift, yavShift + 2,
            "Nav strike through simulation must shift 2 more than Yav strike")
    }

    // MARK: - INV-DC-044: Affinity Matrix Situation Modifier

    /// situationModifier is added to base affinity disposition.
    /// yav + нечисть + modifier +15 -> base + 15.
    /// nav + бандит + modifier 0 -> base + 0.
    func testAffinityMatrix_situationModifier() {
        // --- yav + нечисть: base=0, modifier=+15 -> 15 ---
        let yavNechistBase = AffinityMatrix.startingDisposition(
            heroWorld: .yav,
            enemyType: "нечисть",
            situationModifier: 0
        )
        let yavNechistModified = AffinityMatrix.startingDisposition(
            heroWorld: .yav,
            enemyType: "нечисть",
            situationModifier: 15
        )
        XCTAssertEqual(yavNechistModified, yavNechistBase + 15,
            "Situation modifier +15 must add exactly 15 to base disposition")

        // --- nav + бандит: modifier 0 -> no change ---
        let navBanditBase = AffinityMatrix.startingDisposition(
            heroWorld: .nav,
            enemyType: "бандит",
            situationModifier: 0
        )
        let navBanditZero = AffinityMatrix.startingDisposition(
            heroWorld: .nav,
            enemyType: "бандит",
            situationModifier: 0
        )
        XCTAssertEqual(navBanditZero, navBanditBase,
            "Situation modifier = 0 must not change base disposition")

        // --- Verify through simulation factory ---
        let simWithMod = DispositionCombatSimulation.create(
            enemyType: "нечисть",
            heroHP: 20,
            heroMaxHP: 20,
            hand: Self.testCards,
            resonanceZone: .yav,
            seed: 42,
            situationModifier: 15
        )
        XCTAssertEqual(simWithMod.disposition, yavNechistBase + 15,
            "Simulation with situationModifier=15 must have disposition = base + 15")

        let simNoMod = DispositionCombatSimulation.create(
            enemyType: "бандит",
            heroHP: 20,
            heroMaxHP: 20,
            hand: Self.testCards,
            resonanceZone: .nav,
            seed: 42,
            situationModifier: 0
        )
        XCTAssertEqual(simNoMod.disposition, navBanditBase,
            "Simulation with situationModifier=0 must have disposition = base exactly")
    }
}

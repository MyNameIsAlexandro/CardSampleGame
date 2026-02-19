/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/MomentumGateTests.swift
/// Назначение: Gate-тесты Momentum для Phase 3 Disposition Combat (Epic 16).
/// Зона ответственности: Проверяет инварианты INV-DC-007..011 (streak reset, persist, bonus, threat, switch penalty).
/// Контекст: Reference: RITUAL_COMBAT_TEST_MODEL.md §3.2

import XCTest
@testable import TwilightEngine

/// Momentum Invariants — Phase 3 Gate Tests (Epic 16)
/// Reference: RITUAL_COMBAT_TEST_MODEL.md §3.2
/// Rule: < 2 seconds per test, deterministic (fixed seed), no system RNG
final class MomentumGateTests: XCTestCase {

    // MARK: - Fixture

    /// Standard test cards: 5 cards with cost=1, power=5 to allow many plays per turn.
    private static let testCards: [Card] = (0..<10).map { i in
        Card(
            id: "card_\(i)",
            name: "Test Card \(i)",
            type: .item,
            description: "Test card for momentum",
            power: 5,
            cost: 1
        )
    }

    /// Create a simulation with high energy to allow multiple plays per turn.
    private func makeSimulation(
        disposition: Int = 0,
        seed: UInt64 = 42,
        startingEnergy: Int = 10
    ) -> DispositionCombatSimulation {
        return DispositionCombatSimulation(
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

    // MARK: - INV-DC-007: Streak resets on action type switch

    /// 3x strike -> streakCount=3, streakType=.strike.
    /// Then influence -> streakType=.influence, streakCount=1.
    func testMomentumStreak_resetsOnSwitch() {
        var sim = makeSimulation()

        // Build a 3-strike streak
        XCTAssertTrue(sim.playStrike(cardId: "card_0", targetId: "enemy"))
        XCTAssertEqual(sim.streakType, .strike)
        XCTAssertEqual(sim.streakCount, 1)

        XCTAssertTrue(sim.playStrike(cardId: "card_1", targetId: "enemy"))
        XCTAssertEqual(sim.streakType, .strike)
        XCTAssertEqual(sim.streakCount, 2)

        XCTAssertTrue(sim.playStrike(cardId: "card_2", targetId: "enemy"))
        XCTAssertEqual(sim.streakType, .strike)
        XCTAssertEqual(sim.streakCount, 3, "After 3 strikes, streakCount must be 3")

        // Switch to influence -> streak resets
        XCTAssertTrue(sim.playInfluence(cardId: "card_3"))
        XCTAssertEqual(sim.streakType, .influence,
            "After switching to influence, streakType must be .influence")
        XCTAssertEqual(sim.streakCount, 1,
            "After switching action type, streakCount must reset to 1")
    }

    // MARK: - INV-DC-008: Streak preserved across turns

    /// Turn 1: strike -> endPlayerTurn() -> beginPlayerTurn().
    /// Turn 2: strike -> streakCount = 2 (not reset by turn boundary).
    func testMomentumStreak_preservedAcrossTurns() {
        var sim = makeSimulation()

        // Turn 1: play a strike
        XCTAssertTrue(sim.playStrike(cardId: "card_0", targetId: "enemy"))
        XCTAssertEqual(sim.streakType, .strike)
        XCTAssertEqual(sim.streakCount, 1)

        // Turn boundary
        sim.endPlayerTurn()
        sim.beginPlayerTurn()

        // Verify streak state was NOT reset by turn boundary
        XCTAssertEqual(sim.streakType, .strike,
            "streakType must persist across turn boundary")
        XCTAssertEqual(sim.streakCount, 1,
            "streakCount must persist across turn boundary")

        // Turn 2: play another strike -> streak continues
        XCTAssertTrue(sim.playStrike(cardId: "card_1", targetId: "enemy"))
        XCTAssertEqual(sim.streakType, .strike)
        XCTAssertEqual(sim.streakCount, 2,
            "Strike in turn 2 must continue streak from turn 1: streakCount = 2")
    }

    // MARK: - INV-DC-009: Streak bonus formula

    /// streak_bonus = max(0, streakCount - 1).
    /// streak=1 -> bonus=0, streak=2 -> bonus=1, streak=3 -> bonus=2, streak=5 -> bonus=4.
    func testStreakBonus_formula() {
        let testCases: [(streakCount: Int, expectedBonus: Int)] = [
            (1, 0),
            (2, 1),
            (3, 2),
            (5, 4)
        ]

        for tc in testCases {
            let bonus = DispositionCalculator.streakBonus(streakCount: tc.streakCount)
            XCTAssertEqual(bonus, tc.expectedBonus,
                "streakBonus(streakCount: \(tc.streakCount)) must be \(tc.expectedBonus), got \(bonus)")
        }

        // Also verify through simulation: streak of 3 strikes should produce
        // a larger disposition shift on the 3rd strike than the 1st.
        var sim = makeSimulation(disposition: 0)
        _ = sim.playStrike(cardId: "card_0", targetId: "enemy")
        let shift1 = abs(sim.disposition)  // streak=1, bonus=0 -> power=5

        var sim2 = makeSimulation(disposition: 0)
        _ = sim2.playStrike(cardId: "card_0", targetId: "enemy")
        _ = sim2.playStrike(cardId: "card_1", targetId: "enemy")
        _ = sim2.playStrike(cardId: "card_2", targetId: "enemy")
        let shift3 = abs(sim2.disposition)

        // shift3 should be larger than shift1 * 3 because of streak bonus.
        // 1st strike: power 5, bonus 0 = 5
        // 2nd strike: power 5, bonus 1 = 6
        // 3rd strike: power 5, bonus 2 = 7
        // Total = 5 + 6 + 7 = 18
        XCTAssertEqual(shift3, 18,
            "3 strikes with power=5 and streak bonus: 5+6+7 = 18")
        XCTAssertGreaterThan(shift3, shift1 * 3,
            "Streak bonus makes 3 strikes more powerful than 3x first-strike")
    }

    // MARK: - INV-DC-010: Threat bonus after strike

    /// lastAction=.strike, current=.influence -> threat_bonus = 2.
    /// lastAction=.strike, current=.strike -> threat_bonus = 0.
    func testThreatBonus_afterStrike() {
        // Direct calculator tests
        let threatSI = DispositionCalculator.threatBonus(
            lastActionType: .strike,
            currentActionType: .influence
        )
        XCTAssertEqual(threatSI, 2,
            "Threat bonus must be 2 when switching from strike to influence")

        let threatSS = DispositionCalculator.threatBonus(
            lastActionType: .strike,
            currentActionType: .strike
        )
        XCTAssertEqual(threatSS, 0,
            "Threat bonus must be 0 when continuing with strike")

        let threatII = DispositionCalculator.threatBonus(
            lastActionType: .influence,
            currentActionType: .influence
        )
        XCTAssertEqual(threatII, 0,
            "Threat bonus must be 0 when continuing with influence")

        let threatIS = DispositionCalculator.threatBonus(
            lastActionType: .influence,
            currentActionType: .strike
        )
        XCTAssertEqual(threatIS, 0,
            "Threat bonus must be 0 when switching from influence to strike")

        // End-to-end: strike -> influence should get +2 threat bonus
        var sim = makeSimulation(disposition: 0)
        _ = sim.playStrike(cardId: "card_0", targetId: "enemy")
        let dispositionAfterStrike = sim.disposition  // -5 (base power 5, streak 1, bonus 0)

        _ = sim.playInfluence(cardId: "card_1")
        let influenceShift = sim.disposition - dispositionAfterStrike
        // influence power = 5 (base) + 0 (streak=1, bonus=0) + 2 (threat) = 7
        // But switch penalty from streak=1: penalty = 0 (streak < 3)
        XCTAssertEqual(influenceShift, 7,
            "Influence after strike: base(5) + threat(2) = 7 shift")
    }

    // MARK: - INV-DC-011: Switch penalty for long streak

    /// streakCount=3 -> switchPenalty = max(0, 3-2) = 1.
    /// streakCount=5 -> switchPenalty = max(0, 5-2) = 3.
    /// streakCount=2 -> switchPenalty = 0 (threshold not reached).
    func testSwitchPenalty_longStreak() {
        // Direct formula tests
        XCTAssertEqual(DispositionCalculator.switchPenalty(streakCount: 3), 1,
            "switchPenalty(3) = max(0, 3-2) = 1")
        XCTAssertEqual(DispositionCalculator.switchPenalty(streakCount: 5), 3,
            "switchPenalty(5) = max(0, 5-2) = 3")
        XCTAssertEqual(DispositionCalculator.switchPenalty(streakCount: 2), 0,
            "switchPenalty(2) = 0 (threshold < 3)")
        XCTAssertEqual(DispositionCalculator.switchPenalty(streakCount: 1), 0,
            "switchPenalty(1) = 0 (threshold < 3)")

        // End-to-end simulation: 3 strikes then influence.
        // The influence should have switch penalty = 1 applied.
        var sim3 = makeSimulation(disposition: 0)
        _ = sim3.playStrike(cardId: "card_0", targetId: "enemy")
        _ = sim3.playStrike(cardId: "card_1", targetId: "enemy")
        _ = sim3.playStrike(cardId: "card_2", targetId: "enemy")
        XCTAssertEqual(sim3.streakCount, 3, "Precondition: 3 strikes -> streakCount=3")
        let dispositionBefore = sim3.disposition  // -18 (5+6+7)

        _ = sim3.playInfluence(cardId: "card_3")
        let influenceShift = sim3.disposition - dispositionBefore
        // influence: base=5, streak=1 (reset), bonus=0, threat=2 (strike->influence),
        // switch_penalty = max(0, 3-2) = 1 (from previous streak of 3)
        // effective = 5 + 0 + 2 - 1 = 6
        XCTAssertEqual(influenceShift, 6,
            "Influence after 3 strikes: base(5) + threat(2) - switchPenalty(1) = 6")

        // End-to-end: 2 strikes then influence (no switch penalty).
        var sim2 = makeSimulation(disposition: 0)
        _ = sim2.playStrike(cardId: "card_0", targetId: "enemy")
        _ = sim2.playStrike(cardId: "card_1", targetId: "enemy")
        XCTAssertEqual(sim2.streakCount, 2, "Precondition: 2 strikes -> streakCount=2")
        let disp2Before = sim2.disposition  // -11 (5+6)

        _ = sim2.playInfluence(cardId: "card_2")
        let influenceShift2 = sim2.disposition - disp2Before
        // influence: base=5, streak=1 (reset), bonus=0, threat=2 (strike->influence),
        // switch_penalty = 0 (previous streak=2 < 3)
        // effective = 5 + 0 + 2 - 0 = 7
        XCTAssertEqual(influenceShift2, 7,
            "Influence after 2 strikes: base(5) + threat(2) - switchPenalty(0) = 7")

        // Verify penalty difference: 3-streak switch is penalized vs 2-streak switch
        XCTAssertEqual(influenceShift2 - influenceShift, 1,
            "3-streak switch has 1 more penalty than 2-streak switch")
    }
}

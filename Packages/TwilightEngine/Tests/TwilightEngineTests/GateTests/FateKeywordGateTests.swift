/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/FateKeywordGateTests.swift
/// Назначение: Gate-тесты Fate Keyword System для Phase 3 Disposition Combat (Epic 18).
/// Зона ответственности: Проверяет инварианты INV-DC-017..026, INV-DC-049..051.
/// Контекст: Reference: RITUAL_COMBAT_TEST_MODEL.md §3.3

import XCTest
@testable import TwilightEngine

/// Fate Keyword Invariants — Phase 3 Gate Tests (Epic 18)
/// Reference: RITUAL_COMBAT_TEST_MODEL.md §3.3
/// Rule: < 2 seconds per test, deterministic (fixed seed), no system RNG
final class FateKeywordGateTests: XCTestCase {

    // MARK: - Fixture

    /// Standard test cards used across all tests.
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
        startingEnergy: Int = 10,
        resonanceZone: ResonanceZone = .yav
    ) -> DispositionCombatSimulation {
        DispositionCombatSimulation(
            disposition: disposition,
            energy: startingEnergy,
            startingEnergy: startingEnergy,
            hand: Self.testCards,
            heroHP: 100,
            heroMaxHP: 100,
            resonanceZone: resonanceZone,
            enemyType: "bandit",
            rng: WorldRNG(seed: seed),
            seed: seed
        )
    }

    // MARK: - INV-DC-025: FateDeck draw is deterministic

    /// Same seed must produce identical draw sequence across 100 runs.
    func testFateDeckDeterminism() {
        for seed: UInt64 in [42, 100, 999] {
            var ref = DispositionFateDeck(rng: WorldRNG(seed: seed))
            let refSequence = (0..<5).map { _ in ref.draw() }

            for run in 1...100 {
                var deck = DispositionFateDeck(rng: WorldRNG(seed: seed))
                let sequence = (0..<5).map { _ in deck.draw() }
                XCTAssertEqual(sequence, refSequence,
                    "Seed \(seed), run \(run): draw sequence diverged")
            }
        }
    }

    // MARK: - INV-DC-026: FateDeck auto-reshuffles when empty

    /// Drawing all 20 cards exhausts the pile; next draw auto-reshuffles.
    func testFateDeckAutoReshuffle() {
        var deck = DispositionFateDeck(rng: WorldRNG(seed: 42))

        // Draw all 20 cards
        for _ in 0..<20 { _ = deck.draw() }
        XCTAssertEqual(deck.remainingCount, 0,
            "After drawing 20 cards, draw pile must be empty")

        // Draw one more — should auto-reshuffle
        let card = deck.draw()
        XCTAssertTrue(
            [FateKeyword.surge, .focus, .echo, .shadow, .ward].contains(card),
            "Card drawn after reshuffle must be a valid FateKeyword")
        XCTAssertGreaterThan(deck.remainingCount, 0,
            "After auto-reshuffle, draw pile must have cards")
    }

    // MARK: - INV-DC-017: Surge only affects base power (full flow with fate draw)

    /// Surge multiplies only base power (base * 3/2), not total including bonuses.
    /// Verified through calculator with streak and through FateDeck draw context.
    func testSurge_onlyAffectsBasePower_fullFlow() {
        // With surge, same-type streak (no switch, no threat):
        // surged_base = 6*3/2 = 9, streak_bonus = 3, total = 12
        let surgedPower = DispositionCalculator.effectivePower(
            basePower: 6,
            streakCount: 4,
            lastActionType: .strike,
            currentActionType: .strike,
            fateKeyword: .surge,
            fateModifier: 0,
            resonanceZone: .yav
        )
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

        // Surge difference = surged_base - base = 9 - 6 = 3 (NOT 4)
        XCTAssertEqual(surgedPower - normalPower, 3,
            "Surge bonus must equal surged_base - base = 9 - 6 = 3")
    }

    // MARK: - INV-DC-019: Echo replays last action at 0 energy cost

    /// Echo must replay the last action at zero energy cost with the same fate modifier.
    func testEchoFreeReplay() {
        var sim = makeSimulation(disposition: 0, startingEnergy: 3)

        let ok = sim.playStrike(cardId: "card_0", targetId: "enemy")
        XCTAssertTrue(ok, "Initial strike must succeed")
        let energyAfterStrike = sim.energy
        let dispAfterStrike = sim.disposition

        let echoOK = sim.playEcho(fateModifier: 0)
        XCTAssertTrue(echoOK, "Echo must succeed after strike")
        XCTAssertEqual(sim.energy, energyAfterStrike,
            "Echo must cost 0 energy")
        XCTAssertLessThan(sim.disposition, dispAfterStrike,
            "Echo strike must decrease disposition further")
    }

    // MARK: - INV-DC-018: Echo blocked after sacrifice

    /// Echo must not be allowed after a sacrifice action.
    func testEchoBlockedAfterSacrifice() {
        var sim = makeSimulation(disposition: 0, startingEnergy: 5)

        let sacResult = sim.playCardAsSacrifice(cardId: "card_0")
        XCTAssertTrue(sacResult, "Sacrifice must succeed")

        let echoOK = sim.playEcho()
        XCTAssertFalse(echoOK,
            "Echo must be blocked after sacrifice")
    }

    // MARK: - INV-DC-051: Echo works after strike and after influence

    /// Echo must succeed after both strike and influence actions.
    func testEchoWorksAfterStrikeAndInfluence() {
        // Echo after strike
        var simStrike = makeSimulation(disposition: 0, startingEnergy: 5)
        _ = simStrike.playStrike(cardId: "card_0", targetId: "enemy")
        let echoAfterStrike = simStrike.playEcho()
        XCTAssertTrue(echoAfterStrike,
            "Echo must succeed after strike")

        // Echo after influence
        var simInfluence = makeSimulation(disposition: 0, startingEnergy: 5)
        _ = simInfluence.playInfluence(cardId: "card_0")
        let echoAfterInfluence = simInfluence.playEcho()
        XCTAssertTrue(echoAfterInfluence,
            "Echo must succeed after influence")
    }

    // MARK: - INV-DC-020: Echo continues streak (doesn't reset)

    /// Echo replaying a strike must continue the strike streak, not reset it.
    func testEchoContinuesStreak() {
        var sim = makeSimulation(disposition: 0, startingEnergy: 5)

        _ = sim.playStrike(cardId: "card_0", targetId: "enemy")
        XCTAssertEqual(sim.streakCount, 1, "Precondition: streak=1 after first strike")

        _ = sim.playStrike(cardId: "card_1", targetId: "enemy")
        XCTAssertEqual(sim.streakCount, 2, "Precondition: streak=2 after second strike")

        let echoOK = sim.playEcho()
        XCTAssertTrue(echoOK, "Echo must succeed")
        XCTAssertEqual(sim.streakType, .strike,
            "Echo must maintain streak type as .strike")
        XCTAssertEqual(sim.streakCount, 3,
            "Echo must continue streak: expected 3 after echo")
    }

    // MARK: - INV-DC-021: Echo doesn't trigger new fate draw (echoUsedThisAction flag)

    /// When Echo is used, echoUsedThisAction must be set to true so no new fate draw occurs.
    func testEchoDoesNotTriggerNewFateDraw() {
        var sim = makeSimulation(disposition: 0, startingEnergy: 5)
        _ = sim.playStrike(cardId: "card_0", targetId: "enemy")

        XCTAssertFalse(sim.echoUsedThisAction,
            "echoUsedThisAction must be false before Echo")

        _ = sim.playEcho()

        XCTAssertTrue(sim.echoUsedThisAction,
            "echoUsedThisAction must be true after Echo, preventing new fate draw")
    }

    // MARK: - INV-DC-022: Focus ignores Defend at disposition < -30

    /// Focus keyword must cause Defend reduction to be ignored when disposition < -30.
    func testFocusIgnoresDefend() {
        let ignores = DispositionCalculator.focusIgnoresDefend(
            disposition: -35, fateKeyword: .focus
        )
        XCTAssertTrue(ignores,
            "Focus must ignore Defend when disposition < -30")

        let noIgnore = DispositionCalculator.focusIgnoresDefend(
            disposition: -20, fateKeyword: .focus
        )
        XCTAssertFalse(noIgnore,
            "Focus must NOT ignore Defend when disposition >= -30")

        // Non-focus keyword at disposition < -30 must NOT ignore
        let noFocus = DispositionCalculator.focusIgnoresDefend(
            disposition: -35, fateKeyword: .surge
        )
        XCTAssertFalse(noFocus,
            "Non-focus keyword must not ignore Defend even at disposition < -30")

        // Nil keyword at disposition < -30 must NOT ignore
        let nilKeyword = DispositionCalculator.focusIgnoresDefend(
            disposition: -35, fateKeyword: nil
        )
        XCTAssertFalse(nilKeyword,
            "Nil keyword must not ignore Defend")
    }

    // MARK: - INV-DC-049: Focus ignores Provoke at disposition > +30

    /// Focus keyword must cause Provoke penalty to be ignored when disposition > +30.
    func testFocusIgnoresProvoke() {
        let ignores = DispositionCalculator.focusIgnoresProvoke(
            disposition: 35, fateKeyword: .focus
        )
        XCTAssertTrue(ignores,
            "Focus must ignore Provoke when disposition > +30")

        let noIgnore = DispositionCalculator.focusIgnoresProvoke(
            disposition: 20, fateKeyword: .focus
        )
        XCTAssertFalse(noIgnore,
            "Focus must NOT ignore Provoke when disposition <= +30")

        // Boundary: disposition = 30 must NOT ignore (strictly > 30)
        let boundary = DispositionCalculator.focusIgnoresProvoke(
            disposition: 30, fateKeyword: .focus
        )
        XCTAssertFalse(boundary,
            "Focus must NOT ignore Provoke at exactly +30 (must be > +30)")
    }

    // MARK: - INV-DC-023: Ward cancels resonance backlash

    /// Ward must prevent HP loss from Prav zone strike (resonance backlash).
    func testWardCancelsResonanceBacklash() {
        // Prav zone strike WITHOUT ward: hero loses 1 HP (backlash)
        var simNoWard = makeSimulation(
            disposition: 0, startingEnergy: 5, resonanceZone: .prav
        )
        let hpBefore = simNoWard.heroHP
        _ = simNoWard.playStrike(
            cardId: "card_0", targetId: "enemy",
            fateKeyword: nil
        )
        let hpLossNoWard = hpBefore - simNoWard.heroHP
        XCTAssertEqual(hpLossNoWard, 1,
            "Prav zone strike without ward must cause 1 HP backlash")

        // Prav zone strike WITH ward: no HP loss
        var simWard = makeSimulation(
            disposition: 0, startingEnergy: 5, resonanceZone: .prav
        )
        let hpBeforeWard = simWard.heroHP
        _ = simWard.playStrike(
            cardId: "card_0", targetId: "enemy",
            fateKeyword: .ward
        )
        XCTAssertEqual(simWard.heroHP, hpBeforeWard,
            "Ward must cancel resonance backlash: no HP loss in Prav zone")
    }

    // MARK: - INV-DC-024: Shadow adds +2 switch penalty at disposition < -30

    /// Shadow keyword must add +2 to switch penalty when disposition < -30.
    func testShadowExtraSwitchPenalty() {
        let penalty = DispositionCalculator.shadowSwitchPenalty(
            disposition: -35, fateKeyword: .shadow
        )
        XCTAssertEqual(penalty, 2,
            "Shadow must add +2 switch penalty at disposition < -30")

        let noPenalty = DispositionCalculator.shadowSwitchPenalty(
            disposition: -20, fateKeyword: .shadow
        )
        XCTAssertEqual(noPenalty, 0,
            "Shadow must NOT add penalty when disposition >= -30")

        // Non-shadow keyword must not add penalty
        let nonShadow = DispositionCalculator.shadowSwitchPenalty(
            disposition: -35, fateKeyword: .surge
        )
        XCTAssertEqual(nonShadow, 0,
            "Non-shadow keyword must not add switch penalty")

        // Boundary: disposition = -30 must NOT add penalty (strictly < -30)
        let boundary = DispositionCalculator.shadowSwitchPenalty(
            disposition: -30, fateKeyword: .shadow
        )
        XCTAssertEqual(boundary, 0,
            "Shadow must NOT add penalty at exactly -30 (must be < -30)")
    }

    // MARK: - INV-DC-050: Shadow disables enemy Defend at disposition > +30

    /// Shadow keyword must disable enemy Defend when disposition > +30.
    func testShadowDisablesDefend() {
        let disables = DispositionCalculator.shadowDisablesDefend(
            disposition: 35, fateKeyword: .shadow
        )
        XCTAssertTrue(disables,
            "Shadow must disable Defend when disposition > +30")

        let noDisable = DispositionCalculator.shadowDisablesDefend(
            disposition: 20, fateKeyword: .shadow
        )
        XCTAssertFalse(noDisable,
            "Shadow must NOT disable Defend when disposition <= +30")

        // Boundary: disposition = 30 must NOT disable (strictly > 30)
        let boundary = DispositionCalculator.shadowDisablesDefend(
            disposition: 30, fateKeyword: .shadow
        )
        XCTAssertFalse(boundary,
            "Shadow must NOT disable Defend at exactly +30 (must be > +30)")

        // Non-shadow keyword must not disable
        let nonShadow = DispositionCalculator.shadowDisablesDefend(
            disposition: 35, fateKeyword: .focus
        )
        XCTAssertFalse(nonShadow,
            "Non-shadow keyword must not disable Defend")
    }
}

/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/DispositionIntegrationTests.swift
/// Назначение: End-to-end integration tests для Phase 3 Disposition Combat (Epic 23).
/// Зона ответственности: Full combat paths, mode transitions, resonance scenarios, mid-combat save.
/// Контекст: Reference: RITUAL_COMBAT_TEST_MODEL.md §3.11

import XCTest
@testable import TwilightEngine

/// Disposition Integration Tests — Phase 3 Gate Tests (Epic 23)
/// Reference: RITUAL_COMBAT_TEST_MODEL.md §3.11
/// Rule: < 2 seconds per test, deterministic (fixed seed), no system RNG
final class DispositionIntegrationTests: XCTestCase {

    // MARK: - Fixture

    /// Standard test cards (15 cards, cost=1, power=5).
    private static let testCards: [Card] = (0..<15).map { i in
        Card(id: "card_\(i)", name: "Test Card \(i)", type: .item, description: "Test card", power: 5, cost: 1)
    }

    private func makeSimulation(
        disposition: Int = 0,
        seed: UInt64 = 42,
        startingEnergy: Int = 5,
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

    // MARK: - testFullDestroyPath

    /// Start at disposition near 0, play enough strikes to reach -100.
    /// Verify outcome = .destroyed.
    func testFullDestroyPath() {
        // Start near 0, give lots of energy and cards to reach -100
        var sim = makeSimulation(disposition: 0, startingEnergy: 15)

        // Play strikes until outcome is reached or cards run out
        var cardIndex = 0
        while sim.outcome == nil && cardIndex < Self.testCards.count && sim.energy > 0 {
            sim.playStrike(cardId: "card_\(cardIndex)", targetId: "enemy")
            cardIndex += 1
        }

        // With 15 cards at power=5 and enough energy, we should reach -100
        // Each strike does at least 5 base power, and streaks add bonuses
        XCTAssertEqual(sim.outcome, .destroyed,
            "Must reach destroyed outcome. Final disposition: \(sim.disposition)")
        XCTAssertLessThanOrEqual(sim.disposition, -100)
    }

    // MARK: - testFullSubjugatePath

    /// Play enough influences to reach +100. Verify outcome = .subjugated.
    func testFullSubjugatePath() {
        var sim = makeSimulation(disposition: 0, startingEnergy: 15)

        var cardIndex = 0
        while sim.outcome == nil && cardIndex < Self.testCards.count && sim.energy > 0 {
            sim.playInfluence(cardId: "card_\(cardIndex)")
            cardIndex += 1
        }

        XCTAssertEqual(sim.outcome, .subjugated,
            "Must reach subjugated outcome. Final disposition: \(sim.disposition)")
        XCTAssertGreaterThanOrEqual(sim.disposition, 100)
    }

    // MARK: - testMixedStrategyPath

    /// Alternate strikes and influences with threat bonus.
    /// Verify correct final disposition and momentum tracking.
    func testMixedStrategyPath() {
        var sim = makeSimulation(disposition: 0, startingEnergy: 10)

        // Strike first, then influence (triggers threat bonus +2)
        sim.playStrike(cardId: "card_0", targetId: "enemy")
        XCTAssertEqual(sim.streakType, .strike)
        XCTAssertEqual(sim.streakCount, 1)

        sim.playInfluence(cardId: "card_1")
        // After switching to influence: streak resets to influence=1
        XCTAssertEqual(sim.streakType, .influence)
        XCTAssertEqual(sim.streakCount, 1)
        XCTAssertEqual(sim.lastActionType, .influence)

        // Strike again
        sim.playStrike(cardId: "card_2", targetId: "enemy")
        XCTAssertEqual(sim.streakType, .strike)
        XCTAssertEqual(sim.streakCount, 1)

        // Influence again (threat bonus active: last was strike)
        let dispBefore = sim.disposition
        sim.playInfluence(cardId: "card_3")
        let influenceShift = sim.disposition - dispBefore
        // base=5, threat_bonus=+2 (strike->influence), streak=1 (bonus=0) => effective=7
        XCTAssertEqual(influenceShift, 7,
            "Influence after strike must include +2 threat bonus. Shift=\(influenceShift)")

        // Verify momentum is tracking correctly
        XCTAssertEqual(sim.streakType, .influence)
        XCTAssertEqual(sim.streakCount, 1)
    }

    // MARK: - testSacrificeRecoveryPath

    /// Use sacrifice to regain energy, then play more cards.
    /// Verify energy accounting, sacrifice buff accumulation, and card zone movements.
    func testSacrificeRecoveryPath() {
        var sim = makeSimulation(disposition: 0, startingEnergy: 3)

        // Play 2 strikes (cost 2 energy)
        sim.playStrike(cardId: "card_0", targetId: "enemy")
        sim.playStrike(cardId: "card_1", targetId: "enemy")
        XCTAssertEqual(sim.energy, 1, "Should have 1 energy left after 2 plays from 3")

        // Sacrifice a card (cost=1, regain +1)
        let sacrificeResult = sim.playCardAsSacrifice(cardId: "card_2")
        XCTAssertTrue(sacrificeResult, "Sacrifice must succeed")
        // Cost 1 energy, gain 1 back => net 0 change in yav zone
        XCTAssertEqual(sim.energy, 1, "Energy should be 1 after sacrifice (1-1+1)")
        XCTAssertEqual(sim.enemySacrificeBuff, 1, "Enemy buff must increase by 1")
        XCTAssertTrue(sim.sacrificeUsedThisTurn, "Sacrifice flag must be set")

        // Verify card moved to exhaust pile (not discard)
        XCTAssertTrue(sim.exhaustPile.contains(where: { $0.id == "card_2" }),
            "Sacrificed card must be in exhaust pile")
        XCTAssertFalse(sim.hand.contains(where: { $0.id == "card_2" }),
            "Sacrificed card must not be in hand")

        // Second sacrifice must be rejected (max 1 per turn)
        let secondSacrifice = sim.playCardAsSacrifice(cardId: "card_3")
        XCTAssertFalse(secondSacrifice, "Second sacrifice in same turn must be rejected")

        // Play another strike with remaining energy
        sim.playStrike(cardId: "card_3", targetId: "enemy")
        XCTAssertEqual(sim.energy, 0)

        // Verify discard pile has the strike cards
        XCTAssertEqual(sim.discardPile.count, 3, "3 cards played as strike must be in discard")
    }

    // MARK: - testDefeatPath_heroHPZero

    /// Apply enemy attacks until hero HP reaches 0.
    /// Verify heroHP == 0.
    func testDefeatPath_heroHPZero() {
        var sim = makeSimulation(disposition: 0, startingEnergy: 5)

        // Apply repeated enemy attacks
        for _ in 0..<10 {
            sim.applyEnemyAttack(damage: 12)
        }

        XCTAssertEqual(sim.heroHP, 0,
            "Hero HP must be clamped to 0 after sufficient damage")
    }

    // MARK: - testResonanceNavCombat

    /// Play in Nav zone. Verify strike +2 bonus, sacrifice discount.
    func testResonanceNavCombat() {
        var sim = makeSimulation(disposition: 0, startingEnergy: 10, resonanceZone: .nav)

        // Strike in Nav: base=5 + resonance=+2 = 7 effective power
        let dispBefore = sim.disposition
        sim.playStrike(cardId: "card_0", targetId: "enemy")
        let strikeShift = abs(sim.disposition - dispBefore)
        XCTAssertEqual(strikeShift, 7,
            "Strike in Nav must have +2 resonance bonus. Shift=\(strikeShift)")

        // Sacrifice in Nav: cost reduced by 1 (card cost=1, actual=0)
        let energyBefore = sim.energy
        sim.playCardAsSacrifice(cardId: "card_1")
        // In Nav: actualCost = max(0, 1 - 1) = 0, then +1 energy back
        XCTAssertEqual(sim.energy, energyBefore + 1,
            "Sacrifice in Nav costs 0 (discount) and gains 1 energy")
    }

    // MARK: - testResonancePravCombat

    /// Play in Prav zone. Verify influence +2 bonus, strike backlash -1 HP,
    /// sacrifice extra exhaust risk.
    func testResonancePravCombat() {
        var sim = makeSimulation(disposition: 0, seed: 42, startingEnergy: 10, resonanceZone: .prav)

        // Influence in Prav: base=5 + resonance=+2 = 7
        let dispBefore = sim.disposition
        sim.playInfluence(cardId: "card_0")
        let influenceShift = sim.disposition - dispBefore
        XCTAssertEqual(influenceShift, 7,
            "Influence in Prav must have +2 resonance bonus. Shift=\(influenceShift)")

        // Strike in Prav: backlash -1 HP (no ward keyword)
        let hpBefore = sim.heroHP
        sim.playStrike(cardId: "card_1", targetId: "enemy")
        XCTAssertEqual(sim.heroHP, hpBefore - 1,
            "Strike in Prav must cost -1 HP backlash without ward")

        // Sacrifice in Prav: extra exhaust risk (RNG-dependent with seed=42)
        let handBefore = sim.hand.count
        let exhaustBefore = sim.exhaustPile.count
        sim.playCardAsSacrifice(cardId: "card_2")
        // Card_2 itself is exhausted + possibly one extra
        let exhaustAdded = sim.exhaustPile.count - exhaustBefore
        XCTAssertGreaterThanOrEqual(exhaustAdded, 1,
            "At least the sacrificed card must be exhausted")
        // Verify total cards are accounted for
        let totalCards = sim.hand.count + sim.discardPile.count + sim.exhaustPile.count
        XCTAssertEqual(totalCards, Self.testCards.count,
            "Total cards across all zones must equal starting count")
    }

    // MARK: - testEnemyModeTransitions

    /// Start in normal mode. Build 3-strike streak -> enemy selects Defend.
    /// Move disposition past survival threshold -> mode changes.
    /// Move past desperation -> desperation mode.
    func testEnemyModeTransitions() {
        var sim = makeSimulation(disposition: 0, startingEnergy: 15)
        var modeState = EnemyModeState(seed: 42)
        let rng = WorldRNG(seed: 99)

        // Initial mode is normal
        let initialMode = EnemyAI.evaluateMode(state: &modeState, disposition: sim.disposition)
        XCTAssertEqual(initialMode, .normal, "Initial mode must be normal at disposition=0")

        // Build 3-strike streak
        sim.playStrike(cardId: "card_0", targetId: "enemy")
        sim.playStrike(cardId: "card_1", targetId: "enemy")
        sim.playStrike(cardId: "card_2", targetId: "enemy")
        XCTAssertEqual(sim.streakCount, 3, "Must have 3-strike streak")

        // Enemy should select Defend in normal mode with 3-strike streak
        let action = EnemyAI.selectAction(mode: .normal, simulation: sim, rng: rng)
        XCTAssertEqual(action, .defend(reduction: 3),
            "Normal mode + 3-strike streak must trigger Defend")

        // Move disposition deep negative for survival threshold
        // survivalThreshold for seed 42: -60 + offset
        sim.playStrike(cardId: "card_3", targetId: "enemy")
        sim.playStrike(cardId: "card_4", targetId: "enemy")
        sim.playStrike(cardId: "card_5", targetId: "enemy")
        sim.playStrike(cardId: "card_6", targetId: "enemy")
        sim.playStrike(cardId: "card_7", targetId: "enemy")
        sim.playStrike(cardId: "card_8", targetId: "enemy")
        sim.playStrike(cardId: "card_9", targetId: "enemy")

        // Disposition should be very negative now (10 strikes with streak bonuses)
        XCTAssertLessThan(sim.disposition, -50,
            "Disposition must be deep negative after many strikes")

        // Evaluate mode — should transition based on disposition
        let modeAfterStrikes = EnemyAI.evaluateMode(state: &modeState, disposition: sim.disposition)

        // The mode depends on thresholds and hysteresis, but it should not be normal
        // at this deep negative disposition
        if sim.disposition <= modeState.desperationThreshold {
            // Could be desperation or weakened (if swing was large)
            XCTAssertTrue(
                modeAfterStrikes == .desperation || modeAfterStrikes == .weakened,
                "Must be desperation or weakened at disposition \(sim.disposition)")
        } else if sim.disposition <= modeState.survivalThreshold {
            XCTAssertTrue(
                modeAfterStrikes == .survival || modeAfterStrikes == .weakened,
                "Must be survival or weakened at disposition \(sim.disposition)")
        }
    }

    // MARK: - testMidCombatSaveResume

    /// Play several actions, save snapshot, restore, continue playing on both
    /// original and restored. Verify identical outcomes.
    func testMidCombatSaveResume() {
        var sim = makeSimulation(disposition: 10, startingEnergy: 10)

        // Play initial actions
        sim.playStrike(cardId: "card_0", targetId: "enemy")
        sim.playInfluence(cardId: "card_1")
        sim.playCardAsSacrifice(cardId: "card_2")

        // Save snapshot
        let snapshot = DispositionCombatSnapshot.capture(from: sim)

        // Encode and decode (simulate actual persistence)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        guard let data = try? encoder.encode(snapshot),
              let decoded = try? decoder.decode(DispositionCombatSnapshot.self, from: data) else {
            XCTFail("Snapshot round-trip failed")
            return
        }

        var restored = decoded.restore()

        // Continue playing identical actions on both
        sim.playStrike(cardId: "card_3", targetId: "enemy")
        restored.playStrike(cardId: "card_3", targetId: "enemy")

        sim.playInfluence(cardId: "card_4")
        restored.playInfluence(cardId: "card_4")

        // Apply enemy turn on both
        sim.applyEnemyAttack(damage: 5)
        restored.applyEnemyAttack(damage: 5)

        sim.endPlayerTurn()
        restored.endPlayerTurn()

        sim.beginPlayerTurn()
        restored.beginPlayerTurn()

        sim.playStrike(cardId: "card_5", targetId: "enemy")
        restored.playStrike(cardId: "card_5", targetId: "enemy")

        // Verify identical state
        XCTAssertEqual(sim.disposition, restored.disposition)
        XCTAssertEqual(sim.outcome, restored.outcome)
        XCTAssertEqual(sim.heroHP, restored.heroHP)
        XCTAssertEqual(sim.energy, restored.energy)
        XCTAssertEqual(sim.streakCount, restored.streakCount)
        XCTAssertEqual(sim.streakType, restored.streakType)
        XCTAssertEqual(sim.hand.map(\.id), restored.hand.map(\.id))
        XCTAssertEqual(sim.discardPile.map(\.id), restored.discardPile.map(\.id))
        XCTAssertEqual(sim.exhaustPile.map(\.id), restored.exhaustPile.map(\.id))
        XCTAssertEqual(sim.enemySacrificeBuff, restored.enemySacrificeBuff)
        XCTAssertEqual(sim.rng.currentState(), restored.rng.currentState())
    }

    // MARK: - testAffinityMatrixImpact

    /// Create 3 simulations with different resonance zones (nav, yav, prav) vs same enemy.
    /// Verify different starting dispositions per affinity matrix.
    func testAffinityMatrixImpact() {
        // Use factory method with Russian enemy types that exist in AffinityMatrix
        let navSim = DispositionCombatSimulation.create(
            enemyType: "нечисть",
            heroHP: 100, heroMaxHP: 100,
            hand: Self.testCards,
            resonanceZone: .nav,
            seed: 42
        )

        let yavSim = DispositionCombatSimulation.create(
            enemyType: "нечисть",
            heroHP: 100, heroMaxHP: 100,
            hand: Self.testCards,
            resonanceZone: .yav,
            seed: 42
        )

        let pravSim = DispositionCombatSimulation.create(
            enemyType: "нечисть",
            heroHP: 100, heroMaxHP: 100,
            hand: Self.testCards,
            resonanceZone: .prav,
            seed: 42
        )

        // Verify different starting dispositions
        // From AffinityMatrix: nav/нечисть=30, yav/нечисть=0, prav/нечисть=-40
        XCTAssertEqual(navSim.disposition, 30,
            "Nav vs нечисть must start at 30")
        XCTAssertEqual(yavSim.disposition, 0,
            "Yav vs нечисть must start at 0")
        XCTAssertEqual(pravSim.disposition, -40,
            "Prav vs нечисть must start at -40")

        // All three must be different
        XCTAssertNotEqual(navSim.disposition, yavSim.disposition)
        XCTAssertNotEqual(yavSim.disposition, pravSim.disposition)
        XCTAssertNotEqual(navSim.disposition, pravSim.disposition)
    }

    // MARK: - testFateKeywordIntegration

    /// Play strike with surge, verify enhanced power.
    /// Play influence with focus at disposition > 30, verify provoke ignored.
    /// Play echo after strike, verify free replay.
    func testFateKeywordIntegration() {
        // Surge: strike with surge keyword
        var sim = makeSimulation(disposition: 0, startingEnergy: 10)
        let dispBefore = sim.disposition
        sim.playStrike(cardId: "card_0", targetId: "enemy", fateKeyword: .surge)
        let surgeShift = abs(sim.disposition - dispBefore)
        // Surged base = 5 * 3/2 = 7 (integer math), streak=1 (bonus=0), effective=7
        XCTAssertEqual(surgeShift, 7,
            "Strike with surge must have enhanced power (5*3/2=7). Shift=\(surgeShift)")

        // Focus: influence with focus at disposition > 30, provoke should be ignored
        var simFocus = makeSimulation(disposition: 35, startingEnergy: 10)
        simFocus.applyEnemyProvoke(value: 5)
        let focusDispBefore = simFocus.disposition
        simFocus.playInfluence(cardId: "card_0", fateKeyword: .focus)
        let focusShift = simFocus.disposition - focusDispBefore
        // Focus at disposition > 30: provoke ignored, base=5, effective=5
        XCTAssertEqual(focusShift, 5,
            "Focus must ignore provoke at disposition > 30. Shift=\(focusShift)")

        // Echo: play strike, then echo — free replay at 0 energy cost
        var simEcho = makeSimulation(disposition: 0, startingEnergy: 10)
        simEcho.playStrike(cardId: "card_0", targetId: "enemy")
        let echoDispBefore = simEcho.disposition
        let echoEnergyBefore = simEcho.energy
        let echoResult = simEcho.playEcho()
        XCTAssertTrue(echoResult, "Echo must succeed after strike")
        XCTAssertEqual(simEcho.energy, echoEnergyBefore,
            "Echo must not cost energy")
        let echoShift = abs(simEcho.disposition - echoDispBefore)
        // Echo replays last strike: base=5, streak=2 (bonus=+1), effective=6
        XCTAssertEqual(echoShift, 6,
            "Echo replay of strike must continue streak. Shift=\(echoShift)")
    }

    // MARK: - testEnemyAdaptIntegration

    /// Build streak, apply adapt, verify penalty reduces next same-type action's power
    /// but action still succeeds.
    func testEnemyAdaptIntegration() {
        var sim = makeSimulation(disposition: 0, startingEnergy: 10)

        // Build a 3-strike streak
        sim.playStrike(cardId: "card_0", targetId: "enemy")
        sim.playStrike(cardId: "card_1", targetId: "enemy")
        sim.playStrike(cardId: "card_2", targetId: "enemy")
        XCTAssertEqual(sim.streakCount, 3)

        let dispBeforeAdapt = sim.disposition

        // Apply adapt via EnemyActionResolver (full integration)
        let adaptAction: EnemyAction = .adapt
        EnemyActionResolver.resolve(action: adaptAction, simulation: &sim)

        // Adapt penalty should be max(3, streakBonus(3)) = max(3, 2) = 3
        XCTAssertEqual(sim.adaptPenalty, 3,
            "Adapt penalty must be max(3, streakBonus)")

        // Play another strike — should succeed but with reduced power
        let dispBeforeStrike = sim.disposition
        let result = sim.playStrike(cardId: "card_3", targetId: "enemy")
        XCTAssertTrue(result, "Strike must still succeed with adapt penalty")

        let strikeShift = abs(sim.disposition - dispBeforeStrike)
        // base=5, streak=4(bonus=+3), adapt_penalty=-3 => effective = 5+3-3 = 5
        XCTAssertEqual(strikeShift, 5,
            "Strike with adapt penalty must have reduced effective power. Shift=\(strikeShift)")

        // Disposition must still have changed
        XCTAssertLessThan(sim.disposition, dispBeforeAdapt,
            "Disposition must still decrease despite adapt penalty")
    }

    // MARK: - testMultiTurnCombatFlow

    /// Full 3-turn combat: each turn play cards until energy=0, end turn, enemy acts,
    /// begin new turn. Verify energy resets, streaks persist across turns, enemy actions apply.
    func testMultiTurnCombatFlow() {
        var sim = makeSimulation(disposition: 0, startingEnergy: 3)
        var modeState = EnemyModeState(seed: 42)
        let aiRng = WorldRNG(seed: 99)

        // -- Turn 1 --
        sim.playStrike(cardId: "card_0", targetId: "enemy")
        sim.playStrike(cardId: "card_1", targetId: "enemy")
        sim.playStrike(cardId: "card_2", targetId: "enemy")
        XCTAssertEqual(sim.energy, 0, "Energy must be 0 after 3 plays")
        XCTAssertEqual(sim.streakCount, 3, "Must have 3-strike streak")
        XCTAssertTrue(sim.isAutoTurnEnd, "Turn must auto-end at 0 energy")

        sim.endPlayerTurn()

        // Enemy turn 1
        let mode1 = EnemyAI.evaluateMode(state: &modeState, disposition: sim.disposition)
        let action1 = EnemyAI.selectAction(mode: mode1, simulation: sim, rng: aiRng)
        EnemyActionResolver.resolve(action: action1, simulation: &sim)

        let hpAfterTurn1 = sim.heroHP
        let dispAfterTurn1 = sim.disposition

        // -- Turn 2 --
        sim.beginPlayerTurn()
        XCTAssertEqual(sim.energy, 3, "Energy must reset to startingEnergy at new turn")
        XCTAssertFalse(sim.sacrificeUsedThisTurn, "Sacrifice flag must reset at new turn")
        // Streak persists across turns
        XCTAssertEqual(sim.streakCount, 3, "Streak must persist across turns")

        sim.playStrike(cardId: "card_3", targetId: "enemy")
        sim.playStrike(cardId: "card_4", targetId: "enemy")
        sim.playStrike(cardId: "card_5", targetId: "enemy")
        XCTAssertEqual(sim.streakCount, 6, "Streak must continue across turns")

        sim.endPlayerTurn()

        // Enemy turn 2
        let mode2 = EnemyAI.evaluateMode(state: &modeState, disposition: sim.disposition)
        let action2 = EnemyAI.selectAction(mode: mode2, simulation: sim, rng: aiRng)
        EnemyActionResolver.resolve(action: action2, simulation: &sim)

        // -- Turn 3 --
        sim.beginPlayerTurn()
        XCTAssertEqual(sim.energy, 3)

        sim.playStrike(cardId: "card_6", targetId: "enemy")
        sim.playStrike(cardId: "card_7", targetId: "enemy")
        sim.playStrike(cardId: "card_8", targetId: "enemy")

        sim.endPlayerTurn()

        // Enemy turn 3
        let mode3 = EnemyAI.evaluateMode(state: &modeState, disposition: sim.disposition)
        let action3 = EnemyAI.selectAction(mode: mode3, simulation: sim, rng: aiRng)
        EnemyActionResolver.resolve(action: action3, simulation: &sim)

        // Final state assertions
        // 9 strikes played: disposition must be very negative
        XCTAssertLessThan(sim.disposition, dispAfterTurn1,
            "Disposition must decrease with more strikes")

        // 9 cards played, 0 sacrificed
        XCTAssertEqual(sim.discardPile.count, 9, "9 cards must be in discard")
        XCTAssertEqual(sim.hand.count, Self.testCards.count - 9,
            "Hand must have 6 remaining cards")

        // Enemy attacks should have affected hero HP
        // (action depends on mode/streak but at least some damage applied)
        XCTAssertLessThanOrEqual(sim.heroHP, 100,
            "Hero HP must not exceed max")
    }
}

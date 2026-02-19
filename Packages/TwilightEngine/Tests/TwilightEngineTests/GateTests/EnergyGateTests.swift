/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/EnergyGateTests.swift
/// Назначение: Gate-тесты Energy для Phase 3 Disposition Combat (Epic 17).
/// Зона ответственности: Проверяет инварианты INV-DC-045..048, INV-DC-061, INV-DC-062 (energy deduction, rejection, auto turn-end, reset, Nav discount, Prav risk).
/// Контекст: Reference: RITUAL_COMBAT_TEST_MODEL.md §3.9

import XCTest
@testable import TwilightEngine

/// Energy Invariants — Phase 3 Gate Tests (Epic 17)
/// Reference: RITUAL_COMBAT_TEST_MODEL.md §3.9
/// Rule: < 2 seconds per test, deterministic (fixed seed), no system RNG
final class EnergyGateTests: XCTestCase {

    // MARK: - Fixture

    /// Create a card with specified cost and power.
    private func makeCard(id: String, cost: Int, power: Int = 5) -> Card {
        Card(
            id: id,
            name: "Card \(id)",
            type: .item,
            description: "Test card",
            power: power,
            cost: cost
        )
    }

    /// Create a simulation with specified parameters.
    private func makeSimulation(
        disposition: Int = 0,
        energy: Int = 3,
        startingEnergy: Int = 3,
        hand: [Card],
        resonanceZone: ResonanceZone = .yav,
        seed: UInt64 = 42
    ) -> DispositionCombatSimulation {
        return DispositionCombatSimulation(
            disposition: disposition,
            energy: energy,
            startingEnergy: startingEnergy,
            hand: hand,
            heroHP: 100,
            heroMaxHP: 100,
            resonanceZone: resonanceZone,
            enemyType: "bandit",
            rng: WorldRNG(seed: seed),
            seed: seed
        )
    }

    // MARK: - INV-DC-045: Energy deduction on card play

    /// energy=3, card.cost=2 -> playStrike -> energy=1.
    func testEnergyDeduction() {
        let card = makeCard(id: "strike_2cost", cost: 2)
        var sim = makeSimulation(energy: 3, startingEnergy: 3, hand: [card])

        XCTAssertEqual(sim.energy, 3, "Precondition: energy must be 3")

        let result = sim.playStrike(cardId: "strike_2cost", targetId: "enemy")
        XCTAssertTrue(result, "Strike must succeed when energy >= cost")
        XCTAssertEqual(sim.energy, 1,
            "Energy must be deducted by card cost: 3 - 2 = 1")
    }

    // MARK: - INV-DC-046: Insufficient energy rejected

    /// energy=1, card.cost=2 -> playStrike returns false.
    /// Energy unchanged, card still in hand, disposition unchanged.
    func testInsufficientEnergyRejected() {
        let card = makeCard(id: "expensive", cost: 2)
        var sim = makeSimulation(energy: 1, startingEnergy: 3, hand: [card])

        let dispositionBefore = sim.disposition
        let handBefore = sim.hand

        let result = sim.playStrike(cardId: "expensive", targetId: "enemy")
        XCTAssertFalse(result,
            "Strike must be rejected when energy (1) < card cost (2)")
        XCTAssertEqual(sim.energy, 1,
            "Energy must be unchanged after rejected play")
        XCTAssertEqual(sim.hand, handBefore,
            "Hand must be unchanged after rejected play")
        XCTAssertEqual(sim.disposition, dispositionBefore,
            "Disposition must be unchanged after rejected play")

        // Also verify influence is rejected
        let influenceResult = sim.playInfluence(cardId: "expensive")
        XCTAssertFalse(influenceResult,
            "Influence must also be rejected when energy < cost")
    }

    // MARK: - INV-DC-047: Auto turn-end at zero energy

    /// energy=2, card.cost=2 -> playStrike -> energy=0.
    /// Cannot play another card. isAutoTurnEnd == true.
    func testAutoTurnEndAtZeroEnergy() {
        let card1 = makeCard(id: "card_a", cost: 2)
        let card2 = makeCard(id: "card_b", cost: 1)
        var sim = makeSimulation(energy: 2, startingEnergy: 2, hand: [card1, card2])

        XCTAssertEqual(sim.energy, 2, "Precondition: energy must be 2")
        XCTAssertFalse(sim.isAutoTurnEnd, "Turn should not auto-end when energy > 0")

        let result = sim.playStrike(cardId: "card_a", targetId: "enemy")
        XCTAssertTrue(result, "Strike must succeed with sufficient energy")
        XCTAssertEqual(sim.energy, 0, "Energy must be 0 after playing cost-2 card")
        XCTAssertTrue(sim.isAutoTurnEnd,
            "isAutoTurnEnd must be true when energy = 0")

        // Attempt to play another card -> must fail
        let secondResult = sim.playStrike(cardId: "card_b", targetId: "enemy")
        XCTAssertFalse(secondResult,
            "Cannot play any card when energy = 0")
        let influenceResult = sim.playInfluence(cardId: "card_b")
        XCTAssertFalse(influenceResult,
            "Cannot play influence when energy = 0")
    }

    // MARK: - INV-DC-048: Energy resets each turn

    /// startingEnergy=3, play cards until energy=0 or 1.
    /// endPlayerTurn() -> beginPlayerTurn() -> energy = 3 (fully reset).
    func testEnergyResetEachTurn() {
        let cards = [
            makeCard(id: "card_a", cost: 1),
            makeCard(id: "card_b", cost: 1),
            makeCard(id: "card_c", cost: 1),
            makeCard(id: "card_d", cost: 1),
            makeCard(id: "card_e", cost: 1)
        ]
        var sim = makeSimulation(energy: 3, startingEnergy: 3, hand: cards)

        // Turn 1: play cards to drain energy
        _ = sim.playStrike(cardId: "card_a", targetId: "enemy")
        _ = sim.playStrike(cardId: "card_b", targetId: "enemy")
        _ = sim.playStrike(cardId: "card_c", targetId: "enemy")
        XCTAssertEqual(sim.energy, 0, "Energy must be 0 after 3 cost-1 plays")

        // Turn boundary
        sim.endPlayerTurn()
        sim.beginPlayerTurn()

        // Turn 2: energy fully reset
        XCTAssertEqual(sim.energy, 3,
            "Energy must reset to startingEnergy (3) at the start of each turn")

        // Verify can play again
        let result = sim.playStrike(cardId: "card_d", targetId: "enemy")
        XCTAssertTrue(result, "Must be able to play cards after energy reset")
        XCTAssertEqual(sim.energy, 2, "Energy must be 2 after one cost-1 play")
    }

    // MARK: - INV-DC-061: Nav sacrifice discount

    /// Sacrifice cost = card.cost in Yav, card.cost-1 in Nav.
    /// Sacrifice effect: +1 energy back.
    /// Yav: energy = 3 - 2 + 1 = 2 (net: -1).
    /// Nav: energy = 3 - (2-1) + 1 = 3 (net: 0, break even).
    func testNavSacrificeDiscount() {
        // --- Yav zone: standard sacrifice cost ---
        let yavCard = makeCard(id: "yav_sac", cost: 2)
        var simYav = makeSimulation(
            energy: 3, startingEnergy: 3,
            hand: [yavCard],
            resonanceZone: .yav
        )

        let yavResult = simYav.playCardAsSacrifice(cardId: "yav_sac")
        XCTAssertTrue(yavResult, "Sacrifice must succeed in Yav")
        XCTAssertEqual(simYav.energy, 2,
            "Yav sacrifice: 3 - 2 + 1 = 2 (full cost, +1 refund)")
        XCTAssertTrue(simYav.exhaustPile.contains { $0.id == "yav_sac" },
            "Card must be in exhaustPile after sacrifice")

        // --- Nav zone: discounted sacrifice cost ---
        let navCard = makeCard(id: "nav_sac", cost: 2)
        var simNav = makeSimulation(
            energy: 3, startingEnergy: 3,
            hand: [navCard],
            resonanceZone: .nav
        )

        let navResult = simNav.playCardAsSacrifice(cardId: "nav_sac")
        XCTAssertTrue(navResult, "Sacrifice must succeed in Nav")
        XCTAssertEqual(simNav.energy, 3,
            "Nav sacrifice: 3 - (2-1) + 1 = 3 (discounted cost, break even)")
        XCTAssertTrue(simNav.exhaustPile.contains { $0.id == "nav_sac" },
            "Card must be in exhaustPile after Nav sacrifice")
    }

    // MARK: - INV-DC-062: Prav sacrifice risk — extra exhaust

    /// In Prav zone, sacrifice may exhaust 1 additional random card (rng.nextBool(probability: 0.5)).
    /// In Yav zone, only the sacrificed card is exhausted.
    func testPravSacrificeRisk() {
        // --- Control: Yav zone — only sacrificed card exhausted ---
        let yavCards = [
            makeCard(id: "yav_a", cost: 1),
            makeCard(id: "yav_b", cost: 1),
            makeCard(id: "yav_c", cost: 1)
        ]
        var simYav = makeSimulation(
            energy: 3, startingEnergy: 3,
            hand: yavCards,
            resonanceZone: .yav
        )

        _ = simYav.playCardAsSacrifice(cardId: "yav_a")
        XCTAssertEqual(simYav.exhaustPile.count, 1,
            "Yav sacrifice: only 1 card exhausted (no extra exhaust)")
        XCTAssertEqual(simYav.hand.count, 2,
            "Yav sacrifice: hand reduced by exactly 1")
        XCTAssertTrue(simYav.exhaustPile.contains { $0.id == "yav_a" },
            "Yav sacrifice: the sacrificed card must be in exhaustPile")

        // --- Prav zone: test multiple seeds to find both outcomes ---
        // Probe seeds to find one that triggers extra exhaust and one that doesn't.
        // The RNG call is rng.nextBool(probability: 0.5) -> nextDouble() < 0.5.
        // xorshift64 with small seeds produces small initial values (always < 0.5),
        // so we also test large seeds to find the non-triggering case.
        var triggerSeed: UInt64?
        var noTriggerSeed: UInt64?

        let seedCandidates: [UInt64] = Array(1...50) + [
            UInt64.max, UInt64.max / 2, UInt64.max / 3,
            0xAAAA_AAAA_AAAA_AAAA, 0xFFFF_FFFF_0000_0000,
            0x8000_0000_0000_0000, 0xDEAD_BEEF_DEAD_BEEF,
            0x1234_5678_9ABC_DEF0, 0xFEDC_BA98_7654_3210,
            0x7FFF_FFFF_FFFF_FFFF, 0xCCCC_CCCC_CCCC_CCCC,
            0x5555_5555_5555_5555, 0x9999_9999_9999_9999,
            0xF0F0_F0F0_F0F0_F0F0, 0x0F0F_0F0F_0F0F_0F0F
        ]

        for seed in seedCandidates {
            let cards = [
                makeCard(id: "p_a", cost: 1),
                makeCard(id: "p_b", cost: 1),
                makeCard(id: "p_c", cost: 1)
            ]
            var sim = makeSimulation(
                energy: 3, startingEnergy: 3,
                hand: cards,
                resonanceZone: .prav,
                seed: seed
            )

            _ = sim.playCardAsSacrifice(cardId: "p_a")

            if sim.exhaustPile.count == 2 && triggerSeed == nil {
                triggerSeed = seed
            } else if sim.exhaustPile.count == 1 && noTriggerSeed == nil {
                noTriggerSeed = seed
            }

            if triggerSeed != nil && noTriggerSeed != nil { break }
        }

        // Verify we found both outcomes (validates RNG probability path exists)
        XCTAssertNotNil(triggerSeed,
            "Must find at least one seed where Prav extra exhaust triggers")
        XCTAssertNotNil(noTriggerSeed,
            "Must find at least one seed where Prav extra exhaust does NOT trigger")

        // --- Verify trigger case deterministically ---
        if let seed = triggerSeed {
            let cards = [
                makeCard(id: "p_a", cost: 1),
                makeCard(id: "p_b", cost: 1),
                makeCard(id: "p_c", cost: 1)
            ]
            var sim = makeSimulation(
                energy: 3, startingEnergy: 3,
                hand: cards,
                resonanceZone: .prav,
                seed: seed
            )

            _ = sim.playCardAsSacrifice(cardId: "p_a")
            XCTAssertEqual(sim.exhaustPile.count, 2,
                "Prav sacrifice (seed \(seed)): extra exhaust triggered, 2 cards exhausted")
            XCTAssertEqual(sim.hand.count, 1,
                "Prav sacrifice (seed \(seed)): hand reduced to 1 (sacrificed + extra)")
            XCTAssertTrue(sim.exhaustPile.contains { $0.id == "p_a" },
                "Sacrificed card must be in exhaustPile")
        }

        // --- Verify no-trigger case deterministically ---
        if let seed = noTriggerSeed {
            let cards = [
                makeCard(id: "p_a", cost: 1),
                makeCard(id: "p_b", cost: 1),
                makeCard(id: "p_c", cost: 1)
            ]
            var sim = makeSimulation(
                energy: 3, startingEnergy: 3,
                hand: cards,
                resonanceZone: .prav,
                seed: seed
            )

            _ = sim.playCardAsSacrifice(cardId: "p_a")
            XCTAssertEqual(sim.exhaustPile.count, 1,
                "Prav sacrifice (seed \(seed)): extra exhaust NOT triggered, only 1 card exhausted")
            XCTAssertEqual(sim.hand.count, 2,
                "Prav sacrifice (seed \(seed)): hand reduced by exactly 1")
        }
    }
}

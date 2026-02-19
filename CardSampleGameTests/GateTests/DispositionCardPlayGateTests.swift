/// Файл: CardSampleGameTests/GateTests/DispositionCardPlayGateTests.swift
/// Назначение: Gate-тесты Card Play App Integration для Phase 3 Disposition Combat (Epic 20).
/// Зона ответственности: Проверяет инварианты INV-DC-012..016.
/// Контекст: Reference: RITUAL_COMBAT_TEST_MODEL.md §3.2

import XCTest
import TwilightEngine
@testable import CardSampleGame

/// Card Play App Integration — Phase 3 Gate Tests (Epic 20)
/// Reference: RITUAL_COMBAT_TEST_MODEL.md §3.2
/// Rule: < 2 seconds per test, deterministic (fixed seed)
final class DispositionCardPlayGateTests: XCTestCase {

    // MARK: - INV-DC-012: Strike via ViewModel shifts disposition negatively

    /// Playing a strike through the ViewModel must decrease disposition.
    func testStrikeViaViewModel_shiftsDispositionNegatively() {
        let sim = DispositionCombatSimulation.makeStandard(seed: 42)
        let vm = DispositionCombatViewModel(simulation: sim)
        let initial = vm.disposition

        let accepted = vm.playStrike(cardId: "card_a", targetId: "enemy")

        XCTAssertTrue(accepted,
            "Strike must be accepted for valid card in hand")
        XCTAssertLessThan(vm.disposition, initial,
            "Strike must shift disposition negatively (toward destroyed)")
    }

    // MARK: - INV-DC-013: Influence via ViewModel shifts disposition positively

    /// Playing influence through the ViewModel must increase disposition.
    func testInfluenceViaViewModel_shiftsDispositionPositively() {
        let sim = DispositionCombatSimulation.makeStandard(seed: 42)
        let vm = DispositionCombatViewModel(simulation: sim)
        let initial = vm.disposition

        let accepted = vm.playInfluence(cardId: "card_a")

        XCTAssertTrue(accepted,
            "Influence must be accepted for valid card in hand")
        XCTAssertGreaterThan(vm.disposition, initial,
            "Influence must shift disposition positively (toward subjugated)")
    }

    // MARK: - INV-DC-014: Sacrifice via ViewModel exhausts card and buffs enemy

    /// Sacrifice through ViewModel must exhaust the card, grant +1 energy, and buff enemy.
    func testSacrificeViaViewModel_exhaustsCardAndBuffsEnemy() {
        let sim = DispositionCombatSimulation.makeStandard(seed: 42)
        let vm = DispositionCombatViewModel(simulation: sim)
        let initialHandCount = vm.hand.count

        let accepted = vm.playSacrifice(cardId: "card_a")

        XCTAssertTrue(accepted,
            "Sacrifice must be accepted for valid card in hand")
        XCTAssertEqual(vm.hand.count, initialHandCount - 1,
            "Sacrifice must remove card from hand")
        XCTAssertEqual(vm.simulation.enemySacrificeBuff, 1,
            "Sacrifice must buff enemy by +1")
        XCTAssertTrue(vm.simulation.sacrificeUsedThisTurn,
            "Sacrifice flag must be set (1/turn limit)")
    }

    // MARK: - INV-DC-015: Card play rejects invalid card

    /// Playing a card not in hand must be rejected without side effects.
    func testCardPlay_rejectsInvalidCard() {
        let sim = DispositionCombatSimulation.makeStandard(seed: 42)
        let vm = DispositionCombatViewModel(simulation: sim)
        let initialDisposition = vm.disposition
        let initialEnergy = vm.energy

        let strikeResult = vm.playStrike(cardId: "nonexistent", targetId: "enemy")
        XCTAssertFalse(strikeResult,
            "Strike with invalid card must be rejected")

        let influenceResult = vm.playInfluence(cardId: "nonexistent")
        XCTAssertFalse(influenceResult,
            "Influence with invalid card must be rejected")

        let sacrificeResult = vm.playSacrifice(cardId: "nonexistent")
        XCTAssertFalse(sacrificeResult,
            "Sacrifice with invalid card must be rejected")

        XCTAssertEqual(vm.disposition, initialDisposition,
            "Disposition must not change after rejected actions")
        XCTAssertEqual(vm.energy, initialEnergy,
            "Energy must not change after rejected actions")
    }

    // MARK: - INV-DC-016: Card play deducts energy

    /// Each card play must deduct the card's cost from energy.
    /// When energy is 0, further plays must be rejected.
    func testCardPlay_deductsEnergy() {
        let sim = DispositionCombatSimulation.makeStandard(seed: 42)
        let vm = DispositionCombatViewModel(simulation: sim)
        let initialEnergy = vm.energy  // 3 (from makeStandard)

        vm.playStrike(cardId: "card_a", targetId: "enemy")

        XCTAssertEqual(vm.energy, initialEnergy - 1,
            "Card play must deduct card cost (1) from energy")

        // Play until out of energy
        vm.playInfluence(cardId: "card_b")   // energy: 1
        vm.playInfluence(cardId: "card_c")   // energy: 0

        XCTAssertEqual(vm.energy, 0,
            "Energy must reach 0 after 3 plays (cost=1 each)")

        // No more plays possible
        let rejected = vm.playStrike(cardId: "card_d", targetId: "enemy")
        XCTAssertFalse(rejected,
            "Card play must be rejected when energy is 0")
    }
}

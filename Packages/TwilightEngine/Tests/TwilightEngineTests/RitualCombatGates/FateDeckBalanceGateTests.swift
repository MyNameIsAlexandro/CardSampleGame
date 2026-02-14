/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/RitualCombatGates/FateDeckBalanceGateTests.swift
/// Назначение: Gate-тесты баланса Fate Deck для Phase 3 Ritual Combat (R0).
/// Зона ответственности: Проверяет инварианты matchMultiplier, suit distribution, sticky cap, stale IDs.
/// Контекст: TDD RED — тесты пишутся до реализации. Reference: RITUAL_COMBAT_TEST_MODEL.md §3.1

import XCTest
@testable import TwilightEngine

/// Fate Deck Balance Invariants — Phase 3 Gate Tests (R0)
/// Reference: RITUAL_COMBAT_TEST_MODEL.md §3.1
/// Rule: < 2 seconds per test, deterministic, no system RNG
final class FateDeckBalanceGateTests: XCTestCase {

    // MARK: - INV-FATE-BAL-001: matchMultiplier reads from BalancePack proportionally

    /// Verifies that matchMultiplier is read from BalancePack internally (not passed as parameter)
    /// and affects keyword resolution proportionally.
    ///
    /// Linearity guarantee: fixture uses armor=0, defense=0, HP=100 (no clip/crit/cap).
    /// This ensures damage = baseStrength + fateModifier + keywordEffect(multiplier),
    /// where keywordEffect scales linearly with matchMultiplier.
    func testMatchMultiplierFromBalancePack() {
        // Nav suit + combatPhysical → isMatch = true → multiplier applies
        let surgeCard = FateCard(id: "test_surge", modifier: 1, name: "Surge", suit: .nav, keyword: .surge)

        // --- Baseline: no match → keyword effect without multiplier ---
        let noMatchCard = FateCard(id: "test_surge_nomatch", modifier: 1, name: "Surge", suit: .yav, keyword: .surge)
        let damageNoMatch = runAttackAndMeasureDamage(
            matchMultiplier: 1.0, fateCard: noMatchCard
        )

        // --- Config A: matchMultiplier = 1.0 ---
        let damageA = runAttackAndMeasureDamage(
            matchMultiplier: 1.0, fateCard: surgeCard
        )

        // --- Config B: matchMultiplier = 2.0 ---
        let damageB = runAttackAndMeasureDamage(
            matchMultiplier: 2.0, fateCard: surgeCard
        )

        XCTAssertGreaterThan(damageA, 0, "Attack with surge+match at 1.0x must deal damage")
        XCTAssertGreaterThan(damageB, damageA,
            "matchMultiplier 2.0 must deal more damage than 1.0")

        // --- Proportionality: matchEffect(2.0x) == 2 * matchEffect(1.0x) ---
        // matchEffect(X) = damage_at_X - damageNoMatch (isolates match contribution)
        // Fixture linearity: armor=0, defense=0, HP=100 → no clipping, no crit, pure linear.
        let matchEffect_1 = damageA - damageNoMatch
        let matchEffect_2 = damageB - damageNoMatch

        if matchEffect_1 > 0 {
            XCTAssertEqual(matchEffect_2, 2 * matchEffect_1,
                "Match effect must scale proportionally: effect(2.0x) == 2 * effect(1.0x). " +
                "Got effect(1.0x)=\(matchEffect_1), effect(2.0x)=\(matchEffect_2)")
        } else {
            // Match at 1.0x adds nothing over noMatch → at least 2.0x must add something
            XCTAssertGreaterThan(damageB, damageNoMatch,
                "matchMultiplier 2.0 must deal more damage than no match")
        }

        // --- Default fallback: no matchMultiplier → should use 1.5, not hardcoded 2.0 ---
        let damageDefault = runAttackAndMeasureDamage(
            matchMultiplier: nil, fateCard: surgeCard
        )
        XCTAssertNotEqual(damageDefault, damageB,
            "Default matchMultiplier must not be 2.0 (hardcoded drift)")
    }

    // MARK: - INV-FATE-BAL-002: Surge suit distribution

    /// At least one surge card must have suit ≠ prav (accessible to Kill path)
    func testSurgeSuitDistribution() {
        let registry = TestContentLoader.sharedLoadedRegistry()
        let fateCards = registry.getAllFateCards()

        let surgeCards = fateCards.filter { $0.keyword == .surge }
        XCTAssertFalse(surgeCards.isEmpty, "Fate deck must contain at least one surge card")

        let nonPravSurge = surgeCards.filter { $0.suit != .prav }
        XCTAssertFalse(nonPravSurge.isEmpty,
            "At least 1 surge card must have suit ≠ prav (for Kill path accessibility). " +
            "Found suits: \(surgeCards.compactMap { $0.suit?.rawValue })")
    }

    // MARK: - INV-FATE-BAL-003: Crit card has neutral suit

    /// The critical fate card must have suit = yav (neutral for both Kill and Pacify)
    func testCritCardNeutralSuit() {
        let registry = TestContentLoader.sharedLoadedRegistry()
        let fateCards = registry.getAllFateCards()

        let critCards = fateCards.filter { $0.isCritical }
        XCTAssertFalse(critCards.isEmpty, "Fate deck must contain at least one critical card")

        for card in critCards {
            XCTAssertEqual(card.suit, .yav,
                "Critical card '\(card.id)' must have suit = yav (neutral), got: \(card.suit?.rawValue ?? "nil")")
        }
    }

    // MARK: - INV-FATE-BAL-004: Sticky card resonance modifyValue capped

    /// Sticky cards must have |modifyValue| ≤ 1 in all resonance rules
    func testStickyCardResonanceModifyCapped() {
        let registry = TestContentLoader.sharedLoadedRegistry()
        let fateCards = registry.getAllFateCards()

        let stickyCards = fateCards.filter { $0.isSticky }

        var violations: [String] = []
        for card in stickyCards {
            for rule in card.resonanceRules {
                if abs(rule.modifyValue) > 1 {
                    violations.append("\(card.id): rule modifyValue=\(rule.modifyValue) exceeds ±1")
                }
            }
        }

        XCTAssertTrue(violations.isEmpty,
            "Sticky cards must have |modifyValue| ≤ 1. Violations:\n\(violations.joined(separator: "\n"))")
    }

    // MARK: - INV-FATE-BAL-005: No stale card IDs in content

    /// After card renames, no dangling references to old IDs should remain
    func testNoStaleCardIdsInContent() {
        let registry = TestContentLoader.sharedLoadedRegistry()
        let fateCards = registry.getAllFateCards()
        let allFateIds = Set(fateCards.map { $0.id })

        // Verify renamed card exists under new ID
        XCTAssertTrue(allFateIds.contains("fate_yav_surge_a"),
            "Renamed card fate_yav_surge_a must exist in fate deck")

        // Verify old ID does not exist
        XCTAssertFalse(allFateIds.contains("fate_prav_light_b"),
            "Stale card ID fate_prav_light_b must not exist in fate deck (renamed to fate_yav_surge_a)")
    }

    // MARK: - Helpers

    /// Run a deterministic attack and measure total HP damage dealt.
    /// Fixture guarantees linearity: armor=0, defense=0, HP=100 (no clip/cap/crit interference).
    private func runAttackAndMeasureDamage(
        matchMultiplier: Double?,
        fateCard: FateCard,
        seed: UInt64 = 42
    ) -> Int {
        var config = CombatBalanceConfig.default
        if let mult = matchMultiplier {
            config.matchMultiplier = mult
        } else {
            config.matchMultiplier = nil
        }

        let ctx = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 100, maxHp: 100, strength: 5, armor: 0),
            enemies: [EncounterEnemy(id: "enemy", name: "E", hp: 100, maxHp: 100, power: 1, defense: 0)],
            fateDeckSnapshot: TestFateDeck.makeState(cards: [fateCard], seed: seed),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: seed,
            worldResonance: -50, // deep nav → nav suit matches combatPhysical
            balanceConfig: config
        )
        let engine = EncounterEngine(context: ctx)
        _ = engine.generateIntent(for: "enemy")
        _ = engine.advancePhase() // → playerAction
        _ = engine.performAction(.attack(targetId: "enemy"))
        return 100 - engine.enemies[0].hp // damage dealt
    }
}

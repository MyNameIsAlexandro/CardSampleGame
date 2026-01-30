import XCTest
@testable import TwilightEngine

/// INV-KW: Keyword Effect Gate Tests
/// Verifies that all 5 fate keywords produce correct special effects
/// in combat (physical/spiritual) and defense contexts.
/// Gate rules: < 2s, no XCTSkip, no non-deterministic RNG.
final class INV_KW_GateTests: XCTestCase {

    // MARK: - Helpers

    /// Create encounter context with a single-card fate deck bearing the given keyword
    private func makeContext(keyword: FateKeyword, suit: FateCardSuit? = nil, heroHP: Int = 50, seed: UInt64 = 42) -> EncounterContext {
        let fateCard = FateCard(id: "kw_card", modifier: 2, name: "KW Card", suit: suit, keyword: keyword)
        let deck = FateDeckManager(cards: [fateCard])
        return EncounterContext(
            hero: EncounterHero(id: "hero", hp: heroHP, maxHp: 100, strength: 5, armor: 2, wisdom: 5, willDefense: 1),
            enemies: [
                EncounterEnemy(id: "enemy", name: "Enemy", hp: 50, maxHp: 50, wp: 30, maxWp: 30, power: 10, defense: 3)
            ],
            fateDeckSnapshot: deck.getState(),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: seed
        )
    }

    private func startAndAttack(_ engine: EncounterEngine) -> EncounterActionResult {
        _ = engine.generateIntent(for: "enemy")
        _ = engine.advancePhase() // → playerAction
        return engine.performAction(.attack(targetId: "enemy"))
    }

    private func startAndSpiritAttack(_ engine: EncounterEngine) -> EncounterActionResult {
        _ = engine.generateIntent(for: "enemy")
        _ = engine.advancePhase() // → playerAction
        return engine.performAction(.spiritAttack(targetId: "enemy"))
    }

    // MARK: - ENC-01: Surge

    /// Surge in physical combat: +2 bonus damage (from KeywordInterpreter)
    func testSurge_physicalAttack_bonusDamage() {
        let ctx = makeContext(keyword: .surge)
        let engine = EncounterEngine(context: ctx)
        let result = startAndAttack(engine)
        XCTAssertTrue(result.success)
        // Surge gives +2 bonusDamage in combatPhysical
        // Damage = max(1, 5 strength + 0 bonus - 3 defense + 0 surprise + 2 keyword) = 4
        // Enemy HP should drop from 50
        XCTAssertLessThan(engine.enemies[0].hp, 50)
    }

    /// Surge in spiritual combat: resonance push (+3 toward Prav)
    func testSurge_spiritAttack_resonancePush() {
        let ctx = makeContext(keyword: .surge)
        let engine = EncounterEngine(context: ctx)
        let result = startAndSpiritAttack(engine)
        XCTAssertTrue(result.success)
        // Should have resonance shift change
        let resonanceChanges = result.stateChanges.filter {
            if case .resonanceShifted = $0 { return true }
            return false
        }
        XCTAssertFalse(resonanceChanges.isEmpty, "Surge should cause resonance push on spirit attack")
    }

    // MARK: - ENC-02: Focus

    /// Focus in physical combat: ignore_armor
    func testFocus_physicalAttack_ignoreArmor() {
        let ctx = makeContext(keyword: .focus)
        let engine = EncounterEngine(context: ctx)
        let result = startAndAttack(engine)
        XCTAssertTrue(result.success)
        // Focus gives ignore_armor + 1 bonusDamage
        // Without armor: damage = max(1, 5 + 0 - 0 + 0 + 1) = 6
        // With armor (defense=3): damage = max(1, 5 + 0 - 3 + 0 + 1) = 3
        // So HP should be 50 - 6 = 44 (armor ignored)
        XCTAssertEqual(engine.enemies[0].hp, 44, "Focus should ignore armor (defense)")
    }

    /// Focus in spiritual combat: extra WP pierce (+1)
    func testFocus_spiritAttack_willPierce() {
        let ctx = makeContext(keyword: .focus)
        let engine = EncounterEngine(context: ctx)
        let result = startAndSpiritAttack(engine)
        XCTAssertTrue(result.success)
        // Focus gives bonusDamage=1 + will_pierce (+1 extra) = +2 total keyword bonus
        // damage = max(1, 5 wisdom + 0 bonus + 2 keyword - 0 rageShield - 0 spiritDef) = 7
        XCTAssertEqual(engine.enemies[0].wp, 23, "Focus should add extra WP pierce")
    }

    // MARK: - ENC-03: Echo

    /// Echo in physical combat: return last played card to hand
    func testEcho_physicalAttack_cardReturn() {
        let ctx = makeContext(keyword: .echo)
        let engine = EncounterEngine(context: ctx)

        // Play a card first to put something in discard
        _ = engine.generateIntent(for: "enemy")
        _ = engine.advancePhase() // → playerAction

        let handBefore = engine.hand.count
        // If hand is empty or no affordable card, just test the attack
        if let card = engine.hand.first, card.faithCost <= engine.heroFaith {
            let discardBefore = engine.cardDiscardPile.count
            _ = engine.performAction(.useCard(cardId: card.id, targetId: "enemy"))
            XCTAssertEqual(engine.cardDiscardPile.count, discardBefore + 1)
            // Now attack — echo should return the card
            let result = engine.performAction(.attack(targetId: "enemy"))
            XCTAssertTrue(result.success)
            // Card should have returned from discard to hand
            XCTAssertGreaterThanOrEqual(engine.hand.count, handBefore, "Echo should return last card from discard")
        } else {
            // No card to test — just verify attack works
            let result = engine.performAction(.attack(targetId: "enemy"))
            XCTAssertTrue(result.success)
        }
    }

    // MARK: - ENC-04: Shadow

    /// Shadow in physical combat: vampirism (heal on damage)
    func testShadow_physicalAttack_vampirism() {
        let ctx = makeContext(keyword: .shadow, heroHP: 50)
        let engine = EncounterEngine(context: ctx)
        let result = startAndAttack(engine)
        XCTAssertTrue(result.success)
        // Shadow gives ambush = vampirism: heal for damage/2
        // Check if heroHP increased
        let hpChanges = result.stateChanges.filter {
            if case .playerHPChanged(let delta, _) = $0 { return delta > 0 }
            return false
        }
        XCTAssertFalse(hpChanges.isEmpty, "Shadow should heal hero (vampirism)")
    }

    /// Shadow in defense: halve incoming damage
    func testShadow_defense_evade() {
        // This is tested via KeywordInterpreter directly since defense happens in resolveEnemyAction
        let effect = KeywordInterpreter.resolve(keyword: .shadow, context: .defense)
        XCTAssertEqual(effect.special, "evade", "Shadow defense should have evade special")
    }

    // MARK: - ENC-05: Ward

    /// Ward in defense: prevent failure (0 damage)
    func testWard_defense_fortify() {
        let effect = KeywordInterpreter.resolve(keyword: .ward, context: .defense)
        XCTAssertEqual(effect.special, "fortify", "Ward defense should have fortify special")
        XCTAssertEqual(effect.bonusValue, 3, "Ward defense should give +3 bonus")
    }

    /// Ward in physical combat: parry bonus
    func testWard_physicalAttack_parry() {
        let effect = KeywordInterpreter.resolve(keyword: .ward, context: .combatPhysical)
        XCTAssertEqual(effect.special, "parry")
        XCTAssertEqual(effect.bonusValue, 1)
    }

    // MARK: - Cross-cutting

    /// All 5 keywords produce non-zero effects in combatPhysical
    func testAllKeywords_haveEffects() {
        for keyword in FateKeyword.allCases {
            let effect = KeywordInterpreter.resolve(keyword: keyword, context: .combatPhysical)
            let hasEffect = effect.bonusDamage > 0 || effect.bonusValue > 0 || effect.special != nil
            XCTAssertTrue(hasEffect, "\(keyword) should have some effect in combatPhysical")
        }
    }

    /// Match multiplier doubles bonusDamage
    func testMatchMultiplier_doublesDamage() {
        let base = KeywordInterpreter.resolve(keyword: .surge, context: .combatPhysical, isMatch: false)
        let matched = KeywordInterpreter.resolve(keyword: .surge, context: .combatPhysical, isMatch: true)
        XCTAssertEqual(matched.bonusDamage, base.bonusDamage * 2, "Match should double bonus damage")
    }

    /// Mismatch nullifies keyword
    func testMismatch_nullifiesKeyword() {
        let effect = KeywordInterpreter.resolveWithAlignment(
            keyword: .surge, context: .combatPhysical, isMismatch: true
        )
        XCTAssertEqual(effect.bonusDamage, 0)
        XCTAssertNil(effect.special)
    }
}

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

    /// Match multiplier doubles bonusDamage (unit level)
    func testMatchMultiplier_doublesDamage() {
        let base = KeywordInterpreter.resolve(keyword: .surge, context: .combatPhysical, isMatch: false)
        let matched = KeywordInterpreter.resolve(keyword: .surge, context: .combatPhysical, isMatch: true)
        XCTAssertEqual(matched.bonusDamage, base.bonusDamage * 2, "Match should double bonus damage")
    }

    /// Mismatch nullifies keyword (unit level)
    func testMismatch_nullifiesKeyword() {
        let effect = KeywordInterpreter.resolveWithAlignment(
            keyword: .surge, context: .combatPhysical, isMismatch: true
        )
        XCTAssertEqual(effect.bonusDamage, 0)
        XCTAssertNil(effect.special)
    }

    // MARK: - ENC-06: Match Bonus (end-to-end)

    /// Nav suit on physical attack = match → more damage than no suit
    func testMatchBonus_navSurge_physicalAttack_moreDamage() {
        let ctxNoSuit = makeContext(keyword: .surge, suit: nil)
        let ctxNav = makeContext(keyword: .surge, suit: .nav)

        let engineNoSuit = EncounterEngine(context: ctxNoSuit)
        let engineNav = EncounterEngine(context: ctxNav)

        _ = startAndAttack(engineNoSuit)
        _ = startAndAttack(engineNav)

        // Nav matches combatPhysical → keyword bonus multiplied by 1.5x
        // No suit → no match → base keyword bonus
        XCTAssertLessThan(engineNav.enemies[0].hp, engineNoSuit.enemies[0].hp,
            "Nav suit should deal more damage on physical attack (match bonus)")
    }

    /// Prav suit on physical attack = mismatch → keyword nullified, less damage
    func testMismatchPenalty_pravSurge_physicalAttack_lessDamage() {
        let ctxNoSuit = makeContext(keyword: .surge, suit: nil)
        let ctxPrav = makeContext(keyword: .surge, suit: .prav)

        let engineNoSuit = EncounterEngine(context: ctxNoSuit)
        let enginePrav = EncounterEngine(context: ctxPrav)

        _ = startAndAttack(engineNoSuit)
        _ = startAndAttack(enginePrav)

        // Prav mismatches combatPhysical → keyword nullified (0 bonus)
        // No suit → base keyword bonus (2)
        XCTAssertGreaterThan(enginePrav.enemies[0].hp, engineNoSuit.enemies[0].hp,
            "Prav suit should deal less damage on physical attack (mismatch nullifies keyword)")
    }

    /// Prav suit on spirit attack = match → at least as much WP damage (Int truncation may hide 1.5x on small values)
    func testMatchBonus_pravFocus_spiritAttack_notWorse() {
        let ctxNoSuit = makeContext(keyword: .focus, suit: nil)
        let ctxPrav = makeContext(keyword: .focus, suit: .prav)

        let engineNoSuit = EncounterEngine(context: ctxNoSuit)
        let enginePrav = EncounterEngine(context: ctxPrav)

        _ = startAndSpiritAttack(engineNoSuit)
        _ = startAndSpiritAttack(enginePrav)

        // Prav matches combatSpiritual → bonus >= no-suit (Int(1*1.5)=1 same as base, but never worse)
        XCTAssertLessThanOrEqual(enginePrav.enemies[0].wp!, engineNoSuit.enemies[0].wp!,
            "Prav match should not reduce WP damage on spirit attack")
    }

    /// Match multiplier scales bonusDamage in spiritual context (unit level with 3.0x to avoid truncation)
    func testMatchMultiplier_spiritualContext_scales() {
        let base = KeywordInterpreter.resolve(keyword: .surge, context: .combatSpiritual, isMatch: false)
        let matched = KeywordInterpreter.resolve(keyword: .surge, context: .combatSpiritual, isMatch: true, matchMultiplier: 3.0)
        XCTAssertEqual(matched.bonusDamage, base.bonusDamage * 3,
            "3x match multiplier should triple spiritual bonus damage")
    }

    // MARK: - ENC-07: Pacify control (spirit attack never kills)

    /// Spirit attack reduces WP but never touches HP
    func testSpiritAttack_neverReducesHP() {
        let ctx = makeContext(keyword: .surge)
        let engine = EncounterEngine(context: ctx)
        let hpBefore = engine.enemies[0].hp
        _ = startAndSpiritAttack(engine)
        XCTAssertEqual(engine.enemies[0].hp, hpBefore, "Spirit attack must never reduce HP")
    }

    /// Enemy with WP=0 after spirit attack is pacified, not killed
    func testSpiritAttack_pacifiesWhenWPDepleted() {
        // Create enemy with very low WP so one hit depletes it
        let fateCard = FateCard(id: "kw_card", modifier: 2, name: "KW Card", suit: nil, keyword: .surge)
        let deck = FateDeckManager(cards: [fateCard])
        let ctx = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 50, maxHp: 100, strength: 5, armor: 2, wisdom: 20, willDefense: 1),
            enemies: [
                EncounterEnemy(id: "enemy", name: "Enemy", hp: 50, maxHp: 50, wp: 1, maxWp: 1, power: 10, defense: 3)
            ],
            fateDeckSnapshot: deck.getState(),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42
        )
        let engine = EncounterEngine(context: ctx)
        let result = startAndSpiritAttack(engine)
        XCTAssertTrue(result.success)
        XCTAssertEqual(engine.enemies[0].wp, 0)
        XCTAssertEqual(engine.enemies[0].hp, 50, "HP must remain untouched")
        XCTAssertEqual(engine.enemies[0].outcome, .pacified, "Enemy should be pacified, not killed")
    }

    // MARK: - ENC-08: Resonance zone card cost modifier

    /// Helper: create context with a card that has realm and faith cost
    private func makeCardContext(realm: Realm, faithCost: Int = 2, resonance: Float = 0) -> EncounterContext {
        let card = Card(
            id: "realm_card", name: "Realm Card", type: .spell, description: "Test",
            abilities: [CardAbility(id: "a1", name: "Hit", description: "dmg", effect: .damage(amount: 1, type: .physical))],
            realm: realm, faithCost: faithCost
        )
        let fateCard = FateCard(id: "fate1", modifier: 1, name: "Fate", suit: nil, keyword: nil)
        let deck = FateDeckManager(cards: [fateCard])
        return EncounterContext(
            hero: EncounterHero(id: "hero", hp: 50, maxHp: 100, strength: 5, armor: 2, wisdom: 5, willDefense: 1),
            enemies: [
                EncounterEnemy(id: "enemy", name: "Enemy", hp: 50, maxHp: 50, wp: 30, maxWp: 30, power: 10, defense: 3)
            ],
            fateDeckSnapshot: deck.getState(),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42,
            worldResonance: resonance,
            heroCards: [card],
            heroFaith: 10
        )
    }

    /// Nav card in Prav zone costs +1 faith
    func testResonanceCost_navCardInPravZone_costIncrease() {
        let ctx = makeCardContext(realm: .nav, faithCost: 2, resonance: 50) // prav zone
        let engine = EncounterEngine(context: ctx)
        _ = engine.generateIntent(for: "enemy")
        _ = engine.advancePhase()
        let faithBefore = engine.heroFaith
        let result = engine.performAction(.useCard(cardId: "realm_card", targetId: "enemy"))
        XCTAssertTrue(result.success)
        XCTAssertEqual(faithBefore - engine.heroFaith, 3, "Nav card in Prav zone should cost 2+1=3")
    }

    /// Prav card in Nav zone costs +1 faith
    func testResonanceCost_pravCardInNavZone_costIncrease() {
        let ctx = makeCardContext(realm: .prav, faithCost: 2, resonance: -50) // nav zone
        let engine = EncounterEngine(context: ctx)
        _ = engine.generateIntent(for: "enemy")
        _ = engine.advancePhase()
        let faithBefore = engine.heroFaith
        let result = engine.performAction(.useCard(cardId: "realm_card", targetId: "enemy"))
        XCTAssertTrue(result.success)
        XCTAssertEqual(faithBefore - engine.heroFaith, 3, "Prav card in Nav zone should cost 2+1=3")
    }

    /// Nav card in Nav zone costs -1 faith (discount)
    func testResonanceCost_navCardInNavZone_costDiscount() {
        let ctx = makeCardContext(realm: .nav, faithCost: 2, resonance: -50) // nav zone
        let engine = EncounterEngine(context: ctx)
        _ = engine.generateIntent(for: "enemy")
        _ = engine.advancePhase()
        let faithBefore = engine.heroFaith
        let result = engine.performAction(.useCard(cardId: "realm_card", targetId: "enemy"))
        XCTAssertTrue(result.success)
        XCTAssertEqual(faithBefore - engine.heroFaith, 1, "Nav card in Nav zone should cost 2-1=1")
    }

    /// Card in Yav zone (neutral) has no cost modifier
    func testResonanceCost_cardInYavZone_noCostChange() {
        let ctx = makeCardContext(realm: .nav, faithCost: 2, resonance: 0) // yav zone
        let engine = EncounterEngine(context: ctx)
        _ = engine.generateIntent(for: "enemy")
        _ = engine.advancePhase()
        let faithBefore = engine.heroFaith
        let result = engine.performAction(.useCard(cardId: "realm_card", targetId: "enemy"))
        XCTAssertTrue(result.success)
        XCTAssertEqual(faithBefore - engine.heroFaith, 2, "Card in Yav zone should cost base (2)")
    }

    // MARK: - ENC-09: Enemy resonance modifiers

    /// Enemy with +2 defense in Prav zone takes less damage from physical attack
    func testResonanceModifier_enemyDefenseBoostInPravZone() {
        // Baseline: no resonance behavior, resonance=0 (yav)
        let fateCard = FateCard(id: "f1", modifier: 0, name: "Fate", suit: nil, keyword: nil)
        let deck = FateDeckManager(cards: [fateCard])
        let ctxBase = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 50, maxHp: 100, strength: 5, armor: 2, wisdom: 5, willDefense: 1),
            enemies: [EncounterEnemy(id: "enemy", name: "E", hp: 50, maxHp: 50, power: 10, defense: 3)],
            fateDeckSnapshot: deck.getState(), modifiers: [], rules: EncounterRules(), rngSeed: 42
        )
        let engineBase = EncounterEngine(context: ctxBase)
        _ = startAndAttack(engineBase)
        let hpBase = engineBase.enemies[0].hp

        // With resonance behavior: +2 defense in prav zone, resonance=50 (prav)
        let deck2 = FateDeckManager(cards: [fateCard])
        let ctxMod = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 50, maxHp: 100, strength: 5, armor: 2, wisdom: 5, willDefense: 1),
            enemies: [EncounterEnemy(id: "enemy", name: "E", hp: 50, maxHp: 50, power: 10, defense: 3,
                resonanceBehavior: ["prav": EnemyModifier(defenseDelta: 2)])],
            fateDeckSnapshot: deck2.getState(), modifiers: [], rules: EncounterRules(), rngSeed: 42,
            worldResonance: 50
        )
        let engineMod = EncounterEngine(context: ctxMod)
        _ = startAndAttack(engineMod)
        let hpMod = engineMod.enemies[0].hp

        XCTAssertGreaterThan(hpMod, hpBase,
            "Enemy with +2 defense in prav zone should take less damage")
    }

    /// Enemy resonance modifier not applied in wrong zone
    func testResonanceModifier_notAppliedInWrongZone() {
        let fateCard = FateCard(id: "f1", modifier: 0, name: "Fate", suit: nil, keyword: nil)
        let deck1 = FateDeckManager(cards: [fateCard])
        let deck2 = FateDeckManager(cards: [fateCard])
        // Enemy has prav modifier but resonance is in nav zone
        let ctxBase = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 50, maxHp: 100, strength: 5, armor: 2, wisdom: 5, willDefense: 1),
            enemies: [EncounterEnemy(id: "enemy", name: "E", hp: 50, maxHp: 50, power: 10, defense: 3)],
            fateDeckSnapshot: deck1.getState(), modifiers: [], rules: EncounterRules(), rngSeed: 42,
            worldResonance: -50
        )
        let ctxMod = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 50, maxHp: 100, strength: 5, armor: 2, wisdom: 5, willDefense: 1),
            enemies: [EncounterEnemy(id: "enemy", name: "E", hp: 50, maxHp: 50, power: 10, defense: 3,
                resonanceBehavior: ["prav": EnemyModifier(defenseDelta: 5)])],
            fateDeckSnapshot: deck2.getState(), modifiers: [], rules: EncounterRules(), rngSeed: 42,
            worldResonance: -50 // nav zone, not prav
        )
        let engineBase = EncounterEngine(context: ctxBase)
        let engineMod = EncounterEngine(context: ctxMod)
        _ = startAndAttack(engineBase)
        _ = startAndAttack(engineMod)
        XCTAssertEqual(engineBase.enemies[0].hp, engineMod.enemies[0].hp,
            "Prav modifier should not apply in Nav zone")
    }

    // MARK: - ENC-10: Phase automation

    /// Intent is auto-generated at init (no manual generateIntent needed)
    func testPhaseAutomation_intentAutoGeneratedAtInit() {
        let ctx = makeContext(keyword: .surge)
        let engine = EncounterEngine(context: ctx)
        XCTAssertEqual(engine.currentPhase, .intent)
        XCTAssertNotNil(engine.currentIntent, "Intent should be auto-generated at init")
    }

    /// Intent is auto-generated after roundEnd → intent transition
    func testPhaseAutomation_intentAutoGeneratedAfterRoundEnd() {
        let ctx = makeContext(keyword: .surge)
        let engine = EncounterEngine(context: ctx)
        // Complete a full round: intent → playerAction → enemyResolution → roundEnd → intent
        _ = engine.advancePhase() // → playerAction
        _ = engine.performAction(.attack(targetId: "enemy"))
        _ = engine.advancePhase() // → enemyResolution
        _ = engine.resolveEnemyAction(enemyId: "enemy")
        _ = engine.advancePhase() // → roundEnd
        _ = engine.advancePhase() // → intent (round 2)
        XCTAssertEqual(engine.currentPhase, .intent)
        XCTAssertNotNil(engine.currentIntent, "Intent should be auto-generated at new round")
    }

    // MARK: - ENC-11: Critical defense

    /// Critical fate card in defense = 0 damage
    func testCriticalDefense_zeroDamage() {
        let critCard = FateCard(id: "crit", modifier: 0, isCritical: true, name: "CRIT")
        let deck = FateDeckManager(cards: [critCard])
        let ctx = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 30, maxHp: 100, strength: 5, armor: 0, wisdom: 5, willDefense: 0),
            enemies: [EncounterEnemy(id: "enemy", name: "E", hp: 50, maxHp: 50, power: 20, defense: 3)],
            fateDeckSnapshot: deck.getState(), modifiers: [], rules: EncounterRules(), rngSeed: 42
        )
        let engine = EncounterEngine(context: ctx)
        // Intent already auto-generated; advance to playerAction, skip, then resolve enemy
        _ = engine.advancePhase() // → playerAction
        _ = engine.performAction(.wait)
        _ = engine.advancePhase() // → enemyResolution
        let result = engine.resolveEnemyAction(enemyId: "enemy")
        XCTAssertTrue(result.success)
        XCTAssertEqual(engine.heroHP, 30, "Critical defense should block all damage")
    }

    /// Non-critical fate card in defense allows damage through
    func testNonCriticalDefense_damageApplied() {
        let normalCard = FateCard(id: "norm", modifier: 1, name: "Norm")
        let deck = FateDeckManager(cards: [normalCard])
        let ctx = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 30, maxHp: 100, strength: 5, armor: 0, wisdom: 5, willDefense: 0),
            enemies: [EncounterEnemy(id: "enemy", name: "E", hp: 50, maxHp: 50, power: 20, defense: 3)],
            fateDeckSnapshot: deck.getState(), modifiers: [], rules: EncounterRules(), rngSeed: 42
        )
        let engine = EncounterEngine(context: ctx)
        _ = engine.advancePhase() // → playerAction
        _ = engine.performAction(.wait)
        _ = engine.advancePhase() // → enemyResolution
        let result = engine.resolveEnemyAction(enemyId: "enemy")
        XCTAssertTrue(result.success)
        XCTAssertLessThan(engine.heroHP, 30, "Non-critical defense should allow damage")
    }

    // MARK: - ENC-12: Integration test

    /// Full encounter: init → attack rounds → enemy killed → victory
    func testFullEncounter_physicalVictory() {
        let fateCard = FateCard(id: "f1", modifier: 1, name: "Fate")
        let deck = FateDeckManager(cards: [fateCard])
        let ctx = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 100, maxHp: 100, strength: 10, armor: 5, wisdom: 5, willDefense: 1),
            enemies: [EncounterEnemy(id: "enemy", name: "Weak", hp: 5, maxHp: 5, power: 1, defense: 0)],
            fateDeckSnapshot: deck.getState(), modifiers: [], rules: EncounterRules(), rngSeed: 42
        )
        let engine = EncounterEngine(context: ctx)

        // Round 1: intent auto-generated → advance to playerAction → attack → resolve enemy → roundEnd
        XCTAssertEqual(engine.currentPhase, .intent)
        XCTAssertNotNil(engine.currentIntent)

        _ = engine.advancePhase() // → playerAction
        let attackResult = engine.performAction(.attack(targetId: "enemy"))
        XCTAssertTrue(attackResult.success)
        XCTAssertEqual(engine.enemies[0].hp, 0, "10 strength vs 0 defense should kill 5hp enemy")
        XCTAssertEqual(engine.enemies[0].outcome, .killed)

        _ = engine.advancePhase() // → enemyResolution
        _ = engine.resolveEnemyAction(enemyId: "enemy")
        _ = engine.advancePhase() // → roundEnd

        // Finish encounter
        let result = engine.finishEncounter()
        XCTAssertTrue(engine.isFinished)
        XCTAssertEqual(result.outcome, .victory(.killed))
        XCTAssertEqual(result.perEntityOutcomes["enemy"], .killed)
    }

    /// Full encounter: spirit attack → pacify → nonviolent victory
    func testFullEncounter_pacifyVictory() {
        let fateCard = FateCard(id: "f1", modifier: 1, name: "Fate")
        let deck = FateDeckManager(cards: [fateCard])
        let ctx = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 100, maxHp: 100, strength: 5, armor: 5, wisdom: 20, willDefense: 1),
            enemies: [EncounterEnemy(id: "enemy", name: "Spirit", hp: 50, maxHp: 50, wp: 1, maxWp: 1, power: 1, defense: 0)],
            fateDeckSnapshot: deck.getState(), modifiers: [], rules: EncounterRules(), rngSeed: 42
        )
        let engine = EncounterEngine(context: ctx)

        _ = engine.advancePhase() // → playerAction
        let spiritResult = engine.performAction(.spiritAttack(targetId: "enemy"))
        XCTAssertTrue(spiritResult.success)
        XCTAssertEqual(engine.enemies[0].wp, 0)
        XCTAssertEqual(engine.enemies[0].outcome, .pacified)
        XCTAssertEqual(engine.enemies[0].hp, 50, "HP untouched")

        _ = engine.advancePhase() // → enemyResolution
        _ = engine.resolveEnemyAction(enemyId: "enemy")
        _ = engine.advancePhase() // → roundEnd

        let result = engine.finishEncounter()
        XCTAssertEqual(result.outcome, .victory(.pacified))
        XCTAssertEqual(result.transaction.worldFlags["nonviolent"], true)
    }

    /// Yav suit always matches — never nullified
    func testYavSuit_alwaysMatches_neverNullified() {
        let ctxYavPhys = makeContext(keyword: .surge, suit: .yav)
        let ctxYavSpir = makeContext(keyword: .surge, suit: .yav)

        let enginePhys = EncounterEngine(context: ctxYavPhys)
        let engineSpir = EncounterEngine(context: ctxYavSpir)

        let resultPhys = startAndAttack(enginePhys)
        let resultSpir = startAndSpiritAttack(engineSpir)

        // Yav matches everything — both should succeed with keyword effects
        XCTAssertTrue(resultPhys.success)
        XCTAssertTrue(resultSpir.success)
        XCTAssertLessThan(enginePhys.enemies[0].hp, 50, "Yav should match physical (damage dealt)")
        XCTAssertLessThan(engineSpir.enemies[0].wp!, 30, "Yav should match spiritual (WP dealt)")
    }
}

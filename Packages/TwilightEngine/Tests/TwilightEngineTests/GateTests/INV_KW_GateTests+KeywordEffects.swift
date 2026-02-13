/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/INV_KW_GateTests+KeywordEffects.swift
/// Назначение: Содержит реализацию файла INV_KW_GateTests+KeywordEffects.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import TwilightEngine

extension INV_KW_GateTests {
    // MARK: - ENC-01: Surge

    /// Surge in physical combat: +2 bonus damage (from KeywordInterpreter)
    func testSurge_physicalAttack_bonusDamage() {
        let ctx = makeContext(keyword: .surge)
        let engine = EncounterEngine(context: ctx)
        let result = startAndAttack(engine)
        XCTAssertTrue(result.success)
        XCTAssertLessThan(engine.enemies[0].hp, 50)
    }

    /// Surge in spiritual combat: resonance push (+3 toward Prav)
    func testSurge_spiritAttack_resonancePush() {
        let ctx = makeContext(keyword: .surge)
        let engine = EncounterEngine(context: ctx)
        let result = startAndSpiritAttack(engine)
        XCTAssertTrue(result.success)
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
        XCTAssertEqual(engine.enemies[0].hp, 44, "Focus should ignore armor (defense)")
    }

    /// Focus in spiritual combat: extra WP pierce (+1)
    func testFocus_spiritAttack_willPierce() {
        let ctx = makeContext(keyword: .focus)
        let engine = EncounterEngine(context: ctx)
        let result = startAndSpiritAttack(engine)
        XCTAssertTrue(result.success)
        XCTAssertEqual(engine.enemies[0].wp, 23, "Focus should add extra WP pierce")
    }

    // MARK: - ENC-03: Echo

    /// Echo in physical combat: return last played card to hand
    func testEcho_physicalAttack_cardReturn() {
        let ctx = makeContext(keyword: .echo)
        let engine = EncounterEngine(context: ctx)

        _ = engine.generateIntent(for: "enemy")
        _ = engine.advancePhase() // → playerAction

        let handBefore = engine.hand.count
        if let card = engine.hand.first, card.faithCost <= engine.heroFaith {
            let discardBefore = engine.cardDiscardPile.count
            _ = engine.performAction(.useCard(cardId: card.id, targetId: "enemy"))
            XCTAssertEqual(engine.cardDiscardPile.count, discardBefore + 1)
            let result = engine.performAction(.attack(targetId: "enemy"))
            XCTAssertTrue(result.success)
            XCTAssertGreaterThanOrEqual(engine.hand.count, handBefore, "Echo should return last card from discard")
        } else {
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
        let hpChanges = result.stateChanges.filter {
            if case .playerHPChanged(let delta, _) = $0 { return delta > 0 }
            return false
        }
        XCTAssertFalse(hpChanges.isEmpty, "Shadow should heal hero (vampirism)")
    }

    /// Shadow in defense: halve incoming damage
    func testShadow_defense_evade() {
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

        XCTAssertLessThanOrEqual(enginePrav.enemies[0].wp!, engineNoSuit.enemies[0].wp!,
            "Prav match should not reduce WP damage on spirit attack")
    }

    /// Match multiplier scales bonusDamage in spiritual context (unit level with 3.0x to avoid truncation)
    func testMatchMultiplier_spiritualContext_scales() {
        let base = KeywordInterpreter.resolve(keyword: .surge, context: .combatSpiritual, isMatch: false)
        let matched = KeywordInterpreter.resolve(
            keyword: .surge,
            context: .combatSpiritual,
            isMatch: true,
            matchMultiplier: 3.0
        )
        XCTAssertEqual(matched.bonusDamage, base.bonusDamage * 3,
            "3x match multiplier should triple spiritual bonus damage")
    }
}

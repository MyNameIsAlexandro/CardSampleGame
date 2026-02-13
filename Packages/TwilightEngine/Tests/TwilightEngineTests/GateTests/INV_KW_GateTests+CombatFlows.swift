/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/INV_KW_GateTests+CombatFlows.swift
/// Назначение: Содержит реализацию файла INV_KW_GateTests+CombatFlows.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import TwilightEngine

extension INV_KW_GateTests {
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
        let fateCard = FateCard(id: "kw_card", modifier: 2, name: "KW Card", suit: nil, keyword: .surge)
        let ctx = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 50, maxHp: 100, strength: 5, armor: 2, wisdom: 20, willDefense: 1),
            enemies: [
                EncounterEnemy(id: "enemy", name: "Enemy", hp: 50, maxHp: 50, wp: 1, maxWp: 1, power: 10, defense: 3)
            ],
            fateDeckSnapshot: TestFateDeck.makeState(cards: [fateCard], seed: 42),
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

    /// Nav card in Prav zone costs +1 faith
    func testResonanceCost_navCardInPravZone_costIncrease() {
        let ctx = makeCardContext(realm: .nav, faithCost: 2, resonance: 50)
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
        let ctx = makeCardContext(realm: .prav, faithCost: 2, resonance: -50)
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
        let ctx = makeCardContext(realm: .nav, faithCost: 2, resonance: -50)
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
        let ctx = makeCardContext(realm: .nav, faithCost: 2, resonance: 0)
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
        let fateCard = FateCard(id: "f1", modifier: 0, name: "Fate", suit: nil, keyword: nil)
        let ctxBase = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 50, maxHp: 100, strength: 5, armor: 2, wisdom: 5, willDefense: 1),
            enemies: [EncounterEnemy(id: "enemy", name: "E", hp: 50, maxHp: 50, power: 10, defense: 3)],
            fateDeckSnapshot: TestFateDeck.makeState(cards: [fateCard], seed: 42),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42
        )
        let engineBase = EncounterEngine(context: ctxBase)
        _ = startAndAttack(engineBase)
        let hpBase = engineBase.enemies[0].hp

        let ctxMod = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 50, maxHp: 100, strength: 5, armor: 2, wisdom: 5, willDefense: 1),
            enemies: [EncounterEnemy(
                id: "enemy",
                name: "E",
                hp: 50,
                maxHp: 50,
                power: 10,
                defense: 3,
                resonanceBehavior: ["prav": EnemyModifier(defenseDelta: 2)]
            )],
            fateDeckSnapshot: TestFateDeck.makeState(cards: [fateCard], seed: 42),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42,
            worldResonance: 50
        )
        let engineMod = EncounterEngine(context: ctxMod)
        _ = startAndAttack(engineMod)
        let hpMod = engineMod.enemies[0].hp

        XCTAssertGreaterThan(hpMod, hpBase, "Enemy with +2 defense in prav zone should take less damage")
    }

    /// Enemy resonance modifier not applied in wrong zone
    func testResonanceModifier_notAppliedInWrongZone() {
        let fateCard = FateCard(id: "f1", modifier: 0, name: "Fate", suit: nil, keyword: nil)
        let fateDeckSnapshot1 = TestFateDeck.makeState(cards: [fateCard], seed: 42)
        let fateDeckSnapshot2 = TestFateDeck.makeState(cards: [fateCard], seed: 42)
        let ctxBase = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 50, maxHp: 100, strength: 5, armor: 2, wisdom: 5, willDefense: 1),
            enemies: [EncounterEnemy(id: "enemy", name: "E", hp: 50, maxHp: 50, power: 10, defense: 3)],
            fateDeckSnapshot: fateDeckSnapshot1,
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42,
            worldResonance: -50
        )
        let ctxMod = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 50, maxHp: 100, strength: 5, armor: 2, wisdom: 5, willDefense: 1),
            enemies: [EncounterEnemy(
                id: "enemy",
                name: "E",
                hp: 50,
                maxHp: 50,
                power: 10,
                defense: 3,
                resonanceBehavior: ["prav": EnemyModifier(defenseDelta: 5)]
            )],
            fateDeckSnapshot: fateDeckSnapshot2,
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42,
            worldResonance: -50
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
        let ctx = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 30, maxHp: 100, strength: 5, armor: 0, wisdom: 5, willDefense: 0),
            enemies: [EncounterEnemy(id: "enemy", name: "E", hp: 50, maxHp: 50, power: 20, defense: 3)],
            fateDeckSnapshot: TestFateDeck.makeState(cards: [critCard], seed: 42),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42
        )
        let engine = EncounterEngine(context: ctx)
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
        let ctx = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 30, maxHp: 100, strength: 5, armor: 0, wisdom: 5, willDefense: 0),
            enemies: [EncounterEnemy(id: "enemy", name: "E", hp: 50, maxHp: 50, power: 20, defense: 3)],
            fateDeckSnapshot: TestFateDeck.makeState(cards: [normalCard], seed: 42),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42
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
        let ctx = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 100, maxHp: 100, strength: 10, armor: 5, wisdom: 5, willDefense: 1),
            enemies: [EncounterEnemy(id: "enemy", name: "Weak", hp: 5, maxHp: 5, power: 1, defense: 0)],
            fateDeckSnapshot: TestFateDeck.makeState(cards: [fateCard], seed: 42),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42
        )
        let engine = EncounterEngine(context: ctx)

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

        let result = engine.finishEncounter()
        XCTAssertTrue(engine.isFinished)
        XCTAssertEqual(result.outcome, .victory(.killed))
        XCTAssertEqual(result.perEntityOutcomes["enemy"], .killed)
    }

    /// Full encounter: spirit attack → pacify → nonviolent victory
    func testFullEncounter_pacifyVictory() {
        let fateCard = FateCard(id: "f1", modifier: 1, name: "Fate")
        let ctx = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 100, maxHp: 100, strength: 5, armor: 5, wisdom: 20, willDefense: 1),
            enemies: [EncounterEnemy(id: "enemy", name: "Spirit", hp: 50, maxHp: 50, wp: 1, maxWp: 1, power: 1, defense: 0)],
            fateDeckSnapshot: TestFateDeck.makeState(cards: [fateCard], seed: 42),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42
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

    // MARK: - TST-06: Determinism simulation

    /// 100 encounters with same seed produce identical results
    func testDeterminism_100runs_identicalOutcome() {
        var hpResults: [Int] = []
        var enemyHpResults: [Int] = []

        for _ in 0..<100 {
            let fateCard = FateCard(id: "f1", modifier: 2, name: "Fate", suit: .nav, keyword: .surge)
            let ctx = EncounterContext(
                hero: EncounterHero(id: "hero", hp: 100, maxHp: 100, strength: 8, armor: 3, wisdom: 5, willDefense: 1),
                enemies: [EncounterEnemy(id: "enemy", name: "E", hp: 30, maxHp: 30, power: 6, defense: 2)],
                fateDeckSnapshot: TestFateDeck.makeState(cards: [fateCard], seed: 77),
                modifiers: [],
                rules: EncounterRules(),
                rngSeed: 77
            )
            let engine = EncounterEngine(context: ctx)
            _ = engine.advancePhase() // → playerAction
            _ = engine.performAction(.attack(targetId: "enemy"))
            _ = engine.advancePhase() // → enemyResolution
            _ = engine.resolveEnemyAction(enemyId: "enemy")
            hpResults.append(engine.heroHP)
            enemyHpResults.append(engine.enemies[0].hp)
        }

        XCTAssertEqual(Set(hpResults).count, 1, "Hero HP must be identical across 100 seeded runs")
        XCTAssertEqual(Set(enemyHpResults).count, 1, "Enemy HP must be identical across 100 seeded runs")
    }

    /// Yav suit always matches — never nullified
    func testYavSuit_alwaysMatches_neverNullified() {
        let ctxYavPhys = makeContext(keyword: .surge, suit: .yav)
        let ctxYavSpir = makeContext(keyword: .surge, suit: .yav)

        let enginePhys = EncounterEngine(context: ctxYavPhys)
        let engineSpir = EncounterEngine(context: ctxYavSpir)

        let resultPhys = startAndAttack(enginePhys)
        let resultSpir = startAndSpiritAttack(engineSpir)

        XCTAssertTrue(resultPhys.success)
        XCTAssertTrue(resultSpir.success)
        XCTAssertLessThan(enginePhys.enemies[0].hp, 50, "Yav should match physical (damage dealt)")
        XCTAssertLessThan(engineSpir.enemies[0].wp!, 30, "Yav should match spiritual (WP dealt)")
    }
}

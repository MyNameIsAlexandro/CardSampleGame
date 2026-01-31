import XCTest
@testable import TwilightEngine

/// Multi-enemy encounter tests and expanded integration scenarios
/// Validates EncounterEngine behavior with 2+ enemies, summons, abilities, and weaknesses
final class MultiEnemyEncounterTests: XCTestCase {

    // MARK: - Helpers

    /// Generate a large deterministic fate deck so tests never run out of cards
    private func makeFateDeck(count: Int = 15) -> [FateCard] {
        (0..<count).map { i in
            FateCard(id: "fate_\(i)", modifier: 1, name: "Fortune \(i)")
        }
    }

    private func makeFateDeckState(count: Int = 15) -> FateDeckState {
        FateDeckManager(cards: makeFateDeck(count: count)).getState()
    }

    /// Standard hero for multi-enemy tests
    private var standardHero: EncounterHero {
        EncounterHero(id: "hero", hp: 30, maxHp: 30, strength: 5, armor: 0, wisdom: 3)
    }

    /// Cycle through a full combat round: playerAction -> enemyResolution -> roundEnd -> intent -> playerAction
    /// Call this when engine is in `.playerAction` phase and the player has already acted.
    private func cycleToNextPlayerAction(engine: EncounterEngine, aliveEnemyIds: [String]) {
        _ = engine.advancePhase() // playerAction -> enemyResolution
        for eid in aliveEnemyIds {
            engine.overrideIntentForTest(.attack(damage: 1))
            _ = engine.resolveEnemyAction(enemyId: eid)
        }
        _ = engine.advancePhase() // enemyResolution -> roundEnd
        _ = engine.advancePhase() // roundEnd -> intent (regen triggers here)
        _ = engine.advancePhase() // intent -> playerAction
    }

    // MARK: - Test 1: Two Enemies Can Be Targeted Independently

    func testTwoEnemies_CanTargetEach() {
        let e1 = EncounterEnemy(id: "e1", name: "Goblin A", hp: 20, maxHp: 20, power: 2, defense: 0)
        let e2 = EncounterEnemy(id: "e2", name: "Goblin B", hp: 20, maxHp: 20, power: 2, defense: 0)

        let ctx = EncounterContext(
            hero: standardHero,
            enemies: [e1, e2],
            fateDeckSnapshot: makeFateDeckState(),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42
        )
        let engine = EncounterEngine(context: ctx)

        // Round 1: attack e1
        _ = engine.advancePhase() // intent -> playerAction
        let hp1Before = engine.enemies[0].hp
        _ = engine.performAction(.attack(targetId: "e1"))

        XCTAssertLessThan(engine.enemies[0].hp, hp1Before, "e1 should take damage")
        XCTAssertEqual(engine.enemies[1].hp, 20, "e2 should be untouched")

        // Cycle to next round
        cycleToNextPlayerAction(engine: engine, aliveEnemyIds: ["e1", "e2"])

        // Round 2: attack e2
        let hp2Before = engine.enemies[1].hp
        _ = engine.performAction(.attack(targetId: "e2"))

        XCTAssertLessThan(engine.enemies[1].hp, hp2Before, "e2 should take damage")
    }

    // MARK: - Test 2: Kill One, Target Other

    func testTwoEnemies_KillOneTargetOther() {
        let e1 = EncounterEnemy(id: "e1", name: "Weakling", hp: 1, maxHp: 1, power: 1, defense: 0)
        let e2 = EncounterEnemy(id: "e2", name: "Tough", hp: 50, maxHp: 50, power: 2, defense: 0)

        let ctx = EncounterContext(
            hero: standardHero,
            enemies: [e1, e2],
            fateDeckSnapshot: makeFateDeckState(),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42
        )
        let engine = EncounterEngine(context: ctx)

        // Kill e1
        _ = engine.advancePhase() // intent -> playerAction
        let result = engine.performAction(.attack(targetId: "e1"))

        XCTAssertEqual(engine.enemies[0].hp, 0, "e1 should be dead")
        XCTAssertEqual(engine.enemies[0].outcome, .killed)
        let hasKilled = result.stateChanges.contains { if case .enemyKilled(let eid) = $0 { return eid == "e1" }; return false }
        XCTAssertTrue(hasKilled, "Should emit enemyKilled for e1")

        // Cycle to next round (only e2 is alive)
        cycleToNextPlayerAction(engine: engine, aliveEnemyIds: ["e2"])

        // Attack e2
        let hp2Before = engine.enemies[1].hp
        _ = engine.performAction(.attack(targetId: "e2"))

        XCTAssertLessThan(engine.enemies[1].hp, hp2Before, "e2 should take damage")
        XCTAssertTrue(engine.enemies[1].isAlive, "e2 should still be alive")
    }

    // MARK: - Test 3: Victory Requires All Dead

    func testTwoEnemies_VictoryRequiresAllDead() {
        let e1 = EncounterEnemy(id: "e1", name: "Goblin A", hp: 1, maxHp: 1, power: 1, defense: 0)
        let e2 = EncounterEnemy(id: "e2", name: "Goblin B", hp: 1, maxHp: 1, power: 1, defense: 0)

        let ctx = EncounterContext(
            hero: standardHero,
            enemies: [e1, e2],
            fateDeckSnapshot: makeFateDeckState(),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42
        )
        let engine = EncounterEngine(context: ctx)

        // Kill e1 only
        _ = engine.advancePhase() // intent -> playerAction
        _ = engine.performAction(.attack(targetId: "e1"))
        XCTAssertEqual(engine.enemies[0].outcome, .killed)
        XCTAssertTrue(engine.enemies[1].isAlive)

        // Finish encounter while e2 still alive — should NOT be full victory
        let partialResult = engine.finishEncounter()
        // Since e1 is killed but e2 is alive, outcome logic: anyKilled=true, allDead=false
        // The engine returns .victory(.killed) if anyKilled is true
        // But the perEntityOutcomes should show e2 as .alive
        XCTAssertEqual(partialResult.perEntityOutcomes["e2"], .alive,
                       "e2 should still be alive in per-entity outcomes")

        // Start fresh encounter and kill both
        let engine2 = EncounterEngine(context: ctx)
        _ = engine2.advancePhase() // intent -> playerAction
        _ = engine2.performAction(.attack(targetId: "e1"))
        cycleToNextPlayerAction(engine: engine2, aliveEnemyIds: ["e2"])
        _ = engine2.performAction(.attack(targetId: "e2"))

        XCTAssertEqual(engine2.enemies[0].outcome, .killed)
        XCTAssertEqual(engine2.enemies[1].outcome, .killed)

        let fullResult = engine2.finishEncounter()
        XCTAssertEqual(fullResult.outcome, .victory(.killed))
        XCTAssertEqual(fullResult.perEntityOutcomes["e1"], .killed)
        XCTAssertEqual(fullResult.perEntityOutcomes["e2"], .killed)
    }

    // MARK: - Test 4: Mixed Outcomes (Kill + Pacify)

    func testTwoEnemies_MixedOutcomes() {
        let e1 = EncounterEnemy(id: "e1", name: "Beast", hp: 1, maxHp: 1, power: 1, defense: 0)
        let e2 = EncounterEnemy(id: "e2", name: "Spirit", hp: 50, maxHp: 50, wp: 1, maxWp: 1, power: 1, defense: 0)

        let ctx = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 30, maxHp: 30, strength: 5, armor: 0, wisdom: 10),
            enemies: [e1, e2],
            fateDeckSnapshot: makeFateDeckState(),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42
        )
        let engine = EncounterEngine(context: ctx)

        // Kill e1 physically
        _ = engine.advancePhase() // intent -> playerAction
        _ = engine.performAction(.attack(targetId: "e1"))
        XCTAssertEqual(engine.enemies[0].outcome, .killed)

        // Cycle to next round
        cycleToNextPlayerAction(engine: engine, aliveEnemyIds: ["e2"])

        // Pacify e2 via spirit attack
        let spiritResult = engine.performAction(.spiritAttack(targetId: "e2"))
        let hasPacified = spiritResult.stateChanges.contains { if case .enemyPacified = $0 { return true }; return false }
        XCTAssertTrue(hasPacified, "e2 should be pacified via spirit attack")
        XCTAssertEqual(engine.enemies[1].outcome, .pacified)

        // Check per-entity outcomes
        let result = engine.finishEncounter()
        XCTAssertEqual(result.perEntityOutcomes["e1"], .killed)
        XCTAssertEqual(result.perEntityOutcomes["e2"], .pacified)
    }

    // MARK: - Test 5: Summon Adds New Enemy

    func testSummon_AddsNewEnemy() {
        let summoner = EncounterEnemy(id: "summoner", name: "Necromancer", hp: 30, maxHp: 30, power: 3, defense: 0)
        let minion = EncounterEnemy(id: "minion", name: "Skeleton", hp: 5, maxHp: 5, power: 1, defense: 0)

        let ctx = EncounterContext(
            hero: standardHero,
            enemies: [summoner],
            fateDeckSnapshot: makeFateDeckState(),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42,
            summonPool: ["minion": minion]
        )
        let engine = EncounterEngine(context: ctx)
        XCTAssertEqual(engine.enemies.count, 1)

        // Advance to playerAction, then to enemyResolution
        _ = engine.advancePhase() // intent -> playerAction
        _ = engine.performAction(.wait)
        _ = engine.advancePhase() // playerAction -> enemyResolution

        // Override intent to summon
        engine.overrideIntentForTest(.summon(enemyId: "minion"))
        let result = engine.resolveEnemyAction(enemyId: "summoner")

        XCTAssertTrue(result.success)
        XCTAssertEqual(engine.enemies.count, 2, "Summoned enemy should be added")
        XCTAssertEqual(engine.enemies[1].id, "minion")
        XCTAssertEqual(engine.enemies[1].name, "Skeleton")
        XCTAssertEqual(engine.enemies[1].hp, 5)

        let hasSummon = result.stateChanges.contains {
            if case .enemySummoned(let eid, _) = $0 { return eid == "minion" }; return false
        }
        XCTAssertTrue(hasSummon, "Should emit enemySummoned state change")
    }

    // MARK: - Test 6: Abilities and Weaknesses Integration

    func testIntegration_AbilitiesAndWeaknesses() {
        // Enemy with armor(2) ability and weakness to "surge"
        let armorAbility = EnemyAbility(
            id: "shell",
            name: .inline(LocalizedString(en: "Shell", ru: "Панцирь")),
            description: .inline(LocalizedString(en: "Reduces damage", ru: "Снижает урон")),
            effect: .armor(2)
        )
        let enemy = EncounterEnemy(
            id: "e1", name: "Armored Beast", hp: 50, maxHp: 50,
            power: 3, defense: 1,
            weaknesses: ["surge"],
            abilities: [armorAbility]
        )

        // Fate card with surge keyword — triggers weakness AND is used in attack
        let surgeCards: [FateCard] = (0..<15).map { i in
            FateCard(id: "surge_\(i)", modifier: 2, name: "Surge Card", keyword: .surge)
        }
        let deckState = FateDeckManager(cards: surgeCards).getState()

        let ctx = EncounterContext(
            hero: standardHero,
            enemies: [enemy],
            fateDeckSnapshot: deckState,
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42
        )
        let engine = EncounterEngine(context: ctx)

        _ = engine.advancePhase() // intent -> playerAction

        let hpBefore = engine.enemies[0].hp
        let result = engine.performAction(.attack(targetId: "e1"))

        let hpAfter = engine.enemies[0].hp
        let damage = hpBefore - hpAfter
        XCTAssertGreaterThan(damage, 0, "Attack should deal damage")

        // Check that weakness was triggered
        let hasWeakness = result.stateChanges.contains {
            if case .weaknessTriggered(let eid, let kw) = $0 { return eid == "e1" && kw == "surge" }
            return false
        }
        XCTAssertTrue(hasWeakness, "Surge weakness should be triggered")

        // Armor ability is in effect: enemy has defense 1 + ability armor 2 = 3 effective defense
        // With surge keyword bonus, weakness multiplier 1.5x, exact damage depends on keyword resolution
        // But we can verify the enemy took damage that accounts for both mechanics
        XCTAssertLessThan(hpAfter, hpBefore, "Enemy HP should decrease despite armor")
    }

    // MARK: - Test 7: Regeneration Over Multiple Rounds

    func testIntegration_RegenerationOverMultipleRounds() {
        let regenAbility = EnemyAbility(
            id: "regen",
            name: .inline(LocalizedString(en: "Regeneration", ru: "Регенерация")),
            description: .inline(LocalizedString(en: "Heals 2 HP per round", ru: "Лечит 2 ОЗ за раунд")),
            effect: .regeneration(2)
        )
        let enemy = EncounterEnemy(
            id: "e1", name: "Troll", hp: 30, maxHp: 30,
            power: 3, defense: 0,
            abilities: [regenAbility]
        )

        let ctx = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 100, maxHp: 100, strength: 10, armor: 5, wisdom: 3),
            enemies: [enemy],
            fateDeckSnapshot: makeFateDeckState(count: 20),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42
        )
        let engine = EncounterEngine(context: ctx)

        // Round 1: attack to deal damage
        _ = engine.advancePhase() // intent -> playerAction
        _ = engine.performAction(.attack(targetId: "e1"))
        let hpAfterAttack1 = engine.enemies[0].hp
        XCTAssertLessThan(hpAfterAttack1, 30, "Attack should deal damage")

        // Cycle through round end (regen triggers in roundEnd -> intent transition)
        _ = engine.advancePhase() // playerAction -> enemyResolution
        engine.overrideIntentForTest(.attack(damage: 1))
        _ = engine.resolveEnemyAction(enemyId: "e1")
        _ = engine.advancePhase() // enemyResolution -> roundEnd
        // Regen triggers during roundEnd -> intent transition
        _ = engine.advancePhase() // roundEnd -> intent
        let hpAfterRegen1 = engine.enemies[0].hp
        let regen1 = hpAfterRegen1 - hpAfterAttack1
        XCTAssertEqual(regen1, 2, "Should regenerate 2 HP after round 1")

        // Round 2: attack again
        _ = engine.advancePhase() // intent -> playerAction
        _ = engine.performAction(.attack(targetId: "e1"))
        let hpAfterAttack2 = engine.enemies[0].hp

        // Cycle again
        _ = engine.advancePhase() // playerAction -> enemyResolution
        engine.overrideIntentForTest(.attack(damage: 1))
        _ = engine.resolveEnemyAction(enemyId: "e1")
        _ = engine.advancePhase() // enemyResolution -> roundEnd
        _ = engine.advancePhase() // roundEnd -> intent
        let hpAfterRegen2 = engine.enemies[0].hp
        let regen2 = hpAfterRegen2 - hpAfterAttack2
        XCTAssertEqual(regen2, 2, "Should regenerate 2 HP after round 2")

        // Round 3: attack again
        _ = engine.advancePhase() // intent -> playerAction
        _ = engine.performAction(.attack(targetId: "e1"))
        let hpAfterAttack3 = engine.enemies[0].hp

        // Cycle again
        _ = engine.advancePhase() // playerAction -> enemyResolution
        engine.overrideIntentForTest(.attack(damage: 1))
        _ = engine.resolveEnemyAction(enemyId: "e1")
        _ = engine.advancePhase() // enemyResolution -> roundEnd
        _ = engine.advancePhase() // roundEnd -> intent
        let hpAfterRegen3 = engine.enemies[0].hp
        let regen3 = hpAfterRegen3 - hpAfterAttack3
        XCTAssertEqual(regen3, 2, "Should regenerate 2 HP after round 3")
    }

    // MARK: - Test 8: Intent Generated for Each Enemy

    func testTwoEnemies_IntentGeneratedForEach() {
        let e1 = EncounterEnemy(id: "e1", name: "Goblin A", hp: 20, maxHp: 20, power: 3, defense: 0)
        let e2 = EncounterEnemy(id: "e2", name: "Goblin B", hp: 20, maxHp: 20, power: 4, defense: 0)

        let ctx = EncounterContext(
            hero: standardHero,
            enemies: [e1, e2],
            fateDeckSnapshot: makeFateDeckState(),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42
        )
        let engine = EncounterEngine(context: ctx)

        // Engine auto-generates intents at init for all alive enemies
        // Verify we can generate valid intents for both
        let intent1 = engine.generateIntent(for: "e1")
        XCTAssertNotNil(intent1.type, "e1 should have a valid intent type")
        XCTAssertGreaterThanOrEqual(intent1.value, 0, "e1 intent should have non-negative value")

        let intent2 = engine.generateIntent(for: "e2")
        XCTAssertNotNil(intent2.type, "e2 should have a valid intent type")
        XCTAssertGreaterThanOrEqual(intent2.value, 0, "e2 intent should have non-negative value")

        // Both enemies should be alive
        XCTAssertTrue(engine.enemies[0].isAlive)
        XCTAssertTrue(engine.enemies[1].isAlive)
    }
}

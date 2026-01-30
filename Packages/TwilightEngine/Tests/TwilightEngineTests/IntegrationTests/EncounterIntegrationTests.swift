import XCTest
@testable import TwilightEngine

/// Encounter integration tests — full encounter lifecycle
/// Reference: ENCOUNTER_TEST_MODEL.md §4.1
/// Uses real EncounterEngine, no mocks
final class EncounterIntegrationTests: XCTestCase {

    // #22: Full kill path — physical attacks until HP=0
    func testFullKillPath() {
        let ctx = EncounterContext(
            hero: EncounterHero(id: "warrior", hp: 100, maxHp: 100, strength: 10, armor: 5),
            enemies: [EncounterEnemy(id: "beast", name: "Weak Beast", hp: 10, maxHp: 10, wp: 5, maxWp: 5, power: 3, defense: 1)],
            fateDeckSnapshot: FateDeckFixtures.deterministicState(),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42
        )
        let engine = EncounterEngine(context: ctx)

        // Combat loop
        var rounds = 0
        while engine.enemies[0].isAlive && rounds < 10 {
            _ = engine.generateIntent(for: "beast")
            _ = engine.advancePhase() // intent → playerAction
            _ = engine.performAction(.attack(targetId: "beast"))
            if engine.enemies[0].isAlive {
                _ = engine.advancePhase() // playerAction → enemyResolution
                _ = engine.resolveEnemyAction(enemyId: "beast")
                _ = engine.advancePhase() // roundEnd
            }
            rounds += 1
        }

        let result = engine.finishEncounter()
        XCTAssertEqual(result.outcome, .victory(.killed))
        XCTAssertEqual(result.perEntityOutcomes["beast"], .killed)
        XCTAssertGreaterThan(engine.enemies[0].wp ?? 1, 0, "WP should remain in kill path")
    }

    // #23: Full pacify path — spirit attacks until WP=0
    func testFullPacifyPath() {
        let ctx = EncounterContext(
            hero: EncounterHero(id: "diplomat", hp: 100, maxHp: 100, strength: 3, armor: 2, wisdom: 10),
            enemies: [EncounterEnemy(id: "spirit", name: "Spirit", hp: 100, maxHp: 100, wp: 5, maxWp: 5, power: 3)],
            fateDeckSnapshot: FateDeckFixtures.deterministicState(),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42
        )
        let engine = EncounterEngine(context: ctx)

        var rounds = 0
        while !(engine.enemies[0].isPacified) && rounds < 10 {
            _ = engine.generateIntent(for: "spirit")
            _ = engine.advancePhase() // intent → playerAction
            _ = engine.performAction(.spiritAttack(targetId: "spirit"))
            if !(engine.enemies[0].isPacified) {
                _ = engine.advancePhase() // playerAction → enemyResolution
                _ = engine.resolveEnemyAction(enemyId: "spirit")
                _ = engine.advancePhase()
            }
            rounds += 1
        }

        let result = engine.finishEncounter()
        XCTAssertEqual(result.outcome, .victory(.pacified))
        XCTAssertGreaterThan(engine.enemies[0].hp, 0, "HP should remain in pacify path")
    }

    // #24: Escalation full cycle — spirit→body with resonance penalty
    func testEscalationFullCycle() {
        let ctx = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 100, maxHp: 100, strength: 5, armor: 2, wisdom: 5),
            enemies: [EncounterEnemy(id: "guard", name: "Guard", hp: 100, maxHp: 100, wp: 100, maxWp: 100, power: 5, defense: 2)],
            fateDeckSnapshot: FateDeckFixtures.deterministicState(),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42,
            worldResonance: 0
        )
        let engine = EncounterEngine(context: ctx)

        // Spirit attack (diplomacy)
        _ = engine.advancePhase() // intent → playerAction
        _ = engine.performAction(.spiritAttack(targetId: "guard"))

        // Physical attack (escalation)
        let result = engine.performAction(.attack(targetId: "guard"))

        // Verify resonance shifted
        let resonanceShift = result.stateChanges.compactMap { change -> Float? in
            if case .resonanceShifted(let delta, _) = change { return delta }
            return nil
        }.first

        XCTAssertNotNil(resonanceShift, "Escalation must produce resonance shift")
        XCTAssertLessThan(resonanceShift ?? 0, 0, "Escalation shifts resonance toward Nav (negative)")
    }

    // #19: Multi-enemy — per-entity outcomes
    func testMultiEnemy1vN() {
        let ctx = EncounterContextFixtures.multiEnemy()
        let engine = EncounterEngine(context: ctx)

        // Kill first enemy
        _ = engine.advancePhase() // intent → playerAction
        _ = engine.performAction(.attack(targetId: "enemy_1"))

        // Pacify second
        _ = engine.performAction(.spiritAttack(targetId: "enemy_2"))

        let result = engine.finishEncounter()

        // Per-entity outcomes should exist
        XCTAssertNotNil(result.perEntityOutcomes["enemy_1"])
        XCTAssertNotNil(result.perEntityOutcomes["enemy_2"])
        XCTAssertNotNil(result.perEntityOutcomes["enemy_3"])
    }

    // #20: All pacified → nonviolent encounter
    func testMultiEnemyAllPacified() {
        let ctx = EncounterContextFixtures.multiEnemy()
        let engine = EncounterEngine(context: ctx)

        // Spirit attack all enemies
        _ = engine.advancePhase() // intent → playerAction
        _ = engine.performAction(.spiritAttack(targetId: "enemy_1"))
        _ = engine.performAction(.spiritAttack(targetId: "enemy_2"))
        _ = engine.performAction(.spiritAttack(targetId: "enemy_3"))

        let result = engine.finishEncounter()

        // All should be pacified → nonviolent flag
        for (_, outcome) in result.perEntityOutcomes {
            XCTAssertEqual(outcome, .pacified)
        }
        XCTAssertEqual(result.transaction.worldFlags["nonviolent"], true, "All pacified = nonviolent")
    }

    // Flee path — player escapes
    func testFleePath() {
        let ctx = EncounterContextFixtures.standard()
        let engine = EncounterEngine(context: ctx)

        // One round of combat, then flee
        _ = engine.generateIntent(for: "test_enemy")
        _ = engine.advancePhase() // → playerAction
        _ = engine.performAction(.flee)

        let result = engine.finishEncounter()
        XCTAssertEqual(result.outcome, .escaped)
        XCTAssertTrue(engine.isFinished)
    }

    // Full combat with cards — cards affect damage output
    func testFullKillPathWithCards() {
        let atkCard = Card(
            id: "sword", name: "Sword", type: .weapon, description: "Sharp",
            abilities: [CardAbility(id: "ab1", name: "Slash", description: "Slash", effect: .temporaryStat(stat: "attack", amount: 5, duration: 1))]
        )
        let ctx = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 100, maxHp: 100, strength: 5, armor: 2),
            enemies: [EncounterEnemy(id: "e1", name: "Enemy", hp: 20, maxHp: 20, power: 3, defense: 2)],
            fateDeckSnapshot: FateDeckFixtures.deterministicState(),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42,
            heroCards: [atkCard]
        )
        let engine = EncounterEngine(context: ctx)

        _ = engine.advancePhase() // → playerAction

        // Play card then attack
        let playResult = engine.performAction(.useCard(cardId: "sword", targetId: "e1"))
        XCTAssertTrue(playResult.success)
        XCTAssertEqual(engine.turnAttackBonus, 5)

        _ = engine.performAction(.attack(targetId: "e1"))

        // With str(5) + bonus(5) - def(2) = 8 damage + fate card bonus
        // Enemy started at 20 HP, should take significant damage
        XCTAssertLessThan(engine.enemies[0].hp, 20, "Card bonus must increase damage")
    }
}

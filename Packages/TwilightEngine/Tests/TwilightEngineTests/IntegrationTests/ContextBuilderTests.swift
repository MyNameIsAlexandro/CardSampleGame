import XCTest
@testable import TwilightEngine

/// Context Builder Tests — verify EncounterContext construction patterns
/// Reference: ENCOUNTER_TEST_MODEL.md §4.3
final class ContextBuilderTests: XCTestCase {

    // Modifiers pass through to context correctly
    func testModifiersInContext() {
        let modifier = EncounterModifier(id: "swamp_rot", type: "heal_mult", value: 0.5, source: "Swamp")
        let ctx = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 50, maxHp: 50, strength: 5, armor: 2),
            enemies: [EncounterEnemy(id: "e1", name: "E", hp: 10, maxHp: 10, power: 3)],
            fateDeckSnapshot: FateDeckFixtures.deterministicState(),
            modifiers: [modifier],
            rules: EncounterRules(),
            rngSeed: 42
        )

        XCTAssertEqual(ctx.modifiers.count, 1)
        XCTAssertEqual(ctx.modifiers[0].id, "swamp_rot")
        XCTAssertEqual(ctx.modifiers[0].value, 0.5)
        XCTAssertEqual(ctx.modifiers[0].source, "Swamp")
    }

    // Empty modifiers produces valid context
    func testEmptyContextNoModifiers() {
        let ctx = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 50, maxHp: 50, strength: 5, armor: 2),
            enemies: [EncounterEnemy(id: "e1", name: "E", hp: 10, maxHp: 10, power: 3)],
            fateDeckSnapshot: FateDeckFixtures.deterministicState(),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42
        )

        XCTAssertTrue(ctx.modifiers.isEmpty)
        // Engine should run fine with no modifiers
        let engine = EncounterEngine(context: ctx)
        _ = engine.advancePhase()
        let result = engine.performAction(.attack(targetId: "e1"))
        XCTAssertTrue(result.success)
    }

    // WorldResonance passes through to engine
    func testResonancePassthrough() {
        // Enemy needs WP track for spirit attack to work
        let ctx = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 50, maxHp: 50, strength: 5, armor: 2, wisdom: 5),
            enemies: [EncounterEnemy(id: "e1", name: "E", hp: 100, maxHp: 100, wp: 50, maxWp: 50, power: 3)],
            fateDeckSnapshot: FateDeckFixtures.deterministicState(),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42,
            worldResonance: -80.0
        )

        XCTAssertEqual(ctx.worldResonance, -80.0)
        let engine = EncounterEngine(context: ctx)

        // Escalation from spirit→physical should shift resonance
        _ = engine.advancePhase() // → playerAction
        _ = engine.performAction(.spiritAttack(targetId: "e1"))
        let result = engine.performAction(.attack(targetId: "e1"))

        let shift = result.stateChanges.compactMap { change -> Float? in
            if case .resonanceShifted(let d, _) = change { return d }
            return nil
        }.first

        XCTAssertNotNil(shift, "Resonance shift expected on escalation (spirit→physical)")
    }

    // Rules: canFlee flag
    func testCanFleeRule() {
        let rulesFleeOk = EncounterRules(canFlee: true)
        XCTAssertTrue(rulesFleeOk.canFlee)

        let rulesNoFlee = EncounterRules(canFlee: false)
        XCTAssertFalse(rulesNoFlee.canFlee)
    }

    // Rules: maxRounds
    func testMaxRoundsRule() {
        let rules = EncounterRules(maxRounds: 5)
        XCTAssertEqual(rules.maxRounds, 5)

        let rulesNoLimit = EncounterRules()
        XCTAssertNil(rulesNoLimit.maxRounds)
    }

    // HeroCards pass through to engine hand
    func testHeroCardsPassthrough() {
        let card = Card(id: "sword", name: "Sword", type: .weapon, description: "A sword", power: 3)
        let ctx = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 50, maxHp: 50, strength: 5, armor: 2),
            enemies: [EncounterEnemy(id: "e1", name: "E", hp: 10, maxHp: 10, power: 3)],
            fateDeckSnapshot: FateDeckFixtures.deterministicState(),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42,
            heroCards: [card]
        )

        let engine = EncounterEngine(context: ctx)
        XCTAssertEqual(engine.hand.count, 1)
        XCTAssertEqual(engine.hand[0].id, "sword")
    }

    // Behaviors pass through to context
    func testBehaviorsPassthrough() {
        let behavior = BehaviorDefinition(id: "test_behavior", rules: [])
        let ctx = EncounterContext(
            hero: EncounterHero(id: "hero", hp: 50, maxHp: 50, strength: 5, armor: 2),
            enemies: [EncounterEnemy(id: "e1", name: "E", hp: 10, maxHp: 10, power: 3, behaviorId: "test_behavior")],
            fateDeckSnapshot: FateDeckFixtures.deterministicState(),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42,
            behaviors: ["test_behavior": behavior]
        )

        XCTAssertEqual(ctx.behaviors.count, 1)
        XCTAssertNotNil(ctx.behaviors["test_behavior"])
    }
}

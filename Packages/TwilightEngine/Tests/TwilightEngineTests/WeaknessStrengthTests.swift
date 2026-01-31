import XCTest
@testable import TwilightEngine

/// Tests for EC-01: Weakness / Strength modifiers on physical and spirit attacks
final class WeaknessStrengthTests: XCTestCase {

    // MARK: - Helpers

    private func makeContext(
        weaknesses: [String] = [],
        strengths: [String] = [],
        enemyHP: Int = 40,
        enemyWP: Int? = nil,
        enemyMaxWP: Int? = nil,
        enemyDefense: Int = 0,
        enemySpiritDefense: Int = 0,
        heroStrength: Int = 5,
        heroWisdom: Int = 3,
        fateKeyword: FateKeyword? = .surge,
        fateModifier: Int = 2
    ) -> EncounterContext {
        let card = FateCard(
            id: "f1",
            modifier: fateModifier,
            name: "Test Fate",
            keyword: fateKeyword
        )
        return EncounterContext(
            hero: EncounterHero(id: "hero", hp: 20, maxHp: 20, strength: heroStrength, armor: 0, wisdom: heroWisdom),
            enemies: [
                EncounterEnemy(
                    id: "e1",
                    name: "TestEnemy",
                    hp: enemyHP,
                    maxHp: enemyHP,
                    wp: enemyWP,
                    maxWp: enemyMaxWP,
                    power: 3,
                    defense: enemyDefense,
                    spiritDefense: enemySpiritDefense,
                    weaknesses: weaknesses,
                    strengths: strengths
                )
            ],
            fateDeckSnapshot: FateDeckState(drawPile: [card], discardPile: []),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42
        )
    }

    private func engineInPlayerPhase(context: EncounterContext) -> EncounterEngine {
        let engine = EncounterEngine(context: context)
        _ = engine.advancePhase() // intent → playerAction
        return engine
    }

    // MARK: - Tests

    func testWeakness_IncreasesPhysicalDamage() {
        // Enemy weak to "surge"; fate card has .surge keyword → ×1.5 damage
        let ctx = makeContext(weaknesses: ["surge"], enemyHP: 40, enemyDefense: 0)
        let engine = engineInPlayerPhase(context: ctx)

        let hpBefore = engine.enemies[0].hp
        let result = engine.performAction(.attack(targetId: "e1"))

        XCTAssertTrue(result.success, "Attack should succeed")

        let hpAfter = engine.enemies[0].hp
        let dealt = hpBefore - hpAfter

        // Base damage = hero.strength(5) + fateKeywordBonus + weaknessMultiplier(1.5)
        // Without weakness the raw would be applied at ×1.0; with weakness ×1.5 → strictly more
        // At minimum: max(1, Int(Double(5) * 1.5)) = 7
        XCTAssertGreaterThanOrEqual(dealt, 7, "Weakness should amplify damage by ×1.5")

        let hasWeaknessTrigger = result.stateChanges.contains(where: {
            if case .weaknessTriggered(let eid, let kw) = $0 {
                return eid == "e1" && kw == "surge"
            }
            return false
        })
        XCTAssertTrue(hasWeaknessTrigger, "Should emit weaknessTriggered state change")
    }

    func testStrength_ReducesPhysicalDamage() {
        // Enemy strong against "surge"; fate card has .surge keyword → ×0.67 damage
        let ctx = makeContext(strengths: ["surge"], enemyHP: 40, enemyDefense: 0)
        let engine = engineInPlayerPhase(context: ctx)

        let hpBefore = engine.enemies[0].hp
        let result = engine.performAction(.attack(targetId: "e1"))

        XCTAssertTrue(result.success)

        let hpAfter = engine.enemies[0].hp
        let dealt = hpBefore - hpAfter

        // With strength: max(1, Int(Double(5) * 0.67)) = max(1, 3) = 3 (roughly)
        // Without: would be at least 5
        XCTAssertLessThanOrEqual(dealt, 5, "Strength should reduce damage via ×0.67 multiplier")

        let hasResistanceTrigger = result.stateChanges.contains(where: {
            if case .resistanceTriggered(let eid, let kw) = $0 {
                return eid == "e1" && kw == "surge"
            }
            return false
        })
        XCTAssertTrue(hasResistanceTrigger, "Should emit resistanceTriggered state change")
    }

    func testWeakness_IncreasesSpiritDamage() {
        // Spirit attack on enemy with WP and weakness to "surge"
        let ctx = makeContext(weaknesses: ["surge"], enemyHP: 40, enemyWP: 20, enemyMaxWP: 20)
        let engine = engineInPlayerPhase(context: ctx)

        let wpBefore = engine.enemies[0].wp!
        let result = engine.performAction(.spiritAttack(targetId: "e1"))

        XCTAssertTrue(result.success)

        let wpAfter = engine.enemies[0].wp!
        let dealt = wpBefore - wpAfter

        // wisdom(3) * 1.5 weakness = at least 4
        XCTAssertGreaterThanOrEqual(dealt, 4, "Weakness should amplify spirit damage by ×1.5")

        let hasWeaknessTrigger = result.stateChanges.contains(where: {
            if case .weaknessTriggered(let eid, let kw) = $0 {
                return eid == "e1" && kw == "surge"
            }
            return false
        })
        XCTAssertTrue(hasWeaknessTrigger, "Should emit weaknessTriggered for spirit attack")
    }

    func testNoWeaknessOrStrength_NormalDamage() {
        // No weaknesses or strengths — no modifier state changes
        let ctx = makeContext(weaknesses: [], strengths: [], enemyHP: 40, enemyDefense: 0)
        let engine = engineInPlayerPhase(context: ctx)

        let result = engine.performAction(.attack(targetId: "e1"))

        XCTAssertTrue(result.success)

        let hasWeakness = result.stateChanges.contains(where: {
            if case .weaknessTriggered = $0 { return true }
            return false
        })
        let hasResistance = result.stateChanges.contains(where: {
            if case .resistanceTriggered = $0 { return true }
            return false
        })
        XCTAssertFalse(hasWeakness, "No weakness trigger expected")
        XCTAssertFalse(hasResistance, "No resistance trigger expected")
    }

    func testWeakness_MinimumDamageStillOne() {
        // Strength modifier reducing damage — minimum should be 1
        // Hero strength 1, enemy defense 5, strength multiplier ×0.67
        // rawDamage = 1 - 5 = -4, after multiplier still negative → clamped to 1
        let ctx = makeContext(
            strengths: ["surge"],
            enemyHP: 40,
            enemyDefense: 5,
            heroStrength: 1
        )
        let engine = engineInPlayerPhase(context: ctx)

        let hpBefore = engine.enemies[0].hp
        let result = engine.performAction(.attack(targetId: "e1"))

        XCTAssertTrue(result.success)

        let dealt = hpBefore - engine.enemies[0].hp
        XCTAssertEqual(dealt, 1, "Damage should be clamped to minimum of 1")
    }
}

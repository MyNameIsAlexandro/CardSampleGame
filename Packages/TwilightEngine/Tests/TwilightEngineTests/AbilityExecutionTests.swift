import XCTest
@testable import TwilightEngine

/// Tests for EC-02: Enemy ability execution (bonusDamage, armor, regeneration)
final class AbilityExecutionTests: XCTestCase {

    // MARK: - Helpers

    private func makeAbility(id: String, name: String, description: String, effect: EnemyAbilityEffect) -> EnemyAbility {
        EnemyAbility(
            id: id,
            name: .inline(LocalizedString(en: name, ru: name)),
            description: .inline(LocalizedString(en: description, ru: description)),
            effect: effect
        )
    }

    private func makeContext(
        enemyHP: Int = 30,
        enemyMaxHP: Int = 30,
        enemyPower: Int = 4,
        enemyDefense: Int = 0,
        abilities: [EnemyAbility] = [],
        heroStrength: Int = 5,
        fateModifier: Int = 0
    ) -> EncounterContext {
        let card = FateCard(id: "f1", modifier: fateModifier, name: "Neutral Fate")
        return EncounterContext(
            hero: EncounterHero(id: "hero", hp: 20, maxHp: 20, strength: heroStrength, armor: 0),
            enemies: [
                EncounterEnemy(
                    id: "e1",
                    name: "TestEnemy",
                    hp: enemyHP,
                    maxHp: enemyMaxHP,
                    power: enemyPower,
                    defense: enemyDefense,
                    abilities: abilities
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

    func testBonusDamage_IncreasesIntentValue() {
        let bonus = makeAbility(id: "bd1", name: "Fury", description: "Extra damage", effect: .bonusDamage(3))
        let ctx = makeContext(enemyPower: 4, abilities: [bonus])
        let engine = EncounterEngine(context: ctx)

        let intent = engine.generateIntent(for: "e1")

        // Base power is 4; bonusDamage(3) should make intent value >= 7
        XCTAssertEqual(intent.type, .attack, "Default intent should be attack")
        XCTAssertGreaterThanOrEqual(intent.value, 7, "Intent value should include bonusDamage(3) on top of base power 4")
    }

    func testArmor_ReducesDamageTaken() {
        // Enemy with armor(2) ability and defense 1 → effective armor = 3
        let armorAbility = makeAbility(id: "arm1", name: "Tough Hide", description: "Reduces damage", effect: .armor(2))
        let ctxWithArmor = makeContext(enemyDefense: 1, abilities: [armorAbility], heroStrength: 5)
        let ctxWithout = makeContext(enemyDefense: 1, abilities: [], heroStrength: 5)

        let engineWith = engineInPlayerPhase(context: ctxWithArmor)
        let engineWithout = engineInPlayerPhase(context: ctxWithout)

        let hpBeforeWith = engineWith.enemies[0].hp
        let hpBeforeWithout = engineWithout.enemies[0].hp

        let resultWith = engineWith.performAction(.attack(targetId: "e1"))
        let resultWithout = engineWithout.performAction(.attack(targetId: "e1"))

        XCTAssertTrue(resultWith.success)
        XCTAssertTrue(resultWithout.success)

        let dealtWith = hpBeforeWith - engineWith.enemies[0].hp
        let dealtWithout = hpBeforeWithout - engineWithout.enemies[0].hp

        XCTAssertLessThan(dealtWith, dealtWithout, "Armor ability should reduce damage taken compared to no armor ability")
    }

    func testRegeneration_HealsAtRoundEnd() {
        let regen = makeAbility(id: "regen1", name: "Regen", description: "Heals", effect: .regeneration(3))
        // High HP + high defense so enemy survives the attack
        let ctx = makeContext(enemyHP: 50, enemyMaxHP: 60, enemyDefense: 10, abilities: [regen])
        let engine = engineInPlayerPhase(context: ctx)

        // Perform an attack to reduce HP (damage = max(1, strength - defense) = 1)
        let result = engine.performAction(.attack(targetId: "e1"))
        XCTAssertTrue(result.success)
        let hpAfterAttack = engine.enemies[0].hp
        XCTAssertLessThan(hpAfterAttack, 50, "Attack should reduce HP")

        // Advance through remaining phases: playerAction → enemyResolution → roundEnd → intent (regen triggers)
        _ = engine.advancePhase() // → enemyResolution
        _ = engine.resolveEnemyAction(enemyId: "e1") // resolve enemy turn
        _ = engine.advancePhase() // → roundEnd
        _ = engine.advancePhase() // → intent (regeneration triggers in roundEnd case)

        let hpAfterRoundEnd = engine.enemies[0].hp
        let healed = hpAfterRoundEnd - hpAfterAttack

        XCTAssertGreaterThan(healed, 0, "Regeneration should heal at round end")
        XCTAssertLessThanOrEqual(healed, 3, "Regeneration should heal up to 3 HP")
    }

    func testRegeneration_DoesNotExceedMaxHP() {
        let regen = makeAbility(id: "regen1", name: "Regen", description: "Heals", effect: .regeneration(5))
        // Enemy already at full HP
        let ctx = makeContext(enemyHP: 30, enemyMaxHP: 30, abilities: [regen])
        let engine = EncounterEngine(context: ctx)

        // Advance through a full round: intent → playerAction → enemyResolution → roundEnd
        _ = engine.advancePhase() // → playerAction
        _ = engine.performAction(.wait)
        _ = engine.advancePhase() // → enemyResolution
        _ = engine.advancePhase() // → roundEnd

        XCTAssertEqual(engine.enemies[0].hp, 30, "HP should not exceed maxHP after regeneration")
    }

    func testMultipleAbilities_AllApply() {
        let bonus = makeAbility(id: "bd1", name: "Fury", description: "Extra damage", effect: .bonusDamage(3))
        let armor = makeAbility(id: "arm1", name: "Tough", description: "Armor", effect: .armor(2))
        let ctx = makeContext(enemyPower: 4, enemyDefense: 1, abilities: [bonus, armor], heroStrength: 6)
        let engine = EncounterEngine(context: ctx)

        // Verify intent has bonus damage
        let intent = engine.generateIntent(for: "e1")
        XCTAssertGreaterThanOrEqual(intent.value, 7, "Intent should include bonusDamage(3) on base power 4")

        // Advance to player action and attack
        _ = engine.advancePhase() // → playerAction
        let hpBefore = engine.enemies[0].hp
        let result = engine.performAction(.attack(targetId: "e1"))
        XCTAssertTrue(result.success)

        let dealt = hpBefore - engine.enemies[0].hp
        // Effective armor = defense(1) + abilityArmor(2) = 3
        // rawDamage = heroStrength(6) - armor(3) = 3
        // Damage should be 3 (no weakness multiplier, no keyword bonus with plain card)
        XCTAssertLessThanOrEqual(dealt, 4, "Armor ability should reduce incoming damage")
        XCTAssertGreaterThanOrEqual(dealt, 1, "Damage should be at least 1")
    }

    func testNoAbilities_BaselineBehavior() {
        let ctx = makeContext(enemyPower: 4, enemyDefense: 0, abilities: [], heroStrength: 5)
        let engine = EncounterEngine(context: ctx)

        // Intent should match base power (no bonus)
        let intent = engine.generateIntent(for: "e1")
        if intent.type == .attack {
            XCTAssertEqual(intent.value, 4, "Without bonusDamage ability, intent value should equal base power")
        }

        // Attack with no armor ability — full damage
        _ = engine.advancePhase() // → playerAction
        let hpBefore = engine.enemies[0].hp
        let result = engine.performAction(.attack(targetId: "e1"))
        XCTAssertTrue(result.success)

        let dealt = hpBefore - engine.enemies[0].hp
        // rawDamage = heroStrength(5) - defense(0) = 5, no multiplier
        XCTAssertGreaterThanOrEqual(dealt, 5, "Without armor ability, full hero strength should apply")
    }
}

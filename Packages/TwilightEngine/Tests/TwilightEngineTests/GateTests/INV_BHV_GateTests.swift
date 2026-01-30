import XCTest
@testable import TwilightEngine

/// Behavior Runtime Invariants — Gate Tests
/// Reference: ENCOUNTER_TEST_MODEL.md §2.3
/// Rule: < 2 seconds, deterministic, no system RNG
final class INV_BHV_GateTests: XCTestCase {

    // Sample behavior for testing
    private func sampleBehavior() -> BehaviorDefinition {
        BehaviorDefinition(id: "aggressive_melee", rules: [
            BehaviorRule(
                conditions: [
                    BehaviorCondition(type: "hp_percent", op: ">=", value: 0.5),
                    BehaviorCondition(type: "round_number", op: ">=", value: 1.0)
                ],
                intentType: "attack",
                valueFormula: "power * heavyAttackMultiplier"
            ),
            BehaviorRule(
                conditions: [
                    BehaviorCondition(type: "hp_percent", op: "<", value: 0.3)
                ],
                intentType: "heal",
                valueFormula: "power"
            )
        ])
    }

    // INV-BHV-002: Unknown condition type → hard fail at validation
    func test_INV_BHV_002_ConditionsParsable() {
        let behavior = sampleBehavior()
        let errors = ConditionParser.validateAll(behavior)

        XCTAssertTrue(errors.isEmpty,
            "All conditions must be parsable. Errors: \(errors.joined(separator: "; "))")
    }

    // INV-BHV-004: value_formula must use whitelist (no hardcoded numbers)
    func test_INV_BHV_004_FormulaWhitelist() {
        let behavior = sampleBehavior()
        let knownMultipliers = CombatBalanceConfig.default.knownMultiplierKeys

        var formulaErrors: [String] = []
        for rule in behavior.rules {
            let unknowns = FormulaValidator.validate(
                formula: rule.valueFormula,
                knownMultipliers: knownMultipliers
            )
            if !unknowns.isEmpty {
                formulaErrors.append("\(rule.intentType): unknown tokens \(unknowns)")
            }
        }

        XCTAssertTrue(formulaErrors.isEmpty,
            "Formulas use non-whitelisted tokens: \(formulaErrors.joined(separator: "; "))")
    }

    // INV-BHV-004 (split): Escalation uses Balance Pack value (not hardcoded)
    func test_INV_BHV_004_EscalationUsesBalancePack() {
        let customConfig = CombatBalanceConfig(
            baseDamage: 3, powerModifier: 1.0, defenseReduction: 0.5,
            diceMax: 6, actionsPerTurn: 3, cardsDrawnPerTurn: 5, maxHandSize: 7,
            escalationResonanceShift: -10.0,
            escalationSurpriseBonus: 7,
            deEscalationRageShield: 5,
            matchMultiplier: 2.0
        )
        let ctx = EncounterContext(
            hero: EncounterHero(id: "h1", hp: 100, maxHp: 100, strength: 10, armor: 2, wisdom: 10),
            enemies: [EncounterEnemy(id: "e1", name: "E", hp: 50, maxHp: 50, wp: 20, maxWp: 20, power: 5, defense: 2)],
            fateDeckSnapshot: FateDeckFixtures.deterministicState(),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42,
            worldResonance: 0,
            balanceConfig: customConfig
        )
        let engine = EncounterEngine(context: ctx)

        // First attack spiritual, then physical to trigger escalation
        _ = engine.performAction(.spiritAttack(targetId: "e1"))
        let result = engine.performAction(.attack(targetId: "e1"))

        // Should use custom surprise bonus (7) from balance config
        let hpChange = result.stateChanges.first { change in
            if case .enemyHPChanged = change { return true }
            return false
        }
        XCTAssertNotNil(hpChange, "Physical attack after spirit should deal damage with escalation bonus")

        // Verify resonance shift uses custom value (-10.0)
        let resShift = result.stateChanges.first { change in
            if case .resonanceShifted = change { return true }
            return false
        }
        XCTAssertNotNil(resShift, "Escalation should shift resonance")
        if case .resonanceShifted(let delta, _) = resShift {
            XCTAssertEqual(delta, -10.0, "Resonance shift must come from balance config")
        }
    }

    // INV-BHV-004 (split): Match bonus multiplier from Balance Pack
    func test_INV_BHV_004_MatchMultiplierFromBalancePack() {
        let config = CombatBalanceConfig.default
        XCTAssertNotNil(config.matchMultiplier, "Match multiplier must be defined in balance config")
        XCTAssertEqual(config.matchMultiplier, 1.5, "Default match multiplier should be 1.5")
    }

    // INV-BHV-005: Intent type must be valid IntentType enum value
    func test_INV_BHV_005_IntentTypesValid() {
        let behavior = sampleBehavior()

        var invalidTypes: [String] = []
        for rule in behavior.rules {
            if !rule.hasValidIntentType {
                invalidTypes.append(rule.intentType)
            }
        }

        XCTAssertTrue(invalidTypes.isEmpty,
            "Invalid intent types: \(invalidTypes.joined(separator: ", "))")
    }
}

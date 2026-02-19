/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/SystemicAsymmetryGateTests.swift
/// Назначение: Gate-тесты Systemic Asymmetry для Phase 3 Disposition Combat (Epic 22).
/// Зона ответственности: Проверяет инварианты INV-DC-035..038.
/// Контекст: Reference: RITUAL_COMBAT_TEST_MODEL.md §3.5

import XCTest
@testable import TwilightEngine

/// Systemic Asymmetry Invariants — Phase 3 Gate Tests (Epic 22)
/// Reference: RITUAL_COMBAT_TEST_MODEL.md §3.5
/// Rule: < 2 seconds per test, deterministic (fixed seed), no system RNG
final class SystemicAsymmetryGateTests: XCTestCase {

    // MARK: - INV-DC-035: Vulnerability lookup returns correct modifier

    /// VulnerabilityRegistry must return correct modifier for (enemyType, actionType, zone).
    func testVulnerabilityLookup_correctModifiers() {
        let registry = VulnerabilityRegistry.makeTestDataset()

        // бандит + influence + yav = +2 (vulnerability)
        let banditInfluenceYav = registry.modifier(
            enemyType: "бандит", actionType: .influence, zone: .yav
        )
        XCTAssertEqual(banditInfluenceYav, 2,
            "бандит + influence + yav must return +2 vulnerability")

        // бандит + strike + nav = -2 (resistance)
        let banditStrikeNav = registry.modifier(
            enemyType: "бандит", actionType: .strike, zone: .nav
        )
        XCTAssertEqual(banditStrikeNav, -2,
            "бандит + strike + nav must return -2 resistance")

        // Undefined combination must return 0
        let banditStrikeYav = registry.modifier(
            enemyType: "бандит", actionType: .strike, zone: .yav
        )
        XCTAssertEqual(banditStrikeYav, 0,
            "Undefined (бандит, strike, yav) must return 0")

        // Unknown enemy must return 0
        let unknownEnemy = registry.modifier(
            enemyType: "несуществующий", actionType: .strike, zone: .yav
        )
        XCTAssertEqual(unknownEnemy, 0,
            "Unknown enemy type must return 0")
    }

    // MARK: - INV-DC-036: Resistance reduces effective power

    /// Negative modifier means resistance (power reduced).
    /// Positive modifier means vulnerability (power increased).
    func testResistance_reducesEffectivePower() {
        let registry = VulnerabilityRegistry.makeTestDataset()

        // дух + sacrifice + prav = -3 (resistance)
        let spiritSacPrav = registry.modifier(
            enemyType: "дух", actionType: .sacrifice, zone: .prav
        )
        XCTAssertEqual(spiritSacPrav, -3,
            "дух + sacrifice + prav must return -3 (resistance)")
        XCTAssertLessThan(spiritSacPrav, 0,
            "Resistance must be negative, reducing effective power")

        // дух + sacrifice + nav = +3 (vulnerability)
        let spiritSacNav = registry.modifier(
            enemyType: "дух", actionType: .sacrifice, zone: .nav
        )
        XCTAssertEqual(spiritSacNav, 3,
            "дух + sacrifice + nav must return +3 (vulnerability)")
        XCTAssertGreaterThan(spiritSacNav, 0,
            "Vulnerability must be positive, increasing effective power")
    }

    // MARK: - INV-DC-037: Resonance changes vulnerability

    /// Same enemy has different modifiers in different zones.
    func testResonanceChanges_vulnerabilityByZone() {
        let registry = VulnerabilityRegistry.makeTestDataset()

        // дух flip: sacrifice weak in Nav (+3), resist in Prav (-3)
        let spiritNav = registry.modifier(
            enemyType: "дух", actionType: .sacrifice, zone: .nav
        )
        let spiritPrav = registry.modifier(
            enemyType: "дух", actionType: .sacrifice, zone: .prav
        )
        XCTAssertEqual(spiritNav, 3,
            "дух sacrifice in Nav must be +3 (vulnerable)")
        XCTAssertEqual(spiritPrav, -3,
            "дух sacrifice in Prav must be -3 (resistant)")
        XCTAssertNotEqual(spiritNav, spiritPrav,
            "Same enemy must have different modifiers in different zones")

        // зверь: strike +2 in Nav, influence +2 in Prav
        let beastStrikeNav = registry.modifier(
            enemyType: "зверь", actionType: .strike, zone: .nav
        )
        let beastInfluencePrav = registry.modifier(
            enemyType: "зверь", actionType: .influence, zone: .prav
        )
        XCTAssertEqual(beastStrikeNav, 2,
            "зверь strike in Nav must be +2")
        XCTAssertEqual(beastInfluencePrav, 2,
            "зверь influence in Prav must be +2")
    }

    // MARK: - INV-DC-038: No absolute vulnerability — modifier capped at ±5

    /// Modifier must be capped at ±5 regardless of definition values.
    func testModifierCap_atPlusMinus5() {
        // Create definition with modifier = 10 (exceeds cap)
        let overflowDef = EnemyVulnerabilityDefinition(
            enemyType: "test_overflow",
            modifiers: [
                VulnerabilityModifier(actionType: .strike, zone: .yav, modifier: 10)
            ]
        )

        // Create definition with modifier = -10 (exceeds cap)
        let underflowDef = EnemyVulnerabilityDefinition(
            enemyType: "test_underflow",
            modifiers: [
                VulnerabilityModifier(actionType: .strike, zone: .yav, modifier: -10)
            ]
        )

        var registry = VulnerabilityRegistry(definitions: [overflowDef, underflowDef])

        // Positive overflow capped at +5
        let capped = registry.modifier(
            enemyType: "test_overflow", actionType: .strike, zone: .yav
        )
        XCTAssertEqual(capped, 5,
            "Modifier 10 must be capped at +5 (maxModifier)")

        // Negative overflow capped at -5
        let cappedNeg = registry.modifier(
            enemyType: "test_underflow", actionType: .strike, zone: .yav
        )
        XCTAssertEqual(cappedNeg, -5,
            "Modifier -10 must be capped at -5 (-maxModifier)")

        // Verify the cap constant
        XCTAssertEqual(VulnerabilityRegistry.maxModifier, 5,
            "maxModifier constant must be 5")

        // Within-range values should pass through unchanged
        let normalDef = EnemyVulnerabilityDefinition(
            enemyType: "test_normal",
            modifiers: [
                VulnerabilityModifier(actionType: .strike, zone: .yav, modifier: 3)
            ]
        )
        registry.register(normalDef)

        let normal = registry.modifier(
            enemyType: "test_normal", actionType: .strike, zone: .yav
        )
        XCTAssertEqual(normal, 3,
            "Modifier 3 within ±5 range must pass through unchanged")
    }
}

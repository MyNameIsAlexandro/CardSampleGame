/// Файл: CardSampleGameTests/GateTests/ConditionValidatorTests.swift
/// Назначение: Содержит реализацию файла ConditionValidatorTests.swift.
/// Зона ответственности: Фиксирует проверяемый контракт и не содержит production-логики.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import TwilightEngine

/// Tests for condition validation (Audit G1 requirement).
/// Ensures all conditions in packs use known, valid types.
///
/// Architecture note: This engine uses typed enums for conditions,
/// not string expressions. This provides compile-time safety against typos
/// like "WorldResonanse" - they simply won't compile or parse.
final class ConditionValidatorTests: XCTestCase {

    // MARK: - Whitelist Tests

    func testValidAbilityConditionTypesExist() throws {
        // Verify the whitelist is not empty
        let types = ConditionValidator.allValidConditionTypes()
        XCTAssertFalse(types.isEmpty, "Should have valid condition types")

        // Verify known conditions are in the list
        XCTAssertTrue(types.contains("hpBelowPercent"), "hpBelowPercent should be valid")
        XCTAssertTrue(types.contains("targetFullHP"), "targetFullHP should be valid")
        XCTAssertTrue(types.contains("firstAttack"), "firstAttack should be valid")
    }

    func testValidAbilityTriggersExist() throws {
        let triggers = ConditionValidator.allValidTriggers()
        XCTAssertFalse(triggers.isEmpty, "Should have valid triggers")

        // Verify known triggers
        XCTAssertTrue(triggers.contains("onAttack"), "onAttack should be valid")
        XCTAssertTrue(triggers.contains("turnStart"), "turnStart should be valid")
        XCTAssertTrue(triggers.contains("manual"), "manual should be valid")
    }

    func testValidAbilityEffectTypesExist() throws {
        let effects = ConditionValidator.allValidEffectTypes()
        XCTAssertFalse(effects.isEmpty, "Should have valid effect types")

        // Verify known effects
        XCTAssertTrue(effects.contains("bonusDamage"), "bonusDamage should be valid")
        XCTAssertTrue(effects.contains("heal"), "heal should be valid")
        XCTAssertTrue(effects.contains("drawCard"), "drawCard should be valid")
    }

    // MARK: - Rejection Tests

    func testRejectsUnknownConditionType() throws {
        // Typos like "WorldResonanse" should be rejected
        XCTAssertFalse(
            ConditionValidator.validateAbilityCondition("WorldResonanse"),
            "Unknown condition 'WorldResonanse' should be rejected"
        )
        XCTAssertFalse(
            ConditionValidator.validateAbilityCondition("hp_below_percent"),
            "Snake_case version should be rejected (we use camelCase)"
        )
        XCTAssertFalse(
            ConditionValidator.validateAbilityCondition(""),
            "Empty string should be rejected"
        )
    }

    func testRejectsUnknownTrigger() throws {
        XCTAssertFalse(
            ConditionValidator.validateAbilityTrigger("onDamageRecieved"), // typo
            "Typo 'onDamageRecieved' should be rejected"
        )
        XCTAssertFalse(
            ConditionValidator.validateAbilityTrigger("on_attack"),
            "Snake_case should be rejected"
        )
    }

    func testRejectsUnknownEffectType() throws {
        XCTAssertFalse(
            ConditionValidator.validateAbilityEffectType("bonusDammage"), // typo
            "Typo 'bonusDammage' should be rejected"
        )
        XCTAssertFalse(
            ConditionValidator.validateAbilityEffectType("bonus_damage"),
            "Snake_case should be rejected"
        )
    }

    // MARK: - Integration Test: All Pack Conditions Valid

    func testAllPackConditionsAreValid() throws {
        let registry = try TestContentLoader.makeStandardRegistry()

        // Validate all loaded packs
        for (packId, pack) in registry.loadedPacks {
            let result = ConditionValidator.validate(pack: pack)
            if !result.isValid {
                XCTFail("Pack '\(packId)' has invalid conditions:\n\(result.errors.joined(separator: "\n"))")
            }
        }
    }

    // MARK: - Type Safety Tests

    func testConditionsUseTypedEnumsNotStrings() throws {
        // This test documents that our architecture prevents string-based typos
        // by using typed enums that are validated at parse time

        // AbilityConditionType is an enum with CaseIterable
        let allConditionTypes = AbilityConditionType.allCases
        XCTAssertFalse(allConditionTypes.isEmpty, "AbilityConditionType should have cases")

        // Attempting to decode an unknown type would fail JSON parsing
        let invalidJSON = """
        {"type": "WorldResonanse", "value": 50}
        """.data(using: .utf8)!

        // This should fail to decode because "WorldResonanse" is not a valid enum case
        XCTAssertThrowsError(try JSONDecoder().decode(AbilityCondition.self, from: invalidJSON)) { error in
            // Verify it's a decoding error for unknown enum value
            XCTAssertTrue(error is DecodingError, "Should throw DecodingError for unknown enum value")
        }
    }

    func testValidConditionDecodesSuccessfully() throws {
        // Valid condition should decode
        let validJSON = """
        {"type": "hpBelowPercent", "value": 50}
        """.data(using: .utf8)!

        let condition = try JSONDecoder().decode(AbilityCondition.self, from: validJSON)
        XCTAssertEqual(condition.type, .hpBelowPercent)
        XCTAssertEqual(condition.value, 50)
    }

    func testSnakeCaseEnumValueIsRejected() throws {
        // Enum values must use camelCase, not snake_case
        // keyDecodingStrategy only converts dictionary keys, not enum string values
        let snakeCaseJSON = """
        {"type": "hp_below_percent", "value": 50}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        // This should FAIL because "hp_below_percent" is not a valid enum value
        // Our enums use camelCase: "hpBelowPercent"
        XCTAssertThrowsError(try decoder.decode(AbilityCondition.self, from: snakeCaseJSON)) { error in
            XCTAssertTrue(error is DecodingError, "Snake_case enum values should be rejected")
        }
    }
}

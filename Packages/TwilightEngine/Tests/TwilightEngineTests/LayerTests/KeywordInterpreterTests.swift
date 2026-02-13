/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/LayerTests/KeywordInterpreterTests.swift
/// Назначение: Содержит реализацию файла KeywordInterpreterTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import TwilightEngine

/// Keyword Interpreter component tests
/// Reference: ENCOUNTER_TEST_MODEL.md §3.2
/// Tests context × keyword interpretation matrix
final class KeywordInterpreterTests: XCTestCase {

    // #34: Same keyword gives different effects in different contexts
    func testSurgeInCombatPhysical() {
        let combatEffect = KeywordInterpreter.resolve(keyword: .surge, context: .combatPhysical)
        let exploreEffect = KeywordInterpreter.resolve(keyword: .surge, context: .exploration)

        XCTAssertGreaterThan(combatEffect.bonusDamage, 0,
            "Surge in combat should give bonus damage")
        XCTAssertNotNil(exploreEffect.special,
            "Surge in exploration should have special effect")
        XCTAssertNotEqual(combatEffect, exploreEffect,
            "Same keyword must give different effects in different contexts")
    }

    // #35: Match bonus when suit matches action type
    func testMatchBonusEnhanced() {
        let base = KeywordInterpreter.resolve(keyword: .surge, context: .combatPhysical, isMatch: false)
        let matched = KeywordInterpreter.resolve(keyword: .surge, context: .combatPhysical, isMatch: true)

        XCTAssertEqual(matched.bonusDamage, base.bonusDamage * 2,
            "Match bonus should double the keyword effect")
    }

    // #36: Mismatch gives only value, no keyword effect
    func testMismatchSuppressed() {
        let effect = KeywordInterpreter.resolveWithAlignment(
            keyword: .surge,
            context: .combatPhysical,
            isMismatch: true
        )

        XCTAssertEqual(effect.bonusDamage, 0, "Mismatch should suppress damage bonus")
        XCTAssertEqual(effect.bonusValue, 0, "Mismatch should suppress value bonus")
        XCTAssertNil(effect.special, "Mismatch should suppress special effect")
    }

    // #37: All keywords × all contexts = 25 combinations, none nil
    func testAllKeywordsAllContexts() {
        for keyword in FateKeyword.allCases {
            for context in ActionContext.allCases {
                let effect = KeywordInterpreter.resolve(keyword: keyword, context: context)
                // Effect should have at least one non-zero field
                let hasEffect = effect.bonusDamage > 0 || effect.bonusValue > 0 || effect.special != nil
                XCTAssertTrue(hasEffect,
                    "\(keyword)×\(context) must have a defined effect")
            }
        }
    }
}

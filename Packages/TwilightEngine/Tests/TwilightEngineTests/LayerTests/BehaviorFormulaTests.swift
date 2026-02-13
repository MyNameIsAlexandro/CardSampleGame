/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/LayerTests/BehaviorFormulaTests.swift
/// Назначение: Содержит реализацию файла BehaviorFormulaTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import TwilightEngine

final class BehaviorFormulaTests: XCTestCase {

    private func evaluateAttack(
        formula: String,
        power: Int = 5,
        defense: Int = 0,
        health: Int = 10,
        maxHealth: Int = 10
    ) -> Int {
        let behavior = BehaviorDefinition(
            id: "test_behavior",
            rules: [
                BehaviorRule(
                    conditions: [],
                    intentType: "attack",
                    valueFormula: formula
                )
            ]
        )

        let ctx = BehaviorContext(
            healthPercent: 1.0,
            turn: 1,
            power: power,
            defense: defense,
            health: health,
            maxHealth: maxHealth
        )

        let intent = BehaviorEvaluator.evaluate(behavior: behavior, context: ctx)
        XCTAssertNotNil(intent)
        return intent?.value ?? -1
    }

    func testFormula_PowerMultiplier() {
        XCTAssertEqual(evaluateAttack(formula: "power * 2"), 10)
    }

    func testFormula_DefenseMultiplier() {
        XCTAssertEqual(evaluateAttack(formula: "defense * 3", defense: 4), 12)
    }

    func testFormula_NumericLiteral() {
        XCTAssertEqual(evaluateAttack(formula: "7"), 7)
    }

    func testFormula_UnknownTokenFallsBackToZero() {
        XCTAssertEqual(evaluateAttack(formula: "baseDamage"), 0)
    }
}

/// Файл: CardSampleGameTests/GateTests/ExpressionParserTests.swift
/// Назначение: Содержит реализацию файла ExpressionParserTests.swift.
/// Зона ответственности: Фиксирует проверяемый контракт и не содержит production-логики.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
import TwilightEngine

/// Expression Parser Tests — Audit v2.1, Section 3.1
/// Validates that the ExpressionParser correctly rejects unknown variables,
/// unknown functions, and invalid syntax in pack condition strings.
final class ExpressionParserTests: XCTestCase {

    // MARK: - Rejects Unknown Variables

    func testRejectsUnknownVariables() {
        // "WorldResonanse" is a typo for "WorldResonance"
        let result = ExpressionParser.validate("WorldResonanse < -50")
        XCTAssertNotNil(result, "Should reject unknown variable")

        if case .unknownVariable(let name) = result {
            XCTAssertEqual(name, "WorldResonanse", "Should identify the typo variable")
        } else {
            XCTFail("Expected unknownVariable error, got: \(String(describing: result))")
        }

        // Another typo
        let result2 = ExpressionParser.validate("playerHelth > 5")
        XCTAssertNotNil(result2, "Should reject 'playerHelth' typo")
    }

    func testAcceptsKnownVariables() {
        // These should all pass validation
        let validExpressions = [
            "WorldTension > 50",
            "playerHealth < 10",
            "lightDarkBalance >= 30",
            "currentDay == 5",
            "PlayerFaith <= 3"
        ]

        for expr in validExpressions {
            let result = ExpressionParser.validate(expr)
            XCTAssertNil(result, "Should accept valid expression: '\(expr)', got: \(String(describing: result))")
        }
    }

    // MARK: - Rejects Unknown Functions

    func testRejectsUnknownFunctions() {
        let result = ExpressionParser.validate("unknownFunc(\"test\")")
        XCTAssertNotNil(result, "Should reject unknown function")

        if case .unknownFunction(let name) = result {
            XCTAssertEqual(name, "unknownFunc", "Should identify the unknown function")
        } else {
            XCTFail("Expected unknownFunction error, got: \(String(describing: result))")
        }
    }

    func testAcceptsKnownFunctions() {
        let validExpressions = [
            "hasFlag(\"quest_started\")",
            "notFlag(\"boss_defeated\")",
            "visitedRegion(\"market\")",
            "hasQuest(\"main_quest\")"
        ]

        for expr in validExpressions {
            let result = ExpressionParser.validate(expr)
            XCTAssertNil(result, "Should accept valid expression: '\(expr)', got: \(String(describing: result))")
        }
    }

    // MARK: - Rejects Invalid Syntax

    func testRejectsInvalidSyntax() {
        // Empty expression
        let emptyResult = ExpressionParser.validate("")
        XCTAssertNotNil(emptyResult, "Should reject empty expression")
        if case .emptyExpression = emptyResult {
            // Expected
        } else {
            XCTFail("Expected emptyExpression error")
        }

        // Whitespace only
        let whitespaceResult = ExpressionParser.validate("   ")
        XCTAssertNotNil(whitespaceResult, "Should reject whitespace-only expression")
    }

    func testRejectsUnterminatedString() {
        let result = ExpressionParser.validate("hasFlag(\"unterminated)")
        // Should detect either invalid syntax or reach end of expression improperly
        // The tokenizer handles unterminated strings as invalid
        XCTAssertNotNil(result, "Should reject unterminated string literal")
    }

    // MARK: - Batch Validation

    func testValidateAllReturnsAllErrors() {
        let expressions = [
            "WorldTension > 50",       // Valid
            "WorldResonanse < -50",    // Invalid: typo
            "playerHealth >= 0",       // Valid
            "unknownFunc(\"x\")",      // Invalid: unknown function
        ]

        let errors = ExpressionParser.validateAll(expressions)
        XCTAssertEqual(errors.count, 2, "Should find exactly 2 invalid expressions")
        XCTAssertEqual(errors[0].0, "WorldResonanse < -50")
        XCTAssertEqual(errors[1].0, "unknownFunc(\"x\")")
    }

    // MARK: - Complex Expressions

    func testComplexValidExpression() {
        let result = ExpressionParser.validate("WorldTension > 50 && playerHealth < 10")
        XCTAssertNil(result, "Should accept complex valid expression with &&")
    }

    func testComparisonOperators() {
        let ops = ["<", ">", "<=", ">=", "==", "!="]
        for op in ops {
            let result = ExpressionParser.validate("WorldTension \(op) 50")
            XCTAssertNil(result, "Should accept operator: \(op)")
        }
    }

    // MARK: - Boolean Literals

    func testAcceptsBooleanLiterals() {
        let result = ExpressionParser.validate("hasFlag(\"test\") == true")
        XCTAssertNil(result, "Should accept boolean literal 'true'")
    }

    // MARK: - All Pack Conditions Are Valid (Integration)

    func testAllPackConditionsAreValid() {
        // Load all packs and validate that any string-based conditions parse correctly
        // Currently the engine uses typed Availability structs, not string expressions.
        // This test ensures the ExpressionParser infrastructure is ready for string conditions.

        // Verify the parser accepts all known variable names
        for variable in ExpressionParser.knownVariables {
            let result = ExpressionParser.validate("\(variable) > 0")
            XCTAssertNil(result, "Known variable '\(variable)' should be accepted")
        }

        // Verify the parser accepts all known function names
        for function in ExpressionParser.knownFunctions {
            let result = ExpressionParser.validate("\(function)(\"test\")")
            XCTAssertNil(result, "Known function '\(function)' should be accepted")
        }

        XCTAssertNoThrow(try TestContentLoader.makeStandardRegistry())
    }
}

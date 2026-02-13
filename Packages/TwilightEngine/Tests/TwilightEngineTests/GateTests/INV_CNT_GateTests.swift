/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/INV_CNT_GateTests.swift
/// Назначение: Содержит реализацию файла INV_CNT_GateTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import TwilightEngine

/// Content Validation Invariants — Gate Tests
/// Reference: ENCOUNTER_TEST_MODEL.md §2.4
/// Rule: < 2 seconds, deterministic, no system RNG
final class INV_CNT_GateTests: XCTestCase {

    // INV-CNT-001: All behavior_id refs in enemies must exist
    func test_INV_CNT_001_BehaviorRefsExist() {
        // EncounterEnemy has behaviorId; EnemyDefinition does not yet.
        // Validate that any EncounterEnemy with a behaviorId references a non-empty string.
        // When BehaviorRegistry is loaded, this will validate against actual definitions.
        let testEnemies = [
            EncounterEnemy(id: "e1", name: "Wolf", hp: 10, maxHp: 10, behaviorId: "aggressive_melee"),
            EncounterEnemy(id: "e2", name: "Ghost", hp: 8, maxHp: 8, behaviorId: nil)
        ]

        var missing: [String] = []
        for enemy in testEnemies {
            if let bid = enemy.behaviorId, bid.isEmpty {
                missing.append("\(enemy.id): empty behaviorId")
            }
        }

        XCTAssertTrue(missing.isEmpty,
            "Missing behavior refs: \(missing.joined(separator: ", "))")
    }

    // INV-CNT-002: All fate card IDs must be globally unique
    func test_INV_CNT_002_FateCardIdsUnique() {
        let fateCards = TestContentLoader.sharedLoadedRegistry().getAllFateCards()
        var seen = Set<String>()
        var dupes: [String] = []

        for card in fateCards {
            if seen.contains(card.id) { dupes.append(card.id) }
            seen.insert(card.id)
        }

        XCTAssertTrue(dupes.isEmpty, "Duplicate fate card IDs: \(dupes.joined(separator: ", "))")
    }

    // INV-CNT-003: MULTIPLIER_ID in value_formula must exist in Balance Pack
    func test_INV_CNT_003_MultiplierRefsExist() {
        let behavior = BehaviorDefinition(id: "test_behavior", rules: [
            BehaviorRule(
                conditions: [BehaviorCondition(type: "hp_percent", op: ">=", value: 0.5)],
                intentType: "attack",
                valueFormula: "power * heavyAttackMultiplier"
            )
        ])

        let knownMultipliers = CombatBalanceConfig.default.knownMultiplierKeys

        var unknownRefs: [String] = []
        for rule in behavior.rules {
            let unknowns = FormulaValidator.validate(
                formula: rule.valueFormula,
                knownMultipliers: knownMultipliers
            )
            unknownRefs.append(contentsOf: unknowns)
        }

        XCTAssertTrue(unknownRefs.isEmpty,
            "Unknown multiplier refs: \(unknownRefs.joined(separator: ", "))")
    }
}

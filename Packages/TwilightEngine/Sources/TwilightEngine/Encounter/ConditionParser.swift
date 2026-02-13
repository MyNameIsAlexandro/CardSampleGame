/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Encounter/ConditionParser.swift
/// Назначение: Содержит реализацию файла ConditionParser.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Condition Parser

/// Validates behavior conditions against known types and operators
public struct ConditionParser {

    /// Known condition types
    public static let knownTypes: Set<String> = [
        "world_resonance", "hp_percent", "player_attacking_wp",
        "round_number", "enemy_count"
    ]

    /// Known operators
    public static let knownOperators: Set<String> = [
        ">=", "<=", "==", "!=", ">", "<"
    ]

    /// Validate a single condition
    public static func validate(_ condition: BehaviorCondition) -> Bool {
        knownTypes.contains(condition.type) && knownOperators.contains(condition.op)
    }

    /// Validate all conditions in a behavior definition
    public static func validateAll(_ behavior: BehaviorDefinition) -> [String] {
        var errors: [String] = []
        for (ruleIdx, rule) in behavior.rules.enumerated() {
            for (condIdx, cond) in rule.conditions.enumerated() {
                if !knownTypes.contains(cond.type) {
                    errors.append("Rule[\(ruleIdx)].condition[\(condIdx)]: unknown type '\(cond.type)'")
                }
                if !knownOperators.contains(cond.op) {
                    errors.append("Rule[\(ruleIdx)].condition[\(condIdx)]: unknown operator '\(cond.op)'")
                }
            }
        }
        return errors
    }
}

/// Validates value formulas — no hardcoded numbers allowed
public struct FormulaValidator {

    /// Known formula tokens (variable names allowed in formulas)
    public static let knownVariables: Set<String> = [
        "power", "defense", "health", "maxHealth",
        "will", "maxWill", "turnNumber"
    ]

    /// Validate that a formula uses only known variables and multiplier IDs
    /// Returns list of unknown tokens (empty = valid)
    public static func validate(formula: String, knownMultipliers: Set<String>) -> [String] {
        let tokens = formula
            .replacingOccurrences(of: "*", with: " ")
            .replacingOccurrences(of: "+", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .split(separator: " ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var unknowns: [String] = []
        for token in tokens {
            if knownVariables.contains(token) { continue }
            if knownMultipliers.contains(token) { continue }
            unknowns.append(token)
        }
        return unknowns
    }
}

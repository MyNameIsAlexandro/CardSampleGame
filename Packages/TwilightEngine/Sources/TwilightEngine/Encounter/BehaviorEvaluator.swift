import Foundation

// MARK: - Behavior Evaluator

/// Runtime context for evaluating behavior conditions
public struct BehaviorContext {
    public let healthPercent: Double
    public let turn: Int
    public let power: Int
    public let defense: Int
    public let health: Int
    public let maxHealth: Int
    public let worldResonance: Float?
    public let lastPlayerAction: String?

    public init(
        healthPercent: Double,
        turn: Int,
        power: Int,
        defense: Int,
        health: Int,
        maxHealth: Int,
        worldResonance: Float? = nil,
        lastPlayerAction: String? = nil
    ) {
        self.healthPercent = healthPercent
        self.turn = turn
        self.power = power
        self.defense = defense
        self.health = health
        self.maxHealth = maxHealth
        self.worldResonance = worldResonance
        self.lastPlayerAction = lastPlayerAction
    }
}

/// Evaluates BehaviorDefinition rules against runtime context
/// and produces EnemyIntent from the first matching rule.
public struct BehaviorEvaluator {

    /// Evaluate behavior rules in order, return intent from first match.
    /// Returns nil if no behavior or no rules match (caller falls back to default).
    public static func evaluate(
        behavior: BehaviorDefinition?,
        context: BehaviorContext
    ) -> EnemyIntent? {
        guard let behavior = behavior else { return nil }

        for rule in behavior.rules {
            if allConditionsMet(rule.conditions, context: context) {
                return makeIntent(from: rule, context: context)
            }
        }

        // Default intent fallback
        if let intentStr = behavior.defaultIntent,
           let intentType = IntentType(rawValue: intentStr) {
            let value: Int
            if let formula = behavior.defaultValue {
                value = Int(resolveFormulaToken(formula, context: context))
            } else {
                value = context.power
            }
            return makeIntentFromType(intentType, value: value)
        }

        return nil
    }

    // MARK: - Condition Evaluation

    private static func allConditionsMet(
        _ conditions: [BehaviorCondition],
        context: BehaviorContext
    ) -> Bool {
        for condition in conditions {
            if !evaluateCondition(condition, context: context) {
                return false
            }
        }
        return true
    }

    private static func evaluateCondition(
        _ condition: BehaviorCondition,
        context: BehaviorContext
    ) -> Bool {
        let lhs = resolveConditionValue(condition.type, context: context)
        let rhs = condition.value
        return compare(lhs, condition.op, rhs)
    }

    private static func resolveConditionValue(_ type: String, context: BehaviorContext) -> Double {
        switch type {
        case "health_percent":
            return context.healthPercent
        case "turn":
            return Double(context.turn)
        case "turn_mod3":
            return Double(context.turn % 3)
        case "world_resonance":
            return Double(context.worldResonance ?? 0)
        case "last_player_action":
            // 1.0 = physical, 2.0 = spiritual, 0.0 = none
            switch context.lastPlayerAction {
            case "physical": return 1.0
            case "spiritual": return 2.0
            default: return 0.0
            }
        default:
            return 0
        }
    }

    private static func compare(_ lhs: Double, _ op: String, _ rhs: Double) -> Bool {
        switch op {
        case "<": return lhs < rhs
        case "<=": return lhs <= rhs
        case ">": return lhs > rhs
        case ">=": return lhs >= rhs
        case "==": return abs(lhs - rhs) < 0.001
        case "!=": return abs(lhs - rhs) >= 0.001
        default: return false
        }
    }

    // MARK: - Intent Construction

    private static func makeIntent(from rule: BehaviorRule, context: BehaviorContext) -> EnemyIntent? {
        guard let intentType = IntentType(rawValue: rule.intentType) else { return nil }
        let value = evaluateFormula(rule.valueFormula, context: context)

        switch intentType {
        case .attack:
            return .attack(damage: value)
        case .ritual:
            return .ritual(resonanceShift: -value)
        case .block:
            return .block(reduction: value)
        case .buff:
            return .buff(amount: value)
        case .heal:
            return .heal(amount: value)
        case .summon:
            return .attack(damage: value) // fallback
        case .prepare:
            return .prepare(value: value)
        case .restoreWP:
            return .restoreWP(amount: value)
        case .debuff:
            return .debuff(amount: value)
        case .defend:
            return .defend(reduction: value)
        }
    }

    private static func makeIntentFromType(_ type: IntentType, value: Int) -> EnemyIntent {
        switch type {
        case .attack: return .attack(damage: value)
        case .ritual: return .ritual(resonanceShift: -value)
        case .block: return .block(reduction: value)
        case .buff: return .buff(amount: value)
        case .heal: return .heal(amount: value)
        case .summon: return .attack(damage: value)
        case .prepare: return .prepare(value: value)
        case .restoreWP: return .restoreWP(amount: value)
        case .debuff: return .debuff(amount: value)
        case .defend: return .defend(reduction: value)
        }
    }

    // MARK: - Formula Evaluation

    /// Simple formula evaluator: supports "power", "defense", numeric literals, and "* N" multipliers
    private static func evaluateFormula(_ formula: String, context: BehaviorContext) -> Int {
        let trimmed = formula.trimmingCharacters(in: .whitespaces)

        // Check for "variable * multiplier" pattern
        if trimmed.contains("*") {
            let parts = trimmed.split(separator: "*").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 {
                let lhs = resolveFormulaToken(parts[0], context: context)
                let rhs = resolveFormulaToken(parts[1], context: context)
                return Int(lhs * rhs)
            }
        }

        // Single token
        return Int(resolveFormulaToken(trimmed, context: context))
    }

    private static func resolveFormulaToken(_ token: String, context: BehaviorContext) -> Double {
        switch token {
        case "power": return Double(context.power)
        case "defense": return Double(context.defense)
        case "health": return Double(context.health)
        case "maxHealth": return Double(context.maxHealth)
        case "turnNumber": return Double(context.turn)
        default:
            return Double(token) ?? 0
        }
    }
}

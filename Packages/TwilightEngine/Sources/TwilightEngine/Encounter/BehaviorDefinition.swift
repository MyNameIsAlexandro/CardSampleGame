import Foundation

// MARK: - Behavior Definition

/// Declarative enemy behavior loaded from behaviors.json
public struct BehaviorDefinition: Codable, Equatable {
    public let id: String
    public let rules: [BehaviorRule]
    public let defaultIntent: String?
    public let defaultValue: String?

    public init(id: String, rules: [BehaviorRule], defaultIntent: String? = nil, defaultValue: String? = nil) {
        self.id = id
        self.rules = rules
        self.defaultIntent = defaultIntent
        self.defaultValue = defaultValue
    }
}

/// A single behavior rule: conditions → intent
public struct BehaviorRule: Codable, Equatable {
    public let conditions: [BehaviorCondition]
    public let intentType: String
    public let valueFormula: String

    public init(conditions: [BehaviorCondition], intentType: String, valueFormula: String) {
        self.conditions = conditions
        self.intentType = intentType
        self.valueFormula = valueFormula
    }

    /// Check if intentType is a valid IntentType rawValue
    public var hasValidIntentType: Bool {
        IntentType(rawValue: intentType) != nil
    }
}

/// A condition for rule activation
public struct BehaviorCondition: Codable, Equatable {
    public let type: String
    public let op: String
    public let value: Double

    enum CodingKeys: String, CodingKey {
        case type
        case op = "operator"
        case value
    }

    public init(type: String, op: String, value: Double) {
        self.type = type
        self.op = op
        self.value = value
    }
}

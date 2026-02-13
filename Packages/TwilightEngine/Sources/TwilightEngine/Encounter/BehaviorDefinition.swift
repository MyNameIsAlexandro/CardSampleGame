/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Encounter/BehaviorDefinition.swift
/// Назначение: Содержит реализацию файла BehaviorDefinition.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Behavior Definition

/// Declarative enemy behavior loaded from behaviors.json
public struct BehaviorDefinition: Codable, Equatable {
    public var id: String
    public var rules: [BehaviorRule]
    public var defaultIntent: String?
    public var defaultValue: String?

    public init(id: String, rules: [BehaviorRule], defaultIntent: String? = nil, defaultValue: String? = nil) {
        self.id = id
        self.rules = rules
        self.defaultIntent = defaultIntent
        self.defaultValue = defaultValue
    }
}

/// A single behavior rule: conditions → intent
public struct BehaviorRule: Codable, Equatable {
    public var conditions: [BehaviorCondition]
    public var intentType: String
    public var valueFormula: String

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
    public var type: String
    public var op: String
    public var value: Double

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

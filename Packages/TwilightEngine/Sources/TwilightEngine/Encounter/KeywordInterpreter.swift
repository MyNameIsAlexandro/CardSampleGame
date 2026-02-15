/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Encounter/KeywordInterpreter.swift
/// Назначение: Содержит реализацию файла KeywordInterpreter.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Action Context

/// Context in which a fate card keyword is interpreted
public enum ActionContext: String, CaseIterable, Sendable {
    case combatPhysical
    case combatSpiritual
    case exploration
    case dialogue
    case defense
    case skillCheck
}

// MARK: - Keyword Effect

/// Result of interpreting a keyword in a given context
public struct KeywordEffect: Equatable, Sendable {
    public let bonusDamage: Int
    public let bonusValue: Int
    public let special: String?

    public init(bonusDamage: Int = 0, bonusValue: Int = 0, special: String? = nil) {
        self.bonusDamage = bonusDamage
        self.bonusValue = bonusValue
        self.special = special
    }

    public static let none = KeywordEffect()
}

// MARK: - Keyword Interpreter

/// Resolves fate card keywords into context-dependent effects
public struct KeywordInterpreter {

    /// Resolve a keyword's effect given the action context
    /// - Parameters:
    ///   - keyword: The fate card's keyword
    ///   - context: Current action context
    ///   - baseValue: Card's base value for scaling
    ///   - isMatch: Whether card suit matches action alignment
    /// - Returns: Computed keyword effect
    public static func resolve(
        keyword: FateKeyword,
        context: ActionContext,
        baseValue: Int = 0,
        isMatch: Bool = false,
        matchMultiplier: Double = 2.0
    ) -> KeywordEffect {
        let base = baseEffect(keyword: keyword, context: context)
        if isMatch {
            return KeywordEffect(
                bonusDamage: Int(Double(base.bonusDamage) * matchMultiplier),
                bonusValue: Int(Double(base.bonusValue) * matchMultiplier),
                special: base.special
            )
        }
        return base
    }

    /// Resolve with mismatch suppression — opposing suit nullifies keyword
    public static func resolveWithAlignment(
        keyword: FateKeyword,
        context: ActionContext,
        baseValue: Int = 0,
        isMatch: Bool = false,
        isMismatch: Bool = false,
        matchMultiplier: Double = 2.0
    ) -> KeywordEffect {
        if isMismatch {
            return KeywordEffect(bonusDamage: 0, bonusValue: 0, special: nil)
        }
        return resolve(keyword: keyword, context: context, baseValue: baseValue, isMatch: isMatch, matchMultiplier: matchMultiplier)
    }

    // MARK: - Interpretation Matrix

    private static func baseEffect(keyword: FateKeyword, context: ActionContext) -> KeywordEffect {
        switch (keyword, context) {
        // Surge — damage/power boost
        case (.surge, .combatPhysical):
            return KeywordEffect(bonusDamage: 2)
        case (.surge, .combatSpiritual):
            return KeywordEffect(bonusDamage: 1, special: "resonance_push")
        case (.surge, .exploration):
            return KeywordEffect(bonusValue: 1, special: "discovery")
        case (.surge, .dialogue):
            return KeywordEffect(bonusValue: 1, special: "persuade")
        case (.surge, .defense):
            return KeywordEffect(bonusValue: 1)
        case (.surge, .skillCheck):
            return KeywordEffect(bonusValue: 1, special: "discovery")

        // Focus — precision/accuracy
        case (.focus, .combatPhysical):
            return KeywordEffect(bonusDamage: 1, special: "ignore_armor")
        case (.focus, .combatSpiritual):
            return KeywordEffect(bonusDamage: 1, special: "will_pierce")
        case (.focus, .exploration):
            return KeywordEffect(bonusValue: 2, special: "detail")
        case (.focus, .dialogue):
            return KeywordEffect(bonusValue: 2)
        case (.focus, .defense):
            return KeywordEffect(bonusValue: 1, special: "counter")
        case (.focus, .skillCheck):
            return KeywordEffect(bonusValue: 2, special: "detail")

        // Echo — repeat/amplify
        case (.echo, .combatPhysical):
            return KeywordEffect(bonusDamage: 1, special: "echo_strike")
        case (.echo, .combatSpiritual):
            return KeywordEffect(bonusDamage: 1, special: "echo_prayer")
        case (.echo, .exploration):
            return KeywordEffect(bonusValue: 1, special: "echo_find")
        case (.echo, .dialogue):
            return KeywordEffect(bonusValue: 1, special: "echo_voice")
        case (.echo, .defense):
            return KeywordEffect(bonusValue: 2, special: "echo_shield")
        case (.echo, .skillCheck):
            return KeywordEffect(bonusValue: 1, special: "echo_find")

        // Shadow — stealth/evasion
        case (.shadow, .combatPhysical):
            return KeywordEffect(bonusDamage: 1, special: "ambush")
        case (.shadow, .combatSpiritual):
            return KeywordEffect(bonusValue: 1, special: "veil")
        case (.shadow, .exploration):
            return KeywordEffect(bonusValue: 2, special: "stealth")
        case (.shadow, .dialogue):
            return KeywordEffect(bonusValue: 1, special: "intimidate")
        case (.shadow, .defense):
            return KeywordEffect(bonusValue: 1, special: "evade")
        case (.shadow, .skillCheck):
            return KeywordEffect(bonusValue: 2, special: "stealth")

        // Ward — protection/shield
        case (.ward, .combatPhysical):
            return KeywordEffect(bonusValue: 1, special: "parry")
        case (.ward, .combatSpiritual):
            return KeywordEffect(bonusValue: 1, special: "spirit_shield")
        case (.ward, .exploration):
            return KeywordEffect(bonusValue: 1, special: "safe_passage")
        case (.ward, .dialogue):
            return KeywordEffect(bonusValue: 1, special: "composure")
        case (.ward, .defense):
            return KeywordEffect(bonusDamage: 0, bonusValue: 3, special: "fortify")
        case (.ward, .skillCheck):
            return KeywordEffect(bonusValue: 1, special: "safe_passage")
        }
    }
}

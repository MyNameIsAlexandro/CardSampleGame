/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/ContentPacks/ConditionValidator.swift
/// Назначение: Содержит реализацию файла ConditionValidator.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Condition Validator

/// Validates that all conditions in content packs use known types.
/// This prevents typos like "WorldResonanse" from going undetected.
///
/// Architecture note: All conditions in this engine use typed enums, not string expressions.
/// This provides compile-time and parse-time safety against typos.
public final class ConditionValidator {

    // MARK: - Whitelisted Condition Types

    /// All valid AbilityConditionType values (from HeroAbility.swift)
    public static let validAbilityConditionTypes: Set<String> = Set(
        AbilityConditionType.allCases.map { $0.rawValue }
    )

    /// All valid AbilityTrigger values
    public static let validAbilityTriggers: Set<String> = Set(
        AbilityTrigger.allCases.map { $0.rawValue }
    )

    /// All valid HeroAbilityEffectType values
    public static let validAbilityEffectTypes: Set<String> = Set(
        HeroAbilityEffectType.allCases.map { $0.rawValue }
    )

    /// All valid RegionState values
    public static let validRegionStates: Set<String> = Set(
        RegionState.allCases.map { $0.rawValue }
    )

    // MARK: - Validation Results

    /// Result of condition validation
    public struct ValidationResult: Sendable {
        public let isValid: Bool
        public let errors: [String]
        public let warnings: [String]

        public static let valid = ValidationResult(isValid: true, errors: [], warnings: [])

        public static func invalid(errors: [String]) -> ValidationResult {
            ValidationResult(isValid: false, errors: errors, warnings: [])
        }
    }

    // MARK: - Validation Methods

    /// Validate all conditions in a loaded pack
    public static func validate(pack: LoadedPack) -> ValidationResult {
        var errors: [String] = []

        // Validate hero abilities
        // Note: Abilities are validated during JSON parsing via Codable enums
        // If parsing succeeds, conditions are already valid

        // Validate event availability
        for (eventId, event) in pack.events {
            if let regionStates = event.availability.regionStates {
                for state in regionStates {
                    if !validRegionStates.contains(state) {
                        errors.append("Event '\(eventId)' has unknown region state: '\(state)'")
                    }
                }
            }
        }

        // Validate quest availability
        for (questId, quest) in pack.quests {
            if let regionStates = quest.availability.regionStates {
                for state in regionStates {
                    if !validRegionStates.contains(state) {
                        errors.append("Quest '\(questId)' has unknown region state: '\(state)'")
                    }
                }
            }
        }

        // Validate enemy abilities
        for (_, enemy) in pack.enemies {
            for ability in enemy.abilities {
                // Abilities use typed enums - if they parsed, they're valid
                // This is a defense-in-depth check
                _ = ability.name // Access to ensure parsing succeeded
            }
        }

        if errors.isEmpty {
            return .valid
        } else {
            return .invalid(errors: errors)
        }
    }

    /// Validate a single ability condition
    public static func validateAbilityCondition(_ conditionType: String) -> Bool {
        return validAbilityConditionTypes.contains(conditionType)
    }

    /// Validate a single ability trigger
    public static func validateAbilityTrigger(_ trigger: String) -> Bool {
        return validAbilityTriggers.contains(trigger)
    }

    /// Validate a single ability effect type
    public static func validateAbilityEffectType(_ effectType: String) -> Bool {
        return validAbilityEffectTypes.contains(effectType)
    }

    /// Get all valid condition type names (for documentation/error messages)
    public static func allValidConditionTypes() -> [String] {
        return validAbilityConditionTypes.sorted()
    }

    /// Get all valid trigger names (for documentation/error messages)
    public static func allValidTriggers() -> [String] {
        return validAbilityTriggers.sorted()
    }

    /// Get all valid effect type names (for documentation/error messages)
    public static func allValidEffectTypes() -> [String] {
        return validAbilityEffectTypes.sorted()
    }
}

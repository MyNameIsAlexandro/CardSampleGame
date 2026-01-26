import Foundation

// MARK: - Localization Validator

/// Validates localization schema consistency across content packs.
/// Enforces the canonical localization approach (inline LocalizedString).
///
/// Canonical approach (REQUIRED):
///   - Inline LocalizedString: { "en": "Strike", "ru": "Удар" }
///
/// Deprecated approach (NOT allowed in new content):
///   - StringKey references: "card.strike.name" → string tables
///
/// Reference: Audit B1 requirement - prevent hybrid localization schemes.
public final class LocalizationValidator {

    // MARK: - Configuration

    /// Canonical localization scheme for this project
    public enum LocalizationScheme {
        /// Inline translations in JSON: { "en": "...", "ru": "..." }
        case inlineOnly

        /// String key references to external tables: "card.strike.name"
        case stringKeyOnly

        /// Mixed (deprecated - should not be used)
        case mixed
    }

    /// The canonical scheme enforced by this validator
    public static let canonicalScheme: LocalizationScheme = .inlineOnly

    // MARK: - Validation Results

    public struct ValidationResult {
        public let isValid: Bool
        public let scheme: LocalizationScheme
        public let inlineCount: Int
        public let keyCount: Int
        public let mixedEntities: [String]  // Entity IDs that mix schemes

        public static let valid = ValidationResult(
            isValid: true,
            scheme: .inlineOnly,
            inlineCount: 0,
            keyCount: 0,
            mixedEntities: []
        )
    }

    // MARK: - Validation

    /// Validate localization scheme consistency in a loaded pack
    public static func validate(pack: LoadedPack) -> ValidationResult {
        var inlineCount = 0
        var keyCount = 0
        var mixedEntities: [String] = []

        // Check events
        for (id, event) in pack.events {
            let titleIsInline = event.title.inlineString != nil
            let bodyIsInline = event.body.inlineString != nil

            if titleIsInline { inlineCount += 1 } else { keyCount += 1 }
            if bodyIsInline { inlineCount += 1 } else { keyCount += 1 }

            // Check if entity mixes schemes
            if titleIsInline != bodyIsInline {
                mixedEntities.append("event:\(id)")
            }
        }

        // Check heroes
        for (id, hero) in pack.heroes {
            let nameIsInline = hero.name.inlineString != nil
            let descIsInline = hero.description.inlineString != nil

            if nameIsInline { inlineCount += 1 } else { keyCount += 1 }
            if descIsInline { inlineCount += 1 } else { keyCount += 1 }

            if nameIsInline != descIsInline {
                mixedEntities.append("hero:\(id)")
            }
        }

        // Check cards
        for (id, card) in pack.cards {
            let nameIsInline = card.name.inlineString != nil
            let descIsInline = card.description.inlineString != nil

            if nameIsInline { inlineCount += 1 } else { keyCount += 1 }
            if descIsInline { inlineCount += 1 } else { keyCount += 1 }

            if nameIsInline != descIsInline {
                mixedEntities.append("card:\(id)")
            }
        }

        // Check regions
        for (id, region) in pack.regions {
            let titleIsInline = region.title.inlineString != nil
            let descIsInline = region.description.inlineString != nil

            if titleIsInline { inlineCount += 1 } else { keyCount += 1 }
            if descIsInline { inlineCount += 1 } else { keyCount += 1 }

            if titleIsInline != descIsInline {
                mixedEntities.append("region:\(id)")
            }
        }

        // Check quests
        for (id, quest) in pack.quests {
            let titleIsInline = quest.title.inlineString != nil
            let descIsInline = quest.description.inlineString != nil

            if titleIsInline { inlineCount += 1 } else { keyCount += 1 }
            if descIsInline { inlineCount += 1 } else { keyCount += 1 }

            if titleIsInline != descIsInline {
                mixedEntities.append("quest:\(id)")
            }
        }

        // Determine scheme
        let scheme: LocalizationScheme
        if inlineCount > 0 && keyCount > 0 {
            scheme = .mixed
        } else if keyCount > 0 {
            scheme = .stringKeyOnly
        } else {
            scheme = .inlineOnly
        }

        // Validate against canonical scheme
        let isValid = scheme == canonicalScheme && mixedEntities.isEmpty

        return ValidationResult(
            isValid: isValid,
            scheme: scheme,
            inlineCount: inlineCount,
            keyCount: keyCount,
            mixedEntities: mixedEntities
        )
    }

    /// Check if a single LocalizableText uses the canonical scheme
    public static func isCanonical(_ text: LocalizableText) -> Bool {
        switch canonicalScheme {
        case .inlineOnly:
            return text.inlineString != nil
        case .stringKeyOnly:
            return text.stringKey != nil
        case .mixed:
            return true  // Mixed allows both
        }
    }

    /// Get a description of why the pack failed validation
    public static func failureReason(result: ValidationResult) -> String {
        var reasons: [String] = []

        if result.scheme != canonicalScheme {
            reasons.append("Pack uses \(result.scheme) scheme, but canonical is \(canonicalScheme)")
            reasons.append("  - Inline strings: \(result.inlineCount)")
            reasons.append("  - String keys: \(result.keyCount)")
        }

        if !result.mixedEntities.isEmpty {
            reasons.append("Mixed localization within entities:")
            for entity in result.mixedEntities.prefix(5) {
                reasons.append("  - \(entity)")
            }
            if result.mixedEntities.count > 5 {
                reasons.append("  - ... and \(result.mixedEntities.count - 5) more")
            }
        }

        return reasons.joined(separator: "\n")
    }
}

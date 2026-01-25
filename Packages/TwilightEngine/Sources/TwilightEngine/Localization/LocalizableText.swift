import Foundation

// MARK: - Localizable Text
// Reference: Docs/ENGINE_ARCHITECTURE.md
// Supports both legacy inline LocalizedString and new StringKey approaches

/// Represents text that can be localized in two ways:
/// 1. Legacy inline LocalizedString: { "en": "...", "ru": "..." }
/// 2. New StringKey: "card.strike.name" (references external string tables)
///
/// This enum enables gradual migration from inline translations to string tables
/// while maintaining full backward compatibility with existing content packs.
public enum LocalizableText: Hashable {
    /// Legacy: embedded translations in the JSON content
    case inline(LocalizedString)

    /// New: reference to external string table entry
    case key(StringKey)

    // MARK: - Resolution

    /// Resolve to actual text using shared LocalizationManager
    public var resolved: String {
        switch self {
        case .inline(let localized):
            // Use LocalizationManager's current locale for consistency
            return localized.localized(for: LocalizationManager.shared.currentLocale)
        case .key(let stringKey):
            if let resolved = LocalizationManager.shared.resolve(stringKey) {
                return resolved
            }
            // Fallback: show key in brackets for debugging
            return "[\(stringKey.rawValue)]"
        }
    }

    /// Resolve for a specific locale
    public func resolved(for locale: String) -> String {
        switch self {
        case .inline(let localized):
            return localized.localized(for: locale)
        case .key(let stringKey):
            if let resolved = LocalizationManager.shared.resolve(stringKey, locale: locale) {
                return resolved
            }
            return "[\(stringKey.rawValue)]"
        }
    }

    /// Resolve with pack context for proper fallback chain
    public func resolved(packContext: String?) -> String {
        switch self {
        case .inline(let localized):
            return localized.localized(for: LocalizationManager.shared.currentLocale)
        case .key(let stringKey):
            if let resolved = LocalizationManager.shared.resolve(stringKey, packContext: packContext) {
                return resolved
            }
            return "[\(stringKey.rawValue)]"
        }
    }

    // MARK: - Convenience Properties

    /// Returns the StringKey if this is a key-based text, nil otherwise
    public var stringKey: StringKey? {
        if case .key(let key) = self {
            return key
        }
        return nil
    }

    /// Returns the LocalizedString if this is inline text, nil otherwise
    public var inlineString: LocalizedString? {
        if case .inline(let localized) = self {
            return localized
        }
        return nil
    }

    /// Whether this uses the new key-based localization
    public var usesStringKey: Bool {
        if case .key = self { return true }
        return false
    }

    /// English text for validation purposes
    /// For inline strings, returns the `en` value directly
    /// For key-based strings, returns the key itself (validation should check separately)
    public var en: String {
        switch self {
        case .inline(let localized):
            return localized.en
        case .key(let stringKey):
            // For validation, return the key - validators should check key validity separately
            return stringKey.rawValue
        }
    }

    /// Russian text for validation purposes
    /// For inline strings, returns the `ru` value directly
    /// For key-based strings, returns the key itself (validation should check separately)
    public var ru: String {
        switch self {
        case .inline(let localized):
            return localized.ru
        case .key(let stringKey):
            // For validation, return the key - validators should check key validity separately
            return stringKey.rawValue
        }
    }

    /// Check if the text is effectively empty
    /// For inline strings, checks if English text is empty
    /// For key-based strings, always returns false (key presence = not empty)
    public var isEmpty: Bool {
        switch self {
        case .inline(let localized):
            return localized.en.isEmpty
        case .key(let stringKey):
            // A valid key reference is never "empty"
            return stringKey.rawValue.isEmpty
        }
    }

    /// Alias for `resolved` - compatibility with LocalizedString interface
    /// Returns the string for the current device locale
    public var localized: String {
        resolved
    }
}

// MARK: - Codable

extension LocalizableText: Codable {
    public init(from decoder: Decoder) throws {
        // Try to decode as object (LocalizedString) first
        if let localized = try? LocalizedString(from: decoder) {
            self = .inline(localized)
            return
        }

        // Try to decode as string
        let container = try decoder.singleValueContainer()
        let keyString = try container.decode(String.self)

        // Check if string looks like a valid StringKey (lowercase.dot.separated, no spaces)
        // StringKeys must: start with lowercase, contain dots, no spaces, only alphanumeric/underscore/dot
        let looksLikeStringKey = keyString.first?.isLowercase == true
            && keyString.contains(".")
            && !keyString.contains(" ")
            && keyString.range(of: "^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$", options: .regularExpression) != nil

        if looksLikeStringKey {
            // Valid StringKey format (e.g., "card.strike.name")
            self = .key(StringKey(keyString))
        } else {
            // Plain text string - treat as single-language inline text
            // This handles legacy JSON with raw strings like "Удар Мечом"
            self = .inline(LocalizedString(keyString))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .inline(let localized):
            try localized.encode(to: encoder)
        case .key(let stringKey):
            var container = encoder.singleValueContainer()
            try container.encode(stringKey.rawValue)
        }
    }
}

// MARK: - ExpressibleByStringLiteral

extension LocalizableText: ExpressibleByStringLiteral {
    /// Create from string literal - interpreted as StringKey
    public init(stringLiteral value: String) {
        self = .key(StringKey(value))
    }
}

// MARK: - CustomStringConvertible

extension LocalizableText: CustomStringConvertible {
    public var description: String {
        resolved
    }
}

// MARK: - Convenience Initializers

public extension LocalizableText {
    /// Create inline text with same value for all locales (for testing/development)
    static func text(_ value: String) -> LocalizableText {
        .inline(LocalizedString(value))
    }

    /// Create inline text with specific translations
    static func localized(en: String, ru: String) -> LocalizableText {
        .inline(LocalizedString(en: en, ru: ru))
    }

    /// Create key-based text
    static func key(_ value: String) -> LocalizableText {
        .key(StringKey(value))
    }
}

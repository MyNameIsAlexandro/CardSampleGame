import Foundation

// MARK: - Localized String
// Reference: Docs/ENGINE_ARCHITECTURE.md
// Supports runtime localization without app rebuild - "Cartridge" approach

/// A string with multiple language variants, loaded from JSON content.
/// This enables adding new content without rebuilding the app.
public struct LocalizedString: Codable, Hashable {
    // MARK: - Supported Languages

    /// English text
    public let en: String

    /// Russian text
    public let ru: String

    // MARK: - Localized Access

    /// Returns the string for the current device locale.
    /// Falls back to English if the current locale is not supported.
    public var localized: String {
        let languageCode = Locale.current.language.languageCode?.identifier ?? "en"
        switch languageCode {
        case "ru": return ru
        default: return en
        }
    }

    /// Returns the string for a specific language code.
    public func localized(for languageCode: String) -> String {
        switch languageCode {
        case "ru": return ru
        default: return en
        }
    }

    // MARK: - Convenience Initializers

    /// Create with the same text for all languages (for testing/development)
    public init(_ text: String) {
        self.en = text
        self.ru = text
    }

    /// Create with specific translations
    public init(en: String, ru: String) {
        self.en = en
        self.ru = ru
    }
}

// MARK: - ExpressibleByStringLiteral

extension LocalizedString: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.en = value
        self.ru = value
    }
}

// MARK: - CustomStringConvertible

extension LocalizedString: CustomStringConvertible {
    public var description: String {
        localized
    }
}

// MARK: - LocalizableText Conversion

extension LocalizedString {
    /// Convert to LocalizableText (inline format)
    public var asLocalizableText: LocalizableText {
        .inline(self)
    }
}

// MARK: - Convenience Extensions for LocalizableText

public extension LocalizableText {
    /// Create from a LocalizedString (inline format)
    init(_ localized: LocalizedString) {
        self = .inline(localized)
    }

    /// Create from a LocalizedString with optional (inline format)
    static func from(_ localized: LocalizedString?) -> LocalizableText? {
        guard let localized = localized else { return nil }
        return .inline(localized)
    }
}

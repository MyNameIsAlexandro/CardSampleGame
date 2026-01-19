import Foundation

// MARK: - Localized String
// Reference: Docs/ENGINE_ARCHITECTURE.md
// Supports runtime localization without app rebuild - "Cartridge" approach

/// A string with multiple language variants, loaded from JSON content.
/// This enables adding new content without rebuilding the app.
struct LocalizedString: Codable, Hashable {
    // MARK: - Supported Languages

    /// English text
    let en: String

    /// Russian text
    let ru: String

    // MARK: - Localized Access

    /// Returns the string for the current device locale.
    /// Falls back to English if the current locale is not supported.
    var localized: String {
        let languageCode = Locale.current.language.languageCode?.identifier ?? "en"
        switch languageCode {
        case "ru": return ru
        default: return en
        }
    }

    /// Returns the string for a specific language code.
    func localized(for languageCode: String) -> String {
        switch languageCode {
        case "ru": return ru
        default: return en
        }
    }

    // MARK: - Convenience Initializers

    /// Create with the same text for all languages (for testing/development)
    init(_ text: String) {
        self.en = text
        self.ru = text
    }

    /// Create with specific translations
    init(en: String, ru: String) {
        self.en = en
        self.ru = ru
    }
}

// MARK: - ExpressibleByStringLiteral

extension LocalizedString: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self.en = value
        self.ru = value
    }
}

// MARK: - CustomStringConvertible

extension LocalizedString: CustomStringConvertible {
    var description: String {
        localized
    }
}

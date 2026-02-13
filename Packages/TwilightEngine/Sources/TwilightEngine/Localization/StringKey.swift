/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Localization/StringKey.swift
/// Назначение: Содержит реализацию файла StringKey.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - String Key
// Reference: Docs/ENGINE_ARCHITECTURE.md
// Keys reference strings in pack string tables

/// A key that references a localized string in the pack's string tables.
/// Format: "namespace.entity.field" (e.g., "card.strike.name", "hero.ragnar.description")
public struct StringKey: Hashable, Sendable {
    // MARK: - Properties

    /// The raw string value of the key
    public let rawValue: String

    // MARK: - Initialization

    public init(_ value: String) {
        self.rawValue = value
    }

    // MARK: - Validation

    /// Validates key format: lowercase alphanumeric with dots and underscores
    /// Examples:
    ///   Valid: "card.strike.name", "hero.ragnar_the_brave.description", "region.dark_forest.title"
    ///   Invalid: "Card.Strike" (uppercase), "card strike" (space), "" (empty)
    public var isValid: Bool {
        guard !rawValue.isEmpty else { return false }
        let pattern = "^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)*$"
        return rawValue.range(of: pattern, options: .regularExpression) != nil
    }

    /// Returns validation error message if invalid, nil if valid
    public var validationError: String? {
        guard !rawValue.isEmpty else {
            return "StringKey cannot be empty"
        }

        if rawValue.contains(" ") {
            return "StringKey cannot contain spaces: '\(rawValue)'"
        }

        if rawValue.first?.isUppercase == true {
            return "StringKey must start with lowercase letter: '\(rawValue)'"
        }

        if !isValid {
            return "StringKey has invalid format: '\(rawValue)'. Expected: lowercase.dot.separated.keys"
        }

        return nil
    }
}

// MARK: - Codable

extension StringKey: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - ExpressibleByStringLiteral

extension StringKey: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.rawValue = value
    }
}

// MARK: - CustomStringConvertible

extension StringKey: CustomStringConvertible {
    public var description: String {
        rawValue
    }
}

// MARK: - Key Generation Helpers

public extension StringKey {
    /// Generate a key for a card field
    static func card(_ cardId: String, _ field: String) -> StringKey {
        StringKey("card.\(cardId).\(field)")
    }

    /// Generate a key for a hero field
    static func hero(_ heroId: String, _ field: String) -> StringKey {
        StringKey("hero.\(heroId).\(field)")
    }

    /// Generate a key for a region field
    static func region(_ regionId: String, _ field: String) -> StringKey {
        StringKey("region.\(regionId).\(field)")
    }

    /// Generate a key for an event field
    static func event(_ eventId: String, _ field: String) -> StringKey {
        StringKey("event.\(eventId).\(field)")
    }

    /// Generate a key for an enemy field
    static func enemy(_ enemyId: String, _ field: String) -> StringKey {
        StringKey("enemy.\(enemyId).\(field)")
    }

    /// Generate a key for an ability field
    static func ability(_ abilityId: String, _ field: String) -> StringKey {
        StringKey("ability.\(abilityId).\(field)")
    }

    /// Generate a key for an event choice field
    static func choice(_ eventId: String, _ choiceId: String, _ field: String) -> StringKey {
        StringKey("event.\(eventId).choice.\(choiceId).\(field)")
    }
}

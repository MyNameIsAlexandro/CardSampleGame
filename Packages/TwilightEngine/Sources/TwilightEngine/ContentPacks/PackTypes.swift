/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/ContentPacks/PackTypes.swift
/// Назначение: Содержит реализацию файла PackTypes.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Semantic Versioning

/// Semantic version for Core and Packs
/// Format: MAJOR.MINOR.PATCH
public struct SemanticVersion: Comparable, Hashable, CustomStringConvertible, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public var description: String { "\(major).\(minor).\(patch)" }

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init?(string: String) {
        let parts = string.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        self.major = parts[0]
        self.minor = parts[1]
        self.patch = parts[2]
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    /// Check if this version is compatible with required version
    /// - Same MAJOR version required
    /// - MINOR can be >= required
    public func isCompatible(with required: SemanticVersion) -> Bool {
        return major == required.major && (minor > required.minor || (minor == required.minor && patch >= required.patch))
    }
}

// MARK: - SemanticVersion Codable

extension SemanticVersion: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        let parts = string.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 3 else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid version format: \(string). Expected MAJOR.MINOR.PATCH"
            )
        }
        self.major = parts[0]
        self.minor = parts[1]
        self.patch = parts[2]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

// MARK: - Pack Types

/// Types of content packs
public enum PackType: String, Codable {
    /// Campaign content: regions, events, quests, enemies, story
    case campaign

    /// Character/Hero content: heroes, starting decks, player cards
    /// Note: Called "Character Pack" (not "Investigator Pack" as in Arkham Horror)
    /// to match the game's theme
    case character

    /// Balance tuning: numbers, weights, costs (no new content)
    case balance

    /// Rules extension: new game mechanics, capabilities
    case rulesExtension = "rules_extension"

    /// Full standalone pack: complete game content
    case full

    /// Load priority for pack ordering (lower = loaded first)
    public var loadPriority: Int {
        switch self {
        case .character: return 100  // Characters first
        case .balance: return 200    // Balance tuning second
        case .campaign: return 300   // Campaigns after characters
        case .rulesExtension: return 400
        case .full: return 500       // Full packs last
        }
    }

    /// Whether this pack type provides heroes
    public var providesHeroes: Bool {
        switch self {
        case .character, .full: return true
        case .campaign, .balance, .rulesExtension: return false
        }
    }

    /// Whether this pack type provides story content
    public var providesStory: Bool {
        switch self {
        case .campaign, .full: return true
        case .character, .balance, .rulesExtension: return false
        }
    }
}

/// Mission type for story packs
public enum MissionType: String, Codable {
    /// Multi-session campaign that spans multiple play sessions
    case campaign

    /// Single-session standalone mission
    case standalone
}

/// Pack dependency declaration
public struct PackDependency: Codable, Hashable {
    /// ID of required pack
    public let packId: String

    /// Minimum required version
    public let minVersion: SemanticVersion

    /// Maximum compatible version (nil = any)
    public let maxVersion: SemanticVersion?

    /// Is this dependency optional?
    public let isOptional: Bool

    public init(packId: String, minVersion: SemanticVersion, maxVersion: SemanticVersion? = nil, isOptional: Bool = false) {
        self.packId = packId
        self.minVersion = minVersion
        self.maxVersion = maxVersion
        self.isOptional = isOptional
    }
}

// MARK: - Content Inventory

/// Summary of content provided by a pack
public struct ContentInventory: Codable, Sendable {
    public let regionCount: Int
    public let eventCount: Int
    public let questCount: Int
    public let heroCount: Int
    public let cardCount: Int
    public let anchorCount: Int
    public let enemyCount: Int

    public let hasBalanceConfig: Bool
    public let hasRulesExtension: Bool
    public let hasCampaignContent: Bool

    /// Supported locales (e.g., ["en", "ru"])
    public let supportedLocales: [String]

    public static let empty = ContentInventory(
        regionCount: 0, eventCount: 0, questCount: 0,
        heroCount: 0, cardCount: 0, anchorCount: 0, enemyCount: 0,
        hasBalanceConfig: false, hasRulesExtension: false, hasCampaignContent: false,
        supportedLocales: []
    )
}

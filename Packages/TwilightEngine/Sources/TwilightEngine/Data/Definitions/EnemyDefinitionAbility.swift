/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Data/Definitions/EnemyDefinitionAbility.swift
/// Назначение: Содержит реализацию файла EnemyDefinitionAbility.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Enemy Ability

public struct EnemyAbility: Codable, Hashable, Identifiable {
    public var id: String
    public var name: LocalizableText
    public var description: LocalizableText
    public var effect: EnemyAbilityEffect

    public init(
        id: String,
        name: LocalizableText,
        description: LocalizableText,
        effect: EnemyAbilityEffect
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.effect = effect
    }
}

public enum EnemyAbilityEffect: Codable, Hashable {
    /// Deal extra damage
    case bonusDamage(Int)

    /// Heal each turn
    case regeneration(Int)

    /// Reduce incoming damage
    case armor(Int)

    /// First strike - attacks before player
    case firstStrike

    /// Cannot be targeted by spells
    case spellImmune

    /// Applies curse on hit
    case applyCurse(String)

    /// Custom effect by ID
    case custom(String)

    // MARK: - Custom Codable for JSON compatibility
    // Note: No explicit snake_case mappings - JSONDecoder uses .convertFromSnakeCase
    // which automatically converts bonus_damage → bonusDamage, etc.

    enum CodingKeys: String, CodingKey {
        case bonusDamage
        case regeneration
        case armor
        case firstStrike
        case spellImmune
        case applyCurse
        case custom
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let value = try container.decodeIfPresent(Int.self, forKey: .bonusDamage) {
            self = .bonusDamage(value)
        } else if let value = try container.decodeIfPresent(Int.self, forKey: .regeneration) {
            self = .regeneration(value)
        } else if let value = try container.decodeIfPresent(Int.self, forKey: .armor) {
            self = .armor(value)
        } else if (try? container.decodeIfPresent(Bool.self, forKey: .firstStrike)) == true {
            self = .firstStrike
        } else if (try? container.decodeIfPresent(Bool.self, forKey: .spellImmune)) == true {
            self = .spellImmune
        } else if let value = try container.decodeIfPresent(String.self, forKey: .applyCurse) {
            self = .applyCurse(value)
        } else if let value = try container.decodeIfPresent(String.self, forKey: .custom) {
            self = .custom(value)
        } else {
            // Default to custom with empty string if no recognized key
            self = .custom("unknown")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .bonusDamage(let value):
            try container.encode(value, forKey: .bonusDamage)
        case .regeneration(let value):
            try container.encode(value, forKey: .regeneration)
        case .armor(let value):
            try container.encode(value, forKey: .armor)
        case .firstStrike:
            try container.encode(true, forKey: .firstStrike)
        case .spellImmune:
            try container.encode(true, forKey: .spellImmune)
        case .applyCurse(let value):
            try container.encode(value, forKey: .applyCurse)
        case .custom(let value):
            try container.encode(value, forKey: .custom)
        }
    }
}

// MARK: - Enemy Pattern Step

/// A single step in a repeating enemy behavior pattern.
public struct EnemyPatternStep: Codable, Equatable, Hashable {
    public var type: IntentType
    public var value: Int

    public init(type: IntentType, value: Int = 0) {
        self.type = type
        self.value = value
    }
}

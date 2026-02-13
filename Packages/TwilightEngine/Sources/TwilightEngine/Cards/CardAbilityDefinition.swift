/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Cards/CardAbilityDefinition.swift
/// Назначение: Содержит реализацию файла CardAbilityDefinition.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Card Ability Definition (Data Layer)

/// Static ability data stored in content packs.
///
/// Uses `LocalizableText` to support both inline translations and StringKey-based localization.
/// Backward compatible with legacy `name_ru` / `description_ru` fields.
public struct CardAbilityDefinition: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: LocalizableText
    public var description: LocalizableText
    public var effect: AbilityEffect

    public init(
        id: String,
        name: LocalizableText,
        description: LocalizableText,
        effect: AbilityEffect
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.effect = effect
    }
}

// MARK: - Codable (Backward Compatibility)

extension CardAbilityDefinition: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case nameRu = "name_ru"
        case description
        case descriptionRu = "description_ru"
        case effect
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        effect = try container.decode(AbilityEffect.self, forKey: .effect)

        let decodedName = try container.decode(LocalizableText.self, forKey: .name)
        if let nameRu = try container.decodeIfPresent(String.self, forKey: .nameRu),
           case .inline(let localized) = decodedName {
            name = .inline(LocalizedString(en: localized.en, ru: nameRu))
        } else {
            name = decodedName
        }

        let decodedDescription = try container.decode(LocalizableText.self, forKey: .description)
        if let descriptionRu = try container.decodeIfPresent(String.self, forKey: .descriptionRu),
           case .inline(let localized) = decodedDescription {
            description = .inline(LocalizedString(en: localized.en, ru: descriptionRu))
        } else {
            description = decodedDescription
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(effect, forKey: .effect)
    }
}


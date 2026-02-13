/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/FateCard.swift
/// Назначение: Содержит реализацию файла FateCard.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Fate Card

/// A card in the Fate Deck that modifies action outcomes.
/// v2.0: Resonance-aware with suit, dynamic rules, and side effects.
public struct FateCard: Codable, Equatable, Hashable, Sendable {
    /// Unique card identifier
    public var id: String

    /// Display name (fallback if nameKey not found in localization)
    public var name: String

    /// Localization key for card name (e.g. "card_nav_whisper_name")
    public var nameKey: String?

    /// Base outcome modifier (-2..+3)
    public var baseValue: Int

    /// Alignment suit (nil = neutral/unaligned)
    public var suit: FateCardSuit?

    /// Whether this is a critical success card
    public var isCritical: Bool

    /// Sticky cards (curses) return to discard after reshuffle instead of being removed
    public var isSticky: Bool

    /// Dynamic modifiers based on world resonance zone
    public var resonanceRules: [FateResonanceRule]

    /// Side effects applied when this card is drawn
    public var onDrawEffects: [FateDrawEffect]

    /// Keyword for context-dependent interpretation
    public var keyword: FateKeyword?

    /// Card type (standard or choice)
    public var cardType: FateCardType

    /// Choice options (only for choice-type cards)
    public var choiceOptions: [FateChoiceOption]?

    /// Backward-compatible computed property
    public var modifier: Int { baseValue }

    // MARK: - CodingKeys (backward compat: base_value OR modifier)

    enum CodingKeys: String, CodingKey {
        case id, name, suit
        case nameKey
        case baseValue
        case modifier  // fallback for v1.0 JSON (when decoder doesn't use convertFromSnakeCase)
        case isCritical
        case isSticky
        case resonanceRules
        case onDrawEffects
        case keyword
        case cardType
        case choiceOptions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        nameKey = try container.decodeIfPresent(String.self, forKey: .nameKey)

        // Try base_value first, fall back to modifier (v1.0 compat)
        if let bv = try container.decodeIfPresent(Int.self, forKey: .baseValue) {
            baseValue = bv
        } else {
            baseValue = try container.decode(Int.self, forKey: .modifier)
        }

        suit = try container.decodeIfPresent(FateCardSuit.self, forKey: .suit)
        isCritical = try container.decodeIfPresent(Bool.self, forKey: .isCritical) ?? false
        isSticky = try container.decodeIfPresent(Bool.self, forKey: .isSticky) ?? false
        resonanceRules = try container.decodeIfPresent([FateResonanceRule].self, forKey: .resonanceRules) ?? []
        onDrawEffects = try container.decodeIfPresent([FateDrawEffect].self, forKey: .onDrawEffects) ?? []
        keyword = try container.decodeIfPresent(FateKeyword.self, forKey: .keyword)
        cardType = try container.decodeIfPresent(FateCardType.self, forKey: .cardType) ?? .standard
        choiceOptions = try container.decodeIfPresent([FateChoiceOption].self, forKey: .choiceOptions)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(nameKey, forKey: .nameKey)
        try container.encode(baseValue, forKey: .baseValue)
        try container.encodeIfPresent(suit, forKey: .suit)
        try container.encode(isCritical, forKey: .isCritical)
        try container.encode(isSticky, forKey: .isSticky)
        if !resonanceRules.isEmpty {
            try container.encode(resonanceRules, forKey: .resonanceRules)
        }
        if !onDrawEffects.isEmpty {
            try container.encode(onDrawEffects, forKey: .onDrawEffects)
        }
        try container.encodeIfPresent(keyword, forKey: .keyword)
        if cardType != .standard {
            try container.encode(cardType, forKey: .cardType)
        }
        if let choices = choiceOptions {
            try container.encode(choices, forKey: .choiceOptions)
        }
    }

    public init(
        id: String,
        modifier: Int,
        isCritical: Bool = false,
        isSticky: Bool = false,
        name: String,
        nameKey: String? = nil,
        suit: FateCardSuit? = nil,
        resonanceRules: [FateResonanceRule] = [],
        onDrawEffects: [FateDrawEffect] = [],
        keyword: FateKeyword? = nil,
        cardType: FateCardType = .standard,
        choiceOptions: [FateChoiceOption]? = nil
    ) {
        self.id = id
        self.baseValue = modifier
        self.isCritical = isCritical
        self.isSticky = isSticky
        self.name = name
        self.nameKey = nameKey
        self.suit = suit
        self.resonanceRules = resonanceRules
        self.onDrawEffects = onDrawEffects
        self.keyword = keyword
        self.cardType = cardType
        self.choiceOptions = choiceOptions
    }
}

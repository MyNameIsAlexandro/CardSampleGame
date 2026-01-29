import Foundation

// MARK: - Fate Card Suit

/// Alignment suit of a Fate Card — determines how resonance affects it
public enum FateCardSuit: String, Codable, Hashable {
    case nav   // Darkness/Chaos aligned
    case yav   // Neutral/Balance aligned
    case prav  // Light/Order aligned
}

// MARK: - Fate Resonance Rule

/// Dynamic modifier applied when the world is in a specific resonance zone.
/// Example: Nav card in deepNav zone gets modifyValue=-1 (stronger darkness),
/// same Nav card in deepPrav zone gets modifyValue=+1 (neutralized by light).
public struct FateResonanceRule: Codable, Equatable, Hashable {
    /// Which resonance zone activates this rule
    public let zone: ResonanceZone

    /// Value added to baseValue when this rule activates
    public let modifyValue: Int

    /// Optional visual effect hint for UI (e.g. "shadow_pulse", "light_shimmer")
    public let visualEffect: String?

    public init(zone: ResonanceZone, modifyValue: Int, visualEffect: String? = nil) {
        self.zone = zone
        self.modifyValue = modifyValue
        self.visualEffect = visualEffect
    }
}

// MARK: - Fate Draw Effect

/// Side effect triggered when a Fate Card is drawn
public struct FateDrawEffect: Codable, Equatable, Hashable {
    public let type: FateEffectType
    public let value: Int

    public init(type: FateEffectType, value: Int) {
        self.type = type
        self.value = value
    }
}

/// Types of side effects a Fate Card can trigger on draw
public enum FateEffectType: String, Codable, Hashable {
    case shiftResonance
    case shiftTension
}

// MARK: - Fate Card

/// A card in the Fate Deck that modifies action outcomes.
/// v2.0: Resonance-aware with suit, dynamic rules, and side effects.
public struct FateCard: Codable, Equatable, Hashable {
    /// Unique card identifier
    public let id: String

    /// Display name (fallback if nameKey not found in localization)
    public let name: String

    /// Localization key for card name (e.g. "card_nav_whisper_name")
    public let nameKey: String?

    /// Base outcome modifier (-2..+3)
    public let baseValue: Int

    /// Alignment suit (nil = neutral/unaligned)
    public let suit: FateCardSuit?

    /// Whether this is a critical success card
    public let isCritical: Bool

    /// Sticky cards (curses) return to discard after reshuffle instead of being removed
    public let isSticky: Bool

    /// Dynamic modifiers based on world resonance zone
    public let resonanceRules: [FateResonanceRule]

    /// Side effects applied when this card is drawn
    public let onDrawEffects: [FateDrawEffect]

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
        onDrawEffects: [FateDrawEffect] = []
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
    }
}

/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/FateCardResonance.swift
/// Назначение: Содержит реализацию файла FateCardResonance.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Fate Card Suit

/// Alignment suit of a Fate Card — determines how resonance affects it
public enum FateCardSuit: String, Codable, Hashable, Sendable {
    case nav   // Darkness/Chaos aligned
    case yav   // Neutral/Balance aligned
    case prav  // Light/Order aligned
}

// MARK: - Fate Resonance Rule

/// Dynamic modifier applied when the world is in a specific resonance zone.
/// Example: Nav card in deepNav zone gets modifyValue=-1 (stronger darkness),
/// same Nav card in deepPrav zone gets modifyValue=+1 (neutralized by light).
public struct FateResonanceRule: Codable, Equatable, Hashable, Sendable {
    /// Which resonance zone activates this rule
    public var zone: ResonanceZone

    /// Value added to baseValue when this rule activates
    public var modifyValue: Int

    /// Optional visual effect hint for UI (e.g. "shadow_pulse", "light_shimmer")
    public var visualEffect: String?

    public init(zone: ResonanceZone, modifyValue: Int, visualEffect: String? = nil) {
        self.zone = zone
        self.modifyValue = modifyValue
        self.visualEffect = visualEffect
    }
}

// MARK: - Fate Draw Effect

/// Side effect triggered when a Fate Card is drawn
public struct FateDrawEffect: Codable, Equatable, Hashable, Sendable {
    public var type: FateEffectType
    public var value: Int

    public init(type: FateEffectType, value: Int) {
        self.type = type
        self.value = value
    }
}

/// Types of side effects a Fate Card can trigger on draw
public enum FateEffectType: String, Codable, Hashable, Sendable {
    case shiftResonance
    case shiftTension
}

// MARK: - Fate Keyword

/// Keyword that determines context-dependent effects
public enum FateKeyword: String, Codable, Hashable, CaseIterable, Sendable {
    case surge    // Damage boost in combat
    case focus    // Precision/accuracy bonus
    case echo     // Repeat/amplify effect
    case shadow   // Stealth/evasion bonus
    case ward     // Protection/shield effect
}

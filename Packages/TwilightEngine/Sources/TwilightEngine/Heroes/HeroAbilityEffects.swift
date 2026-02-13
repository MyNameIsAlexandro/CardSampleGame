/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Heroes/HeroAbilityEffects.swift
/// Назначение: Содержит реализацию файла HeroAbilityEffects.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// Hero ability effect
public struct HeroAbilityEffect: Codable, Equatable {
    public var type: HeroAbilityEffectType
    public var value: Int
    public var description: String?

    public init(type: HeroAbilityEffectType, value: Int, description: String? = nil) {
        self.type = type
        self.value = value
        self.description = description
    }
}

/// Ability effect type
public enum HeroAbilityEffectType: String, Codable, CaseIterable {
    /// Damage bonus
    case bonusDamage

    /// Damage reduction
    case damageReduction

    /// Additional attack dice
    case bonusDice

    /// Heal HP
    case heal

    /// Gain faith
    case gainFaith

    /// Lose faith
    case loseFaith

    /// Shift balance to Light
    case shiftLight

    /// Shift balance to Dark
    case shiftDark

    /// Draw card
    case drawCard

    /// Discard card
    case discardCard

    /// Apply curse to enemy
    case applyCurseToEnemy

    /// Remove curse
    case removeCurse

    /// Defense bonus
    case bonusDefense

    /// Summon spirit
    case summonSpirit

    /// Bonus to next attack
    case bonusNextAttack

    /// Reroll dice
    case rerollDice
}

/// Ability activation cost
public struct AbilityCost: Codable, Equatable {
    public var type: AbilityCostType
    public var value: Int

    public init(type: AbilityCostType, value: Int) {
        self.type = type
        self.value = value
    }
}

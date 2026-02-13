/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Heroes/HeroAbilityConditions.swift
/// Назначение: Содержит реализацию файла HeroAbilityConditions.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// Hero ability type
public enum HeroAbilityType: String, Codable {
    /// Passive - works automatically
    case passive

    /// Active - requires manual activation
    case active

    /// Reactive - triggers in response to event
    case reactive

    /// Ultimate - powerful ability with long cooldown
    case ultimate
}

/// Ability activation trigger
public enum AbilityTrigger: String, Codable, CaseIterable {
    /// Always active
    case always

    /// At turn start
    case turnStart

    /// At turn end
    case turnEnd

    /// On attack
    case onAttack

    /// On damage received
    case onDamageReceived

    /// On damage dealt
    case onDamageDealt

    /// On card played
    case onCardPlayed

    /// On combat start
    case onCombatStart

    /// On combat end
    case onCombatEnd

    /// On explore
    case onExplore

    /// Manual activation
    case manual
}

/// Ability activation condition
public struct AbilityCondition: Codable, Equatable {
    public var type: AbilityConditionType
    public var value: Int?
    public var stringValue: String?

    public init(type: AbilityConditionType, value: Int? = nil, stringValue: String? = nil) {
        self.type = type
        self.value = value
        self.stringValue = stringValue
    }
}

/// Condition type
public enum AbilityConditionType: String, Codable, CaseIterable {
    /// HP below percent
    case hpBelowPercent

    /// HP above percent
    case hpAbovePercent

    /// Target at full HP
    case targetFullHP

    /// First attack in combat
    case firstAttack

    /// Damage source is dark
    case damageSourceDark

    /// Damage source is light
    case damageSourceLight

    /// Has specific curse
    case hasCurse

    /// Balance above value
    case balanceAbove

    /// Balance below value
    case balanceBelow

    /// Has card in hand
    case hasCardInHand
}

/// Cost type
public enum AbilityCostType: String, Codable {
    case health
    case faith
    case card
    case action
}

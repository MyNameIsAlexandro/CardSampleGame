import Foundation

/// Hero ability
/// Defines unique actions and passive effects of the hero
public struct HeroAbility: Codable, Equatable {
    /// Unique ability identifier
    public var id: String

    /// Ability name (supports inline LocalizedString or StringKey)
    public var name: LocalizableText

    /// Description for UI (supports inline LocalizedString or StringKey)
    public var description: LocalizableText

    /// Icon (SF Symbol or emoji)
    public var icon: String

    /// Ability type
    public var type: HeroAbilityType

    /// Activation trigger (for passives)
    public var trigger: AbilityTrigger

    /// Activation condition
    public var condition: AbilityCondition?

    /// Ability effects
    public var effects: [HeroAbilityEffect]

    /// Cooldown (in turns, 0 = no cooldown)
    public var cooldown: Int

    /// Activation cost (for active abilities)
    public var cost: AbilityCost?

    public init(
        id: String,
        name: LocalizableText,
        description: LocalizableText,
        icon: String,
        type: HeroAbilityType,
        trigger: AbilityTrigger,
        condition: AbilityCondition?,
        effects: [HeroAbilityEffect],
        cooldown: Int,
        cost: AbilityCost?
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.type = type
        self.trigger = trigger
        self.condition = condition
        self.effects = effects
        self.cooldown = cooldown
        self.cost = cost
    }
}

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

/// Cost type
public enum AbilityCostType: String, Codable {
    case health
    case faith
    case card
    case action
}

// MARK: - Ability Lookup

extension HeroAbility {
    /// Получить способность по ID (data-driven через AbilityRegistry)
    /// Способности загружаются из hero_abilities.json в ContentPack
    public static func forAbilityId(_ id: String) -> HeroAbility? {
        return AbilityRegistry.shared.ability(id: id)
    }
}

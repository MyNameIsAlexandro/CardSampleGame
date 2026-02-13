/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Heroes/HeroAbility.swift
/// Назначение: Содержит реализацию файла HeroAbility.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

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

// MARK: - Ability Lookup

extension HeroAbility {
    /// Получить способность по ID (data-driven через AbilityRegistry)
    /// Способности загружаются из hero_abilities.json в ContentPack
    public static func forAbilityId(_ id: String, registry: AbilityRegistry) -> HeroAbility? {
        return registry.ability(id: id)
    }
}

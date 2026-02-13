/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Heroes/AbilityRegistry.swift
/// Назначение: Содержит реализацию файла AbilityRegistry.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// Реестр способностей героев - data-driven загрузка из JSON
/// Заменяет хардкод в HeroAbility.forAbilityId()
public final class AbilityRegistry {
    // MARK: - Storage

    /// Зарегистрированные способности по ID
    private var abilities: [String: HeroAbility] = [:]

    // MARK: - Init

    public init() {
        // Способности загружаются из ContentPack (hero_abilities.json)
        // Пустой init - данные загружаются через loadFromJSON()
    }

    // MARK: - Registration

    /// Зарегистрировать способность
    public func register(_ ability: HeroAbility) {
        abilities[ability.id] = ability
    }

    /// Зарегистрировать несколько способностей
    public func registerAll(_ newAbilities: [HeroAbility]) {
        for ability in newAbilities {
            register(ability)
        }
    }

    /// Очистить реестр
    public func clear() {
        abilities.removeAll()
    }

    /// Перезагрузить реестр (очистка для повторной загрузки)
    public func reload() {
        clear()
    }

    // MARK: - Queries

    /// Получить способность по ID
    public func ability(id: String) -> HeroAbility? {
        return abilities[id]
    }

    /// Все доступные способности
    public var allAbilities: [HeroAbility] {
        return Array(abilities.values)
    }

    /// Количество зарегистрированных способностей
    public var count: Int {
        return abilities.count
    }

    // MARK: - JSON Loading

    /// Загрузить способности из JSON файла
    public func loadFromJSON(at url: URL) {
        guard let data = try? Data(contentsOf: url) else {
            #if DEBUG
            print("AbilityRegistry: Failed to load JSON from \(url)")
            #endif
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let jsonAbilities = try decoder.decode([JSONAbilityDefinition].self, from: data)
            let converted = jsonAbilities.compactMap { $0.toHeroAbility() }
            registerAll(converted)
            #if DEBUG
            print("AbilityRegistry: Loaded \(converted.count) abilities from \(url.lastPathComponent)")
            #endif
        } catch {
            #if DEBUG
            print("AbilityRegistry: Failed to decode abilities: \(error)")
            #endif
        }
    }

}

// MARK: - JSON Ability Definition

/// JSON структура для способности
public struct JSONAbilityDefinition: Codable {
    public let id: String
    public let name: LocalizedString
    public let description: LocalizedString
    public let icon: String
    public let type: String
    public let trigger: String
    public let condition: JSONAbilityCondition?
    public let effects: [JSONAbilityEffect]
    public let cooldown: Int
    public let cost: JSONAbilityCost?

    public func toHeroAbility() -> HeroAbility? {
        // Конвертируем тип
        guard let abilityType = HeroAbilityType(rawValue: type) else {
            #if DEBUG
            print("AbilityRegistry: Unknown ability type '\(type)' for '\(id)'")
            #endif
            return nil
        }

        // Конвертируем триггер
        let abilityTrigger = AbilityTrigger.fromString(trigger) ?? .always

        // Конвертируем условие
        let abilityCondition = condition?.toAbilityCondition()

        // Конвертируем эффекты
        let abilityEffects = effects.compactMap { $0.toHeroAbilityEffect() }

        // Конвертируем стоимость
        let abilityCost = cost?.toAbilityCost()

        return HeroAbility(
            id: id,
            name: .inline(name),
            description: .inline(description),
            icon: icon,
            type: abilityType,
            trigger: abilityTrigger,
            condition: abilityCondition,
            effects: abilityEffects,
            cooldown: cooldown,
            cost: abilityCost
        )
    }
}

/// JSON структура для условия способности
public struct JSONAbilityCondition: Codable {
    public let type: String
    public let value: Int?
    public let stringValue: String?

    public func toAbilityCondition() -> AbilityCondition? {
        guard let conditionType = AbilityConditionType(rawValue: type) else {
            // Try converting from snake_case
            let camelType = type.replacingOccurrences(of: "_", with: "")
            for enumCase in AbilityConditionType.allCases {
                if enumCase.rawValue.lowercased() == camelType.lowercased() {
                    return AbilityCondition(type: enumCase, value: value, stringValue: stringValue)
                }
            }
            #if DEBUG
            print("AbilityRegistry: Unknown condition type '\(type)'")
            #endif
            return nil
        }
        return AbilityCondition(type: conditionType, value: value, stringValue: stringValue)
    }
}

/// JSON структура для эффекта способности
public struct JSONAbilityEffect: Codable {
    public let type: String
    public let value: Int
    public let description: String?

    public func toHeroAbilityEffect() -> HeroAbilityEffect? {
        guard let effectType = HeroAbilityEffectType(rawValue: type) else {
            // Try converting from snake_case
            let camelType = type.replacingOccurrences(of: "_", with: "")
            for enumCase in HeroAbilityEffectType.allCases {
                if enumCase.rawValue.lowercased() == camelType.lowercased() {
                    return HeroAbilityEffect(type: enumCase, value: value, description: description)
                }
            }
            #if DEBUG
            print("AbilityRegistry: Unknown effect type '\(type)'")
            #endif
            return nil
        }
        return HeroAbilityEffect(type: effectType, value: value, description: description)
    }
}

/// JSON структура для стоимости способности
public struct JSONAbilityCost: Codable {
    public let type: String
    public let value: Int

    public func toAbilityCost() -> AbilityCost? {
        guard let costType = AbilityCostType(rawValue: type) else {
            #if DEBUG
            print("AbilityRegistry: Unknown cost type '\(type)'")
            #endif
            return nil
        }
        return AbilityCost(type: costType, value: value)
    }
}

// MARK: - AbilityTrigger Extension

extension AbilityTrigger {
    /// Конвертация из snake_case строки
    public static func fromString(_ string: String) -> AbilityTrigger? {
        // Прямое совпадение
        if let trigger = AbilityTrigger(rawValue: string) {
            return trigger
        }

        // Конвертация snake_case -> camelCase
        let mapping: [String: AbilityTrigger] = [
            "always": .always,
            "turn_start": .turnStart,
            "turn_end": .turnEnd,
            "on_attack": .onAttack,
            "on_damage_received": .onDamageReceived,
            "on_damage_dealt": .onDamageDealt,
            "on_card_played": .onCardPlayed,
            "on_combat_start": .onCombatStart,
            "on_combat_end": .onCombatEnd,
            "on_explore": .onExplore,
            "manual": .manual
        ]

        return mapping[string]
    }
}

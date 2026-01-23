import Foundation

/// Реестр способностей героев - data-driven загрузка из JSON
/// Заменяет хардкод в HeroAbility.forAbilityId()
final class AbilityRegistry {

    // MARK: - Singleton

    static let shared = AbilityRegistry()

    // MARK: - Storage

    /// Зарегистрированные способности по ID
    private var abilities: [String: HeroAbility] = [:]

    // MARK: - Init

    private init() {
        // Способности загружаются из ContentPack (hero_abilities.json)
        // Пустой init - данные загружаются через loadFromJSON()
    }

    // MARK: - Registration

    /// Зарегистрировать способность
    func register(_ ability: HeroAbility) {
        abilities[ability.id] = ability
    }

    /// Зарегистрировать несколько способностей
    func registerAll(_ newAbilities: [HeroAbility]) {
        for ability in newAbilities {
            register(ability)
        }
    }

    /// Очистить реестр
    func clear() {
        abilities.removeAll()
    }

    /// Перезагрузить реестр (очистка для повторной загрузки)
    func reload() {
        clear()
    }

    // MARK: - Queries

    /// Получить способность по ID
    func ability(id: String) -> HeroAbility? {
        return abilities[id]
    }

    /// Все доступные способности
    var allAbilities: [HeroAbility] {
        return Array(abilities.values)
    }

    /// Количество зарегистрированных способностей
    var count: Int {
        return abilities.count
    }

    // MARK: - JSON Loading

    /// Загрузить способности из JSON файла
    func loadFromJSON(at url: URL) {
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
struct JSONAbilityDefinition: Codable {
    let id: String
    let name: LocalizedString
    let description: LocalizedString
    let icon: String
    let type: String
    let trigger: String
    let condition: JSONAbilityCondition?
    let effects: [JSONAbilityEffect]
    let cooldown: Int
    let cost: JSONAbilityCost?

    func toHeroAbility() -> HeroAbility? {
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
            name: name.localized,
            description: description.localized,
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
struct JSONAbilityCondition: Codable {
    let type: String
    let value: Int?
    let stringValue: String?

    func toAbilityCondition() -> AbilityCondition? {
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
struct JSONAbilityEffect: Codable {
    let type: String
    let value: Int
    let description: String?

    func toHeroAbilityEffect() -> HeroAbilityEffect? {
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
struct JSONAbilityCost: Codable {
    let type: String
    let value: Int

    func toAbilityCost() -> AbilityCost? {
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
    static func fromString(_ string: String) -> AbilityTrigger? {
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


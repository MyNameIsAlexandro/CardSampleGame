import Foundation

/// Способность героя
/// Определяет уникальные действия и пассивные эффекты героя
struct HeroAbility: Codable, Equatable {
    /// Уникальный идентификатор способности
    let id: String

    /// Название способности
    let name: String

    /// Описание для UI
    let description: String

    /// Иконка (SF Symbol или emoji)
    let icon: String

    /// Тип способности
    let type: HeroAbilityType

    /// Триггер активации (для пассивных)
    let trigger: AbilityTrigger

    /// Условие активации
    let condition: AbilityCondition?

    /// Эффекты способности
    let effects: [HeroAbilityEffect]

    /// Кулдаун (в ходах, 0 = нет кулдауна)
    let cooldown: Int

    /// Стоимость активации (для активных способностей)
    let cost: AbilityCost?
}

/// Тип способности героя
enum HeroAbilityType: String, Codable {
    /// Пассивная - работает автоматически
    case passive

    /// Активная - требует ручной активации
    case active

    /// Реактивная - срабатывает в ответ на событие
    case reactive

    /// Ультимейт - мощная способность с долгим кулдауном
    case ultimate
}

/// Триггер активации способности
enum AbilityTrigger: String, Codable {
    /// Всегда активна
    case always

    /// В начале хода
    case turnStart

    /// В конце хода
    case turnEnd

    /// При атаке
    case onAttack

    /// При получении урона
    case onDamageReceived

    /// При нанесении урона
    case onDamageDealt

    /// При использовании карты
    case onCardPlayed

    /// При входе в бой
    case onCombatStart

    /// При выходе из боя
    case onCombatEnd

    /// При исследовании
    case onExplore

    /// Ручная активация
    case manual
}

/// Условие активации способности
struct AbilityCondition: Codable, Equatable {
    let type: AbilityConditionType
    let value: Int?
    let stringValue: String?

    init(type: AbilityConditionType, value: Int? = nil, stringValue: String? = nil) {
        self.type = type
        self.value = value
        self.stringValue = stringValue
    }
}

/// Тип условия
enum AbilityConditionType: String, Codable, CaseIterable {
    /// HP ниже процента
    case hpBelowPercent

    /// HP выше процента
    case hpAbovePercent

    /// Цель на полном HP
    case targetFullHP

    /// Первая атака в бою
    case firstAttack

    /// Источник урона - тьма
    case damageSourceDark

    /// Источник урона - свет
    case damageSourceLight

    /// Есть определённое проклятие
    case hasCurse

    /// Баланс выше значения
    case balanceAbove

    /// Баланс ниже значения
    case balanceBelow

    /// Есть карта в руке
    case hasCardInHand
}

/// Эффект способности героя
struct HeroAbilityEffect: Codable, Equatable {
    let type: HeroAbilityEffectType
    let value: Int
    let description: String?

    init(type: HeroAbilityEffectType, value: Int, description: String? = nil) {
        self.type = type
        self.value = value
        self.description = description
    }
}

/// Тип эффекта способности
enum HeroAbilityEffectType: String, Codable, CaseIterable {
    /// Бонус к урону
    case bonusDamage

    /// Снижение получаемого урона
    case damageReduction

    /// Дополнительный кубик атаки
    case bonusDice

    /// Восстановление HP
    case heal

    /// Восстановление веры
    case gainFaith

    /// Потеря веры
    case loseFaith

    /// Сдвиг баланса к Свету
    case shiftLight

    /// Сдвиг баланса к Тьме
    case shiftDark

    /// Взять карту
    case drawCard

    /// Сбросить карту
    case discardCard

    /// Применить проклятие к врагу
    case applyCurseToEnemy

    /// Снять проклятие с себя
    case removeCurse

    /// Бонус к защите
    case bonusDefense

    /// Вызов духа
    case summonSpirit

    /// Бонус к следующей атаке
    case bonusNextAttack

    /// Перебросить кубик
    case rerollDice
}

/// Стоимость активации способности
struct AbilityCost: Codable, Equatable {
    let type: AbilityCostType
    let value: Int
}

/// Тип стоимости
enum AbilityCostType: String, Codable {
    case health
    case faith
    case card
    case action
}

// MARK: - Ability Lookup

extension HeroAbility {
    /// Получить способность по ID (data-driven через AbilityRegistry)
    /// Способности загружаются из hero_abilities.json в ContentPack
    static func forAbilityId(_ id: String) -> HeroAbility? {
        return AbilityRegistry.shared.ability(id: id)
    }
}

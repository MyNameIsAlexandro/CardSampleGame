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
enum AbilityConditionType: String, Codable {
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
enum HeroAbilityEffectType: String, Codable {
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

// MARK: - Предустановленные способности классов

extension HeroAbility {

    /// Ярость Воина: +2 урона при HP < 50%
    static let warriorRage = HeroAbility(
        id: "warrior_rage",
        name: "Ярость",
        description: "+2 к урону при HP ниже 50%",
        icon: "🔥",
        type: .passive,
        trigger: .onDamageDealt,
        condition: AbilityCondition(type: .hpBelowPercent, value: 50),
        effects: [HeroAbilityEffect(type: .bonusDamage, value: 2)],
        cooldown: 0,
        cost: nil
    )

    /// Медитация Мага: +1 вера в конце хода
    static let mageMeditation = HeroAbility(
        id: "mage_meditation",
        name: "Медитация",
        description: "+1 вера в конце каждого хода",
        icon: "🧘",
        type: .passive,
        trigger: .turnEnd,
        condition: nil,
        effects: [HeroAbilityEffect(type: .gainFaith, value: 1)],
        cooldown: 0,
        cost: nil
    )

    /// Выслеживание Следопыта: +1 кубик при первой атаке
    static let rangerTracking = HeroAbility(
        id: "ranger_tracking",
        name: "Выслеживание",
        description: "+1 кубик атаки при первой атаке в бою",
        icon: "🎯",
        type: .passive,
        trigger: .onAttack,
        condition: AbilityCondition(type: .firstAttack),
        effects: [HeroAbilityEffect(type: .bonusDice, value: 1)],
        cooldown: 0,
        cost: nil
    )

    /// Благословение Жреца: -1 урон от тёмных источников
    static let priestBlessing = HeroAbility(
        id: "priest_blessing",
        name: "Благословение",
        description: "-1 урон от тёмных источников",
        icon: "✨",
        type: .passive,
        trigger: .onDamageReceived,
        condition: AbilityCondition(type: .damageSourceDark),
        effects: [HeroAbilityEffect(type: .damageReduction, value: 1)],
        cooldown: 0,
        cost: nil
    )

    /// Засада Тени: +3 урона по целям с полным HP
    static let shadowAmbush = HeroAbility(
        id: "shadow_ambush",
        name: "Засада",
        description: "+3 урона по врагам с полным здоровьем",
        icon: "🗡️",
        type: .passive,
        trigger: .onDamageDealt,
        condition: AbilityCondition(type: .targetFullHP),
        effects: [HeroAbilityEffect(type: .bonusDamage, value: 3)],
        cooldown: 0,
        cost: nil
    )

    /// Получить способность по классу героя
    static func forHeroClass(_ heroClass: HeroClass) -> HeroAbility {
        switch heroClass {
        case .warrior: return .warriorRage
        case .mage: return .mageMeditation
        case .ranger: return .rangerTracking
        case .priest: return .priestBlessing
        case .shadow: return .shadowAmbush
        }
    }
}

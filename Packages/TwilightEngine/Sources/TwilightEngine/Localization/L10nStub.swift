import Foundation

// MARK: - L10n Stub
// Provides localized strings for the TwilightEngine package
// This is a stub that returns Russian strings directly
// In production, these would come from the LocalizationManager

/// Localization enum for TwilightEngine package
public enum L10n {
    // MARK: - Region States
    case regionStateStable
    case regionStateBorderland
    case regionStateBreach

    // MARK: - Region Types
    case regionTypeForest
    case regionTypeSwamp
    case regionTypeMountain
    case regionTypeSettlement
    case regionTypeWater
    case regionTypeWasteland
    case regionTypeSacred

    // MARK: - Combat Modifiers
    case combatModifierBorderland
    case combatModifierBreach

    // MARK: - Anchor Types
    case anchorTypeShrine
    case anchorTypeBarrow
    case anchorTypeSacredTree
    case anchorTypeStoneIdol
    case anchorTypeSpring
    case anchorTypeChapel
    case anchorTypeTemple
    case anchorTypeCross

    // MARK: - Event Types
    case eventTypeCombat
    case eventTypeRitual
    case eventTypeNarrative
    case eventTypeExploration
    case eventTypeWorldShift

    // MARK: - Curses (display names)
    case curseWeakness
    case curseFear
    case curseExhaustion
    case curseGreed
    case curseShadowOfNav
    case curseBloodCurse
    case curseSealOfNav

    // MARK: - Curse Names (full)
    case curseWeaknessName
    case curseFearName
    case curseExhaustionName
    case curseGreedName
    case curseShadowOfNavName
    case curseBloodCurseName
    case curseSealOfNavName

    // MARK: - Curse Descriptions
    case curseWeaknessDescription
    case curseFearDescription
    case curseExhaustionDescription
    case curseGreedDescription
    case curseShadowOfNavDescription
    case curseBloodCurseDescription
    case curseSealOfNavDescription

    // MARK: - Combat Calculator
    case calcHit
    case calcMiss
    case calcAttackVsDefense
    case calcStrength
    case calcBonusDice
    case calcBonusDamage
    case calcDamage
    case calcBaseDamage
    case calcHeroAbilityDice
    case calcHeroAbility
    case calcCurseWeakness
    case calcCurseShadowOfNav

    // MARK: - Error Messages
    case errorInvalidAction
    case errorRegionNotAccessible
    case errorRegionNotNeighbor
    case errorActionNotAvailable
    case errorInsufficientResources
    case errorHealthTooLow
    case errorGameNotInProgress
    case errorCombatInProgress
    case errorEventInProgress
    case errorNoActiveEvent
    case errorNoActiveCombat
    case errorEventNotFound
    case errorInvalidChoiceIndex
    case errorChoiceRequirementsNotMet
    case errorCardNotInHand
    case errorNotEnoughActions
    case errorInvalidTarget

    // MARK: - Localized String

    public var localized: String {
        switch self {
        // Region States
        case .regionStateStable: return "Стабильный"
        case .regionStateBorderland: return "Пограничье"
        case .regionStateBreach: return "Прорыв"

        // Region Types
        case .regionTypeForest: return "Лес"
        case .regionTypeSwamp: return "Болото"
        case .regionTypeMountain: return "Горы"
        case .regionTypeSettlement: return "Поселение"
        case .regionTypeWater: return "Водоём"
        case .regionTypeWasteland: return "Пустошь"
        case .regionTypeSacred: return "Священное место"

        // Combat Modifiers
        case .combatModifierBorderland: return "Пограничье: враги +1 к атаке"
        case .combatModifierBreach: return "Прорыв: враги +2 к атаке и защите"

        // Anchor Types
        case .anchorTypeShrine: return "Капище"
        case .anchorTypeBarrow: return "Курган"
        case .anchorTypeSacredTree: return "Священный дуб"
        case .anchorTypeStoneIdol: return "Каменная баба"
        case .anchorTypeSpring: return "Родник"
        case .anchorTypeChapel: return "Часовня"
        case .anchorTypeTemple: return "Храм"
        case .anchorTypeCross: return "Обетный крест"

        // Event Types
        case .eventTypeCombat: return "Бой"
        case .eventTypeRitual: return "Ритуал"
        case .eventTypeNarrative: return "Событие"
        case .eventTypeExploration: return "Исследование"
        case .eventTypeWorldShift: return "Сдвиг мира"

        // Curses (short names)
        case .curseWeakness: return "Слабость"
        case .curseFear: return "Страх"
        case .curseExhaustion: return "Истощение"
        case .curseGreed: return "Жадность"
        case .curseShadowOfNav: return "Тень Нави"
        case .curseBloodCurse: return "Проклятие крови"
        case .curseSealOfNav: return "Печать Нави"

        // Curse Names (full)
        case .curseWeaknessName: return "Слабость"
        case .curseFearName: return "Страх"
        case .curseExhaustionName: return "Истощение"
        case .curseGreedName: return "Жадность"
        case .curseShadowOfNavName: return "Тень Нави"
        case .curseBloodCurseName: return "Проклятие крови"
        case .curseSealOfNavName: return "Печать Нави"

        // Curse Descriptions
        case .curseWeaknessDescription: return "-1 к урону до конца боя"
        case .curseFearDescription: return "-1 к защите до конца боя"
        case .curseExhaustionDescription: return "-1 действие в этом ходу"
        case .curseGreedDescription: return "+2 веры, но WorldTension +1"
        case .curseShadowOfNavDescription: return "+3 урона, но -2 HP"
        case .curseBloodCurseDescription: return "При убийстве +2 HP, баланс к тьме"
        case .curseSealOfNavDescription: return "Нельзя использовать Sustain карты"

        // Combat Calculator
        case .calcHit: return "Попадание!"
        case .calcMiss: return "Промах!"
        case .calcAttackVsDefense: return "Атака vs Защита"
        case .calcStrength: return "Сила"
        case .calcBonusDice: return "Бонусные кубики"
        case .calcBonusDamage: return "Бонусный урон"
        case .calcDamage: return "Урон"
        case .calcBaseDamage: return "Базовый урон"
        case .calcHeroAbilityDice: return "Способность героя (кубики)"
        case .calcHeroAbility: return "Способность героя"
        case .calcCurseWeakness: return "Проклятие: Слабость"
        case .calcCurseShadowOfNav: return "Проклятие: Тень Нави"

        // Error Messages
        case .errorInvalidAction: return "Недопустимое действие"
        case .errorRegionNotAccessible: return "Регион недоступен"
        case .errorRegionNotNeighbor: return "Регион не является соседним"
        case .errorActionNotAvailable: return "Действие недоступно в этом регионе"
        case .errorInsufficientResources: return "Недостаточно ресурсов"
        case .errorHealthTooLow: return "Слишком мало здоровья"
        case .errorGameNotInProgress: return "Игра не запущена"
        case .errorCombatInProgress: return "Идёт бой"
        case .errorEventInProgress: return "Событие в процессе"
        case .errorNoActiveEvent: return "Нет активного события"
        case .errorNoActiveCombat: return "Нет активного боя"
        case .errorEventNotFound: return "Событие не найдено"
        case .errorInvalidChoiceIndex: return "Неверный индекс выбора"
        case .errorChoiceRequirementsNotMet: return "Требования выбора не выполнены"
        case .errorCardNotInHand: return "Карта не в руке"
        case .errorNotEnoughActions: return "Недостаточно действий"
        case .errorInvalidTarget: return "Неверная цель"
        }
    }

    // MARK: - Localized with Arguments

    public func localized(with args: CVarArg...) -> String {
        let format = self.localized
        return String(format: format, arguments: args)
    }
}

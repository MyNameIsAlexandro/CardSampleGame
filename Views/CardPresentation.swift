/// Файл: Views/CardPresentation.swift
/// Назначение: Содержит реализацию файла CardPresentation.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine

/// Единый слой UI-представления `Card` для всех карточных вью.
/// Здесь хранится только mapping модели в UI-семантику (цвета/иконки/локализация).
extension Card {
    var uiLocalizedType: String {
        switch type {
        case .character: return L10n.cardTypeCharacter.localized
        case .weapon: return L10n.cardTypeWeapon.localized
        case .spell: return L10n.cardTypeSpell.localized
        case .armor: return L10n.cardTypeArmor.localized
        case .item: return L10n.cardTypeItem.localized
        case .ally: return L10n.cardTypeAlly.localized
        case .blessing: return L10n.cardTypeBlessing.localized
        case .monster: return L10n.cardTypeMonster.localized
        case .location: return L10n.cardTypeLocation.localized
        case .scenario: return type.rawValue.capitalized
        case .curse: return L10n.tmCardTypeCurse.localized
        case .spirit: return L10n.tmCardTypeSpirit.localized
        case .artifact: return L10n.tmCardTypeArtifact.localized
        case .ritual: return L10n.tmCardTypeRitual.localized
        case .resource: return L10n.cardTypeResource.localized
        case .attack: return L10n.cardTypeAttack.localized
        case .defense: return L10n.cardTypeDefense.localized
        case .special: return L10n.cardTypeSpecial.localized
        }
    }

    var uiLocalizedRarity: String {
        switch rarity {
        case .common: return L10n.rarityCommon.localized
        case .uncommon: return L10n.rarityUncommon.localized
        case .rare: return L10n.rarityRare.localized
        case .epic: return L10n.rarityEpic.localized
        case .legendary: return L10n.rarityLegendary.localized
        }
    }

    var uiHeaderColor: Color {
        switch type {
        case .character: return AppColors.dark
        case .weapon: return AppColors.danger
        case .spell: return AppColors.primary
        case .armor: return AppColors.secondary
        case .item: return Color.brown
        case .ally: return AppColors.success
        case .blessing: return AppColors.light
        case .monster: return AppColors.danger.opacity(Opacity.high)
        case .location: return Color.teal
        case .scenario: return Color.indigo
        case .curse: return Color.black
        case .spirit: return Color.cyan
        case .artifact: return AppColors.power
        case .ritual: return Color.indigo
        case .resource: return AppColors.success
        case .attack: return AppColors.danger
        case .defense: return AppColors.defense
        case .special: return AppColors.dark
        }
    }

    var uiColor: Color {
        uiHeaderColor.opacity(Opacity.mediumHigh)
    }

    var uiIcon: String {
        switch type {
        case .character: return "person.fill"
        case .weapon: return "bolt.fill"
        case .spell: return "sparkles"
        case .armor: return "shield.fill"
        case .item: return "bag.fill"
        case .ally: return "person.2.fill"
        case .blessing: return "star.fill"
        case .monster: return "flame.fill"
        case .location: return "mappin.and.ellipse"
        case .scenario: return "book.fill"
        case .curse: return "cloud.bolt.fill"
        case .spirit: return "cloud.moon.fill"
        case .artifact: return "crown.fill"
        case .ritual: return "book.closed.fill"
        case .resource: return "leaf.fill"
        case .attack: return "bolt.fill"
        case .defense: return "shield.fill"
        case .special: return "star.circle.fill"
        }
    }

    var uiRarityColor: Color {
        switch rarity {
        case .common: return AppColors.rarityCommon
        case .uncommon: return AppColors.rarityUncommon
        case .rare: return AppColors.rarityRare
        case .epic: return AppColors.rarityEpic
        case .legendary: return AppColors.rarityLegendary
        }
    }
}

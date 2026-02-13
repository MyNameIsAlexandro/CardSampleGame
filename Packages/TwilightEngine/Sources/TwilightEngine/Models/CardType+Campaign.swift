/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Models/CardType+Campaign.swift
/// Назначение: Содержит реализацию файла CardType+Campaign.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// Balance system (Light/Dark)
public enum CardBalance: String, Codable, Hashable, Sendable, CaseIterable {
    case light      // Cards from Prav, protective/healing
    case neutral    // Balanced cards
    case dark       // Cards from Nav, aggressive/cursing

    /// Initialize from Engine's AnchorInfluence
    /// Used by data-driven content loading
    public init(from influence: AnchorInfluence) {
        switch influence {
        case .light: self = .light
        case .neutral: self = .neutral
        case .dark: self = .dark
        }
    }
}

// Three Realms system
public enum Realm: String, Codable, Hashable, Sendable, CaseIterable {
    case yav        // Явь - World of the Living (reality, settlements, heroes)
    case nav        // Навь - World of the Dead (spirits, undead, curses)
    case prav       // Правь - World of the Gods (higher powers, blessings, ancient magic)
}

// Functional Card Roles (Campaign system)
// See EXPLORATION_CORE_DESIGN.md, section 22
public enum CardRole: String, Codable, Hashable, Sendable {
    case sustain    // Поддержка - healing, curse removal, recovery
    case control    // Контроль - region stabilization, anchor protection, tension reduction
    case power      // Сила - fast progress, elite enemies, rare rewards (always with a price)
    case utility    // Гибкость - card draw, deck manipulation, preparation

    /// Default balance alignment for this role
    public var defaultBalance: CardBalance {
        switch self {
        case .sustain: return .light
        case .control: return .light
        case .power: return .dark
        case .utility: return .neutral
        }
    }

    /// Typical rarity for this role
    public var typicalRarity: [CardRarity] {
        switch self {
        case .sustain: return [.common, .uncommon]
        case .control: return [.rare, .epic]
        case .power: return [.uncommon, .rare]
        case .utility: return [.common, .uncommon]
        }
    }
}

// Curse system (PLAYABLE curses)
// See EXPLORATION_CORE_DESIGN.md, section 26
public enum CurseType: String, Codable, Hashable, Sendable {
    case weakness       // Слабость: -1 к урону до конца боя (2 веры снять)
    case fear           // Страх: -1 к защите до конца боя (2 веры)
    case exhaustion     // Истощение: -1 действие в этом ходу (3 веры)
    case greed          // Жадность: +2 веры, но WorldTension +1 (4 веры)
    case shadowOfNav    // Тень Нави: +3 урона, но -2 HP (5 веры)
    case bloodCurse     // Проклятие крови: При убийстве +2 HP, баланс к тьме (6 веры)
    case sealOfNav      // Печать Нави: Нельзя использовать Sustain карты (8 веры)

    /// Cost in faith to remove this curse
    public var removalCost: Int {
        switch self {
        case .weakness: return 2
        case .fear: return 2
        case .exhaustion: return 3
        case .greed: return 4
        case .shadowOfNav: return 5
        case .bloodCurse: return 6
        case .sealOfNav: return 8
        }
    }

    /// Localized name
    public var displayName: String {
        switch self {
        case .weakness: return L10n.curseWeakness.localized
        case .fear: return L10n.curseFear.localized
        case .exhaustion: return L10n.curseExhaustion.localized
        case .greed: return L10n.curseGreed.localized
        case .shadowOfNav: return L10n.curseShadowOfNav.localized
        case .bloodCurse: return L10n.curseBloodCurse.localized
        case .sealOfNav: return L10n.curseSealOfNav.localized
        }
    }
}

// Expansion tracking
public enum ExpansionSet: String, Codable, Sendable {
    case baseSet            // Базовый набор
    case twilightMarches    // Сумрачные Пределы (campaign)
    case borderlands        // Порубежье (first expansion)
    case deepForest         // Дремучий Лес
    case ancientRuins       // Древние Руины
    case frozenNorth        // Замерзший Север
}

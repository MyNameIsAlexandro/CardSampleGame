import Foundation

public enum CardType: String, Codable, Hashable, Sendable {
    case character
    case weapon
    case spell
    case armor
    case item
    case ally
    case blessing
    case monster
    case location
    case scenario

    // Twilight Marches specific card types
    case curse      // Проклятия - negative effects
    case spirit     // Духи - summonable allies/enemies
    case artifact   // Артефакты - powerful ancient items
    case ritual     // Ритуалы - special spells requiring preparation

    // Deck-building game card types
    case resource   // Ресурсы - used to purchase cards from market
    case attack     // Атака - deal damage to enemies
    case defense    // Защита - block damage or protect
    case special    // Особые - unique effects and abilities
}

public enum CardRarity: String, Codable, Hashable, Sendable {
    case common
    case uncommon
    case rare
    case epic
    case legendary
}

public enum DamageType: String, Codable, Hashable, Sendable {
    case physical
    case fire
    case cold
    case electricity
    case acid
    case mental
    case poison
    case arcane
}

// Twilight Marches: Balance system (Light/Dark)
public enum CardBalance: String, Codable, Hashable, Sendable {
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

// Twilight Marches: Three Realms system
public enum Realm: String, Codable, Hashable, Sendable {
    case yav        // Явь - World of the Living (reality, settlements, heroes)
    case nav        // Навь - World of the Dead (spirits, undead, curses)
    case prav       // Правь - World of the Gods (higher powers, blessings, ancient magic)
}

// Twilight Marches: Functional Card Roles (Campaign system)
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

// Twilight Marches: Curse system (PLAYABLE curses)
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

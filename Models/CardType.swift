import Foundation

enum CardType: String, Codable, Hashable {
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

enum CardRarity: String, Codable, Hashable {
    case common
    case uncommon
    case rare
    case epic
    case legendary
}

enum DamageType: String, Codable, Hashable {
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
enum CardBalance: String, Codable, Hashable {
    case light      // Cards from Prav, protective/healing
    case neutral    // Balanced cards
    case dark       // Cards from Nav, aggressive/cursing
}

// Twilight Marches: Three Realms system
enum Realm: String, Codable, Hashable {
    case yav        // Явь - World of the Living (reality, settlements, heroes)
    case nav        // Навь - World of the Dead (spirits, undead, curses)
    case prav       // Правь - World of the Gods (higher powers, blessings, ancient magic)
}

// Twilight Marches: Curse system
enum CurseType: String, Codable, Hashable {
    case blindness      // Слепота - reduce accuracy/vision
    case muteness       // Немота - can't cast spells
    case weakness       // Слабость - reduce power
    case forgetfulness  // Забвение - discard cards
    case sickness       // Болезнь - lose health over time
    case madness        // Безумие - random effects
    case transformation // Превращение - change form
}

// Expansion tracking
enum ExpansionSet: String, Codable {
    case baseSet        // Базовый набор
    case borderlands    // Порубежье (first expansion)
    case deepForest     // Дремучий Лес
    case ancientRuins   // Древние Руины
    case frozenNorth    // Замерзший Север
}

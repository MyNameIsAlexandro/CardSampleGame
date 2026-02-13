/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Models/CardType.swift
/// Назначение: Содержит реализацию файла CardType.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

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

    // Campaign-specific card types
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

public enum DamageType: String, Codable, Hashable, Sendable, CaseIterable {
    case physical
    case fire
    case cold
    case electricity
    case acid
    case mental
    case poison
    case arcane
}

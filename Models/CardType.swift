import Foundation

enum CardType: String, Codable {
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
}

enum CardRarity: String, Codable {
    case common
    case uncommon
    case rare
    case epic
    case legendary
}

enum DamageType: String, Codable {
    case physical
    case fire
    case cold
    case electricity
    case acid
    case mental
    case poison
}

import Foundation

struct Card: Identifiable, Codable {
    let id: UUID
    let name: String
    let type: CardType
    let rarity: CardRarity
    let description: String
    let imageURL: String?

    // Stats
    var power: Int?
    var defense: Int?
    var health: Int?
    var cost: Int?

    // Abilities and traits
    var abilities: [CardAbility]
    var traits: [String]

    // Card-specific properties
    var damageType: DamageType?
    var range: Int?

    init(
        id: UUID = UUID(),
        name: String,
        type: CardType,
        rarity: CardRarity = .common,
        description: String,
        imageURL: String? = nil,
        power: Int? = nil,
        defense: Int? = nil,
        health: Int? = nil,
        cost: Int? = nil,
        abilities: [CardAbility] = [],
        traits: [String] = [],
        damageType: DamageType? = nil,
        range: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.rarity = rarity
        self.description = description
        self.imageURL = imageURL
        self.power = power
        self.defense = defense
        self.health = health
        self.cost = cost
        self.abilities = abilities
        self.traits = traits
        self.damageType = damageType
        self.range = range
    }
}

struct CardAbility: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let effect: AbilityEffect

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        effect: AbilityEffect
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.effect = effect
    }
}

enum AbilityEffect: Codable {
    case damage(amount: Int, type: DamageType)
    case heal(amount: Int)
    case drawCards(count: Int)
    case addDice(count: Int)
    case reroll
    case explore
    case custom(String)
}

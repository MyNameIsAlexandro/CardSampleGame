import Foundation

struct SampleCards {
    static func createCharacterDeck() -> [Card] {
        return [
            Card(
                name: "Valeros",
                type: .character,
                rarity: .rare,
                description: "A brave fighter from the city guard, skilled with sword and shield.",
                power: 8,
                defense: 6,
                health: 12,
                abilities: [
                    CardAbility(
                        name: "Weapon Master",
                        description: "Add 2 dice when using weapons",
                        effect: .addDice(count: 2)
                    )
                ],
                traits: ["Human", "Warrior", "Fighter"]
            ),
            Card(
                name: "Seoni",
                type: .character,
                rarity: .rare,
                description: "A powerful sorceress who channels arcane energies.",
                power: 4,
                defense: 3,
                health: 8,
                abilities: [
                    CardAbility(
                        name: "Arcane Blast",
                        description: "Deal 3 fire damage to any enemy",
                        effect: .damage(amount: 3, type: .fire)
                    ),
                    CardAbility(
                        name: "Spell Focus",
                        description: "Draw 1 extra card when casting spells",
                        effect: .drawCards(count: 1)
                    )
                ],
                traits: ["Human", "Sorcerer", "Magic"]
            ),
            Card(
                name: "Kyra",
                type: .character,
                rarity: .rare,
                description: "A devoted cleric who heals allies and smites evil.",
                power: 5,
                defense: 5,
                health: 10,
                abilities: [
                    CardAbility(
                        name: "Divine Healing",
                        description: "Heal yourself or an ally for 4 health",
                        effect: .heal(amount: 4)
                    )
                ],
                traits: ["Human", "Cleric", "Divine"]
            )
        ]
    }

    static func createWeapons() -> [Card] {
        return [
            Card(
                name: "Longsword",
                type: .weapon,
                rarity: .common,
                description: "A well-balanced blade, deadly in skilled hands.",
                power: 4,
                cost: 2,
                abilities: [],
                traits: ["Melee", "Slashing"],
                damageType: .physical
            ),
            Card(
                name: "Flaming Sword",
                type: .weapon,
                rarity: .rare,
                description: "A magical blade wreathed in flames.",
                power: 6,
                cost: 4,
                abilities: [
                    CardAbility(
                        name: "Burning Strike",
                        description: "Deal 2 additional fire damage",
                        effect: .damage(amount: 2, type: .fire)
                    )
                ],
                traits: ["Melee", "Magical", "Fire"],
                damageType: .fire
            ),
            Card(
                name: "Longbow",
                type: .weapon,
                rarity: .uncommon,
                description: "Strike your enemies from afar.",
                power: 5,
                cost: 3,
                abilities: [],
                traits: ["Ranged", "Piercing"],
                damageType: .physical,
                range: 3
            )
        ]
    }

    static func createSpells() -> [Card] {
        return [
            Card(
                name: "Fireball",
                type: .spell,
                rarity: .uncommon,
                description: "Hurl a ball of flame at your enemies.",
                power: 7,
                cost: 3,
                abilities: [
                    CardAbility(
                        name: "Explosive",
                        description: "Deal damage to multiple enemies",
                        effect: .damage(amount: 7, type: .fire)
                    )
                ],
                traits: ["Fire", "Evocation"],
                damageType: .fire
            ),
            Card(
                name: "Lightning Bolt",
                type: .spell,
                rarity: .uncommon,
                description: "Call down a bolt of electricity.",
                power: 6,
                cost: 2,
                abilities: [
                    CardAbility(
                        name: "Chain Lightning",
                        description: "Can hit multiple targets",
                        effect: .damage(amount: 6, type: .electricity)
                    )
                ],
                traits: ["Electricity", "Evocation"],
                damageType: .electricity
            ),
            Card(
                name: "Cure",
                type: .spell,
                rarity: .common,
                description: "Heal wounds with divine magic.",
                cost: 1,
                abilities: [
                    CardAbility(
                        name: "Healing Touch",
                        description: "Restore 5 health",
                        effect: .heal(amount: 5)
                    )
                ],
                traits: ["Divine", "Healing"]
            )
        ]
    }

    static func createMonsters() -> [Card] {
        return [
            Card(
                name: "Goblin Raider",
                type: .monster,
                rarity: .common,
                description: "A sneaky goblin armed with crude weapons.",
                power: 3,
                defense: 2,
                health: 4,
                abilities: [],
                traits: ["Goblin", "Humanoid"]
            ),
            Card(
                name: "Orc Berserker",
                type: .monster,
                rarity: .uncommon,
                description: "A brutal orc warrior consumed by battle rage.",
                power: 6,
                defense: 4,
                health: 8,
                abilities: [
                    CardAbility(
                        name: "Rage",
                        description: "Gains +2 power when damaged",
                        effect: .addDice(count: 2)
                    )
                ],
                traits: ["Orc", "Humanoid"]
            ),
            Card(
                name: "Ancient Dragon",
                type: .monster,
                rarity: .legendary,
                description: "A massive wyrm of terrible power.",
                power: 12,
                defense: 10,
                health: 20,
                abilities: [
                    CardAbility(
                        name: "Dragon Breath",
                        description: "Deal 8 fire damage to all players",
                        effect: .damage(amount: 8, type: .fire)
                    ),
                    CardAbility(
                        name: "Armored Scales",
                        description: "Reduce all damage by 3",
                        effect: .custom("Damage reduction 3")
                    )
                ],
                traits: ["Dragon", "Fire"],
                damageType: .fire
            ),
            Card(
                name: "Skeleton Warrior",
                type: .monster,
                rarity: .common,
                description: "An undead soldier wielding ancient weapons.",
                power: 4,
                defense: 3,
                health: 5,
                abilities: [],
                traits: ["Undead", "Skeleton"]
            )
        ]
    }

    static func createItems() -> [Card] {
        return [
            Card(
                name: "Healing Potion",
                type: .item,
                rarity: .common,
                description: "A vial of magical healing liquid.",
                cost: 1,
                abilities: [
                    CardAbility(
                        name: "Drink",
                        description: "Restore 3 health",
                        effect: .heal(amount: 3)
                    )
                ],
                traits: ["Potion", "Consumable"]
            ),
            Card(
                name: "Magic Ring",
                type: .item,
                rarity: .rare,
                description: "A ring imbued with protective enchantments.",
                defense: 2,
                cost: 3,
                abilities: [
                    CardAbility(
                        name: "Shield",
                        description: "Add 1 die to all defense checks",
                        effect: .addDice(count: 1)
                    )
                ],
                traits: ["Ring", "Magical"]
            )
        ]
    }

    static func createArmor() -> [Card] {
        return [
            Card(
                name: "Leather Armor",
                type: .armor,
                rarity: .common,
                description: "Light armor that doesn't restrict movement.",
                defense: 3,
                cost: 2,
                abilities: [],
                traits: ["Light Armor"]
            ),
            Card(
                name: "Plate Mail",
                type: .armor,
                rarity: .uncommon,
                description: "Heavy armor providing excellent protection.",
                defense: 6,
                cost: 4,
                abilities: [],
                traits: ["Heavy Armor"]
            )
        ]
    }

    static func createBlessings() -> [Card] {
        return [
            Card(
                name: "Blessing of the Gods",
                type: .blessing,
                rarity: .uncommon,
                description: "Divine favor aids your actions.",
                cost: 0,
                abilities: [
                    CardAbility(
                        name: "Divine Aid",
                        description: "Reroll any check",
                        effect: .reroll
                    )
                ],
                traits: ["Divine", "Blessing"]
            ),
            Card(
                name: "Lucky Charm",
                type: .blessing,
                rarity: .common,
                description: "Luck smiles upon you.",
                cost: 0,
                abilities: [
                    CardAbility(
                        name: "Fortune",
                        description: "Add 2 dice to any check",
                        effect: .addDice(count: 2)
                    )
                ],
                traits: ["Luck", "Blessing"]
            )
        ]
    }

    static func createFullDeck() -> [Card] {
        var deck: [Card] = []
        deck.append(contentsOf: createWeapons())
        deck.append(contentsOf: createWeapons())  // Add duplicates
        deck.append(contentsOf: createSpells())
        deck.append(contentsOf: createSpells())
        deck.append(contentsOf: createItems())
        deck.append(contentsOf: createItems())
        deck.append(contentsOf: createArmor())
        deck.append(contentsOf: createBlessings())
        deck.append(contentsOf: createBlessings())
        deck.append(contentsOf: createBlessings())
        return deck
    }

    static func createEncounterDeck() -> [Card] {
        var deck: [Card] = []
        let monsters = createMonsters()
        deck.append(contentsOf: monsters)
        deck.append(contentsOf: monsters)
        deck.append(contentsOf: monsters)
        return deck
    }
}

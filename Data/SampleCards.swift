import Foundation

struct SampleCards {
    static func createCharacterDeck() -> [Card] {
        return [
            Card(
                name: "card.valeros.name".localized,
                type: .character,
                rarity: .rare,
                description: "card.valeros.desc".localized,
                power: 8,
                defense: 6,
                health: 12,
                abilities: [
                    CardAbility(
                        name: "ability.weapon.master".localized,
                        description: "ability.weapon.master.desc".localized,
                        effect: .addDice(count: 2)
                    )
                ],
                traits: ["trait.human".localized, "trait.warrior".localized, "trait.fighter".localized]
            ),
            Card(
                name: "card.seoni.name".localized,
                type: .character,
                rarity: .rare,
                description: "card.seoni.desc".localized,
                power: 4,
                defense: 3,
                health: 8,
                abilities: [
                    CardAbility(
                        name: "ability.arcane.blast".localized,
                        description: "ability.arcane.blast.desc".localized,
                        effect: .damage(amount: 3, type: .fire)
                    ),
                    CardAbility(
                        name: "ability.spell.focus".localized,
                        description: "ability.spell.focus.desc".localized,
                        effect: .drawCards(count: 1)
                    )
                ],
                traits: ["trait.human".localized, "trait.sorcerer".localized, "trait.magic".localized]
            ),
            Card(
                name: "card.kyra.name".localized,
                type: .character,
                rarity: .rare,
                description: "card.kyra.desc".localized,
                power: 5,
                defense: 5,
                health: 10,
                abilities: [
                    CardAbility(
                        name: "ability.divine.healing".localized,
                        description: "ability.divine.healing.desc".localized,
                        effect: .heal(amount: 4)
                    )
                ],
                traits: ["trait.human".localized, "trait.cleric".localized, "trait.divine".localized]
            )
        ]
    }

    static func createWeapons() -> [Card] {
        return [
            Card(
                name: "card.longsword.name".localized,
                type: .weapon,
                rarity: .common,
                description: "card.longsword.desc".localized,
                power: 4,
                cost: 2,
                abilities: [
                    CardAbility(
                        name: "ability.power.strike".localized,
                        description: "ability.power.strike.desc".localized,
                        effect: .damage(amount: 3, type: .physical)
                    )
                ],
                traits: ["trait.melee".localized],
                damageType: .physical
            ),
            Card(
                name: "card.staff.power.name".localized,
                type: .weapon,
                rarity: .rare,
                description: "card.staff.power.desc".localized,
                power: 6,
                cost: 4,
                abilities: [
                    CardAbility(
                        name: "ability.arcane.surge".localized,
                        description: "ability.arcane.surge.desc".localized,
                        effect: .damage(amount: 2, type: .arcane)
                    )
                ],
                traits: ["trait.melee".localized, "trait.magical".localized, "trait.arcane".localized],
                damageType: .arcane
            ),
            Card(
                name: "card.longbow.name".localized,
                type: .weapon,
                rarity: .uncommon,
                description: "card.longbow.desc".localized,
                power: 5,
                cost: 3,
                abilities: [
                    CardAbility(
                        name: "ability.precise.shot".localized,
                        description: "ability.precise.shot.desc".localized,
                        effect: .custom("Ignore armor")
                    )
                ],
                traits: ["trait.ranged".localized],
                damageType: .physical,
                range: 3
            )
        ]
    }

    static func createSpells() -> [Card] {
        return [
            Card(
                name: "card.fireball.name".localized,
                type: .spell,
                rarity: .uncommon,
                description: "card.fireball.desc".localized,
                power: 7,
                cost: 3,
                abilities: [
                    CardAbility(
                        name: "ability.burn".localized,
                        description: "ability.burn.desc".localized,
                        effect: .damage(amount: 4, type: .fire)
                    )
                ],
                traits: ["trait.fire".localized, "trait.arcane".localized],
                damageType: .fire
            ),
            Card(
                name: "card.lightning.bolt.name".localized,
                type: .spell,
                rarity: .uncommon,
                description: "card.lightning.bolt.desc".localized,
                power: 6,
                cost: 2,
                abilities: [
                    CardAbility(
                        name: "ability.chain.lightning".localized,
                        description: "ability.chain.lightning.desc".localized,
                        effect: .damage(amount: 3, type: .electricity)
                    )
                ],
                traits: ["trait.lightning".localized, "trait.arcane".localized],
                damageType: .electricity
            ),
            Card(
                name: "card.healing.touch.name".localized,
                type: .spell,
                rarity: .common,
                description: "card.healing.touch.desc".localized,
                cost: 1,
                abilities: [
                    CardAbility(
                        name: "ability.restore".localized,
                        description: "ability.restore.desc".localized,
                        effect: .heal(amount: 5)
                    )
                ],
                traits: ["trait.divine".localized, "trait.healing".localized]
            )
        ]
    }

    static func createMonsters() -> [Card] {
        return [
            Card(
                name: "card.goblin.raider.name".localized,
                type: .monster,
                rarity: .common,
                description: "card.goblin.raider.desc".localized,
                power: 3,
                defense: 2,
                health: 4,
                abilities: [],
                traits: ["trait.goblin".localized, "trait.evil".localized]
            ),
            Card(
                name: "card.orc.warrior.name".localized,
                type: .monster,
                rarity: .uncommon,
                description: "card.orc.warrior.desc".localized,
                power: 6,
                defense: 4,
                health: 8,
                abilities: [],
                traits: ["trait.orc".localized, "trait.evil".localized]
            ),
            Card(
                name: "card.ancient.dragon.name".localized,
                type: .monster,
                rarity: .legendary,
                description: "card.ancient.dragon.desc".localized,
                power: 12,
                defense: 10,
                health: 20,
                abilities: [],
                traits: ["trait.dragon".localized, "trait.ancient".localized, "trait.fire".localized],
                damageType: .fire
            ),
            Card(
                name: "card.skeleton.warrior.name".localized,
                type: .monster,
                rarity: .common,
                description: "card.skeleton.warrior.desc".localized,
                power: 4,
                defense: 3,
                health: 5,
                abilities: [],
                traits: ["trait.undead".localized, "trait.skeleton".localized]
            )
        ]
    }

    static func createItems() -> [Card] {
        return [
            Card(
                name: "card.healing.potion.name".localized,
                type: .item,
                rarity: .common,
                description: "card.healing.potion.desc".localized,
                cost: 1,
                abilities: [
                    CardAbility(
                        name: "ability.quick.heal".localized,
                        description: "ability.quick.heal.desc".localized,
                        effect: .heal(amount: 3)
                    )
                ],
                traits: ["trait.potion".localized]
            ),
            Card(
                name: "card.magic.ring.name".localized,
                type: .item,
                rarity: .rare,
                description: "card.magic.ring.desc".localized,
                defense: 2,
                cost: 3,
                abilities: [
                    CardAbility(
                        name: "ability.shield".localized,
                        description: "ability.shield.desc".localized,
                        effect: .addDice(count: 1)
                    )
                ],
                traits: ["trait.magical".localized]
            )
        ]
    }

    static func createArmor() -> [Card] {
        return [
            Card(
                name: "card.leather.armor.name".localized,
                type: .armor,
                rarity: .common,
                description: "card.leather.armor.desc".localized,
                defense: 3,
                cost: 2,
                abilities: [],
                traits: ["trait.light".localized]
            ),
            Card(
                name: "card.plate.armor.name".localized,
                type: .armor,
                rarity: .uncommon,
                description: "card.plate.armor.desc".localized,
                defense: 6,
                cost: 4,
                abilities: [],
                traits: ["trait.heavy".localized]
            )
        ]
    }

    static func createBlessings() -> [Card] {
        return [
            Card(
                name: "card.blessing.gods.name".localized,
                type: .blessing,
                rarity: .uncommon,
                description: "card.blessing.gods.desc".localized,
                cost: 0,
                abilities: [
                    CardAbility(
                        name: "ability.divine.favor".localized,
                        description: "ability.divine.favor.desc".localized,
                        effect: .reroll
                    )
                ],
                traits: ["trait.divine".localized, "trait.blessing".localized]
            ),
            Card(
                name: "card.blessing.luck.name".localized,
                type: .blessing,
                rarity: .common,
                description: "card.blessing.luck.desc".localized,
                cost: 0,
                abilities: [
                    CardAbility(
                        name: "ability.lucky".localized,
                        description: "ability.lucky.desc".localized,
                        effect: .addDice(count: 2)
                    )
                ],
                traits: ["trait.blessing".localized]
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

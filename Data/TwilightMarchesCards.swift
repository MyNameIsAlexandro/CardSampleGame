import Foundation

// Twilight Marches (Сумрачные Пределы)
// Original Slavic dark fantasy card game

struct TwilightMarchesCards {

    // MARK: - Playable Characters

    static func createGuardians() -> [Card] {
        return [
            // Велеслава - Ведунья пограничья (Vedunya - Wise Woman of the Borderlands)
            Card(
                name: "tm.char.veleslava.name".localized,
                type: .character,
                rarity: .rare,
                description: "tm.char.veleslava.desc".localized,
                power: 3,
                defense: 4,
                health: 10,
                abilities: [
                    CardAbility(
                        name: "tm.ability.herb.wisdom".localized,
                        description: "tm.ability.herb.wisdom.desc".localized,
                        effect: .heal(amount: 3)
                    ),
                    CardAbility(
                        name: "tm.ability.curse.breaker".localized,
                        description: "tm.ability.curse.breaker.desc".localized,
                        effect: .removeCurse(type: nil)
                    )
                ],
                traits: ["tm.trait.healer".localized, "tm.trait.vedunya".localized, "tm.trait.light".localized],
                balance: .light,
                realm: .yav,
                expansionSet: "baseSet"
            ),

            // Ратибор - Воевода-изгнанник (Voevoda - Exiled Warlord)
            Card(
                name: "tm.char.ratibor.name".localized,
                type: .character,
                rarity: .rare,
                description: "tm.char.ratibor.desc".localized,
                power: 8,
                defense: 6,
                health: 14,
                abilities: [
                    CardAbility(
                        name: "tm.ability.battle.fury".localized,
                        description: "tm.ability.battle.fury.desc".localized,
                        effect: .addDice(count: 3)
                    ),
                    CardAbility(
                        name: "tm.ability.commanders.will".localized,
                        description: "tm.ability.commanders.will.desc".localized,
                        effect: .gainFaith(amount: 2)
                    )
                ],
                traits: ["tm.trait.warrior".localized, "tm.trait.voevoda".localized, "tm.trait.neutral".localized],
                balance: .neutral,
                realm: .yav,
                expansionSet: "baseSet"
            ),

            // Мирослав - Волхв-отступник (Volkhv - Apostate Sorcerer)
            Card(
                name: "tm.char.miroslav.name".localized,
                type: .character,
                rarity: .rare,
                description: "tm.char.miroslav.desc".localized,
                power: 6,
                defense: 3,
                health: 9,
                abilities: [
                    CardAbility(
                        name: "tm.ability.dark.pact".localized,
                        description: "tm.ability.dark.pact.desc".localized,
                        effect: .summonSpirit(power: 5, realm: .nav)
                    ),
                    CardAbility(
                        name: "tm.ability.soul.drain".localized,
                        description: "tm.ability.soul.drain.desc".localized,
                        effect: .sacrifice(cost: 2, benefit: "Draw 3 cards")
                    )
                ],
                traits: ["tm.trait.sorcerer".localized, "tm.trait.volkhv".localized, "tm.trait.dark".localized],
                balance: .dark,
                realm: .yav,
                expansionSet: "baseSet"
            ),

            // Забава - Охотница на нечисть (Hunter of the Unclean)
            Card(
                name: "tm.char.zabava.name".localized,
                type: .character,
                rarity: .rare,
                description: "tm.char.zabava.desc".localized,
                power: 7,
                defense: 5,
                health: 11,
                abilities: [
                    CardAbility(
                        name: "tm.ability.silver.arrow".localized,
                        description: "tm.ability.silver.arrow.desc".localized,
                        effect: .damage(amount: 5, type: .physical)
                    ),
                    CardAbility(
                        name: "tm.ability.track.prey".localized,
                        description: "tm.ability.track.prey.desc".localized,
                        effect: .drawCards(count: 2)
                    )
                ],
                traits: ["tm.trait.hunter".localized, "tm.trait.ranger".localized, "tm.trait.neutral".localized],
                range: 3,
                balance: .neutral,
                realm: .yav,
                expansionSet: "baseSet"
            )
        ]
    }

    // MARK: - Enemies from Slavic Mythology

    static func createNavMonsters() -> [Card] {
        return [
            // Навий - Дух мертвого (Navii - Spirit of the Dead)
            Card(
                name: "tm.enemy.navii.name".localized,
                type: .monster,
                rarity: .common,
                description: "tm.enemy.navii.desc".localized,
                power: 3,
                defense: 2,
                health: 5,
                abilities: [
                    CardAbility(
                        name: "tm.ability.soul.touch".localized,
                        description: "tm.ability.soul.touch.desc".localized,
                        effect: .applyCurse(type: .weakness, duration: 2)
                    )
                ],
                traits: ["tm.trait.undead".localized, "tm.trait.spirit".localized, "tm.trait.nav".localized],
                damageType: .mental,
                balance: .dark,
                realm: .nav,
                expansionSet: "baseSet"
            ),

            // Упырь (Upyr - Vampire)
            Card(
                name: "tm.enemy.upyr.name".localized,
                type: .monster,
                rarity: .uncommon,
                description: "tm.enemy.upyr.desc".localized,
                power: 6,
                defense: 4,
                health: 8,
                abilities: [
                    CardAbility(
                        name: "tm.ability.blood.drain".localized,
                        description: "tm.ability.blood.drain.desc".localized,
                        effect: .damage(amount: 4, type: .mental)
                    ),
                    CardAbility(
                        name: "tm.ability.life.steal".localized,
                        description: "tm.ability.life.steal.desc".localized,
                        effect: .heal(amount: 2)
                    )
                ],
                traits: ["tm.trait.undead".localized, "tm.trait.upyr".localized, "tm.trait.nav".localized],
                damageType: .mental,
                balance: .dark,
                realm: .nav,
                expansionSet: "baseSet"
            ),

            // Леший (Leshiy - Forest Spirit)
            Card(
                name: "tm.enemy.leshiy.name".localized,
                type: .monster,
                rarity: .uncommon,
                description: "tm.enemy.leshiy.desc".localized,
                power: 5,
                defense: 6,
                health: 10,
                abilities: [
                    CardAbility(
                        name: "tm.ability.forest.maze".localized,
                        description: "tm.ability.forest.maze.desc".localized,
                        effect: .applyCurse(type: .forgetfulness, duration: 3)
                    ),
                    CardAbility(
                        name: "tm.ability.natures.wrath".localized,
                        description: "tm.ability.natures.wrath.desc".localized,
                        effect: .damage(amount: 3, type: .physical)
                    )
                ],
                traits: ["tm.trait.spirit".localized, "tm.trait.nature".localized, "tm.trait.leshiy".localized],
                damageType: .physical,
                balance: .dark,
                realm: .yav,
                expansionSet: "baseSet"
            ),

            // Русалка (Rusalka - Water Spirit)
            Card(
                name: "tm.enemy.rusalka.name".localized,
                type: .monster,
                rarity: .rare,
                description: "tm.enemy.rusalka.desc".localized,
                power: 4,
                defense: 3,
                health: 7,
                abilities: [
                    CardAbility(
                        name: "tm.ability.drowning.song".localized,
                        description: "tm.ability.drowning.song.desc".localized,
                        effect: .applyCurse(type: .madness, duration: 2)
                    ),
                    CardAbility(
                        name: "tm.ability.water.grasp".localized,
                        description: "tm.ability.water.grasp.desc".localized,
                        effect: .damage(amount: 3, type: .cold)
                    )
                ],
                traits: ["tm.trait.spirit".localized, "tm.trait.water".localized, "tm.trait.rusalka".localized],
                damageType: .cold,
                balance: .dark,
                realm: .nav,
                expansionSet: "baseSet"
            ),

            // Змей Горыныч (Zmey Gorynych - Three-Headed Dragon)
            Card(
                name: "tm.enemy.zmey.name".localized,
                type: .monster,
                rarity: .legendary,
                description: "tm.enemy.zmey.desc".localized,
                power: 15,
                defense: 12,
                health: 30,
                abilities: [
                    CardAbility(
                        name: "tm.ability.three.breaths".localized,
                        description: "tm.ability.three.breaths.desc".localized,
                        effect: .damage(amount: 10, type: .fire)
                    ),
                    CardAbility(
                        name: "tm.ability.ancient.curse".localized,
                        description: "tm.ability.ancient.curse.desc".localized,
                        effect: .applyCurse(type: .sickness, duration: 5)
                    )
                ],
                traits: ["tm.trait.dragon".localized, "tm.trait.ancient".localized, "tm.trait.zmey".localized],
                damageType: .fire,
                balance: .dark,
                realm: .prav,
                expansionSet: "baseSet"
            )
        ]
    }

    // MARK: - Spirit Cards

    static func createSpirits() -> [Card] {
        return [
            // Домовой (Domovoy - House Spirit)
            Card(
                name: "tm.spirit.domovoy.name".localized,
                type: .spirit,
                rarity: .common,
                description: "tm.spirit.domovoy.desc".localized,
                power: 2,
                defense: 3,
                health: 5,
                cost: 2,
                abilities: [
                    CardAbility(
                        name: "tm.ability.home.guard".localized,
                        description: "tm.ability.home.guard.desc".localized,
                        effect: .addDice(count: 1)
                    )
                ],
                traits: ["tm.trait.spirit".localized, "tm.trait.guardian".localized, "tm.trait.light".localized],
                balance: .light,
                realm: .yav,
                expansionSet: "baseSet"
            ),

            // Берегиня (Bereginya - Protective Spirit)
            Card(
                name: "tm.spirit.bereginya.name".localized,
                type: .spirit,
                rarity: .uncommon,
                description: "tm.spirit.bereginya.desc".localized,
                power: 3,
                defense: 5,
                health: 8,
                cost: 3,
                abilities: [
                    CardAbility(
                        name: "tm.ability.protective.aura".localized,
                        description: "tm.ability.protective.aura.desc".localized,
                        effect: .removeCurse(type: nil)
                    ),
                    CardAbility(
                        name: "tm.ability.blessing.shield".localized,
                        description: "tm.ability.blessing.shield.desc".localized,
                        effect: .shiftBalance(towards: .light, amount: 2)
                    )
                ],
                traits: ["tm.trait.spirit".localized, "tm.trait.bereginya".localized, "tm.trait.light".localized],
                balance: .light,
                realm: .prav,
                expansionSet: "baseSet"
            )
        ]
    }

    // MARK: - Curse Cards

    static func createCurses() -> [Card] {
        return [
            // Черная метка (Black Mark)
            Card(
                name: "tm.curse.black.mark.name".localized,
                type: .curse,
                rarity: .common,
                description: "tm.curse.black.mark.desc".localized,
                cost: 0,
                abilities: [
                    CardAbility(
                        name: "tm.ability.mark.of.nav".localized,
                        description: "tm.ability.mark.of.nav.desc".localized,
                        effect: .applyCurse(type: .weakness, duration: 3)
                    )
                ],
                traits: ["tm.trait.curse".localized, "tm.trait.nav".localized],
                balance: .dark,
                realm: .nav,
                curseType: .weakness,
                expansionSet: "baseSet"
            ),

            // Безумие (Madness)
            Card(
                name: "tm.curse.madness.name".localized,
                type: .curse,
                rarity: .uncommon,
                description: "tm.curse.madness.desc".localized,
                cost: 0,
                abilities: [
                    CardAbility(
                        name: "tm.ability.lose.sanity".localized,
                        description: "tm.ability.lose.sanity.desc".localized,
                        effect: .applyCurse(type: .madness, duration: 4)
                    )
                ],
                traits: ["tm.trait.curse".localized, "tm.trait.mental".localized],
                balance: .dark,
                realm: .nav,
                curseType: .madness,
                expansionSet: "baseSet"
            )
        ]
    }

    // MARK: - Artifact Cards

    static func createArtifacts() -> [Card] {
        return [
            // Калинов Меч (Kalinov Sword - Legendary Blade)
            Card(
                name: "tm.artifact.kalinov.sword.name".localized,
                type: .artifact,
                rarity: .legendary,
                description: "tm.artifact.kalinov.sword.desc".localized,
                power: 10,
                cost: 5,
                abilities: [
                    CardAbility(
                        name: "tm.ability.cleaving.strike".localized,
                        description: "tm.ability.cleaving.strike.desc".localized,
                        effect: .damage(amount: 8, type: .physical)
                    ),
                    CardAbility(
                        name: "tm.ability.banish.darkness".localized,
                        description: "tm.ability.banish.darkness.desc".localized,
                        effect: .shiftBalance(towards: .light, amount: 3)
                    )
                ],
                traits: ["tm.trait.artifact".localized, "tm.trait.weapon".localized, "tm.trait.legendary".localized],
                damageType: .physical,
                balance: .light,
                realm: .prav,
                expansionSet: "baseSet"
            ),

            // Алатырь-камень (Alatyr Stone - Sacred Stone)
            Card(
                name: "tm.artifact.alatyr.stone.name".localized,
                type: .artifact,
                rarity: .epic,
                description: "tm.artifact.alatyr.stone.desc".localized,
                defense: 5,
                cost: 4,
                abilities: [
                    CardAbility(
                        name: "tm.ability.realm.anchor".localized,
                        description: "tm.ability.realm.anchor.desc".localized,
                        effect: .travelRealm(to: .yav)
                    ),
                    CardAbility(
                        name: "tm.ability.restore.balance".localized,
                        description: "tm.ability.restore.balance.desc".localized,
                        effect: .shiftBalance(towards: .neutral, amount: 5)
                    )
                ],
                traits: ["tm.trait.artifact".localized, "tm.trait.sacred".localized, "tm.trait.ancient".localized],
                balance: .neutral,
                realm: .prav,
                expansionSet: "baseSet"
            )
        ]
    }

    // MARK: - Deck Creation

    static func createFullDeck() -> [Card] {
        var deck: [Card] = []

        // Add spirits
        let spirits = createSpirits()
        deck.append(contentsOf: spirits)
        deck.append(contentsOf: spirits)  // Add duplicates

        // Add artifacts (rare)
        deck.append(contentsOf: createArtifacts())

        return deck
    }

    static func createEncounterDeck() -> [Card] {
        var deck: [Card] = []

        let monsters = createNavMonsters()
        let curses = createCurses()

        deck.append(contentsOf: monsters)
        deck.append(contentsOf: monsters)  // Add duplicates
        deck.append(contentsOf: curses)
        deck.append(contentsOf: curses)
        deck.append(contentsOf: curses)  // More curses

        return deck
    }
}

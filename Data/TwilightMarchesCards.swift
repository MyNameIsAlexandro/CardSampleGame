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

    // MARK: - Starting Decks (10 cards each, unique per hero)

    static func createStartingDeck(for characterName: String) -> [Card] {
        // Determine which character and return their starting deck
        if characterName.contains("Велеслава") || characterName.contains("Veleslava") {
            return createVeleslavaStartingDeck()
        } else if characterName.contains("Ратибор") || characterName.contains("Ratibor") {
            return createRatiborStartingDeck()
        } else if characterName.contains("Мирослав") || characterName.contains("Miroslav") {
            return createMiroslavStartingDeck()
        } else if characterName.contains("Забава") || characterName.contains("Zabava") {
            return createZabavaStartingDeck()
        } else {
            // Default starting deck
            return createGenericStartingDeck()
        }
    }

    // Велеслава - Healer/Light focused deck
    static func createVeleslavaStartingDeck() -> [Card] {
        return [
            // 5x Resource cards (common)
            Card(name: "Травяной Сбор", type: .resource, rarity: .common,
                 description: "Собранные целебные травы. Дают 1 веру.",
                 cost: 0, abilities: [], balance: .light, realm: .yav),
            Card(name: "Травяной Сбор", type: .resource, rarity: .common,
                 description: "Собранные целебные травы. Дают 1 веру.",
                 cost: 0, abilities: [], balance: .light, realm: .yav),
            Card(name: "Травяной Сбор", type: .resource, rarity: .common,
                 description: "Собранные целебные травы. Дают 1 веру.",
                 cost: 0, abilities: [], balance: .light, realm: .yav),
            Card(name: "Травяной Сбор", type: .resource, rarity: .common,
                 description: "Собранные целебные травы. Дают 1 веру.",
                 cost: 0, abilities: [], balance: .light, realm: .yav),
            Card(name: "Травяной Сбор", type: .resource, rarity: .common,
                 description: "Собранные целебные травы. Дают 1 веру.",
                 cost: 0, abilities: [], balance: .light, realm: .yav),

            // 2x Attack cards (weak)
            Card(name: "Защитный Посох", type: .attack, rarity: .common,
                 description: "Простой посох. Наносит 2 урона.",
                 power: 2, cost: 0, abilities: [], balance: .light, realm: .yav),
            Card(name: "Защитный Посох", type: .attack, rarity: .common,
                 description: "Простой посох. Наносит 2 урона.",
                 power: 2, cost: 0, abilities: [], balance: .light, realm: .yav),

            // 2x Defense cards
            Card(name: "Светлый Оберег", type: .defense, rarity: .common,
                 description: "Простой защитный оберег. Блокирует 1 урона.",
                 defense: 1, cost: 0, abilities: [], balance: .light, realm: .yav),
            Card(name: "Светлый Оберег", type: .defense, rarity: .common,
                 description: "Простой защитный оберег. Блокирует 1 урона.",
                 defense: 1, cost: 0, abilities: [], balance: .light, realm: .yav),

            // 1x Special card (unique to character)
            Card(name: "Исцеляющее Касание", type: .special, rarity: .uncommon,
                 description: "Ведунья лечит раны прикосновением. Восстанавливает 3 здоровья.",
                 cost: 0, abilities: [
                     CardAbility(name: "Исцеление", description: "Восстанавливает 3 здоровья.", effect: .heal(amount: 3))
                 ], balance: .light, realm: .yav)
        ]
    }

    // Ратибор - Warrior/Neutral focused deck
    static func createRatiborStartingDeck() -> [Card] {
        return [
            // 5x Resource cards (common)
            Card(name: "Военная Добыча", type: .resource, rarity: .common,
                 description: "Трофеи с поля боя. Дают 1 веру.",
                 cost: 0, abilities: [], balance: .neutral, realm: .yav),
            Card(name: "Военная Добыча", type: .resource, rarity: .common,
                 description: "Трофеи с поля боя. Дают 1 веру.",
                 cost: 0, abilities: [], balance: .neutral, realm: .yav),
            Card(name: "Военная Добыча", type: .resource, rarity: .common,
                 description: "Трофеи с поля боя. Дают 1 веру.",
                 cost: 0, abilities: [], balance: .neutral, realm: .yav),
            Card(name: "Военная Добыча", type: .resource, rarity: .common,
                 description: "Трофеи с поля боя. Дают 1 веру.",
                 cost: 0, abilities: [], balance: .neutral, realm: .yav),
            Card(name: "Военная Добыча", type: .resource, rarity: .common,
                 description: "Трофеи с поля боя. Дают 1 веру.",
                 cost: 0, abilities: [], balance: .neutral, realm: .yav),

            // 3x Attack cards (stronger than healer)
            Card(name: "Удар Мечом", type: .attack, rarity: .common,
                 description: "Удар воеводы. Наносит 3 урона.",
                 power: 3, cost: 0, abilities: [], balance: .neutral, realm: .yav),
            Card(name: "Удар Мечом", type: .attack, rarity: .common,
                 description: "Удар воеводы. Наносит 3 урона.",
                 power: 3, cost: 0, abilities: [], balance: .neutral, realm: .yav),
            Card(name: "Удар Мечом", type: .attack, rarity: .common,
                 description: "Удар воеводы. Наносит 3 урона.",
                 power: 3, cost: 0, abilities: [], balance: .neutral, realm: .yav),

            // 1x Defense card
            Card(name: "Боевая Стойка", type: .defense, rarity: .common,
                 description: "Защитная стойка воина. Блокирует 2 урона.",
                 defense: 2, cost: 0, abilities: [], balance: .neutral, realm: .yav),

            // 1x Special card
            Card(name: "Боевой Клич", type: .special, rarity: .uncommon,
                 description: "Воевода вдохновляет себя. Получает +2 к атаке до конца хода.",
                 cost: 0, abilities: [
                     CardAbility(name: "Вдохновение", description: "+2 к атаке до конца хода.", effect: .addDice(count: 2))
                 ], balance: .neutral, realm: .yav)
        ]
    }

    // Мирослав - Sorcerer/Dark focused deck
    static func createMiroslavStartingDeck() -> [Card] {
        return [
            // 5x Resource cards (common)
            Card(name: "Темная Энергия", type: .resource, rarity: .common,
                 description: "Энергия из Нави. Дает 1 веру.",
                 cost: 0, abilities: [], balance: .dark, realm: .nav),
            Card(name: "Темная Энергия", type: .resource, rarity: .common,
                 description: "Энергия из Нави. Дает 1 веру.",
                 cost: 0, abilities: [], balance: .dark, realm: .nav),
            Card(name: "Темная Энергия", type: .resource, rarity: .common,
                 description: "Энергия из Нави. Дает 1 веру.",
                 cost: 0, abilities: [], balance: .dark, realm: .nav),
            Card(name: "Темная Энергия", type: .resource, rarity: .common,
                 description: "Энергия из Нави. Дает 1 веру.",
                 cost: 0, abilities: [], balance: .dark, realm: .nav),
            Card(name: "Темная Энергия", type: .resource, rarity: .common,
                 description: "Энергия из Нави. Дает 1 веру.",
                 cost: 0, abilities: [], balance: .dark, realm: .nav),

            // 2x Attack cards (magical damage)
            Card(name: "Темный Снаряд", type: .attack, rarity: .common,
                 description: "Магический снаряд тьмы. Наносит 3 урона.",
                 power: 3, cost: 0, abilities: [], damageType: .arcane, balance: .dark, realm: .nav),
            Card(name: "Темный Снаряд", type: .attack, rarity: .common,
                 description: "Магический снаряд тьмы. Наносит 3 урона.",
                 power: 3, cost: 0, abilities: [], damageType: .arcane, balance: .dark, realm: .nav),

            // 1x Defense card (weak)
            Card(name: "Теневой Покров", type: .defense, rarity: .common,
                 description: "Защита тенями. Блокирует 1 урона.",
                 defense: 1, cost: 0, abilities: [], balance: .dark, realm: .nav),

            // 1x Special card
            Card(name: "Жертвоприношение", type: .special, rarity: .uncommon,
                 description: "Волхв жертвует здоровьем ради силы. Теряет 2 здоровья, получает 2 веры.",
                 cost: 0, abilities: [
                     CardAbility(name: "Жертва", description: "Теряет 2 здоровья, получает 2 веры.", effect: .sacrifice(cost: 2, benefit: "Gain 2 faith"))
                 ], balance: .dark, realm: .nav),

            // 1x Curse card (starting weakness)
            Card(name: "Темное Проклятие", type: .curse, rarity: .common,
                 description: "Проклятие тьмы. Нужно 1 веру чтобы сбросить.",
                 cost: 1, abilities: [], balance: .dark, realm: .nav, curseType: .weakness)
        ]
    }

    // Забава - Hunter focused deck
    static func createZabavaStartingDeck() -> [Card] {
        return [
            // 5x Resource cards (common)
            Card(name: "Охотничьи Припасы", type: .resource, rarity: .common,
                 description: "Запасы охотника. Дают 1 веру.",
                 cost: 0, abilities: [], balance: .neutral, realm: .yav),
            Card(name: "Охотничьи Припасы", type: .resource, rarity: .common,
                 description: "Запасы охотника. Дают 1 веру.",
                 cost: 0, abilities: [], balance: .neutral, realm: .yav),
            Card(name: "Охотничьи Припасы", type: .resource, rarity: .common,
                 description: "Запасы охотника. Дают 1 веру.",
                 cost: 0, abilities: [], balance: .neutral, realm: .yav),
            Card(name: "Охотничьи Припасы", type: .resource, rarity: .common,
                 description: "Запасы охотника. Дают 1 веру.",
                 cost: 0, abilities: [], balance: .neutral, realm: .yav),
            Card(name: "Охотничьи Припасы", type: .resource, rarity: .common,
                 description: "Запасы охотника. Дают 1 веру.",
                 cost: 0, abilities: [], balance: .neutral, realm: .yav),

            // 3x Attack cards (ranged)
            Card(name: "Выстрел из Лука", type: .attack, rarity: .common,
                 description: "Точный выстрел. Наносит 2 урона.",
                 power: 2, cost: 0, abilities: [], range: 3, balance: .neutral, realm: .yav),
            Card(name: "Выстрел из Лука", type: .attack, rarity: .common,
                 description: "Точный выстрел. Наносит 2 урона.",
                 power: 2, cost: 0, abilities: [], range: 3, balance: .neutral, realm: .yav),
            Card(name: "Выстрел из Лука", type: .attack, rarity: .common,
                 description: "Точный выстрел. Наносит 2 урона.",
                 power: 2, cost: 0, abilities: [], range: 3, balance: .neutral, realm: .yav),

            // 1x Defense card
            Card(name: "Уклонение", type: .defense, rarity: .common,
                 description: "Охотник уклоняется от удара. Блокирует 1 урона.",
                 defense: 1, cost: 0, abilities: [], balance: .neutral, realm: .yav),

            // 1x Special card
            Card(name: "Меткий Выстрел", type: .special, rarity: .uncommon,
                 description: "Охотник целится точнее. Следующая атака наносит +3 урона.",
                 cost: 0, abilities: [
                     CardAbility(name: "Точность", description: "+3 к урону для следующей атаки.", effect: .damage(amount: 3, type: .physical))
                 ], balance: .neutral, realm: .yav)
        ]
    }

    // Generic starting deck for unknown characters
    static func createGenericStartingDeck() -> [Card] {
        return [
            Card(name: "Ресурс", type: .resource, rarity: .common, description: "Базовый ресурс. Дает 1 веру.", cost: 0, abilities: []),
            Card(name: "Ресурс", type: .resource, rarity: .common, description: "Базовый ресурс. Дает 1 веру.", cost: 0, abilities: []),
            Card(name: "Ресурс", type: .resource, rarity: .common, description: "Базовый ресурс. Дает 1 веру.", cost: 0, abilities: []),
            Card(name: "Ресурс", type: .resource, rarity: .common, description: "Базовый ресурс. Дает 1 веру.", cost: 0, abilities: []),
            Card(name: "Ресурс", type: .resource, rarity: .common, description: "Базовый ресурс. Дает 1 веру.", cost: 0, abilities: []),
            Card(name: "Атака", type: .attack, rarity: .common, description: "Базовая атака. Наносит 2 урона.", power: 2, cost: 0, abilities: []),
            Card(name: "Атака", type: .attack, rarity: .common, description: "Базовая атака. Наносит 2 урона.", power: 2, cost: 0, abilities: []),
            Card(name: "Защита", type: .defense, rarity: .common, description: "Базовая защита. Блокирует 1 урона.", defense: 1, cost: 0, abilities: []),
            Card(name: "Защита", type: .defense, rarity: .common, description: "Базовая защита. Блокирует 1 урона.", defense: 1, cost: 0, abilities: []),
            Card(name: "Особое", type: .special, rarity: .common, description: "Базовая особая карта.", cost: 0, abilities: [])
        ]
    }

    static func createFullDeck() -> [Card] {
        var deck: [Card] = []

        // Add spirits
        let spirits = createSpirits()
        deck.append(contentsOf: spirits)
        deck.append(contentsOf: spirits)  // Add duplicates

        // Add artifacts (rare)
        deck.append(contentsOf: createArtifacts())

        // Add starting curses (like weaknesses in Arkham Horror)
        let curses = createCurses()
        deck.append(curses[0])  // Add one curse to start with

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

    // MARK: - Market Cards (for purchase during game)

    static func createMarketCards() -> [Card] {
        return [
            // Common Resource cards (cost 2 faith, give 2 faith when played)
            Card(name: "Молитва", type: .resource, rarity: .common,
                 description: "Молитва богам. Дает 2 веры.",
                 cost: 2, abilities: [], balance: .light, realm: .prav),
            Card(name: "Молитва", type: .resource, rarity: .common,
                 description: "Молитва богам. Дает 2 веры.",
                 cost: 2, abilities: [], balance: .light, realm: .prav),

            // Uncommon Resource cards (cost 4, give 3 faith)
            Card(name: "Древний Ритуал", type: .resource, rarity: .uncommon,
                 description: "Древний ритуал призыва силы. Дает 3 веры.",
                 cost: 4, abilities: [], balance: .neutral, realm: .prav),

            // Common Attack cards (cost 3, deal 4 damage)
            Card(name: "Меч Света", type: .attack, rarity: .common,
                 description: "Светлый меч. Наносит 4 урона.",
                 power: 4, cost: 3, abilities: [], balance: .light, realm: .yav),
            Card(name: "Меч Света", type: .attack, rarity: .common,
                 description: "Светлый меч. Наносит 4 урона.",
                 power: 4, cost: 3, abilities: [], balance: .light, realm: .yav),

            // Uncommon Attack cards (cost 5, deal 6 damage)
            Card(name: "Огненный Шар", type: .attack, rarity: .uncommon,
                 description: "Мощный огненный шар. Наносит 6 урона.",
                 power: 6, cost: 5, abilities: [], damageType: .fire, balance: .neutral, realm: .yav),

            // Rare Attack cards (cost 7, deal 8 damage + effect)
            Card(name: "Божественный Удар", type: .attack, rarity: .rare,
                 description: "Удар божественной силы. Наносит 8 урона и восстанавливает 2 здоровья.",
                 power: 8, cost: 7, abilities: [
                     CardAbility(name: "Исцеление", description: "Восстанавливает 2 здоровья.", effect: .heal(amount: 2))
                 ], balance: .light, realm: .prav),

            // Common Defense cards (cost 2, block 3 damage)
            Card(name: "Щит Веры", type: .defense, rarity: .common,
                 description: "Защитный щит. Блокирует 3 урона.",
                 defense: 3, cost: 2, abilities: [], balance: .light, realm: .yav),
            Card(name: "Щит Веры", type: .defense, rarity: .common,
                 description: "Защитный щит. Блокирует 3 урона.",
                 defense: 3, cost: 2, abilities: [], balance: .light, realm: .yav),

            // Uncommon Defense cards (cost 4, block 5 damage)
            Card(name: "Каменная Кожа", type: .defense, rarity: .uncommon,
                 description: "Магическая защита. Блокирует 5 урона.",
                 defense: 5, cost: 4, abilities: [], balance: .neutral, realm: .yav),

            // Common Special cards (cost 3, draw 2 cards)
            Card(name: "Прозрение", type: .special, rarity: .common,
                 description: "Видение будущего. Берете 2 карты.",
                 cost: 3, abilities: [
                     CardAbility(name: "Карты", description: "Берете 2 карты.", effect: .drawCards(count: 2))
                 ], balance: .light, realm: .prav),

            // Uncommon Special cards (cost 5, heal 5 health)
            Card(name: "Великое Исцеление", type: .special, rarity: .uncommon,
                 description: "Мощное целебное заклинание. Восстанавливает 5 здоровья.",
                 cost: 5, abilities: [
                     CardAbility(name: "Исцеление", description: "Восстанавливает 5 здоровья.", effect: .heal(amount: 5))
                 ], balance: .light, realm: .prav),

            // Rare Special cards (cost 6, powerful effects)
            Card(name: "Перерождение", type: .special, rarity: .rare,
                 description: "Древнее заклинание перерождения. Восстанавливает 7 здоровья и дает 2 веры.",
                 cost: 6, abilities: [
                     CardAbility(name: "Перерождение", description: "Восстанавливает 7 здоровья.", effect: .heal(amount: 7)),
                     CardAbility(name: "Сила", description: "Дает 2 веры.", effect: .gainFaith(amount: 2))
                 ], balance: .light, realm: .prav),

            // Legendary cards (cost 10, extremely powerful)
            Card(name: "Дар Богов", type: .special, rarity: .legendary,
                 description: "Величайший дар от богов. Берете 3 карты, восстанавливаете 5 здоровья, получаете 3 веры.",
                 cost: 10, abilities: [
                     CardAbility(name: "Дар", description: "Берете 3 карты.", effect: .drawCards(count: 3)),
                     CardAbility(name: "Исцеление", description: "Восстанавливаете 5 здоровья.", effect: .heal(amount: 5)),
                     CardAbility(name: "Сила", description: "Получаете 3 веры.", effect: .gainFaith(amount: 3))
                 ], balance: .light, realm: .prav)
        ]
    }
}

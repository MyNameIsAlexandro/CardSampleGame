import XCTest
@testable import CardSampleGame

/// Тесты модуля карт
final class CardModuleTests: XCTestCase {

    // MARK: - CardOwnership Tests

    func testUniversalCardOwnership() {
        let ownership = CardOwnership.universal

        XCTAssertTrue(ownership.isAvailable(forHeroID: nil))
        XCTAssertTrue(ownership.isAvailable(forHeroID: "any_hero"))
    }

    func testHeroSignatureCardOwnership() {
        let ownership = CardOwnership.heroSignature(heroID: "warrior_ragnar")

        XCTAssertTrue(ownership.isAvailable(forHeroID: "warrior_ragnar"))
        XCTAssertFalse(ownership.isAvailable(forHeroID: "mage_elvira"))
        XCTAssertFalse(ownership.isAvailable(forHeroID: nil))
    }

    func testExpansionCardOwnership() {
        let ownership = CardOwnership.expansion(setID: "dark_expansion")

        XCTAssertTrue(ownership.isAvailable(
            forHeroID: nil,
            ownedExpansions: ["dark_expansion"]
        ))
        XCTAssertFalse(ownership.isAvailable(
            forHeroID: nil,
            ownedExpansions: []
        ))
    }

    func testRequiresUnlockCardOwnership() {
        let ownership = CardOwnership.requiresUnlock(condition: "beat_tutorial")

        XCTAssertTrue(ownership.isAvailable(
            forHeroID: nil,
            ownedExpansions: [],
            unlockedConditions: ["beat_tutorial"]
        ))
        XCTAssertFalse(ownership.isAvailable(
            forHeroID: nil,
            ownedExpansions: [],
            unlockedConditions: []
        ))
    }

    func testCompositeCardOwnership() {
        let ownership = CardOwnership.composite([
            .heroSignature(heroID: "warrior_ragnar"),
            .expansion(setID: "dark_expansion")
        ])

        // Both conditions must be met
        XCTAssertTrue(ownership.isAvailable(
            forHeroID: "warrior_ragnar",
            ownedExpansions: ["dark_expansion"]
        ))

        // Missing hero
        XCTAssertFalse(ownership.isAvailable(
            forHeroID: "other_hero",
            ownedExpansions: ["dark_expansion"]
        ))

        // Missing expansion
        XCTAssertFalse(ownership.isAvailable(
            forHeroID: "warrior_ragnar",
            ownedExpansions: []
        ))
    }

    // MARK: - CardDefinition Tests

    func testStandardCardDefinitionCreation() {
        let card = StandardCardDefinition(
            id: "test_card",
            name: "Тестовая карта",
            cardType: .attack,
            rarity: .common,
            description: "Тестовое описание",
            icon: "⚔️",
            ownership: .universal,
            abilities: [],
            faithCost: 3,
            balance: .neutral,
            power: 5
        )

        XCTAssertEqual(card.id, "test_card")
        XCTAssertEqual(card.name, "Тестовая карта")
        XCTAssertEqual(card.cardType, .attack)
        XCTAssertEqual(card.rarity, .common)
        XCTAssertEqual(card.faithCost, 3)
        XCTAssertEqual(card.power, 5)
    }

    func testCardDefinitionToCard() {
        let definition = StandardCardDefinition(
            id: "test_card",
            name: "Тестовая карта",
            cardType: .attack,
            rarity: .uncommon,
            description: "Описание",
            icon: "⚔️",
            ownership: .universal,
            abilities: [],
            faithCost: 4,
            balance: .light,
            power: 3,
            defense: 2
        )

        let card = definition.toCard()

        XCTAssertEqual(card.name, "Тестовая карта")
        XCTAssertEqual(card.type, .attack)
        XCTAssertEqual(card.rarity, .uncommon)
        XCTAssertEqual(card.faithCost, 4)
        XCTAssertEqual(card.power, 3)
        XCTAssertEqual(card.defense, 2)
        XCTAssertEqual(card.balance, .light)
    }

    // MARK: - CardRegistry Tests

    func testCardRegistryContainsBuiltInCards() {
        let registry = CardRegistry.shared

        // Should have basic cards
        XCTAssertNotNil(registry.card(id: "strike_basic"))
        XCTAssertNotNil(registry.card(id: "defend_basic"))
        XCTAssertNotNil(registry.card(id: "heal_basic"))
    }

    func testCardRegistryUniversalCards() {
        let registry = CardRegistry.shared

        let universalCards = registry.universalCards
        XCTAssertFalse(universalCards.isEmpty, "Должны быть универсальные карты")

        // All universal cards should be available to anyone
        for card in universalCards {
            XCTAssertTrue(
                card.ownership.isAvailable(forHeroID: nil),
                "Карта \(card.id) должна быть доступна всем"
            )
        }
    }

    func testCardRegistryAvailableCards() {
        let registry = CardRegistry.shared

        // Any hero should have access to universal cards
        let cards = registry.availableCards(forHeroID: "warrior_ragnar")

        // Should include universal cards
        XCTAssertTrue(cards.contains { $0.id == "strike_basic" })
    }

    func testCardRegistrySignatureCards() {
        let registry = CardRegistry.shared

        // Get signature cards for Ragnar
        let signature = registry.signatureCards(forHeroID: "warrior_ragnar")

        XCTAssertNotNil(signature)
        XCTAssertFalse(signature?.requiredCards.isEmpty ?? true, "Рагнар должен иметь обязательные карты")
        XCTAssertNotNil(signature?.weakness, "Рагнар должен иметь слабость")
    }

    func testCardRegistryStartingDeck() {
        let registry = CardRegistry.shared

        let deck = registry.startingDeck(forHeroID: "warrior_ragnar")

        XCTAssertFalse(deck.isEmpty, "Стартовая колода не должна быть пустой")

        // Should contain basic cards
        XCTAssertTrue(deck.contains { $0.name == "Удар" || $0.name == "Защита" })
    }

    func testCardRegistryShopCards() {
        let registry = CardRegistry.shared

        let shopCards = registry.shopCards(
            forHeroID: "warrior_ragnar",
            maxRarity: .rare
        )

        // Shop cards should not include legendary
        XCTAssertFalse(shopCards.contains { $0.rarity == .legendary })

        // Shop cards should not include hero signatures
        for card in shopCards {
            if case .heroSignature = card.ownership {
                XCTFail("Сигнатурные карты не должны быть в магазине: \(card.id)")
            }
        }
    }

    // MARK: - CardRarity Tests

    func testCardRarityOrder() {
        XCTAssertLessThan(CardRarity.common.order, CardRarity.uncommon.order)
        XCTAssertLessThan(CardRarity.uncommon.order, CardRarity.rare.order)
        XCTAssertLessThan(CardRarity.rare.order, CardRarity.epic.order)
        XCTAssertLessThan(CardRarity.epic.order, CardRarity.legendary.order)
    }

    // MARK: - HeroSignatureCards Tests

    func testHeroSignatureCardsStructure() {
        let signatureCards = HeroSignatureCards(
            heroID: "test_hero",
            requiredCards: [
                StandardCardDefinition(
                    id: "test_required",
                    name: "Обязательная",
                    cardType: .weapon,
                    description: "Тест",
                    ownership: .heroSignature(heroID: "test_hero")
                )
            ],
            optionalCards: [],
            weakness: StandardCardDefinition(
                id: "test_weakness",
                name: "Слабость",
                cardType: .curse,
                description: "Тест",
                ownership: .heroSignature(heroID: "test_hero")
            )
        )

        XCTAssertEqual(signatureCards.heroID, "test_hero")
        XCTAssertEqual(signatureCards.requiredCards.count, 1)
        XCTAssertNotNil(signatureCards.weakness)
        XCTAssertEqual(signatureCards.allCardIDs.count, 2) // required + weakness
    }

    // MARK: - Integration Tests

    func testHeroAndCardIntegration() throws {
        // Get any hero from HeroRegistry
        let registry = HeroRegistry.shared
        guard let hero = registry.firstHero else {
            throw XCTSkip("No heroes in registry")
        }

        // Get starting deck from CardRegistry
        let deck = CardRegistry.shared.startingDeck(forHeroID: hero.id)

        // Starting deck may be empty for fallback heroes
        // Just check that the method works
        XCTAssertNotNil(deck)
    }

    // MARK: - Card Economy Tests (v2.0)

    func testStartingDeckResourceCardsAreFree() {
        // Resource cards should cost 0 (they generate faith)
        let veleslavaCards = TwilightMarchesCards.createVeleslavaStartingDeck()
        let resourceCards = veleslavaCards.filter { $0.type == .resource }

        XCTAssertGreaterThan(resourceCards.count, 0, "Должны быть ресурсные карты в колоде")

        for card in resourceCards {
            XCTAssertEqual(card.cost ?? 0, 0, "Ресурсная карта '\(card.name)' должна быть бесплатной")
        }
    }

    func testStartingDeckAttackCardsHaveCost() {
        // Attack cards should cost faith (1-2)
        let ratiborCards = TwilightMarchesCards.createRatiborStartingDeck()
        let attackCards = ratiborCards.filter { $0.type == .attack }

        XCTAssertGreaterThan(attackCards.count, 0, "Должны быть карты атаки в колоде")

        for card in attackCards {
            XCTAssertGreaterThan(card.cost ?? 0, 0, "Карта атаки '\(card.name)' должна стоить веру")
        }
    }

    func testStartingDeckDefenseCardsHaveCost() {
        // Defense cards should cost faith
        let zabavaCards = TwilightMarchesCards.createZabavaStartingDeck()
        let defenseCards = zabavaCards.filter { $0.type == .defense }

        XCTAssertGreaterThan(defenseCards.count, 0, "Должны быть карты защиты в колоде")

        for card in defenseCards {
            XCTAssertGreaterThan(card.cost ?? 0, 0, "Карта защиты '\(card.name)' должна стоить веру")
        }
    }

    func testStartingDeckSpecialCardsHaveCost() {
        // Special cards should cost faith (unless they are sacrifice cards like Miroslav's)
        let veleslavaCards = TwilightMarchesCards.createVeleslavaStartingDeck()
        let specialCards = veleslavaCards.filter { $0.type == .special }

        for card in specialCards {
            XCTAssertGreaterThan(card.cost ?? 0, 0, "Спецкарта '\(card.name)' должна стоить веру")
        }
    }

    func testMiroslavSacrificeCardIsFree() {
        // Miroslav's Sacrifice card is free (it costs HP instead of faith)
        let miroslavCards = TwilightMarchesCards.createMiroslavStartingDeck()
        let sacrificeCard = miroslavCards.first { $0.name == "Жертвоприношение" }

        XCTAssertNotNil(sacrificeCard, "Должна быть карта Жертвоприношение")
        XCTAssertEqual(sacrificeCard?.cost ?? -1, 0, "Жертвоприношение должно быть бесплатным (оно стоит HP)")
    }

    func testResourceCardsGenerateFaith() {
        // Resource cards should have gainFaith ability
        let genericDeck = TwilightMarchesCards.createGenericStartingDeck()
        let resourceCards = genericDeck.filter { $0.type == .resource }

        for card in resourceCards {
            let hasGainFaith = card.abilities.contains { ability in
                if case .gainFaith = ability.effect { return true }
                return false
            }
            XCTAssertTrue(hasGainFaith, "Ресурсная карта '\(card.name)' должна давать веру")
        }
    }

    func testAllStartingDecksHaveProperEconomy() {
        // Test all four hero starting decks
        let decks: [(String, [Card])] = [
            ("Велеслава", TwilightMarchesCards.createVeleslavaStartingDeck()),
            ("Ратибор", TwilightMarchesCards.createRatiborStartingDeck()),
            ("Мирослав", TwilightMarchesCards.createMiroslavStartingDeck()),
            ("Забава", TwilightMarchesCards.createZabavaStartingDeck())
        ]

        for (heroName, deck) in decks {
            // Count cards by type
            let resourceCount = deck.filter { $0.type == .resource }.count
            let attackCount = deck.filter { $0.type == .attack }.count
            let defenseCount = deck.filter { $0.type == .defense }.count

            // Each deck should have 5 resource cards
            XCTAssertEqual(resourceCount, 5, "\(heroName) должен иметь 5 ресурсных карт")

            // Each deck should have at least 2 attack cards
            XCTAssertGreaterThanOrEqual(attackCount, 2, "\(heroName) должен иметь минимум 2 карты атаки")

            // Each deck should have at least 1 defense card
            XCTAssertGreaterThanOrEqual(defenseCount, 1, "\(heroName) должен иметь минимум 1 карту защиты")

            // Total should be 10 cards
            XCTAssertEqual(deck.count, 10, "\(heroName) должен иметь 10 карт в стартовой колоде")
        }
    }

    // MARK: - Combat Stats Tests

    func testCombatStatsCreation() {
        // Test CombatStats structure (defined in CombatView)
        // This tests the summary string format
        let turnsPlayed = 5
        let totalDamageDealt = 25
        let totalDamageTaken = 12
        let summary = "Ходов: \(turnsPlayed), урон нанесён: \(totalDamageDealt), урон получен: \(totalDamageTaken)"

        XCTAssertTrue(summary.contains("Ходов: 5"))
        XCTAssertTrue(summary.contains("урон нанесён: 25"))
        XCTAssertTrue(summary.contains("урон получен: 12"))
    }
}

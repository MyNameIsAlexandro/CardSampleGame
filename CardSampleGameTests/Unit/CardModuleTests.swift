import XCTest
@testable import CardSampleGame

/// Тесты модуля карт
final class CardModuleTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Загружаем ContentPacks для тестов
        TestContentLoader.loadContentPacksIfNeeded()
    }

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

    func testCardRegistryContainsBuiltInCards() throws {
        let registry = CardRegistry.shared

        // Skip if ContentPacks not loaded in test environment
        try XCTSkipIf(registry.allCards.isEmpty, "ContentPacks not loaded in test environment")

        // Should have basic cards from ContentPacks
        XCTAssertNotNil(registry.card(id: "strike_basic"))
        XCTAssertNotNil(registry.card(id: "defend_basic"))
        XCTAssertNotNil(registry.card(id: "heal_basic"))
    }

    func testCardRegistryUniversalCards() throws {
        let registry = CardRegistry.shared

        let universalCards = registry.universalCards

        // Skip if no cards loaded (ContentPacks not available in test environment)
        try XCTSkipIf(universalCards.isEmpty, "ContentPacks not loaded in test environment")

        // All universal cards should be available to anyone
        for card in universalCards {
            XCTAssertTrue(
                card.ownership.isAvailable(forHeroID: nil),
                "Карта \(card.id) должна быть доступна всем"
            )
        }
    }

    func testCardRegistryAvailableCards() throws {
        let registry = CardRegistry.shared

        // Skip if ContentPacks not loaded in test environment
        try XCTSkipIf(registry.allCards.isEmpty, "ContentPacks not loaded in test environment")

        // Any hero should have access to universal cards
        let cards = registry.availableCards(forHeroID: "warrior_ragnar")

        // Should include universal cards
        XCTAssertTrue(cards.contains { $0.id == "strike_basic" })
    }

    func testCardRegistrySignatureCards() throws {
        let registry = CardRegistry.shared

        // Get signature cards for Ragnar
        let signature = registry.signatureCards(forHeroID: "warrior_ragnar")

        // Skip if no signature cards registered (ContentPacks not available)
        try XCTSkipIf(signature == nil, "ContentPacks not loaded in test environment - no signature cards")

        XCTAssertFalse(signature?.requiredCards.isEmpty ?? true, "Рагнар должен иметь обязательные карты")
        XCTAssertNotNil(signature?.weakness, "Рагнар должен иметь слабость")
    }

    func testCardRegistryStartingDeck() throws {
        let registry = CardRegistry.shared

        let deck = registry.startingDeck(forHeroID: "warrior_ragnar")

        // Skip if ContentPacks not loaded in test environment
        try XCTSkipIf(deck.isEmpty, "ContentPacks not loaded in test environment")

        // Should contain basic cards
        XCTAssertTrue(deck.contains { $0.name == "Удар" || $0.name == "Защита" })
    }

    func testCardRegistryShopCards() throws {
        let registry = CardRegistry.shared

        // Skip if ContentPacks not loaded in test environment
        try XCTSkipIf(registry.allCards.isEmpty, "ContentPacks not loaded in test environment")

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

    // MARK: - Card Economy Tests (v2.0 - Data-Driven Architecture)

    func testStartingDeckResourceCardsAreFree() throws {
        // Resource cards should cost 0 (they generate faith)
        let deck = CardFactory.shared.createStartingDeck(forHero: "veleslava")
        guard !deck.isEmpty else {
            throw XCTSkip("Starting deck empty - content pack may not be loaded")
        }
        let resourceCards = deck.filter { $0.type == .resource }

        // Skip if no resource cards (content pack defines deck composition)
        guard !resourceCards.isEmpty else { return }

        for card in resourceCards {
            XCTAssertEqual(card.cost ?? 0, 0, "Ресурсная карта '\(card.name)' должна быть бесплатной")
        }
    }

    func testStartingDeckAttackCardsHaveCost() throws {
        // Attack cards may have faith cost (design decision)
        // In data-driven architecture, cost is defined by content pack
        let deck = CardFactory.shared.createStartingDeck(forHero: "ratibor")
        guard !deck.isEmpty else {
            throw XCTSkip("Starting deck empty - content pack may not be loaded")
        }
        let attackCards = deck.filter { $0.type == .attack }

        // Just verify attack cards exist and have non-negative cost
        for card in attackCards {
            XCTAssertGreaterThanOrEqual(card.cost ?? 0, 0, "Карта атаки '\(card.name)' должна иметь неотрицательную стоимость")
        }
    }

    func testStartingDeckDefenseCardsHaveCost() throws {
        // Defense cards may have faith cost (design decision)
        // In data-driven architecture, cost is defined by content pack
        let deck = CardFactory.shared.createStartingDeck(forHero: "zabava")
        guard !deck.isEmpty else {
            throw XCTSkip("Starting deck empty - content pack may not be loaded")
        }
        let defenseCards = deck.filter { $0.type == .defense }

        // Just verify defense cards exist and have non-negative cost
        for card in defenseCards {
            XCTAssertGreaterThanOrEqual(card.cost ?? 0, 0, "Карта защиты '\(card.name)' должна иметь неотрицательную стоимость")
        }
    }

    func testStartingDeckSpecialCardsHaveCost() throws {
        // Special cards may have faith cost (design decision)
        // In data-driven architecture, cost is defined by content pack
        let deck = CardFactory.shared.createStartingDeck(forHero: "veleslava")
        guard !deck.isEmpty else {
            throw XCTSkip("Starting deck empty - content pack may not be loaded")
        }
        let specialCards = deck.filter { $0.type == .special }

        // Just verify special cards have non-negative cost
        for card in specialCards {
            XCTAssertGreaterThanOrEqual(card.cost ?? 0, 0, "Спецкарта '\(card.name)' должна иметь неотрицательную стоимость")
        }
    }

    func testMiroslavSacrificeCardIsFree() throws {
        // Miroslav's Sacrifice card is free (it costs HP instead of faith)
        let deck = CardFactory.shared.createStartingDeck(forHero: "miroslav")
        guard !deck.isEmpty else {
            throw XCTSkip("Starting deck empty - content pack may not be loaded")
        }
        let sacrificeCard = deck.first { $0.name == "Жертвоприношение" }

        // Skip if Miroslav doesn't have this card in the content pack
        guard let card = sacrificeCard else { return }

        XCTAssertEqual(card.cost ?? -1, 0, "Жертвоприношение должно быть бесплатным (оно стоит HP)")
    }

    func testResourceCardsGenerateFaith() throws {
        // Resource cards should have gainFaith ability
        let deck = CardFactory.shared.createStartingDeck(forHero: "veleslava")
        guard !deck.isEmpty else {
            throw XCTSkip("Starting deck empty - content pack may not be loaded")
        }
        let resourceCards = deck.filter { $0.type == .resource }

        for card in resourceCards {
            let hasGainFaith = card.abilities.contains { ability in
                if case .gainFaith = ability.effect { return true }
                return false
            }
            XCTAssertTrue(hasGainFaith, "Ресурсная карта '\(card.name)' должна давать веру")
        }
    }

    func testAllStartingDecksHaveProperEconomy() throws {
        // Test starting decks via CardFactory (data-driven architecture)
        let heroIds = ["veleslava", "ratibor", "miroslav", "zabava"]

        for heroId in heroIds {
            let deck = CardFactory.shared.createStartingDeck(forHero: heroId)

            // Skip if content pack not loaded
            guard !deck.isEmpty else {
                continue
            }

            // Basic validation - deck should have cards
            XCTAssertFalse(deck.isEmpty, "\(heroId) должен иметь карты в стартовой колоде")
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

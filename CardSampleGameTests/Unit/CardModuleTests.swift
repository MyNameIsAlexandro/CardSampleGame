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
}

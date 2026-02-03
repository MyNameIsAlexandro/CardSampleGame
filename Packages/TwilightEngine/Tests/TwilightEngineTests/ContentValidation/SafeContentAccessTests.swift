import XCTest
@testable import TwilightEngine

/// Comprehensive tests for SafeContentAccess
/// Tests all content types, validation, and error handling
final class SafeContentAccessTests: XCTestCase {

    var registry: ContentRegistry!
    var safeAccess: SafeContentAccess!

    override func setUp() {
        super.setUp()
        registry = ContentRegistry()
        safeAccess = SafeContentAccess(registry: registry)
    }

    override func tearDown() {
        registry.resetForTesting()
        safeAccess = nil
        registry = nil
        super.tearDown()
    }

    // MARK: - Hero Access Tests

    func testGetHeroReturnsErrorForMissingHero() {
        // When
        let result = safeAccess.getHero(id: "nonexistent-hero")

        // Then
        switch result {
        case .success:
            XCTFail("Should return error for missing hero")
        case .failure(let error):
            if case .notFound(let type, let id) = error {
                XCTAssertEqual(type, "Hero")
                XCTAssertEqual(id, "nonexistent-hero")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testGetHeroReturnsSuccessForExistingHero() {
        // Given
        let hero = createMockHero(id: "test-hero")
        registry.registerMockContent(heroes: ["test-hero": hero])

        // When
        let result = safeAccess.getHero(id: "test-hero")

        // Then
        switch result {
        case .success(let foundHero):
            XCTAssertEqual(foundHero.id, "test-hero")
        case .failure(let error):
            XCTFail("Should succeed: \(error)")
        }
    }

    // MARK: - Starting Deck Tests

    func testGetStartingDeckReturnsErrorForMissingHero() {
        // When
        let result = safeAccess.getStartingDeck(forHero: "nonexistent-hero")

        // Then
        switch result {
        case .success:
            XCTFail("Should return error for missing hero")
        case .failure(let error):
            if case .notFound(let type, _) = error {
                XCTAssertEqual(type, "Hero")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testGetStartingDeckReturnsErrorForIncompleteDeck() {
        // Given - Hero with cards that don't exist
        let hero = createMockHero(id: "test-hero", startingDeckCardIDs: ["card-1", "card-2", "card-3"])
        registry.registerMockContent(heroes: ["test-hero": hero])
        // Note: cards are NOT registered

        // When
        let result = safeAccess.getStartingDeck(forHero: "test-hero")

        // Then
        switch result {
        case .success:
            XCTFail("Should return error for incomplete deck")
        case .failure(let error):
            if case .incompleteContent(let type, let id, let missing) = error {
                XCTAssertEqual(type, "StartingDeck")
                XCTAssertEqual(id, "test-hero")
                XCTAssertEqual(Set(missing), Set(["card-1", "card-2", "card-3"]))
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testGetStartingDeckReturnsSuccessForCompleteDeck() {
        // Given
        let hero = createMockHero(id: "test-hero", startingDeckCardIDs: ["card-1", "card-2"])
        let card1 = createMockCard(id: "card-1")
        let card2 = createMockCard(id: "card-2")

        registry.registerMockContent(
            heroes: ["test-hero": hero],
            cards: ["card-1": card1, "card-2": card2]
        )

        // When
        let result = safeAccess.getStartingDeck(forHero: "test-hero")

        // Then
        switch result {
        case .success(let deck):
            XCTAssertEqual(deck.count, 2)
            XCTAssertTrue(deck.contains { $0.id == "card-1" })
            XCTAssertTrue(deck.contains { $0.id == "card-2" })
        case .failure(let error):
            XCTFail("Should succeed: \(error)")
        }
    }

    // MARK: - Enemy Access Tests

    func testGetEnemyReturnsErrorForMissing() {
        // When
        let result = safeAccess.getEnemy(id: "nonexistent-enemy")

        // Then
        switch result {
        case .success:
            XCTFail("Should return error")
        case .failure(let error):
            if case .notFound(let type, let id) = error {
                XCTAssertEqual(type, "Enemy")
                XCTAssertEqual(id, "nonexistent-enemy")
            } else {
                XCTFail("Wrong error type")
            }
        }
    }

    func testGetEnemyReturnsSuccessForExisting() {
        // Given
        let enemy = createMockEnemy(id: "test-enemy")
        registry.registerMockContent(enemies: ["test-enemy": enemy])

        // When
        let result = safeAccess.getEnemy(id: "test-enemy")

        // Then
        switch result {
        case .success(let foundEnemy):
            XCTAssertEqual(foundEnemy.id, "test-enemy")
        case .failure(let error):
            XCTFail("Should succeed: \(error)")
        }
    }

    // MARK: - Card Access Tests

    func testGetCardReturnsErrorForMissing() {
        // When
        let result = safeAccess.getCard(id: "nonexistent-card")

        // Then
        switch result {
        case .success:
            XCTFail("Should return error")
        case .failure(let error):
            if case .notFound(let type, _) = error {
                XCTAssertEqual(type, "Card")
            } else {
                XCTFail("Wrong error type")
            }
        }
    }

    // MARK: - Event Access Tests

    func testGetEventReturnsErrorForMissing() {
        // When
        let result = safeAccess.getEvent(id: "nonexistent-event")

        // Then
        switch result {
        case .success:
            XCTFail("Should return error")
        case .failure(let error):
            if case .notFound(let type, _) = error {
                XCTAssertEqual(type, "Event")
            } else {
                XCTFail("Wrong error type")
            }
        }
    }

    // MARK: - Region Access Tests

    func testGetRegionReturnsErrorForMissing() {
        // When
        let result = safeAccess.getRegion(id: "nonexistent-region")

        // Then
        switch result {
        case .success:
            XCTFail("Should return error")
        case .failure(let error):
            if case .notFound(let type, _) = error {
                XCTAssertEqual(type, "Region")
            } else {
                XCTFail("Wrong error type")
            }
        }
    }

    // MARK: - Fate Cards Tests

    func testGetFateCardsReturnsErrorWhenEmpty() {
        // When
        let result = safeAccess.getFateCards(minimumCount: 1)

        // Then
        switch result {
        case .success:
            XCTFail("Should return error when no fate cards")
        case .failure(let error):
            if case .insufficientContent(let type, let required, let found) = error {
                XCTAssertEqual(type, "FateCards")
                XCTAssertEqual(required, 1)
                XCTAssertEqual(found, 0)
            } else {
                XCTFail("Wrong error type")
            }
        }
    }

    func testGetFateCardsReturnsSuccessWithEnoughCards() {
        // Given
        let fateCards = [
            createMockFateCard(id: "fate-1"),
            createMockFateCard(id: "fate-2"),
            createMockFateCard(id: "fate-3")
        ]
        var fateCardDict: [String: FateCard] = [:]
        for card in fateCards {
            fateCardDict[card.id] = card
        }
        registry.registerMockContent(fateCards: fateCardDict)

        // When
        let result = safeAccess.getFateCards(minimumCount: 2)

        // Then
        switch result {
        case .success(let cards):
            XCTAssertGreaterThanOrEqual(cards.count, 2)
        case .failure(let error):
            XCTFail("Should succeed: \(error)")
        }
    }

    // MARK: - Playable Heroes Tests

    func testGetPlayableHeroesExcludesIncompleteDeck() {
        // Given
        let heroWithDeck = createMockHero(id: "hero-complete", startingDeckCardIDs: ["card-1"])
        let heroWithoutDeck = createMockHero(id: "hero-incomplete", startingDeckCardIDs: ["missing-card"])
        let card1 = createMockCard(id: "card-1")

        registry.registerMockContent(
            heroes: ["hero-complete": heroWithDeck, "hero-incomplete": heroWithoutDeck],
            cards: ["card-1": card1]
        )

        // When
        let playable = safeAccess.getPlayableHeroes()

        // Then
        XCTAssertEqual(playable.count, 1)
        XCTAssertEqual(playable.first?.id, "hero-complete")
    }

    // MARK: - Gameplay Readiness Tests

    func testIsReadyForGameplayRequiresHeroes() {
        // Given - No heroes
        registry.registerMockContent()

        // When
        let result = safeAccess.isReadyForGameplay(requireHeroes: true)

        // Then
        switch result {
        case .success:
            XCTFail("Should fail without heroes")
        case .failure(let error):
            if case .insufficientContent(let type, _, _) = error {
                XCTAssertEqual(type, "Heroes")
            } else {
                XCTFail("Wrong error type")
            }
        }
    }

    func testIsReadyForGameplayRequiresFateCards() {
        // Given - Heroes but no fate cards
        let hero = createMockHero(id: "test-hero", startingDeckCardIDs: ["card-1"])
        let card = createMockCard(id: "card-1")
        registry.registerMockContent(
            heroes: ["test-hero": hero],
            cards: ["card-1": card]
        )

        // When
        let result = safeAccess.isReadyForGameplay(requireFateCards: true)

        // Then
        switch result {
        case .success:
            XCTFail("Should fail without fate cards")
        case .failure(let error):
            if case .insufficientContent(let type, _, _) = error {
                XCTAssertEqual(type, "FateCards")
            } else {
                XCTFail("Wrong error type")
            }
        }
    }

    func testIsReadyForGameplaySucceedsWithCompleteContent() {
        // Given
        let hero = createMockHero(id: "test-hero", startingDeckCardIDs: ["card-1"])
        let card = createMockCard(id: "card-1")
        let fateCard = createMockFateCard(id: "fate-1")

        registry.registerMockContent(
            heroes: ["test-hero": hero],
            cards: ["card-1": card],
            fateCards: ["fate-1": fateCard]
        )

        // When
        let result = safeAccess.isReadyForGameplay(
            requireHeroes: true,
            requireFateCards: true,
            requireEnemies: false
        )

        // Then
        switch result {
        case .success:
            break // Expected
        case .failure(let error):
            XCTFail("Should succeed: \(error)")
        }
    }

    // MARK: - Validation Tests

    func testValidationDetectsIncompleteDeck() {
        // Given - Hero with missing cards
        let hero = createMockHero(id: "test-hero", startingDeckCardIDs: ["missing-card"])
        registry.registerMockContent(heroes: ["test-hero": hero])

        // When
        let result = safeAccess.validateAllContent()

        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.message.contains("missing cards") })
    }

    func testValidationDetectsMissingFateCards() {
        // Given - No fate cards
        registry.registerMockContent()

        // When
        let result = safeAccess.validateAllContent()

        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.message.contains("fate cards") })
    }

    func testValidationDetectsInvalidEnemyHealth() {
        // Given - Enemy with zero health
        let badEnemy = EnemyDefinition(
            id: "bad-enemy",
            name: .inline(LocalizedString(en: "Bad", ru: "Плохой")),
            description: .inline(LocalizedString(en: "", ru: "")),
            health: 0,
            power: 5,
            defense: 0
        )
        registry.registerMockContent(enemies: ["bad-enemy": badEnemy])

        // When
        let result = safeAccess.validateAllContent()

        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.message.contains("non-positive health") })
    }

    func testValidationBrokenEventChain() {
        // Given - Event that triggers nonexistent event
        let event = createMockEvent(
            id: "test-event",
            triggerEventId: "nonexistent-trigger"
        )
        registry.registerMockContent(events: ["test-event": event])

        // When
        let result = safeAccess.validateAllContent()

        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains {
            $0.message.contains("non-existent event") || $0.message.contains("triggers")
        })
    }

    func testValidationPassesWithValidContent() {
        // Given - Complete valid content
        let hero = createMockHero(id: "test-hero", startingDeckCardIDs: ["card-1"])
        let card = createMockCard(id: "card-1")
        let fateCards = (1...10).map { createMockFateCard(id: "fate-\($0)") }
        var fateCardDict: [String: FateCard] = [:]
        for fc in fateCards {
            fateCardDict[fc.id] = fc
        }
        let region = createMockRegion(id: "test-region")

        registry.registerMockContent(
            regions: ["test-region": region],
            heroes: ["test-hero": hero],
            cards: ["card-1": card],
            fateCards: fateCardDict
        )

        // When
        let result = safeAccess.validateAllContent()

        // Then
        XCTAssertTrue(result.isValid, "Errors: \(result.errors.map { $0.message })")
    }

    func testContentSummaryIsPopulated() {
        // Given
        let hero = createMockHero(id: "test-hero")
        let card = createMockCard(id: "card-1")
        let enemy = createMockEnemy(id: "enemy-1")
        let region = createMockRegion(id: "region-1")
        let fateCard = createMockFateCard(id: "fate-1")

        registry.registerMockContent(
            regions: ["region-1": region],
            heroes: ["test-hero": hero],
            cards: ["card-1": card],
            enemies: ["enemy-1": enemy],
            fateCards: ["fate-1": fateCard]
        )

        // When
        let result = safeAccess.validateAllContent()

        // Then
        XCTAssertEqual(result.contentSummary.heroCount, 1)
        XCTAssertEqual(result.contentSummary.cardCount, 1)
        XCTAssertEqual(result.contentSummary.enemyCount, 1)
        XCTAssertEqual(result.contentSummary.regionCount, 1)
        XCTAssertEqual(result.contentSummary.fateCardCount, 1)
    }

    // MARK: - Mock Factories

    private func createMockHero(
        id: String,
        startingDeckCardIDs: [String] = []
    ) -> StandardHeroDefinition {
        let stats = HeroStats(
            health: 20,
            maxHealth: 20,
            strength: 3,
            dexterity: 3,
            constitution: 3,
            intelligence: 3,
            wisdom: 3,
            charisma: 3,
            faith: 10,
            maxFaith: 10,
            startingBalance: 0
        )

        let ability = HeroAbility(
            id: "test-ability",
            name: .inline(LocalizedString(en: "Test Ability", ru: "Тестовая Способность")),
            description: .inline(LocalizedString(en: "Test", ru: "Тест")),
            icon: "⚔️",
            type: .active,
            trigger: .manual,
            condition: nil,
            effects: [],
            cooldown: 0,
            cost: nil
        )

        return StandardHeroDefinition(
            id: id,
            heroClass: .warrior,
            name: .inline(LocalizedString(en: "Test Hero", ru: "Тестовый Герой")),
            description: .inline(LocalizedString(en: "Test", ru: "Тест")),
            icon: "🦸",
            baseStats: stats,
            specialAbility: ability,
            startingDeckCardIDs: startingDeckCardIDs
        )
    }

    private func createMockCard(id: String) -> StandardCardDefinition {
        StandardCardDefinition(
            id: id,
            name: .inline(LocalizedString(en: "Test Card", ru: "Тестовая Карта")),
            cardType: .attack,
            rarity: .common,
            description: .inline(LocalizedString(en: "Test", ru: "Тест"))
        )
    }

    private func createMockEnemy(id: String) -> EnemyDefinition {
        EnemyDefinition(
            id: id,
            name: .inline(LocalizedString(en: "Test Enemy", ru: "Тестовый Враг")),
            description: .inline(LocalizedString(en: "Test", ru: "Тест")),
            health: 10,
            power: 5,
            defense: 0
        )
    }

    private func createMockFateCard(id: String) -> FateCard {
        FateCard(
            id: id,
            modifier: 0,
            name: "Fate"
        )
    }

    private func createMockRegion(id: String) -> RegionDefinition {
        RegionDefinition(
            id: id,
            title: .inline(LocalizedString(en: "Test Region", ru: "Тестовый Регион")),
            description: .inline(LocalizedString(en: "Test", ru: "Тест")),
            regionType: "test",
            neighborIds: []
        )
    }

    private func createMockEvent(
        id: String,
        triggerEventId: String? = nil
    ) -> EventDefinition {
        var consequences = ChoiceConsequences()
        consequences.triggerEventId = triggerEventId

        let choice = ChoiceDefinition(
            id: "choice-1",
            label: .inline(LocalizedString(en: "Continue", ru: "Продолжить")),
            consequences: consequences
        )

        return EventDefinition(
            id: id,
            title: .inline(LocalizedString(en: "Test Event", ru: "Тестовое Событие")),
            body: .inline(LocalizedString(en: "Test", ru: "Тест")),
            eventKind: .inline,
            availability: .always,
            poolIds: [],
            choices: [choice]
        )
    }
}

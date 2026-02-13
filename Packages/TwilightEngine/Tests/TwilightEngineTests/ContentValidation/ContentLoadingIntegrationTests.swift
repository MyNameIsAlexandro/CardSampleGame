/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/ContentValidation/ContentLoadingIntegrationTests.swift
/// Назначение: Содержит реализацию файла ContentLoadingIntegrationTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@_spi(Testing) @testable import TwilightEngine

/// Integration tests for content loading with real pack validation
final class ContentLoadingIntegrationTests: XCTestCase {

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

    // MARK: - All Content Types Tests

    func testAllContentTypesHaveUniqueIds() {
        // Given - Mock content with various types
        let heroes = createMockHeroes(count: 5)
        let cards = createMockCards(count: 10)
        let enemies = createMockEnemies(count: 5)
        let regions = createMockRegions(count: 3)
        let fateCards = createMockFateCards(count: 15)

        registry.registerMockContent(
            regions: regions,
            heroes: heroes,
            cards: cards,
            enemies: enemies,
            fateCards: fateCards
        )

        // When
        let result = safeAccess.validateAllContent()

        // Then - All IDs should be unique within their type
        let duplicateErrors = result.errors.filter { $0.type == .duplicateId }
        XCTAssertTrue(duplicateErrors.isEmpty, "Should have no duplicate IDs: \(duplicateErrors)")
    }

    func testAllHeroesHaveCompleteDeck() {
        // Given - Heroes with valid cards
        let cards = createMockCards(count: 10)
        let cardIds = Array(cards.keys)

        var heroes: [String: StandardHeroDefinition] = [:]
        for i in 0..<3 {
            let heroId = "hero-\(i)"
            let deckCardIds = Array(cardIds.prefix(5)) // Each hero gets first 5 cards
            heroes[heroId] = createMockHero(id: heroId, startingDeckCardIDs: deckCardIds)
        }

        let fateCards = createMockFateCards(count: 15)

        registry.registerMockContent(
            heroes: heroes,
            cards: cards,
            fateCards: fateCards
        )

        // When
        let result = safeAccess.validateAllContent()

        // Then
        let deckErrors = result.errors.filter { $0.message.contains("starting deck") }
        XCTAssertTrue(deckErrors.isEmpty, "All heroes should have complete decks: \(deckErrors)")
    }

    func testAllEnemiesHaveValidStats() {
        // Given - Valid enemies
        var enemies: [String: EnemyDefinition] = [:]
        for i in 0..<5 {
            enemies["enemy-\(i)"] = EnemyDefinition(
                id: "enemy-\(i)",
                name: .inline(LocalizedString(en: "Enemy \(i)", ru: "Враг \(i)")),
                description: .inline(LocalizedString(en: "Test", ru: "Тест")),
                health: 10 + i * 5,
                power: 5 + i,
                defense: i,
                difficulty: min(i + 1, 10)
            )
        }

        let fateCards = createMockFateCards(count: 15)

        registry.registerMockContent(
            enemies: enemies,
            fateCards: fateCards
        )

        // When
        let result = safeAccess.validateAllContent()

        // Then - No health errors
        let healthErrors = result.errors.filter { $0.message.contains("health") }
        XCTAssertTrue(healthErrors.isEmpty, "All enemies should have valid health: \(healthErrors)")
    }

    func testAllRegionNeighborsExist() {
        // Given - Regions with valid neighbors
        let region1 = createMockRegion(id: "region-1", neighborIds: ["region-2", "region-3"])
        let region2 = createMockRegion(id: "region-2", neighborIds: ["region-1", "region-3"])
        let region3 = createMockRegion(id: "region-3", neighborIds: ["region-1", "region-2"])

        let fateCards = createMockFateCards(count: 15)

        registry.registerMockContent(
            regions: [
                "region-1": region1,
                "region-2": region2,
                "region-3": region3
            ],
            fateCards: fateCards
        )

        // When
        let result = safeAccess.validateAllContent()

        // Then - No neighbor reference errors
        let neighborErrors = result.errors.filter { $0.message.contains("neighbor") }
        XCTAssertTrue(neighborErrors.isEmpty, "All neighbor references should be valid: \(neighborErrors)")
    }

    func testEventChainIntegrity() {
        // Given - Events with valid chain
        let event1 = createMockEvent(id: "event-1", triggerEventId: "event-2")
        let event2 = createMockEvent(id: "event-2", triggerEventId: "event-3")
        let event3 = createMockEvent(id: "event-3", triggerEventId: nil) // End of chain

        let fateCards = createMockFateCards(count: 15)

        registry.registerMockContent(
            events: [
                "event-1": event1,
                "event-2": event2,
                "event-3": event3
            ],
            fateCards: fateCards
        )

        // When
        let result = safeAccess.validateAllContent()

        // Then - No chain errors
        let chainErrors = result.errors.filter {
            $0.message.contains("triggers") || $0.message.contains("non-existent event")
        }
        XCTAssertTrue(chainErrors.isEmpty, "Event chain should be valid: \(chainErrors)")
    }

    // MARK: - Edge Cases

    func testEmptyContentIsInvalid() {
        // Given - Empty registry

        // When
        let result = safeAccess.validateAllContent()

        // Then - Should have errors (at least missing fate cards)
        XCTAssertFalse(result.isValid, "Empty content should not be valid")
        XCTAssertTrue(result.errors.contains { $0.message.contains("fate cards") })
    }

    func testPartialContentDetected() {
        // Given - Hero with some missing cards
        let hero = createMockHero(id: "hero-1", startingDeckCardIDs: ["card-1", "card-2", "missing-card"])
        let card1 = createMockCard(id: "card-1")
        let card2 = createMockCard(id: "card-2")
        // Note: "missing-card" is NOT created

        let fateCards = createMockFateCards(count: 15)

        registry.registerMockContent(
            heroes: ["hero-1": hero],
            cards: ["card-1": card1, "card-2": card2],
            fateCards: fateCards
        )

        // When
        let result = safeAccess.validateAllContent()

        // Then
        XCTAssertFalse(result.isValid, "Should detect missing card")
        XCTAssertTrue(result.errors.contains { $0.message.contains("missing") })
    }

    func testBrokenRegionReference() {
        // Given - Region with invalid neighbor
        let region = createMockRegion(id: "region-1", neighborIds: ["nonexistent-region"])
        let fateCards = createMockFateCards(count: 15)

        registry.registerMockContent(
            regions: ["region-1": region],
            fateCards: fateCards
        )

        // When
        let result = safeAccess.validateAllContent()

        // Then
        XCTAssertFalse(result.isValid, "Should detect broken reference")
        XCTAssertTrue(result.errors.contains { $0.type == .brokenReference })
    }

    func testInvalidEnemyWithZeroHealth() {
        // Given - Enemy with zero health
        let enemy = EnemyDefinition(
            id: "bad-enemy",
            name: .inline(LocalizedString(en: "Bad", ru: "Плохой")),
            description: .inline(LocalizedString(en: "Test", ru: "Тест")),
            health: 0, // Invalid!
            power: 5,
            defense: 0
        )
        let fateCards = createMockFateCards(count: 15)

        registry.registerMockContent(
            enemies: ["bad-enemy": enemy],
            fateCards: fateCards
        )

        // When
        let result = safeAccess.validateAllContent()

        // Then
        XCTAssertFalse(result.isValid, "Should detect invalid health")
        XCTAssertTrue(result.errors.contains { $0.message.contains("non-positive health") })
    }

    func testMinimumFateCardsWarning() {
        // Given - Only 5 fate cards (below recommended 10)
        let fateCards = createMockFateCards(count: 5)
        let hero = createMockHero(id: "hero-1", startingDeckCardIDs: [])

        registry.registerMockContent(
            heroes: ["hero-1": hero],
            fateCards: fateCards
        )

        // When
        let result = safeAccess.validateAllContent()

        // Then - Should produce warning but still be valid
        XCTAssertTrue(result.hasWarnings, "Should warn about low fate card count")
        XCTAssertTrue(result.warnings.contains { $0.message.contains("fate cards") })
    }

    // MARK: - Content Summary Tests

    func testContentSummaryAccurate() {
        // Given
        let heroes = createMockHeroes(count: 3)
        let cards = createMockCards(count: 10)
        let enemies = createMockEnemies(count: 5)
        let regions = createMockRegions(count: 4)
        let fateCards = createMockFateCards(count: 15)

        registry.registerMockContent(
            regions: regions,
            heroes: heroes,
            cards: cards,
            enemies: enemies,
            fateCards: fateCards
        )

        // When
        let result = safeAccess.validateAllContent()

        // Then
        XCTAssertEqual(result.contentSummary.heroCount, 3)
        XCTAssertEqual(result.contentSummary.cardCount, 10)
        XCTAssertEqual(result.contentSummary.enemyCount, 5)
        XCTAssertEqual(result.contentSummary.regionCount, 4)
        XCTAssertEqual(result.contentSummary.fateCardCount, 15)
    }

    // MARK: - Mock Factories

    private func createMockHeroes(count: Int) -> [String: StandardHeroDefinition] {
        var heroes: [String: StandardHeroDefinition] = [:]
        for i in 0..<count {
            let id = "hero-\(i)"
            heroes[id] = createMockHero(id: id, startingDeckCardIDs: [])
        }
        return heroes
    }

    private func createMockCards(count: Int) -> [String: StandardCardDefinition] {
        var cards: [String: StandardCardDefinition] = [:]
        for i in 0..<count {
            let id = "card-\(i)"
            cards[id] = createMockCard(id: id)
        }
        return cards
    }

    private func createMockEnemies(count: Int) -> [String: EnemyDefinition] {
        var enemies: [String: EnemyDefinition] = [:]
        for i in 0..<count {
            let id = "enemy-\(i)"
            enemies[id] = EnemyDefinition(
                id: id,
                name: .inline(LocalizedString(en: "Enemy \(i)", ru: "Враг \(i)")),
                description: .inline(LocalizedString(en: "Test", ru: "Тест")),
                health: 10 + i * 5,
                power: 5 + i,
                defense: i
            )
        }
        return enemies
    }

    private func createMockRegions(count: Int) -> [String: RegionDefinition] {
        var regions: [String: RegionDefinition] = [:]
        for i in 0..<count {
            let id = "region-\(i)"
            regions[id] = createMockRegion(id: id, neighborIds: [])
        }
        return regions
    }

    private func createMockFateCards(count: Int) -> [String: FateCard] {
        var cards: [String: FateCard] = [:]
        for i in 0..<count {
            let id = "fate-\(i)"
            cards[id] = FateCard(id: id, modifier: i % 5 - 2, name: "Fate \(i)")
        }
        return cards
    }

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
            id: "\(id)-ability",
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
            name: .inline(LocalizedString(en: "Test Hero \(id)", ru: "Тестовый Герой \(id)")),
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
            name: .inline(LocalizedString(en: "Test Card \(id)", ru: "Тестовая Карта \(id)")),
            cardType: .attack,
            rarity: .common,
            description: .inline(LocalizedString(en: "Test", ru: "Тест"))
        )
    }

    private func createMockRegion(id: String, neighborIds: [String] = []) -> RegionDefinition {
        RegionDefinition(
            id: id,
            title: .inline(LocalizedString(en: "Test Region \(id)", ru: "Тестовый Регион \(id)")),
            description: .inline(LocalizedString(en: "Test", ru: "Тест")),
            regionType: "test",
            neighborIds: neighborIds
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
            title: .inline(LocalizedString(en: "Test Event \(id)", ru: "Тестовое Событие \(id)")),
            body: .inline(LocalizedString(en: "Test", ru: "Тест")),
            eventKind: .inline,
            availability: .always,
            poolIds: [],
            choices: [choice]
        )
    }
}

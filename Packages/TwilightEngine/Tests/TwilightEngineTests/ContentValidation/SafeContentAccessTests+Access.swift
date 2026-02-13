/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/ContentValidation/SafeContentAccessTests+Access.swift
/// Назначение: Содержит реализацию файла SafeContentAccessTests+Access.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@_spi(Testing) @testable import TwilightEngine

extension SafeContentAccessTests {
    // MARK: - Hero Access Tests

    func testGetHeroReturnsErrorForMissingHero() {
        let result = safeAccess.getHero(id: "nonexistent-hero")

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
        let hero = createMockHero(id: "test-hero")
        registry.registerMockContent(heroes: ["test-hero": hero])

        let result = safeAccess.getHero(id: "test-hero")

        switch result {
        case .success(let foundHero):
            XCTAssertEqual(foundHero.id, "test-hero")
        case .failure(let error):
            XCTFail("Should succeed: \(error)")
        }
    }

    // MARK: - Starting Deck Tests

    func testGetStartingDeckReturnsErrorForMissingHero() {
        let result = safeAccess.getStartingDeck(forHero: "nonexistent-hero")

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
        let hero = createMockHero(id: "test-hero", startingDeckCardIDs: ["card-1", "card-2", "card-3"])
        registry.registerMockContent(heroes: ["test-hero": hero])

        let result = safeAccess.getStartingDeck(forHero: "test-hero")

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
        let hero = createMockHero(id: "test-hero", startingDeckCardIDs: ["card-1", "card-2"])
        let card1 = createMockCard(id: "card-1")
        let card2 = createMockCard(id: "card-2")

        registry.registerMockContent(
            heroes: ["test-hero": hero],
            cards: ["card-1": card1, "card-2": card2]
        )

        let result = safeAccess.getStartingDeck(forHero: "test-hero")

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
        let result = safeAccess.getEnemy(id: "nonexistent-enemy")

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
        let enemy = createMockEnemy(id: "test-enemy")
        registry.registerMockContent(enemies: ["test-enemy": enemy])

        let result = safeAccess.getEnemy(id: "test-enemy")

        switch result {
        case .success(let foundEnemy):
            XCTAssertEqual(foundEnemy.id, "test-enemy")
        case .failure(let error):
            XCTFail("Should succeed: \(error)")
        }
    }

    // MARK: - Card Access Tests

    func testGetCardReturnsErrorForMissing() {
        let result = safeAccess.getCard(id: "nonexistent-card")

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
        let result = safeAccess.getEvent(id: "nonexistent-event")

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
        let result = safeAccess.getRegion(id: "nonexistent-region")

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
        let result = safeAccess.getFateCards(minimumCount: 1)

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

        let result = safeAccess.getFateCards(minimumCount: 2)

        switch result {
        case .success(let cards):
            XCTAssertGreaterThanOrEqual(cards.count, 2)
        case .failure(let error):
            XCTFail("Should succeed: \(error)")
        }
    }

    // MARK: - Playable Heroes Tests

    func testGetPlayableHeroesExcludesIncompleteDeck() {
        let heroWithDeck = createMockHero(id: "hero-complete", startingDeckCardIDs: ["card-1"])
        let heroWithoutDeck = createMockHero(id: "hero-incomplete", startingDeckCardIDs: ["missing-card"])
        let card1 = createMockCard(id: "card-1")

        registry.registerMockContent(
            heroes: ["hero-complete": heroWithDeck, "hero-incomplete": heroWithoutDeck],
            cards: ["card-1": card1]
        )

        let playable = safeAccess.getPlayableHeroes()

        XCTAssertEqual(playable.count, 1)
        XCTAssertEqual(playable.first?.id, "hero-complete")
    }
}

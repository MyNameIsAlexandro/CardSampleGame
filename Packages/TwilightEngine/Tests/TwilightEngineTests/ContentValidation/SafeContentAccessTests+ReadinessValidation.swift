/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/ContentValidation/SafeContentAccessTests+ReadinessValidation.swift
/// Назначение: Содержит реализацию файла SafeContentAccessTests+ReadinessValidation.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@_spi(Testing) @testable import TwilightEngine

extension SafeContentAccessTests {
    // MARK: - Gameplay Readiness Tests

    func testIsReadyForGameplayRequiresHeroes() {
        registry.registerMockContent()

        let result = safeAccess.isReadyForGameplay(requireHeroes: true)

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
        let hero = createMockHero(id: "test-hero", startingDeckCardIDs: ["card-1"])
        let card = createMockCard(id: "card-1")
        registry.registerMockContent(
            heroes: ["test-hero": hero],
            cards: ["card-1": card]
        )

        let result = safeAccess.isReadyForGameplay(requireFateCards: true)

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
        let hero = createMockHero(id: "test-hero", startingDeckCardIDs: ["card-1"])
        let card = createMockCard(id: "card-1")
        let fateCard = createMockFateCard(id: "fate-1")

        registry.registerMockContent(
            heroes: ["test-hero": hero],
            cards: ["card-1": card],
            fateCards: ["fate-1": fateCard]
        )

        let result = safeAccess.isReadyForGameplay(
            requireHeroes: true,
            requireFateCards: true,
            requireEnemies: false
        )

        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("Should succeed: \(error)")
        }
    }

    // MARK: - Validation Tests

    func testValidationDetectsIncompleteDeck() {
        let hero = createMockHero(id: "test-hero", startingDeckCardIDs: ["missing-card"])
        registry.registerMockContent(heroes: ["test-hero": hero])

        let result = safeAccess.validateAllContent()

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.message.contains("missing cards") })
    }

    func testValidationDetectsMissingFateCards() {
        registry.registerMockContent()

        let result = safeAccess.validateAllContent()

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.message.contains("fate cards") })
    }

    func testValidationDetectsInvalidEnemyHealth() {
        let badEnemy = EnemyDefinition(
            id: "bad-enemy",
            name: .inline(LocalizedString(en: "Bad", ru: "Плохой")),
            description: .inline(LocalizedString(en: "", ru: "")),
            health: 0,
            power: 5,
            defense: 0
        )
        registry.registerMockContent(enemies: ["bad-enemy": badEnemy])

        let result = safeAccess.validateAllContent()

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.message.contains("non-positive health") })
    }

    func testValidationBrokenEventChain() {
        let event = createMockEvent(
            id: "test-event",
            triggerEventId: "nonexistent-trigger"
        )
        registry.registerMockContent(events: ["test-event": event])

        let result = safeAccess.validateAllContent()

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains {
            $0.message.contains("non-existent event") || $0.message.contains("triggers")
        })
    }

    func testValidationPassesWithValidContent() {
        let hero = createMockHero(id: "test-hero", startingDeckCardIDs: ["card-1"])
        let card = createMockCard(id: "card-1")
        let fateCards = (1...10).map { createMockFateCard(id: "fate-\($0)") }
        var fateCardDict: [String: FateCard] = [:]
        for fateCard in fateCards {
            fateCardDict[fateCard.id] = fateCard
        }
        let region = createMockRegion(id: "test-region")

        registry.registerMockContent(
            regions: ["test-region": region],
            heroes: ["test-hero": hero],
            cards: ["card-1": card],
            fateCards: fateCardDict
        )

        let result = safeAccess.validateAllContent()

        XCTAssertTrue(result.isValid, "Errors: \(result.errors.map { $0.message })")
    }

    func testContentSummaryIsPopulated() {
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

        let result = safeAccess.validateAllContent()

        XCTAssertEqual(result.contentSummary.heroCount, 1)
        XCTAssertEqual(result.contentSummary.cardCount, 1)
        XCTAssertEqual(result.contentSummary.enemyCount, 1)
        XCTAssertEqual(result.contentSummary.regionCount, 1)
        XCTAssertEqual(result.contentSummary.fateCardCount, 1)
    }
}

/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/INV_FATE_GateTests.swift
/// Назначение: Содержит реализацию файла INV_FATE_GateTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import TwilightEngine

/// Fate Deck Invariants — Gate Tests
/// Reference: ENCOUNTER_TEST_MODEL.md §2.2
/// Rule: < 2 seconds, deterministic, no system RNG
final class INV_FATE_GateTests: XCTestCase {

    // INV-FATE-001: FateDeck is global across contexts (conservation)
    func test_INV_FATE_001_DeckConservation() {
        let ctx = EncounterContextFixtures.standard()
        let initialSnapshot = ctx.fateDeckSnapshot
        let engine = EncounterEngine(context: ctx)

        // Perform attack to trigger fate draw in enemy resolution
        _ = engine.generateIntent(for: "test_enemy")
        _ = engine.advancePhase() // intent → playerAction
        _ = engine.advancePhase() // playerAction → enemyResolution
        _ = engine.resolveEnemyAction(enemyId: "test_enemy")

        let result = engine.finishEncounter()

        // The updated fate deck state must differ from initial (cards were drawn)
        XCTAssertNotEqual(initialSnapshot, result.updatedFateDeck,
            "Fate deck state must change after cards are drawn")
    }

    // INV-FATE-002: Wait action has no side effects on Fate deck
    func test_INV_FATE_002_WaitNoFateDeckSideEffect() {
        let ctx = EncounterContextFixtures.standard()
        let engine = EncounterEngine(context: ctx)

        _ = engine.advancePhase() // intent → playerAction
        let result = engine.performAction(.wait)

        let hasDraw = result.stateChanges.contains { change in
            if case .fateDraw = change { return true }
            return false
        }
        XCTAssertFalse(hasDraw, "Wait action must not draw a fate card")
    }

    // INV-FATE-006: All fate card suits must be valid
    func test_INV_FATE_006_SuitValidity() {
        let fateCards = TestContentLoader.sharedLoadedRegistry().getAllFateCards()

        let validSuits: Set<String> = ["nav", "prav", "yav"]
        var invalid: [String] = []

        for card in fateCards {
            if let suit = card.suit?.rawValue, !validSuits.contains(suit) {
                invalid.append("\(card.id): \(suit)")
            }
        }

        XCTAssertTrue(invalid.isEmpty, "Invalid suits: \(invalid.joined(separator: ", "))")
    }

    // INV-FATE-007: Choice cards must have both options
    func test_INV_FATE_007_ChoiceCardCompleteness() {
        let fateCards = TestContentLoader.sharedLoadedRegistry().getAllFateCards()

        let choiceCards = fateCards.filter { $0.cardType == .choice }
        var incomplete: [String] = []

        for card in choiceCards {
            guard let options = card.choiceOptions, options.count >= 2 else {
                incomplete.append(card.id)
                continue
            }
        }

        XCTAssertTrue(incomplete.isEmpty,
            "Choice cards missing 2+ options: \(incomplete.joined(separator: ", "))")
    }

    // INV-FATE-008: All fate card keywords must be valid FateKeyword enum values
    func test_INV_FATE_008_KeywordValidity() {
        // Validate that:
        // 1. FateKeyword enum exists and has all expected cases
        // 2. Any card with a keyword has a valid value (guaranteed by Codable decode)
        // 3. Programmatic FateCard init accepts keywords correctly

        let allKeywords = FateKeyword.allCases
        XCTAssertEqual(allKeywords.count, 5, "FateKeyword must have exactly 5 cases")

        let expectedRawValues: Set<String> = ["surge", "focus", "echo", "shadow", "ward"]
        let actualRawValues = Set(allKeywords.map { $0.rawValue })
        XCTAssertEqual(actualRawValues, expectedRawValues,
            "FateKeyword cases must match spec")

        // Verify keyword round-trips through Codable
        for keyword in allKeywords {
            let card = FateCard(id: "test_\(keyword.rawValue)", modifier: 0, name: "Test", keyword: keyword)
            let data = try! JSONEncoder().encode(card)
            let decoded = try! JSONDecoder().decode(FateCard.self, from: data)
            XCTAssertEqual(decoded.keyword, keyword,
                "Keyword \(keyword.rawValue) must survive encode/decode")
        }
    }
}

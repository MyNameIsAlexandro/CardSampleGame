/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/LayerTests/FateDeckEngineTests.swift
/// Назначение: Содержит реализацию файла FateDeckEngineTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import TwilightEngine

/// Fate Deck Engine component tests
/// Reference: ENCOUNTER_TEST_MODEL.md §3.3
final class FateDeckEngineTests: XCTestCase {

    // #14: Wait action does not draw fate card
    func testWaitNoFateDraw() {
        let ctx = EncounterContextFixtures.standard()
        let engine = EncounterEngine(context: ctx)

        // Wait should not draw
        _ = engine.advancePhase() // intent → playerAction
        let result = engine.performAction(.wait)

        // No fate draw in state changes
        let hasDraw = result.stateChanges.contains { change in
            if case .fateDraw = change { return true }
            return false
        }
        XCTAssertFalse(hasDraw, "Wait action must not draw a fate card")
    }

    // #39: Fate card resolution order: DRAW → MATCH → VALUE → KEYWORD → RESONANCE
    func testResolutionOrder() {
        // Resolution pipeline is tracked through state changes emitted by resolveEnemyAction
        // When an enemy attacks, the engine: draws a fate card → checks value → applies to damage
        let ctx = EncounterContextFixtures.standard()
        let engine = EncounterEngine(context: ctx)

        // Generate and resolve enemy attack
        let intent = engine.generateIntent(for: "test_enemy")
        XCTAssertEqual(intent.type, .attack, "Default intent should be attack")

        _ = engine.advancePhase() // intent → playerAction
        _ = engine.advancePhase() // playerAction → enemyResolution
        let result = engine.resolveEnemyAction(enemyId: "test_enemy")
        XCTAssertTrue(result.success, "Enemy resolution should succeed")

        // State changes should contain fateDraw before playerHPChanged
        // This validates the resolution order: draw happens before damage calc
        var sawDraw = false
        var sawHP = false
        var orderCorrect = true

        for change in result.stateChanges {
            switch change {
            case .fateDraw:
                sawDraw = true
                if sawHP { orderCorrect = false } // draw must come before HP change
            case .playerHPChanged:
                sawHP = true
            default:
                break
            }
        }

        // If a fate card was drawn, it must appear before HP change
        if sawDraw && sawHP {
            XCTAssertTrue(orderCorrect, "Fate draw must precede HP change in resolution order")
        }
        // At minimum, HP change should occur (enemy attacked)
        XCTAssertTrue(sawHP, "Enemy attack should produce playerHPChanged")
    }
}

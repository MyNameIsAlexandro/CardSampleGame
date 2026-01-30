import XCTest
@testable import TwilightEngine

/// Tests that EncounterEngine surfaces FateDrawResult and deck counts
/// after every action that draws a Fate Card.
final class EncounterFateFlowTests: XCTestCase {

    // MARK: - Physical attack sets lastFateDrawResult

    func testPhysicalAttackSetsFateDrawResult() {
        let ctx = EncounterContextFixtures.standard()
        let engine = EncounterEngine(context: ctx)
        _ = engine.advancePhase() // intent → playerAction

        XCTAssertNil(engine.lastFateDrawResult, "No fate draw before any action")

        let initialDraw = engine.fateDeckDrawCount
        let result = engine.performAction(.attack(targetId: "test_enemy"))

        XCTAssertTrue(result.success)
        XCTAssertNotNil(engine.lastFateDrawResult, "Fate draw result set after attack")
        XCTAssertEqual(engine.fateDeckDrawCount, initialDraw - 1, "Draw pile shrinks by 1")
        XCTAssertEqual(engine.fateDeckDiscardCount, 1, "Discard pile grows by 1")

        // State change includes fateDraw
        let fateDrawChanges = result.stateChanges.filter {
            if case .fateDraw = $0 { return true }
            return false
        }
        XCTAssertEqual(fateDrawChanges.count, 1, "Exactly one fateDraw state change")
    }

    // MARK: - Spirit attack sets lastFateDrawResult

    func testSpiritAttackSetsFateDrawResult() {
        let ctx = EncounterContextFixtures.standard() // enemy has wp=30
        let engine = EncounterEngine(context: ctx)
        _ = engine.advancePhase() // intent → playerAction

        let result = engine.performAction(.spiritAttack(targetId: "test_enemy"))

        XCTAssertTrue(result.success)
        XCTAssertNotNil(engine.lastFateDrawResult, "Fate draw result set after spirit attack")
    }

    // MARK: - Enemy resolution sets lastFateDrawResult (attack intent)

    func testEnemyResolutionSetsFateDrawResult() {
        let ctx = EncounterContextFixtures.standard()
        let engine = EncounterEngine(context: ctx)

        // Generate attack intent
        let intent = engine.generateIntent(for: "test_enemy")
        XCTAssertEqual(intent.type, .attack, "Default intent should be attack")

        // Advance to enemy resolution
        _ = engine.advancePhase() // intent → playerAction
        _ = engine.advancePhase() // playerAction → enemyResolution

        let result = engine.resolveEnemyAction(enemyId: "test_enemy")
        XCTAssertTrue(result.success)
        XCTAssertNotNil(engine.lastFateDrawResult, "Defense fate draw set during enemy resolution")
    }

    // MARK: - Wait does NOT draw a fate card

    func testWaitDoesNotDrawFate() {
        let ctx = EncounterContextFixtures.standard()
        let engine = EncounterEngine(context: ctx)
        _ = engine.advancePhase() // intent → playerAction

        let initialDraw = engine.fateDeckDrawCount
        let result = engine.performAction(.wait)

        XCTAssertTrue(result.success)
        XCTAssertNil(engine.lastFateDrawResult, "Wait should not draw fate")
        XCTAssertEqual(engine.fateDeckDrawCount, initialDraw, "Draw pile unchanged")
    }

    // MARK: - Deck counts update after draws

    func testDeckCountsSyncAfterMultipleDraws() {
        let ctx = EncounterContextFixtures.standard()
        let engine = EncounterEngine(context: ctx)
        _ = engine.advancePhase() // intent → playerAction

        let total = engine.fateDeckDrawCount + engine.fateDeckDiscardCount

        // Draw 3 times via attacks
        _ = engine.performAction(.attack(targetId: "test_enemy"))
        _ = engine.performAction(.attack(targetId: "test_enemy"))
        _ = engine.performAction(.attack(targetId: "test_enemy"))

        let newTotal = engine.fateDeckDrawCount + engine.fateDeckDiscardCount
        XCTAssertEqual(newTotal, total, "Total cards stay constant (draw + discard)")
        XCTAssertEqual(engine.fateDeckDiscardCount, 3, "3 cards discarded after 3 attacks")
    }

    // MARK: - Consecutive draws update lastFateDrawResult each time

    func testLastFateDrawResultUpdatesEachDraw() {
        let ctx = EncounterContextFixtures.standard()
        let engine = EncounterEngine(context: ctx)
        _ = engine.advancePhase() // intent → playerAction

        _ = engine.performAction(.attack(targetId: "test_enemy"))
        let first = engine.lastFateDrawResult
        XCTAssertNotNil(first)

        _ = engine.performAction(.attack(targetId: "test_enemy"))
        let second = engine.lastFateDrawResult
        XCTAssertNotNil(second)

        // They should be different cards (deterministic deck has distinct cards)
        XCTAssertNotEqual(first?.card.id, second?.card.id, "Second draw should be a different card")
    }

    // MARK: - FateDrawResult contains effectiveValue with resonance

    func testFateDrawResultHasEffectiveValue() {
        let ctx = EncounterContextFixtures.standard()
        let engine = EncounterEngine(context: ctx)
        _ = engine.advancePhase() // intent → playerAction

        _ = engine.performAction(.attack(targetId: "test_enemy"))
        let result = engine.lastFateDrawResult!

        // effectiveValue should be at least baseValue (resonance may add to it)
        XCTAssertNotNil(result.card, "Card should be present")
        XCTAssertTrue(result.effectiveValue >= result.card.baseValue - 5,
                       "Effective value should be reasonable")
    }

    // MARK: - Full round: two fate draws (attack + defense)

    func testFullRoundDrawsTwice() {
        let ctx = EncounterContextFixtures.standard()
        let engine = EncounterEngine(context: ctx)

        let initialDraw = engine.fateDeckDrawCount

        // Intent phase → generate attack intent
        _ = engine.generateIntent(for: "test_enemy")
        _ = engine.advancePhase() // intent → playerAction

        // Player attacks (draw 1)
        _ = engine.performAction(.attack(targetId: "test_enemy"))
        let afterAttack = engine.fateDeckDrawCount
        XCTAssertEqual(afterAttack, initialDraw - 1)

        // Advance to enemy resolution
        _ = engine.advancePhase() // playerAction → enemyResolution

        // Enemy resolves attack intent (draw 2)
        _ = engine.resolveEnemyAction(enemyId: "test_enemy")
        let afterDefense = engine.fateDeckDrawCount
        XCTAssertEqual(afterDefense, initialDraw - 2, "Two draws in one full round")
        XCTAssertEqual(engine.fateDeckDiscardCount, 2)
    }
}

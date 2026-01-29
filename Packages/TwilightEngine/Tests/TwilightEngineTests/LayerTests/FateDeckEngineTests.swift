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
        // TODO: Requires resolution order tracking
        XCTFail("Fate card resolution order tracking not implemented — TDD RED")
    }
}

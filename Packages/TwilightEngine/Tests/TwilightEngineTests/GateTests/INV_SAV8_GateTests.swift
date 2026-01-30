import XCTest
@testable import TwilightEngine

/// INV-SAV8: Save Safety Gate Tests (Epic 8)
/// Verifies fate deck persistence, save round-trip with fate state.
/// Gate rules: < 2s, no XCTSkip, no non-deterministic RNG.
final class INV_SAV8_GateTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TestContentLoader.loadContentPacksIfNeeded()
        WorldRNG.shared.setSeed(42)
    }

    override func tearDown() {
        WorldRNG.shared.setSeed(0)
        super.tearDown()
    }

    // MARK: - SAV-02: Fate Deck Persistence

    /// Fate deck state is included in EngineSave
    func testFateDeckState_includedInSave() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame(playerName: "Test", heroId: nil)

        // Draw a card to change deck state
        let drawBefore = engine.fateDeckDrawCount
        let discardBefore = engine.fateDeckDiscardCount

        let save = engine.createEngineSave()
        XCTAssertNotNil(save.fateDeckState, "Fate deck state should be saved")

        if let state = save.fateDeckState {
            XCTAssertEqual(state.drawPile.count + state.discardPile.count, drawBefore + discardBefore,
                           "Total cards should be preserved")
        }
    }

    /// Fate deck state round-trips through save/load
    func testFateDeckState_roundTrip() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame(playerName: "Test", heroId: nil)

        // Draw some cards to modify state
        let _ = engine.fateDeck?.draw()
        let _ = engine.fateDeck?.draw()

        let drawCountBefore = engine.fateDeckDrawCount
        let discardCountBefore = engine.fateDeckDiscardCount

        // Save
        let save = engine.createEngineSave()

        // Draw more cards (change state after save)
        let _ = engine.fateDeck?.draw()
        XCTAssertNotEqual(engine.fateDeckDrawCount, drawCountBefore, "State should have changed")

        // Restore
        engine.restoreFromEngineSave(save)

        XCTAssertEqual(engine.fateDeckDrawCount, drawCountBefore,
                       "Draw pile should be restored")
        XCTAssertEqual(engine.fateDeckDiscardCount, discardCountBefore,
                       "Discard pile should be restored")
    }

    /// Old saves without fateDeckState load without crash (backward compatibility)
    func testFateDeckState_backwardCompatible() {
        let save = EngineSave(
            playerName: "OldSave",
            playerHealth: 10,
            playerMaxHealth: 10,
            rngSeed: 42,
            rngState: 42
        )

        // fateDeckState defaults to nil — should not crash
        XCTAssertNil(save.fateDeckState)

        let engine = TwilightGameEngine()
        engine.initializeNewGame(playerName: "Test", heroId: nil)

        // Restore old save — should not crash, deck state unchanged
        let drawBefore = engine.fateDeckDrawCount
        engine.restoreFromEngineSave(save)

        // Deck should remain as-is (no fateDeckState to restore)
        XCTAssertEqual(engine.fateDeckDrawCount, drawBefore)
    }
}

/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/INV_SAV8_GateTests.swift
/// Назначение: Содержит реализацию файла INV_SAV8_GateTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import TwilightEngine

/// INV-SAV8: Save Safety Gate Tests (Epic 8)
/// Verifies fate deck persistence, save round-trip with fate state.
/// Gate rules: < 2s, no XCTSkip, no non-deterministic RNG.
final class INV_SAV8_GateTests: XCTestCase {

    override func setUp() {
        super.setUp()
        _ = TestContentLoader.sharedLoadedRegistry()
    }

    // MARK: - SAV-02: Fate Deck Persistence

    /// Fate deck state is included in EngineSave
    func testFateDeckState_includedInSave() {
        let engine = TestEngineFactory.makeEngine(seed: 42)
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
        let engine = TestEngineFactory.makeEngine(seed: 42)
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

        let engine = TestEngineFactory.makeEngine(seed: 42)
        engine.initializeNewGame(playerName: "Test", heroId: nil)

        // Restore old save — should not crash, deck state unchanged
        let drawBefore = engine.fateDeckDrawCount
        engine.restoreFromEngineSave(save)

        // Deck should remain as-is (no fateDeckState to restore)
        XCTAssertEqual(engine.fateDeckDrawCount, drawBefore)
    }

    // MARK: - SAV-03: Save Format Version Compatibility

    /// Save with older formatVersion round-trips through Codable without data loss
    func testSaveFormatVersion_olderVersionDecodesSuccessfully() throws {
        let oldSave = EngineSave(
            formatVersion: 0,
            playerName: "OldFormatPlayer",
            playerHealth: 15,
            playerMaxHealth: 20,
            rngSeed: 99,
            rngState: 99
        )

        let data = try JSONEncoder().encode(oldSave)
        let decoded = try JSONDecoder().decode(EngineSave.self, from: data)

        XCTAssertEqual(decoded.formatVersion, 0,
                       "Older formatVersion must be preserved through Codable round-trip")
        XCTAssertEqual(decoded.playerName, "OldFormatPlayer")
        XCTAssertEqual(decoded.playerHealth, 15)
        XCTAssertEqual(decoded.playerMaxHealth, 20)
    }

    /// Future formatVersion (higher than current) is rejected by compatibility validation
    func testSaveCompatibility_futureFormatVersionReturnsIncompatible() {
        let futureSave = EngineSave(
            formatVersion: EngineSave.currentFormatVersion + 1,
            playerName: "FutureSave",
            playerHealth: 10,
            playerMaxHealth: 10,
            rngSeed: 42,
            rngState: 42
        )

        let registry = TestContentLoader.sharedLoadedRegistry()
        let result = futureSave.validateCompatibility(with: registry)

        XCTAssertFalse(result.isLoadable,
            "Save with formatVersion newer than supported must be incompatible")
        XCTAssertFalse(result.errorMessages.isEmpty,
            "Incompatible result must include error messages describing the version mismatch")
    }

    // MARK: - SAV-04: RNG Determinism After Save/Restore

    /// RNG produces identical sequence after save/load round-trip (determinism invariant)
    func testRNGDeterminism_preservedThroughSaveRestore() {
        let engine = TestEngineFactory.makeEngine(seed: 42)
        engine.initializeNewGame(playerName: "Test", heroId: nil)

        // Advance RNG state by drawing fate cards
        let _ = engine.fateDeck?.draw()
        let _ = engine.fateDeck?.draw()

        // Save current state
        let save = engine.createEngineSave()

        // Generate reference RNG sequence from saved state
        let referenceRNG = WorldRNG(seed: save.rngSeed)
        referenceRNG.restoreState(save.rngState)
        let expected = (0..<10).map { _ in referenceRNG.next() }

        // Restore and capture RNG state from restored engine
        engine.restoreFromEngineSave(save)
        let restoredSave = engine.createEngineSave()

        let restoredRNG = WorldRNG(seed: restoredSave.rngSeed)
        restoredRNG.restoreState(restoredSave.rngState)
        let actual = (0..<10).map { _ in restoredRNG.next() }

        XCTAssertEqual(expected, actual,
            "RNG sequence must be identical after save/restore — determinism contract (CLAUDE.md §1.3)")
        XCTAssertEqual(save.rngState, restoredSave.rngState,
            "RNG state must match in save snapshots before and after restore round-trip")
    }
}

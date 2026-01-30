import XCTest
@testable import TwilightEngine

/// INV-DEBT11: Debt Closure Gate Tests (Epic 11)
/// Verifies Codable round-trips, snapshot/restore, backward compat, difficulty levels.
/// Gate rules: < 2s, no XCTSkip, no non-deterministic RNG.
final class INV_DEBT11_GateTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TestContentLoader.loadContentPacksIfNeeded()
        WorldRNG.shared.setSeed(42)
    }

    override func tearDown() {
        WorldRNG.shared.setSeed(0)
        super.tearDown()
    }

    // MARK: - DEBT-01: VictoryType Codable Round-Trip

    func test_victoryType_killed_roundTrip() throws {
        let original = VictoryType.killed
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VictoryType.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_victoryType_pacified_roundTrip() throws {
        let original = VictoryType.pacified
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VictoryType.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_victoryType_custom_roundTrip() throws {
        let original = VictoryType.custom("ritual_complete")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VictoryType.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - DEBT-03: EncounterSaveState Round-Trip

    func test_encounterSaveState_codable_roundTrip() throws {
        let ctx = makeTestContext()
        let engine = EncounterEngine(context: ctx)
        // Advance to playerAction phase so state is non-trivial
        _ = engine.advancePhase()

        let snapshot = engine.createSaveState()
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(EncounterSaveState.self, from: data)
        XCTAssertEqual(decoded, snapshot)
    }

    // MARK: - DEBT-04: Snapshot/Restore

    func test_encounterEngine_snapshot_restore() throws {
        let ctx = makeTestContext()
        let engine = EncounterEngine(context: ctx)
        // Advance past intent phase
        _ = engine.advancePhase()

        let snapshot = engine.createSaveState()
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(EncounterSaveState.self, from: data)

        let restored = EncounterEngine.restore(from: decoded)
        XCTAssertEqual(restored.currentPhase, engine.currentPhase)
        XCTAssertEqual(restored.currentRound, engine.currentRound)
        XCTAssertEqual(restored.heroHP, engine.heroHP)
        XCTAssertEqual(restored.enemies.count, engine.enemies.count)
    }

    // MARK: - DEBT-05: EngineSave Backward Compat

    func test_engineSave_nilEncounterState_decodesOK() throws {
        // Simulate a save from before mid-combat save was added
        let save = EngineSave(
            playerName: "Test",
            playerHealth: 20,
            playerMaxHealth: 25,
            encounterState: nil,
            rngSeed: 42,
            rngState: 42
        )
        let data = try JSONEncoder().encode(save)
        let decoded = try JSONDecoder().decode(EngineSave.self, from: data)
        XCTAssertNil(decoded.encounterState)
        XCTAssertEqual(decoded.playerName, "Test")
    }

    // MARK: - DEBT-07: DifficultyLevel

    func test_difficultyLevel_multipliers() {
        XCTAssertEqual(DifficultyLevel.easy.hpMultiplier, 0.75)
        XCTAssertEqual(DifficultyLevel.easy.powerMultiplier, 0.75)
        XCTAssertEqual(DifficultyLevel.normal.hpMultiplier, 1.0)
        XCTAssertEqual(DifficultyLevel.normal.powerMultiplier, 1.0)
        XCTAssertEqual(DifficultyLevel.hard.hpMultiplier, 1.5)
        XCTAssertEqual(DifficultyLevel.hard.powerMultiplier, 1.25)
    }

    func test_difficultyLevel_codable_roundTrip() throws {
        for level in DifficultyLevel.allCases {
            let data = try JSONEncoder().encode(level)
            let decoded = try JSONDecoder().decode(DifficultyLevel.self, from: data)
            XCTAssertEqual(decoded, level)
        }
    }

    // MARK: - Helpers

    private func makeTestContext() -> EncounterContext {
        let hero = EncounterHero(id: "test_hero", hp: 25, maxHp: 25, strength: 6, armor: 2, wisdom: 3)
        let enemy = EncounterEnemy(id: "wolf", name: "Wolf", hp: 8, maxHp: 8, power: 4)
        let fateDeck = FateDeckState(drawPile: [], discardPile: [])
        return EncounterContext(
            hero: hero,
            enemies: [enemy],
            fateDeckSnapshot: fateDeck,
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42
        )
    }
}

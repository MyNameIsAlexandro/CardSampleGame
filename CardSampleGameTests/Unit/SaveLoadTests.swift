/// Файл: CardSampleGameTests/Unit/SaveLoadTests.swift
/// Назначение: Содержит реализацию файла SaveLoadTests.swift.
/// Зона ответственности: Фиксирует проверяемый контракт и не содержит production-логики.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
import TwilightEngine

@testable import CardSampleGame

/// Engine-First Save/Load Tests
/// Tests the EngineSave-based save system (no legacy GameSave)
@MainActor
final class SaveLoadTests: XCTestCase {

    var engine: TwilightGameEngine!
    var saveManager: SaveManager!
    private var registry: ContentRegistry!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let services = try TestContentLoader.makeStandardEngineServices(seed: 0)
        registry = services.contentRegistry
        engine = TwilightGameEngine(services: services)

        let heroId = try XCTUnwrap(registry.heroRegistry.firstHero?.id, "No heroes loaded for SaveLoadTests")
        engine.initializeNewGame(playerName: "Test Hero", heroId: heroId)
        saveManager = SaveManager()

        // Clear test slots
        for slot in 100...105 {
            saveManager.deleteSave(from: slot)
        }
    }

    override func tearDown() {
        // Clear after tests
        for slot in 100...105 {
            saveManager.deleteSave(from: slot)
        }
        engine = nil
        registry = nil
        saveManager = nil
        super.tearDown()
    }

    // MARK: - Basic Save/Load

    func testSaveGameCreatesSlot() {
        saveManager.saveGame(to: 100, engine: engine)
        XCTAssertTrue(saveManager.hasSave(in: 100), "Slot should have a save")
    }

    func testSaveGamePreservesPlayerName() {
        saveManager.saveGame(to: 100, engine: engine)
        let save = saveManager.getSave(from: 100)

        XCTAssertEqual(save?.playerName, "Test Hero")
    }

    func testSaveGamePreservesHealth() {
        let initialHealth = engine.player.health
        let initialMaxHealth = engine.player.maxHealth

        saveManager.saveGame(to: 100, engine: engine)
        let save = saveManager.getSave(from: 100)

        XCTAssertEqual(save?.playerHealth, initialHealth)
        XCTAssertEqual(save?.playerMaxHealth, initialMaxHealth)
    }

    func testSaveGamePreservesFaith() {
        let initialFaith = engine.player.faith
        let initialMaxFaith = engine.player.maxFaith

        saveManager.saveGame(to: 100, engine: engine)
        let save = saveManager.getSave(from: 100)

        XCTAssertEqual(save?.playerFaith, initialFaith)
        XCTAssertEqual(save?.playerMaxFaith, initialMaxFaith)
    }

    func testSaveGamePreservesBalance() {
        let initialBalance = engine.player.balance

        saveManager.saveGame(to: 100, engine: engine)
        let save = saveManager.getSave(from: 100)

        XCTAssertEqual(save?.playerBalance, initialBalance)
    }

    func testSaveGamePreservesCurrentDay() {
        // Advance some days
        _ = engine.performAction(.skipTurn)
        _ = engine.performAction(.skipTurn)
        let currentDay = engine.currentDay

        saveManager.saveGame(to: 100, engine: engine)
        let save = saveManager.getSave(from: 100)

        XCTAssertEqual(save?.currentDay, currentDay)
    }

    // MARK: - Deck Preservation (CRITICAL)

    func testSaveGamePreservesDeck() {
        let deckCount = engine.deck.playerDeck.count

        saveManager.saveGame(to: 100, engine: engine)
        let save = saveManager.getSave(from: 100)

        XCTAssertEqual(save?.deckCardIds.count, deckCount, "Deck preserved")
    }

    func testSaveGamePreservesHand() {
        let handCount = engine.deck.playerHand.count

        saveManager.saveGame(to: 100, engine: engine)
        let save = saveManager.getSave(from: 100)

        XCTAssertEqual(save?.handCardIds.count, handCount, "Hand preserved")
    }

    // MARK: - World State Preservation (CRITICAL)

    func testSaveGamePreservesWorldTension() {
        // Advance time to increase tension
        for _ in 0..<6 {
            _ = engine.performAction(.skipTurn)
        }
        let tension = engine.worldTension

        saveManager.saveGame(to: 100, engine: engine)
        let save = saveManager.getSave(from: 100)

        XCTAssertEqual(save?.worldTension, tension)
    }

    func testSaveGamePreservesMainQuestStage() {
        let stage = engine.mainQuestStage

        saveManager.saveGame(to: 100, engine: engine)
        let save = saveManager.getSave(from: 100)

        XCTAssertEqual(save?.mainQuestStage, stage)
    }

    func testSaveGamePreservesWorldFlags() {
        engine.setWorldFlags(["test_flag": true, "another_flag": false])

        saveManager.saveGame(to: 100, engine: engine)
        let save = saveManager.getSave(from: 100)

        XCTAssertEqual(save?.worldFlags["test_flag"], true)
        XCTAssertEqual(save?.worldFlags["another_flag"], false)
    }

    // MARK: - Load Game

    func testLoadGameRestoresHealth() {
        saveManager.saveGame(to: 100, engine: engine)
        let savedHealth = engine.player.health

        let newEngine = TwilightGameEngine(
            services: EngineServices(rng: WorldRNG(seed: 0), contentRegistry: registry, localizationManager: engine.services.localizationManager)
        )
        XCTAssertTrue(saveManager.loadGame(from: 100, engine: newEngine, registry: registry))

        XCTAssertEqual(newEngine.player.health, savedHealth)
    }

    func testLoadGameRestoresFaith() {
        saveManager.saveGame(to: 100, engine: engine)
        let savedFaith = engine.player.faith

        let newEngine = TwilightGameEngine(
            services: EngineServices(rng: WorldRNG(seed: 0), contentRegistry: registry, localizationManager: engine.services.localizationManager)
        )
        XCTAssertTrue(saveManager.loadGame(from: 100, engine: newEngine, registry: registry))

        XCTAssertEqual(newEngine.player.faith, savedFaith)
    }

    func testLoadGameRestoresBalance() {
        saveManager.saveGame(to: 100, engine: engine)
        let savedBalance = engine.player.balance

        let newEngine = TwilightGameEngine(
            services: EngineServices(rng: WorldRNG(seed: 0), contentRegistry: registry, localizationManager: engine.services.localizationManager)
        )
        XCTAssertTrue(saveManager.loadGame(from: 100, engine: newEngine, registry: registry))

        XCTAssertEqual(newEngine.player.balance, savedBalance)
    }

    func testLoadGameRestoresCurrentDay() {
        _ = engine.performAction(.skipTurn)
        _ = engine.performAction(.skipTurn)
        saveManager.saveGame(to: 100, engine: engine)
        let savedDay = engine.currentDay

        let newEngine = TwilightGameEngine(
            services: EngineServices(rng: WorldRNG(seed: 0), contentRegistry: registry, localizationManager: engine.services.localizationManager)
        )
        XCTAssertTrue(saveManager.loadGame(from: 100, engine: newEngine, registry: registry))

        XCTAssertEqual(newEngine.currentDay, savedDay)
    }

    func testLoadGameRestoresWorldTension() {
        for _ in 0..<6 {
            _ = engine.performAction(.skipTurn)
        }
        saveManager.saveGame(to: 100, engine: engine)
        let savedTension = engine.worldTension

        let newEngine = TwilightGameEngine(
            services: EngineServices(rng: WorldRNG(seed: 0), contentRegistry: registry, localizationManager: engine.services.localizationManager)
        )
        XCTAssertTrue(saveManager.loadGame(from: 100, engine: newEngine, registry: registry))

        XCTAssertEqual(newEngine.worldTension, savedTension)
    }

    func testEchoEncounterBridgeRelocalizesResumeDeckCardsFromRegistry() throws {
        let localizedCard = try XCTUnwrap(
            registry.getCard(id: "strike_basic")?.toCard(localizationManager: engine.services.localizationManager),
            "Missing strike_basic in loaded test content"
        )

        let staleCard = Card(
            id: "strike_basic_2",
            name: "STALE_STRIKE_NAME",
            type: .attack,
            description: "STALE_STRIKE_DESCRIPTION"
        )

        let context = EncounterContext(
            hero: EncounterHero(
                id: "test_hero",
                hp: engine.player.health,
                maxHp: engine.player.maxHealth,
                strength: engine.player.strength,
                armor: 0
            ),
            enemies: [EncounterEnemy(
                id: "test_enemy",
                name: "Test Enemy",
                hp: 10,
                maxHp: 10,
                power: 2,
                defense: 1
            )],
            fateDeckSnapshot: FateDeckState(drawPile: [], discardPile: []),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42,
            rngState: 42,
            worldResonance: 0,
            heroCards: [staleCard],
            heroFaith: engine.player.faith
        )
        let savedState = EncounterEngine(context: context).createSaveState()

        let config = try XCTUnwrap(
            EchoEncounterBridge.makeCombatConfig(from: savedState, engine: engine, registry: registry)
        )
        let bridgedCard = try XCTUnwrap(config.playerDeck.first)

        XCTAssertEqual(bridgedCard.id, staleCard.id, "Bridge must preserve runtime instance id")
        XCTAssertEqual(bridgedCard.name, localizedCard.name, "Bridge must relocalize card name from registry definition")
        XCTAssertEqual(
            bridgedCard.description,
            localizedCard.description,
            "Bridge must relocalize card description from registry definition"
        )
        XCTAssertNotEqual(bridgedCard.name, staleCard.name, "Stale save payload text must not leak into resumed combat")
        XCTAssertNotEqual(
            bridgedCard.description,
            staleCard.description,
            "Stale save payload text must not leak into resumed combat"
        )
    }

    // MARK: - Delete Save

    func testDeleteSave() {
        saveManager.saveGame(to: 100, engine: engine)
        XCTAssertTrue(saveManager.hasSave(in: 100))

        saveManager.deleteSave(from: 100)

        XCTAssertFalse(saveManager.hasSave(in: 100))
    }

    // MARK: - Multiple Slots

    func testMultipleSaveSlots() {
        engine.initializeNewGame(playerName: "Hero 1", heroId: nil)
        saveManager.saveGame(to: 101, engine: engine)

        engine.initializeNewGame(playerName: "Hero 2", heroId: nil)
        saveManager.saveGame(to: 102, engine: engine)

        let save1 = saveManager.getSave(from: 101)
        let save2 = saveManager.getSave(from: 102)

        XCTAssertEqual(save1?.playerName, "Hero 1")
        XCTAssertEqual(save2?.playerName, "Hero 2")
    }

    func testOverwriteSave() {
        // Ensure slot is clean
        saveManager.deleteSave(from: 100)

        let firstDay = engine.currentDay
        saveManager.saveGame(to: 100, engine: engine)

        // Advance time (use skipTurn - doesn't require region validation)
        _ = engine.performAction(.skipTurn)
        _ = engine.performAction(.skipTurn)

        let secondDay = engine.currentDay
        XCTAssertGreaterThan(secondDay, firstDay, "Day should advance after skipTurn")

        // Overwrite save
        saveManager.saveGame(to: 100, engine: engine)

        let save = saveManager.getSave(from: 100)
        XCTAssertEqual(save?.currentDay, secondDay, "Save should have updated day")
    }

    // MARK: - Data Integrity

    func testSaveDataIntegrity() {
        // Advance the game a bit
        for _ in 0..<5 {
            _ = engine.performAction(.skipTurn)
        }

        saveManager.saveGame(to: 100, engine: engine)

        let newEngine = TwilightGameEngine(
            services: EngineServices(rng: WorldRNG(seed: 0), contentRegistry: registry, localizationManager: engine.services.localizationManager)
        )
        XCTAssertTrue(saveManager.loadGame(from: 100, engine: newEngine, registry: registry))

        // Verify all fields match
        XCTAssertEqual(newEngine.player.name, engine.player.name)
        XCTAssertEqual(newEngine.player.health, engine.player.health)
        XCTAssertEqual(newEngine.player.maxHealth, engine.player.maxHealth)
        XCTAssertEqual(newEngine.player.faith, engine.player.faith)
        XCTAssertEqual(newEngine.player.maxFaith, engine.player.maxFaith)
        XCTAssertEqual(newEngine.player.balance, engine.player.balance)
        XCTAssertEqual(newEngine.currentDay, engine.currentDay)
        XCTAssertEqual(newEngine.worldTension, engine.worldTension)
        XCTAssertEqual(newEngine.mainQuestStage, engine.mainQuestStage)
    }

    // MARK: - EngineSave Encoding/Decoding

    func testEngineSaveEncodeDecode() {
        saveManager.saveGame(to: 100, engine: engine)

        guard let save = saveManager.getSave(from: 100) else {
            XCTFail("Failed to get save")
            return
        }

        do {
            let encoded = try JSONEncoder().encode(save)
            let decoded = try JSONDecoder().decode(EngineSave.self, from: encoded)

            XCTAssertEqual(decoded.playerName, save.playerName)
            XCTAssertEqual(decoded.playerHealth, save.playerHealth)
            XCTAssertEqual(decoded.currentDay, save.currentDay)
        } catch {
            XCTFail("Encoding error: \(error)")
        }
    }

    // MARK: - Pack Compatibility (Epic 7)

    func testSaveStoresPackSetAndRefusesIncompatibleLoad() {
        // 1. Save the game - should capture current pack set
        saveManager.saveGame(to: 100, engine: engine)

        guard let save = saveManager.getSave(from: 100) else {
            XCTFail("Failed to get save")
            return
        }

        // 2. Verify save stores pack compatibility info
        XCTAssertFalse(save.coreVersion.isEmpty, "Save should store coreVersion")
        XCTAssertGreaterThan(save.formatVersion, 0, "Save should store formatVersion")
        // activePackSet may be empty if no packs loaded - that's OK for test

        // 3. Verify compatibility check works for current save
        let compatibility = save.validateCompatibility(with: registry)
        XCTAssertTrue(compatibility.isLoadable, "Save with current packs should be loadable")

        // 4. Test incompatible save (format version too new)
        let incompatibleSave = EngineSave(
            version: save.version,
            savedAt: save.savedAt,
            gameDuration: save.gameDuration,
            coreVersion: save.coreVersion,
            activePackSet: save.activePackSet,
            formatVersion: EngineSave.currentFormatVersion + 10, // Future format
            primaryCampaignPackId: "nonexistent_campaign_pack", // Missing pack
            playerName: save.playerName,
            heroId: save.heroId,
            playerHealth: save.playerHealth,
            playerMaxHealth: save.playerMaxHealth,
            playerFaith: save.playerFaith,
            playerMaxFaith: save.playerMaxFaith,
            playerBalance: save.playerBalance,
            deckCardIds: save.deckCardIds,
            handCardIds: save.handCardIds,
            discardCardIds: save.discardCardIds,
            currentDay: save.currentDay,
            worldTension: save.worldTension,
            lightDarkBalance: save.lightDarkBalance,
            currentRegionId: save.currentRegionId,
            regions: save.regions,
            mainQuestStage: save.mainQuestStage,
            activeQuestIds: save.activeQuestIds,
            completedQuestIds: save.completedQuestIds,
            questStages: save.questStages,
            completedEventIds: save.completedEventIds,
            eventLog: save.eventLog,
            worldFlags: save.worldFlags,
            rngSeed: save.rngSeed,
            rngState: save.rngState
        )

        // 5. Verify incompatible save is rejected
        let incompatibleResult = incompatibleSave.validateCompatibility(with: registry)
        XCTAssertFalse(incompatibleResult.isLoadable, "Save with future format should not be loadable")
        XCTAssertFalse(incompatibleResult.errorMessages.isEmpty, "Should have error messages")

        // 6. Test SaveManager returns detailed result
        let loadResult = saveManager.loadGameWithResult(from: 100, engine: engine, registry: registry)
        XCTAssertTrue(loadResult.success, "Loading current save should succeed")
        XCTAssertNil(loadResult.error, "No error for successful load")
    }

    func testSaveStoresPrimaryCampaignPackId() {
        // Save should capture the primary campaign pack
        saveManager.saveGame(to: 100, engine: engine)

        guard let save = saveManager.getSave(from: 100) else {
            XCTFail("Failed to get save")
            return
        }

        // If packs are loaded, primaryCampaignPackId should be set
        // If no packs loaded (test environment), it can be nil - that's OK
        if !registry.loadedPacks.isEmpty {
            // At least one pack loaded - check if it's a campaign/full pack
            let hasCampaignPack = registry.loadedPacks.values
                .contains { $0.manifest.packType == .campaign || $0.manifest.packType == .full }

            if hasCampaignPack {
                XCTAssertNotNil(save.primaryCampaignPackId, "Should store primary campaign pack ID")
            }
        }

        // Either way, the save should be valid
        let compatibility = save.validateCompatibility(with: registry)
        XCTAssertTrue(compatibility.isLoadable, "Save should be loadable")
    }

    func testLoadGameWithResultReturnsSaveNotFoundError() {
        // Try to load from empty slot
        let result = saveManager.loadGameWithResult(from: 999, engine: engine, registry: registry)

        XCTAssertFalse(result.success, "Loading from empty slot should fail")
        XCTAssertNotNil(result.error, "Should have error")

        if case .saveNotFound(let slot) = result.error {
            XCTAssertEqual(slot, 999, "Error should contain correct slot")
        } else {
            XCTFail("Expected saveNotFound error")
        }
    }
}

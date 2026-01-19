import XCTest
@testable import CardSampleGame

/// Тесты системы сохранения/загрузки
/// Покрывает: создание сохранений, восстановление состояния, целостность данных
/// См. QA_ACT_I_CHECKLIST.md, TEST-016
final class SaveLoadTests: XCTestCase {

    var player: Player!
    var gameState: GameState!
    var saveManager: SaveManager!

    override func setUp() {
        super.setUp()
        player = Player(name: "Тестовый герой")
        gameState = GameState(players: [player])
        saveManager = SaveManager()

        // Очищаем тестовые слоты
        for slot in 100...105 {
            saveManager.deleteSave(from: slot)
        }
    }

    override func tearDown() {
        // Очищаем после тестов
        for slot in 100...105 {
            saveManager.deleteSave(from: slot)
        }
        player = nil
        gameState = nil
        saveManager = nil
        WorldRNG.shared.resetToSystem()
        super.tearDown()
    }

    // MARK: - Создание сохранения

    func testSaveGameCreatesSlot() {
        saveManager.saveGame(to: 100, gameState: gameState)

        XCTAssertFalse(saveManager.isSlotEmpty(100), "Слот не должен быть пустым")
    }

    func testSaveGamePreservesCharacterName() {
        player.name = "Иван Хранитель"

        saveManager.saveGame(to: 100, gameState: gameState)
        let save = saveManager.loadGame(from: 100)

        XCTAssertEqual(save?.characterName, "Иван Хранитель")
    }

    func testSaveGamePreservesHealth() {
        player.health = 7
        player.maxHealth = 12

        saveManager.saveGame(to: 100, gameState: gameState)
        let save = saveManager.loadGame(from: 100)

        XCTAssertEqual(save?.health, 7)
        XCTAssertEqual(save?.maxHealth, 12)
    }

    func testSaveGamePreservesFaith() {
        player.faith = 5
        player.maxFaith = 15

        saveManager.saveGame(to: 100, gameState: gameState)
        let save = saveManager.loadGame(from: 100)

        XCTAssertEqual(save?.faith, 5)
        XCTAssertEqual(save?.maxFaith, 15)
    }

    func testSaveGamePreservesBalance() {
        player.balance = 75

        saveManager.saveGame(to: 100, gameState: gameState)
        let save = saveManager.loadGame(from: 100)

        XCTAssertEqual(save?.balance, 75)
    }

    func testSaveGamePreservesTurnNumber() {
        gameState.turnNumber = 15

        saveManager.saveGame(to: 100, gameState: gameState)
        let save = saveManager.loadGame(from: 100)

        XCTAssertEqual(save?.turnNumber, 15)
    }

    // MARK: - Сохранение колоды (CRITICAL)

    func testSaveGamePreservesDeck() {
        let card1 = Card(name: "Меч", type: .item, description: "")
        let card2 = Card(name: "Щит", type: .item, description: "")
        player.deck = [card1, card2]

        saveManager.saveGame(to: 100, gameState: gameState)
        let save = saveManager.loadGame(from: 100)

        XCTAssertEqual(save?.playerDeck.count, 2, "Колода сохранена")
        XCTAssertEqual(save?.playerDeck[0].name, "Меч")
        XCTAssertEqual(save?.playerDeck[1].name, "Щит")
    }

    func testSaveGamePreservesHand() {
        let card = Card(name: "В руке", type: .spell, description: "")
        player.hand = [card]

        saveManager.saveGame(to: 100, gameState: gameState)
        let save = saveManager.loadGame(from: 100)

        XCTAssertEqual(save?.playerHand.count, 1)
        XCTAssertEqual(save?.playerHand[0].name, "В руке")
    }

    func testSaveGamePreservesDiscard() {
        let card = Card(name: "Сброшена", type: .spell, description: "")
        player.discard = [card]

        saveManager.saveGame(to: 100, gameState: gameState)
        let save = saveManager.loadGame(from: 100)

        XCTAssertEqual(save?.playerDiscard.count, 1)
        XCTAssertEqual(save?.playerDiscard[0].name, "Сброшена")
    }

    // MARK: - Сохранение проклятий

    func testSaveGamePreservesCurses() {
        player.applyCurse(type: .weakness, duration: 5)
        player.applyCurse(type: .fear, duration: 3)

        saveManager.saveGame(to: 100, gameState: gameState)
        let save = saveManager.loadGame(from: 100)

        XCTAssertEqual(save?.activeCurses.count, 2)
        XCTAssertTrue(save?.activeCurses.contains { $0.type == .weakness } ?? false)
        XCTAssertTrue(save?.activeCurses.contains { $0.type == .fear } ?? false)
    }

    func testSaveGamePreservesCurseDuration() {
        player.applyCurse(type: .exhaustion, duration: 7)

        saveManager.saveGame(to: 100, gameState: gameState)
        let save = saveManager.loadGame(from: 100)

        let curse = save?.activeCurses.first { $0.type == .exhaustion }
        XCTAssertEqual(curse?.duration, 7)
    }

    // MARK: - Сохранение духов

    func testSaveGamePreservesSpirits() {
        let spirit = Card(name: "Дух леса", type: .spirit, description: "")
        player.spirits = [spirit]

        saveManager.saveGame(to: 100, gameState: gameState)
        let save = saveManager.loadGame(from: 100)

        XCTAssertEqual(save?.spirits.count, 1)
        XCTAssertEqual(save?.spirits[0].name, "Дух леса")
    }

    func testSaveGamePreservesRealm() {
        player.currentRealm = .nav

        saveManager.saveGame(to: 100, gameState: gameState)
        let save = saveManager.loadGame(from: 100)

        XCTAssertEqual(save?.currentRealm, .nav)
    }

    // MARK: - Сохранение WorldState (CRITICAL)

    func testSaveGamePreservesWorldTension() {
        gameState.worldState.worldTension = 55

        saveManager.saveGame(to: 100, gameState: gameState)
        let save = saveManager.loadGame(from: 100)

        XCTAssertEqual(save?.worldState.worldTension, 55)
    }

    func testSaveGamePreservesDaysPassed() {
        gameState.worldState.daysPassed = 12

        saveManager.saveGame(to: 100, gameState: gameState)
        let save = saveManager.loadGame(from: 100)

        XCTAssertEqual(save?.worldState.daysPassed, 12)
    }

    func testSaveGamePreservesMainQuestStage() {
        gameState.worldState.mainQuestStage = 3

        saveManager.saveGame(to: 100, gameState: gameState)
        let save = saveManager.loadGame(from: 100)

        XCTAssertEqual(save?.worldState.mainQuestStage, 3)
    }

    func testSaveGamePreservesWorldFlags() {
        gameState.worldState.setFlag("quest_complete", value: true)
        gameState.worldState.setFlag("boss_defeated", value: true)

        saveManager.saveGame(to: 100, gameState: gameState)
        let save = saveManager.loadGame(from: 100)

        XCTAssertTrue(save?.worldState.hasFlag("quest_complete") ?? false)
        XCTAssertTrue(save?.worldState.hasFlag("boss_defeated") ?? false)
    }

    func testSaveGamePreservesCurrentRegion() {
        let regionId = gameState.worldState.currentRegionId

        saveManager.saveGame(to: 100, gameState: gameState)
        let save = saveManager.loadGame(from: 100)

        XCTAssertEqual(save?.worldState.currentRegionId, regionId)
    }

    // MARK: - Восстановление игры

    func testRestoreGameStateHealth() {
        player.health = 6
        saveManager.saveGame(to: 100, gameState: gameState)

        let save = saveManager.loadGame(from: 100)!
        let restored = saveManager.restoreGameState(from: save)

        XCTAssertEqual(restored.currentPlayer.health, 6)
    }

    func testRestoreGameStateFaith() {
        player.faith = 8
        saveManager.saveGame(to: 100, gameState: gameState)

        let save = saveManager.loadGame(from: 100)!
        let restored = saveManager.restoreGameState(from: save)

        XCTAssertEqual(restored.currentPlayer.faith, 8)
    }

    func testRestoreGameStateBalance() {
        player.balance = 25
        saveManager.saveGame(to: 100, gameState: gameState)

        let save = saveManager.loadGame(from: 100)!
        let restored = saveManager.restoreGameState(from: save)

        XCTAssertEqual(restored.currentPlayer.balance, 25)
    }

    func testRestoreGameStateDeck() {
        let card = Card(name: "Restored Card", type: .spell, description: "")
        player.deck = [card]
        saveManager.saveGame(to: 100, gameState: gameState)

        let save = saveManager.loadGame(from: 100)!
        let restored = saveManager.restoreGameState(from: save)

        XCTAssertEqual(restored.currentPlayer.deck.count, 1)
        XCTAssertEqual(restored.currentPlayer.deck[0].name, "Restored Card")
    }

    func testRestoreGameStateCurses() {
        player.applyCurse(type: .shadowOfNav, duration: 10)
        saveManager.saveGame(to: 100, gameState: gameState)

        let save = saveManager.loadGame(from: 100)!
        let restored = saveManager.restoreGameState(from: save)

        XCTAssertTrue(restored.currentPlayer.hasCurse(.shadowOfNav))
    }

    func testRestoreGameStateWorldTension() {
        gameState.worldState.worldTension = 70
        saveManager.saveGame(to: 100, gameState: gameState)

        let save = saveManager.loadGame(from: 100)!
        let restored = saveManager.restoreGameState(from: save)

        XCTAssertEqual(restored.worldState.worldTension, 70)
    }

    func testRestoreGameStateTurnNumber() {
        gameState.turnNumber = 20
        saveManager.saveGame(to: 100, gameState: gameState)

        let save = saveManager.loadGame(from: 100)!
        let restored = saveManager.restoreGameState(from: save)

        XCTAssertEqual(restored.turnNumber, 20)
    }

    func testRestoreGameStatePhase() {
        gameState.isVictory = false
        gameState.isDefeat = false
        saveManager.saveGame(to: 100, gameState: gameState)

        let save = saveManager.loadGame(from: 100)!
        let restored = saveManager.restoreGameState(from: save)

        XCTAssertEqual(restored.currentPhase, .exploration)
    }

    func testRestoreGameStateGameOver() {
        gameState.isVictory = true
        saveManager.saveGame(to: 100, gameState: gameState)

        let save = saveManager.loadGame(from: 100)!
        let restored = saveManager.restoreGameState(from: save)

        XCTAssertEqual(restored.currentPhase, .gameOver)
    }

    // MARK: - Удаление сохранений

    func testDeleteSave() {
        saveManager.saveGame(to: 100, gameState: gameState)
        XCTAssertFalse(saveManager.isSlotEmpty(100))

        saveManager.deleteSave(from: 100)

        XCTAssertTrue(saveManager.isSlotEmpty(100))
    }

    // MARK: - Множественные слоты

    func testMultipleSaveSlots() {
        player.name = "Герой 1"
        saveManager.saveGame(to: 101, gameState: gameState)

        player.name = "Герой 2"
        saveManager.saveGame(to: 102, gameState: gameState)

        let save1 = saveManager.loadGame(from: 101)
        let save2 = saveManager.loadGame(from: 102)

        XCTAssertEqual(save1?.characterName, "Герой 1")
        XCTAssertEqual(save2?.characterName, "Герой 2")
    }

    func testOverwriteSave() {
        player.health = 10
        saveManager.saveGame(to: 100, gameState: gameState)

        player.health = 5
        saveManager.saveGame(to: 100, gameState: gameState)

        let save = saveManager.loadGame(from: 100)
        XCTAssertEqual(save?.health, 5, "Сохранение перезаписано")
    }

    // MARK: - Форматирование даты

    func testFormattedDate() {
        saveManager.saveGame(to: 100, gameState: gameState)
        let save = saveManager.loadGame(from: 100)

        XCTAssertFalse(save?.formattedDate.isEmpty ?? true, "Дата отформатирована")
    }

    // MARK: - Целостность данных

    func testSaveDataIntegrity() {
        // Полная настройка игры
        player.name = "Тест Целостности"
        player.health = 8
        player.maxHealth = 12
        player.faith = 6
        player.balance = 35

        let card1 = Card(name: "Карта1", type: .spell, description: "")
        let card2 = Card(name: "Карта2", type: .item, description: "")
        player.deck = [card1]
        player.hand = [card2]

        player.applyCurse(type: .fear, duration: 4)
        player.currentRealm = .nav

        gameState.turnNumber = 25
        gameState.worldState.worldTension = 45
        gameState.worldState.daysPassed = 18
        gameState.worldState.mainQuestStage = 2

        // Сохранение
        saveManager.saveGame(to: 100, gameState: gameState)

        // Восстановление
        let save = saveManager.loadGame(from: 100)!
        let restored = saveManager.restoreGameState(from: save)

        // Проверка всех полей
        XCTAssertEqual(restored.currentPlayer.name, "Тест Целостности")
        XCTAssertEqual(restored.currentPlayer.health, 8)
        XCTAssertEqual(restored.currentPlayer.maxHealth, 12)
        XCTAssertEqual(restored.currentPlayer.faith, 6)
        XCTAssertEqual(restored.currentPlayer.balance, 35)
        XCTAssertEqual(restored.currentPlayer.deck.count, 1)
        XCTAssertEqual(restored.currentPlayer.hand.count, 1)
        XCTAssertTrue(restored.currentPlayer.hasCurse(.fear))
        XCTAssertEqual(restored.currentPlayer.currentRealm, .nav)
        XCTAssertEqual(restored.turnNumber, 25)
        XCTAssertEqual(restored.worldState.worldTension, 45)
        XCTAssertEqual(restored.worldState.daysPassed, 18)
        XCTAssertEqual(restored.worldState.mainQuestStage, 2)
    }

    // MARK: - WorldState Codable

    func testWorldStateEncodeDecode() {
        let worldState = WorldState()
        worldState.worldTension = 42
        worldState.daysPassed = 10
        worldState.mainQuestStage = 2

        do {
            let encoded = try JSONEncoder().encode(worldState)
            let decoded = try JSONDecoder().decode(WorldState.self, from: encoded)

            XCTAssertEqual(decoded.worldTension, 42)
            XCTAssertEqual(decoded.daysPassed, 10)
            XCTAssertEqual(decoded.mainQuestStage, 2)
        } catch {
            XCTFail("Ошибка кодирования: \(error)")
        }
    }

    func testGameSaveEncodeDecode() {
        saveManager.saveGame(to: 100, gameState: gameState)

        guard let save = saveManager.loadGame(from: 100) else {
            XCTFail("Не удалось загрузить сохранение")
            return
        }

        do {
            let encoded = try JSONEncoder().encode(save)
            let decoded = try JSONDecoder().decode(GameSave.self, from: encoded)

            XCTAssertEqual(decoded.characterName, save.characterName)
            XCTAssertEqual(decoded.health, save.health)
            XCTAssertEqual(decoded.turnNumber, save.turnNumber)
        } catch {
            XCTFail("Ошибка кодирования GameSave: \(error)")
        }
    }
}

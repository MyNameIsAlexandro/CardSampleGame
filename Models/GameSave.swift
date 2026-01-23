import Foundation

// Save slot for saving/loading games (Campaign v2.0)
struct GameSave: Codable, Identifiable {
    let id: UUID
    let slotNumber: Int
    let characterName: String
    let heroId: String?  // Hero ID for data-driven system
    let turnNumber: Int

    // Basic player stats
    let health: Int
    let maxHealth: Int
    let faith: Int
    let maxFaith: Int
    let balance: Int

    // CRITICAL: Deck composition (deck-building mechanic)
    let playerDeck: [Card]
    let playerHand: [Card]
    let playerDiscard: [Card]
    let playerBuried: [Card]

    // Player curses and spirits
    let activeCurses: [ActiveCurse]
    let spirits: [Card]
    let currentRealm: Realm

    // Character stats
    let strength: Int
    let dexterity: Int
    let constitution: Int
    let intelligence: Int
    let wisdom: Int
    let charisma: Int

    // CRITICAL: World state (campaign progression)
    let worldState: WorldState

    // Game progress (old system - kept for compatibility)
    let encountersDefeated: Int
    let isVictory: Bool
    let isDefeat: Bool

    let timestamp: Date

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

// Manager for saving/loading games
class SaveManager: ObservableObject {
    static let shared = SaveManager()

    @Published var saveSlots: [Int: GameSave] = [:]

    private let savesKey = "twilight_marches_saves"

    init() {
        loadAllSaves()
        loadEngineSaves()  // Engine-First: Load engine saves
    }

    // Save game to slot (Campaign v2.0 - full save)
    func saveGame(to slot: Int, gameState: GameState) {
        guard let player = gameState.players.first else { return }

        let save = GameSave(
            id: UUID(),
            slotNumber: slot,
            characterName: player.name,
            heroId: player.heroId,
            turnNumber: gameState.turnNumber,
            health: player.health,
            maxHealth: player.maxHealth,
            faith: player.faith,
            maxFaith: player.maxFaith,
            balance: player.balance,
            // CRITICAL: Save deck composition
            playerDeck: player.deck,
            playerHand: player.hand,
            playerDiscard: player.discard,
            playerBuried: player.buried,
            // Save curses and spirits
            activeCurses: player.activeCurses,
            spirits: player.spirits,
            currentRealm: player.currentRealm,
            // Save character stats
            strength: player.strength,
            dexterity: player.dexterity,
            constitution: player.constitution,
            intelligence: player.intelligence,
            wisdom: player.wisdom,
            charisma: player.charisma,
            // CRITICAL: Save world state (campaign progression)
            worldState: gameState.worldState,
            // Old system (compatibility)
            encountersDefeated: gameState.encountersDefeated,
            isVictory: gameState.isVictory,
            isDefeat: gameState.isDefeat,
            timestamp: Date()
        )

        saveSlots[slot] = save
        persistSaves()
    }

    // Load game from slot
    func loadGame(from slot: Int) -> GameSave? {
        return saveSlots[slot]
    }

    // Restore full game state from save (Campaign v2.0)
    func restoreGameState(from save: GameSave) -> GameState {
        // Restore player with full state and heroId
        let player = Player(
            name: save.characterName,
            health: save.health,
            maxHealth: save.maxHealth,
            strength: save.strength,
            dexterity: save.dexterity,
            constitution: save.constitution,
            intelligence: save.intelligence,
            wisdom: save.wisdom,
            charisma: save.charisma,
            faith: save.faith,
            maxFaith: save.maxFaith,
            balance: save.balance,
            currentRealm: save.currentRealm,
            heroId: save.heroId
        )

        // Restore deck composition (CRITICAL for deck-building)
        player.deck = save.playerDeck
        player.hand = save.playerHand
        player.discard = save.playerDiscard
        player.buried = save.playerBuried

        // Restore curses and spirits
        player.activeCurses = save.activeCurses
        player.spirits = save.spirits

        // Create game state with restored player
        let gameState = GameState(players: [player])

        // Restore world state (CRITICAL for campaign)
        gameState.worldState = save.worldState

        // Restore game progress
        gameState.turnNumber = save.turnNumber
        gameState.encountersDefeated = save.encountersDefeated
        gameState.isVictory = save.isVictory
        gameState.isDefeat = save.isDefeat

        // Set initial phase
        if gameState.isGameOver {
            gameState.currentPhase = .gameOver
        } else {
            gameState.currentPhase = .exploration
        }

        return gameState
    }

    // Delete save from slot
    func deleteSave(from slot: Int) {
        saveSlots.removeValue(forKey: slot)
        persistSaves()
    }

    // Check if slot is empty
    func isSlotEmpty(_ slot: Int) -> Bool {
        return saveSlots[slot] == nil
    }

    // Get all saves sorted by slot number
    var allSaves: [GameSave] {
        return saveSlots.values.sorted { $0.slotNumber < $1.slotNumber }
    }

    // MARK: - Persistence

    private func persistSaves() {
        if let encoded = try? JSONEncoder().encode(saveSlots) {
            UserDefaults.standard.set(encoded, forKey: savesKey)
        }
    }

    private func loadAllSaves() {
        if let data = UserDefaults.standard.data(forKey: savesKey),
           let decoded = try? JSONDecoder().decode([Int: GameSave].self, from: data) {
            saveSlots = decoded
        }
    }

    // MARK: - Engine-First Save/Load (Replaces legacy GameState-based saves)

    private let engineSavesKey = "twilight_marches_engine_saves"
    @Published var engineSaveSlots: [Int: EngineSave] = [:]

    /// Save game directly from Engine (Engine-First Architecture)
    func saveGameFromEngine(to slot: Int, engine: TwilightGameEngine) {
        let save = engine.createEngineSave()
        engineSaveSlots[slot] = save
        persistEngineSaves()
    }

    /// Load game into Engine (Engine-First Architecture)
    func loadGameToEngine(from slot: Int, engine: TwilightGameEngine) -> Bool {
        guard let save = engineSaveSlots[slot] else {
            // Legacy save exists - caller should use migrateFromLegacySave()
            if saveSlots[slot] != nil {
                print("ℹ️ Legacy save found in slot \(slot) - use migrateFromLegacySave()")
            }
            return false
        }

        engine.restoreFromEngineSave(save)
        return true
    }

    /// Get engine save from slot
    func getEngineSave(from slot: Int) -> EngineSave? {
        return engineSaveSlots[slot]
    }

    /// Delete engine save from slot
    func deleteEngineSave(from slot: Int) {
        engineSaveSlots.removeValue(forKey: slot)
        persistEngineSaves()
    }

    /// Check if engine save slot is empty
    func isEngineSlotEmpty(_ slot: Int) -> Bool {
        return engineSaveSlots[slot] == nil
    }

    /// Get all engine saves
    var allEngineSaves: [EngineSave] {
        return engineSaveSlots.values.sorted { $0.savedAt > $1.savedAt }
    }

    /// Check if any engine saves exist
    var hasEngineSaves: Bool {
        return !engineSaveSlots.isEmpty
    }

    private func persistEngineSaves() {
        if let encoded = try? JSONEncoder().encode(engineSaveSlots) {
            UserDefaults.standard.set(encoded, forKey: engineSavesKey)
        }
    }

    private func loadEngineSaves() {
        if let data = UserDefaults.standard.data(forKey: engineSavesKey),
           let decoded = try? JSONDecoder().decode([Int: EngineSave].self, from: data) {
            engineSaveSlots = decoded
        }
    }
}

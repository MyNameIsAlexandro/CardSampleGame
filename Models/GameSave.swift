import Foundation

// Save slot for saving/loading games
struct GameSave: Codable, Identifiable {
    let id: UUID
    let slotNumber: Int
    let characterName: String
    let turnNumber: Int
    let health: Int
    let maxHealth: Int
    let faith: Int
    let balance: Int
    let encountersDefeated: Int
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
    }

    // Save game to slot
    func saveGame(to slot: Int, gameState: GameState) {
        guard let player = gameState.players.first else { return }

        let save = GameSave(
            id: UUID(),
            slotNumber: slot,
            characterName: player.name,
            turnNumber: gameState.turnNumber,
            health: player.health,
            maxHealth: player.maxHealth,
            faith: player.faith,
            balance: player.balance,
            encountersDefeated: gameState.encountersDefeated,
            timestamp: Date()
        )

        saveSlots[slot] = save
        persistSaves()
    }

    // Load game from slot
    func loadGame(from slot: Int) -> GameSave? {
        return saveSlots[slot]
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
}

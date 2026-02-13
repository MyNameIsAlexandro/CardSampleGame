/// Файл: Models/GameSave.swift
/// Назначение: Содержит реализацию файла GameSave.swift.
/// Зона ответственности: Описывает предметные модели и их инварианты.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import Foundation
import TwilightEngine

// MARK: - Save Manager (Engine-First Architecture)
// Uses only EngineSave format - no legacy format needed

// MARK: - Save Load Result

/// Detailed result of a save load operation
struct SaveLoadResult {
    /// Whether the load succeeded
    let success: Bool
    /// Compatibility check result (if save was found)
    let compatibility: SaveCompatibilityResult?
    /// Error if load failed
    let error: SaveLoadError?

    /// Warnings from compatibility check (for UI display)
    var warnings: [String] {
        switch compatibility {
        case .compatible(let warnings):
            return warnings
        default:
            return []
        }
    }

    /// Whether this was a partial load with warnings
    var hasWarnings: Bool {
        return success && !warnings.isEmpty
    }
}

/// Errors that can occur during save load
enum SaveLoadError: Error, Equatable {
    case saveNotFound(slot: Int)
    case incompatibleSave(details: [String])
    case decodingFailed(reason: String)

    var localizedDescription: String {
        switch self {
        case .saveNotFound(let slot):
            return L10n.errorSaveNotFound.localized(with: slot)
        case .incompatibleSave(let details):
            return L10n.errorIncompatibleSave.localized + ": " + details.joined(separator: "; ")
        case .decodingFailed(let reason):
            return L10n.errorSaveDecodingFailed.localized(with: reason)
        }
    }
}

@MainActor
class SaveManager: ObservableObject {
    static let shared = SaveManager()

    private let savesKey = "twilight_marches_engine_saves"
    @Published private(set) var isLoaded = false
    @Published var saveSlots: [Int: EngineSave] = [:]

    init() {
        loadSaves()
        isLoaded = true
    }

    // MARK: - Public API

    /// Save game from engine to slot
    func saveGame(to slot: Int, engine: TwilightGameEngine) {
        let save = engine.createEngineSave()
        saveSlots[slot] = save
        persistSaves()
    }

    /// Load game from slot into engine
    func loadGame(from slot: Int, engine: TwilightGameEngine, registry: ContentRegistry) -> Bool {
        let result = loadGameWithResult(from: slot, engine: engine, registry: registry)
        return result.success
    }

    /// Load game from slot with detailed result (for UI error display)
    func loadGameWithResult(from slot: Int, engine: TwilightGameEngine, registry: ContentRegistry) -> SaveLoadResult {
        guard let save = saveSlots[slot] else {
            return SaveLoadResult(
                success: false,
                compatibility: nil,
                error: .saveNotFound(slot: slot)
            )
        }

        // Check compatibility before loading
        let compatibility = save.validateCompatibility(with: registry)

        if !compatibility.isLoadable {
            return SaveLoadResult(
                success: false,
                compatibility: compatibility,
                error: .incompatibleSave(details: compatibility.errorMessages)
            )
        }

        // Load the save
        engine.restoreFromEngineSave(save)

        return SaveLoadResult(
            success: true,
            compatibility: compatibility,
            error: nil
        )
    }

    /// Check compatibility of a save without loading it
    func checkCompatibility(slot: Int, registry: ContentRegistry) -> SaveCompatibilityResult? {
        guard let save = saveSlots[slot] else { return nil }
        return save.validateCompatibility(with: registry)
    }

    /// Get save from slot (for display purposes)
    func getSave(from slot: Int) -> EngineSave? {
        return saveSlots[slot]
    }

    /// Delete save from slot
    func deleteSave(from slot: Int) {
        saveSlots.removeValue(forKey: slot)
        persistSaves()

        // Also clean up any old legacy saves (one-time migration cleanup)
        UserDefaults.standard.removeObject(forKey: "twilight_marches_saves")
    }

    /// Delete all saves
    func deleteAllSaves() {
        saveSlots.removeAll()
        persistSaves()
        UserDefaults.standard.removeObject(forKey: "twilight_marches_saves")
    }

    /// Check if slot has a save
    func hasSave(in slot: Int) -> Bool {
        return saveSlots[slot] != nil
    }

    /// Get all saves sorted by date (most recent first)
    var allSaves: [EngineSave] {
        return saveSlots.values.sorted { $0.savedAt > $1.savedAt }
    }

    /// Total number of saves
    var saveCount: Int {
        return saveSlots.count
    }

    /// Check if any saves exist
    var hasSaves: Bool {
        return !saveSlots.isEmpty
    }

    // MARK: - Persistence

    private func persistSaves() {
        if let encoded = try? JSONEncoder().encode(saveSlots) {
            UserDefaults.standard.set(encoded, forKey: savesKey)
        }
    }

    private func loadSaves() {
        if let data = UserDefaults.standard.data(forKey: savesKey),
           let decoded = try? JSONDecoder().decode([Int: EngineSave].self, from: data) {
            saveSlots = decoded
        }
    }
}

/// Файл: App/ContentFlow.swift
/// Назначение: Содержит реализацию файла ContentFlow.swift.
/// Зона ответственности: Изолирован логикой уровня инициализации и навигации приложения.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import Foundation
import TwilightEngine

/// Координатор навигационного потока корневого экрана.
/// Инкапсулирует переходы между экранами и сценарии start/load/continue.
enum ContentRootScreen {
    case characterSelection
    case saveSlots
    case loadSlots
    case worldMap
    case battleArena
}

enum ContentModal: String, Identifiable {
    case rules
    case statistics
    case settings
    case bestiary
    case achievements
    case contentManager

    var id: String { rawValue }
}

@MainActor
final class ContentFlow: ObservableObject {
    @Published var screen: ContentRootScreen = .characterSelection
    @Published var modal: ContentModal?
    @Published var selectedHeroId: String?
    @Published var selectedSaveSlot: Int?

    @Published var showingTutorial = false
    @Published var resumingCombat = false
    @Published var showingLoadAlert = false
    @Published var loadAlertMessage: String?

    func startGame(
        in slot: Int,
        registry: ContentRegistry,
        engine: TwilightGameEngine,
        saveManager: SaveManager,
        hasCompletedTutorial: Bool
    ) {
        guard let heroId = selectedHeroId,
              let hero = registry.heroRegistry.hero(id: heroId) else {
            return
        }

        engine.initializeNewGame(
            playerName: hero.name.localized,
            heroId: heroId
        )

        selectedSaveSlot = slot
        saveManager.saveGame(to: slot, engine: engine)

        screen = .worldMap

        if !hasCompletedTutorial {
            showingTutorial = true
        }
    }

    func loadGame(
        from slot: Int,
        engine: TwilightGameEngine,
        saveManager: SaveManager,
        registry: ContentRegistry
    ) {
        let result = saveManager.loadGameWithResult(from: slot, engine: engine, registry: registry)
        if result.success {
            selectedHeroId = engine.player.heroId
            selectedSaveSlot = slot

            if engine.pendingEncounterState != nil {
                resumingCombat = true
            }

            screen = .worldMap

            if result.hasWarnings {
                loadAlertMessage = result.warnings.joined(separator: "\n")
                showingLoadAlert = true
            }
        } else if let error = result.error {
            loadAlertMessage = error.localizedDescription
            showingLoadAlert = true
        }
    }

    func handleContinueGame(saveManager: SaveManager, engine: TwilightGameEngine, registry: ContentRegistry) {
        let count = saveManager.saveCount

        if count == 0 {
            return
        } else if count == 1 {
            if let slot = saveManager.saveSlots.max(by: { $0.value.savedAt < $1.value.savedAt })?.key {
                loadGame(from: slot, engine: engine, saveManager: saveManager, registry: registry)
            }
        } else {
            screen = .loadSlots
        }
    }

    func dismissLoadAlert() {
        showingLoadAlert = false
        loadAlertMessage = nil
    }
}

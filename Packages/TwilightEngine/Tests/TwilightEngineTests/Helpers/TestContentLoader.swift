import Foundation
@testable import TwilightEngine

/// Helper для загрузки ContentPacks в тестовом окружении пакета TwilightEngine
/// Загружает паки из директории проекта (CoreHeroes + TwilightMarchesActI)
enum TestContentLoader {

    /// Флаг, показывающий загружены ли паки
    private(set) static var isLoaded = false

    /// Загрузить ContentPacks из исходной директории
    /// Безопасно вызывать многократно - загрузка произойдёт только один раз
    static func loadContentPacksIfNeeded() {
        guard !isLoaded else { return }

        let packURLs = findContentPacksURLs()

        guard !packURLs.isEmpty else {
            print("⚠️ TestContentLoader: ContentPacks not found")
            return
        }

        do {
            // Загружаем паки через ContentRegistry
            let registry = ContentRegistry.shared

            // Проверяем, не загружен ли уже
            if registry.loadedPackIds.isEmpty {
                try registry.loadPacks(from: packURLs)
                print("✅ TestContentLoader: Loaded \(packURLs.count) packs")
            }

            isLoaded = true
        } catch {
            print("❌ TestContentLoader: Failed to load packs: \(error)")
        }
    }

    /// Найти пути к ContentPacks
    private static func findContentPacksURLs() -> [URL] {
        // Путь от файла теста к корню проекта:
        // TwilightEngineTests/Helpers/TestContentLoader.swift
        //   → TwilightEngineTests
        //   → Tests
        //   → TwilightEngine
        //   → Packages
        //   → ProjectRoot
        let testFilePath = URL(fileURLWithPath: #filePath)
        let projectRoot = testFilePath
            .deletingLastPathComponent()  // Helpers
            .deletingLastPathComponent()  // TwilightEngineTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // TwilightEngine
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // Project root

        var urls: [URL] = []

        // Character pack (CoreHeroes)
        let coreHeroesPath = projectRoot
            .appendingPathComponent("Packages")
            .appendingPathComponent("CharacterPacks")
            .appendingPathComponent("CoreHeroes")
            .appendingPathComponent("Sources")
            .appendingPathComponent("CoreHeroesContent")
            .appendingPathComponent("Resources")
            .appendingPathComponent("CoreHeroes")

        if FileManager.default.fileExists(atPath: coreHeroesPath.path) {
            urls.append(coreHeroesPath)
        }

        // Story pack (TwilightMarchesActI)
        let storyPackPath = projectRoot
            .appendingPathComponent("Packages")
            .appendingPathComponent("StoryPacks")
            .appendingPathComponent("TwilightMarchesActI")
            .appendingPathComponent("Sources")
            .appendingPathComponent("TwilightMarchesActIContent")
            .appendingPathComponent("Resources")
            .appendingPathComponent("TwilightMarchesActI")

        if FileManager.default.fileExists(atPath: storyPackPath.path) {
            urls.append(storyPackPath)
        }

        if urls.isEmpty {
            print("❌ TestContentLoader: ContentPacks not found")
        }

        return urls
    }

    /// Сбросить состояние (для изолированных тестов)
    static func reset() {
        ContentRegistry.shared.unloadAllPacks()
        CardRegistry.shared.clear()
        AbilityRegistry.shared.clear()
        isLoaded = false
    }
}

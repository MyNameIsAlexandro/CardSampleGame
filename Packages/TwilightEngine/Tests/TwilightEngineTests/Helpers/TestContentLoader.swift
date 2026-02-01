import Foundation
@testable import TwilightEngine

/// Helper для загрузки ContentPacks в тестовом окружении пакета TwilightEngine
/// Загружает паки из директории проекта (CoreHeroes + TwilightMarchesActI)
enum TestContentLoader {

    /// Lock to prevent concurrent content loading from parallel test suites
    private static let lock = NSLock()

    /// Флаг, показывающий загружены ли паки
    private(set) static var isLoaded = false

    /// Загрузить ContentPacks из исходной директории
    /// Безопасно вызывать многократно - загрузка произойдёт только один раз
    static func loadContentPacksIfNeeded() {
        lock.lock()
        defer { lock.unlock() }

        let registry = ContentRegistry.shared

        // Always check actual registry state, not just isLoaded flag.
        // Other test classes may call resetForTesting() which clears the registry.
        guard registry.loadedPackIds.isEmpty else {
            isLoaded = true
            return
        }

        let packURLs = findContentPacksURLs()

        guard !packURLs.isEmpty else {
            print("⚠️ TestContentLoader: ContentPacks not found")
            return
        }

        do {
            try registry.loadPacks(from: packURLs)
            print("✅ TestContentLoader: Loaded \(packURLs.count) packs")
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

        // Character pack (CoreHeroes) — must point to .pack file, not directory
        let coreHeroesPath = projectRoot
            .appendingPathComponent("Packages")
            .appendingPathComponent("CharacterPacks")
            .appendingPathComponent("CoreHeroes")
            .appendingPathComponent("Sources")
            .appendingPathComponent("CoreHeroesContent")
            .appendingPathComponent("Resources")
            .appendingPathComponent("CoreHeroes.pack")

        if FileManager.default.fileExists(atPath: coreHeroesPath.path) {
            urls.append(coreHeroesPath)
        }

        // Story pack (TwilightMarchesActI) — must point to .pack file, not directory
        let storyPackPath = projectRoot
            .appendingPathComponent("Packages")
            .appendingPathComponent("StoryPacks")
            .appendingPathComponent("Season1")
            .appendingPathComponent("TwilightMarchesActI")
            .appendingPathComponent("Sources")
            .appendingPathComponent("TwilightMarchesActIContent")
            .appendingPathComponent("Resources")
            .appendingPathComponent("TwilightMarchesActI.pack")

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
        isLoaded = false
    }
}

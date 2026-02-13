/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/Helpers/TestContentLoader.swift
/// Назначение: Содержит реализацию файла TestContentLoader.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import Foundation
@testable import TwilightEngine

/// Helper for loading ContentPacks in TwilightEngine SwiftPM tests.
/// Loads packs from the project directory (CoreHeroes + TwilightMarchesActI).
enum TestContentLoader {

    private struct CacheState {
        var sharedRegistry: ContentRegistry?
        var cachedPackURLs: [URL]?
    }

    private final class Locked<Value>: @unchecked Sendable {
        private let lock = NSLock()
        private var value: Value

        init(_ value: Value) {
            self.value = value
        }

        func withLock<R>(_ body: (inout Value) -> R) -> R {
            lock.lock()
            defer { lock.unlock() }
            return body(&value)
        }
    }

    private static let cache = Locked(CacheState())

    private static var isVerboseLoggingEnabled: Bool {
        guard let rawValue = ProcessInfo.processInfo.environment["TWILIGHT_TEST_VERBOSE"]?.lowercased() else {
            return false
        }
        return rawValue == "1" || rawValue == "true" || rawValue == "yes" || rawValue == "on"
    }

    private static func verboseLog(_ message: @autoclosure () -> String) {
        guard isVerboseLoggingEnabled else {
            return
        }
        print(message())
    }

    static func sharedLoadedRegistry() -> ContentRegistry {
        cache.withLock { state in

            if let sharedRegistry = state.sharedRegistry, !sharedRegistry.loadedPackIds.isEmpty {
                return sharedRegistry
            }

            let registry = ContentRegistry()

            let packURLs = state.cachedPackURLs ?? findContentPacksURLs()
            state.cachedPackURLs = packURLs

            guard !packURLs.isEmpty else {
                verboseLog("⚠️ TestContentLoader: ContentPacks not found")
                state.sharedRegistry = registry
                return registry
            }

            do {
                try registry.loadPacks(from: packURLs)
                verboseLog("✅ TestContentLoader: Loaded \(packURLs.count) packs (shared)")
            } catch {
                verboseLog("❌ TestContentLoader: Failed to load packs (shared): \(error)")
            }

            state.sharedRegistry = registry
            return registry
        }
    }

    static func makeLoadedRegistry() -> ContentRegistry {
        let registry = ContentRegistry()
        loadContentPacksIfNeeded(into: registry)
        return registry
    }

    static func loadContentPacksIfNeeded(into registry: ContentRegistry) {
        cache.withLock { state in

            guard registry.loadedPackIds.isEmpty else {
                return
            }

            let packURLs = state.cachedPackURLs ?? findContentPacksURLs()
            state.cachedPackURLs = packURLs

            guard !packURLs.isEmpty else {
                verboseLog("⚠️ TestContentLoader: ContentPacks not found")
                return
            }

            do {
                try registry.loadPacks(from: packURLs)
                verboseLog("✅ TestContentLoader: Loaded \(packURLs.count) packs")
            } catch {
                verboseLog("❌ TestContentLoader: Failed to load packs: \(error)")
            }
        }
    }

    private static func findContentPacksURLs() -> [URL] {
        // Path from this test helper to project root:
        // TwilightEngineTests/Helpers/TestContentLoader.swift
        //   -> Helpers
        //   -> TwilightEngineTests
        //   -> Tests
        //   -> TwilightEngine
        //   -> Packages
        //   -> ProjectRoot
        let testFilePath = URL(fileURLWithPath: #filePath)
        let projectRoot = testFilePath
            .deletingLastPathComponent()  // Helpers
            .deletingLastPathComponent()  // TwilightEngineTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // TwilightEngine
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // Project root

        var urls: [URL] = []

        // Character pack (CoreHeroes) - must point to .pack file, not directory.
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

        // Story pack (TwilightMarchesActI) - must point to .pack file, not directory.
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

        return urls
    }
}

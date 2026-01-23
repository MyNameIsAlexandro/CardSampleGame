import Foundation
@testable import CardSampleGame

/// Helper для загрузки ContentPacks в тестовом окружении
/// Загружает паки из исходной директории проекта
enum TestContentLoader {

    /// Флаг, показывающий загружены ли паки
    private(set) static var isLoaded = false

    /// Загрузить ContentPacks из исходной директории
    /// Безопасно вызывать многократно - загрузка произойдёт только один раз
    static func loadContentPacksIfNeeded() {
        guard !isLoaded else { return }

        guard let packURL = findContentPacksURL() else {
            print("⚠️ TestContentLoader: ContentPacks not found")
            return
        }

        do {
            // Загружаем пак через ContentRegistry
            let registry = ContentRegistry.shared

            // Проверяем, не загружен ли уже
            if registry.loadedPackIds.isEmpty {
                try registry.loadPack(from: packURL)
                print("✅ TestContentLoader: Loaded pack from \(packURL.lastPathComponent)")
            }

            isLoaded = true
        } catch {
            print("❌ TestContentLoader: Failed to load pack: \(error)")
        }
    }

    /// Найти путь к ContentPacks
    private static func findContentPacksURL() -> URL? {
        // 1. Попробуем найти через #filePath (работает в тестах)
        let testFilePath = URL(fileURLWithPath: #filePath)
        let projectRoot = testFilePath
            .deletingLastPathComponent()  // TestHelpers
            .deletingLastPathComponent()  // CardSampleGameTests
            .deletingLastPathComponent()  // Project root

        let twilightMarchesPath = projectRoot
            .appendingPathComponent("ContentPacks")
            .appendingPathComponent("TwilightMarches")

        print("🔍 TestContentLoader: Checking path: \(twilightMarchesPath.path)")

        if FileManager.default.fileExists(atPath: twilightMarchesPath.path) {
            print("✅ TestContentLoader: Found ContentPacks at #filePath derived path")
            return twilightMarchesPath
        }

        // 2. Попробуем Bundle основного приложения
        if let mainBundlePath = Bundle.main.url(
            forResource: "TwilightMarches",
            withExtension: nil,
            subdirectory: "ContentPacks"
        ) {
            print("✅ TestContentLoader: Found ContentPacks in main bundle")
            return mainBundlePath
        }

        // 3. Попробуем Bundle тестов
        if let testBundlePath = Bundle(for: BundleToken.self).url(
            forResource: "TwilightMarches",
            withExtension: nil,
            subdirectory: "ContentPacks"
        ) {
            print("✅ TestContentLoader: Found ContentPacks in test bundle")
            return testBundlePath
        }

        // 4. Альтернативный путь
        let altPath = projectRoot
            .deletingLastPathComponent()
            .appendingPathComponent("CardSampleGame")
            .appendingPathComponent("ContentPacks")
            .appendingPathComponent("TwilightMarches")

        if FileManager.default.fileExists(atPath: altPath.path) {
            print("✅ TestContentLoader: Found ContentPacks at alternative path")
            return altPath
        }

        print("❌ TestContentLoader: ContentPacks not found at any path")
        return nil
    }

    /// Сбросить состояние (для изолированных тестов)
    static func reset() {
        ContentRegistry.shared.unloadAllPacks()
        CardRegistry.shared.clear()
        AbilityRegistry.shared.clear()
        isLoaded = false
    }
}

/// Маркер для поиска bundle тестового таргета
private class BundleToken {}

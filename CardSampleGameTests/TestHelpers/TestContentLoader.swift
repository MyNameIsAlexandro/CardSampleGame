import Foundation
import TwilightEngine
import CoreHeroesContent
import TwilightMarchesActIContent

@testable import CardSampleGame

/// Helper для загрузки ContentPacks в тестовом окружении
/// Использует CoreHeroes и TwilightMarchesActI пакеты для получения контента
enum TestContentLoader {

    /// Флаг, показывающий загружены ли паки
    private(set) static var isLoaded = false

    // MARK: - JSON Directory URLs (for PackLoader tests)

    /// URL to CoreHeroes JSON source directory (for testing PackLoader)
    /// Returns the directory containing manifest.json and content files
    static var characterPackJSONURL: URL? {
        // Get .pack URL and derive JSON directory (sibling directory with same name)
        if let packURL = characterPackURL {
            let jsonDirURL = packURL.deletingPathExtension()
            if FileManager.default.fileExists(atPath: jsonDirURL.appendingPathComponent("manifest.json").path) {
                return jsonDirURL
            }
        }
        // Fallback: search directly
        return findJSONDirectory(bundleName: "CoreHeroes_CoreHeroesContent", resourceName: "CoreHeroes")
    }

    /// URL to TwilightMarchesActI JSON source directory (for testing PackLoader)
    /// Returns the directory containing manifest.json and content files
    static var storyPackJSONURL: URL? {
        // Get .pack URL and derive JSON directory (sibling directory with same name)
        if let packURL = storyPackURL {
            let jsonDirURL = packURL.deletingPathExtension()
            if FileManager.default.fileExists(atPath: jsonDirURL.appendingPathComponent("manifest.json").path) {
                return jsonDirURL
            }
        }
        // Fallback: search directly
        return findJSONDirectory(bundleName: "TwilightMarchesActI_TwilightMarchesActIContent", resourceName: "TwilightMarchesActI")
    }

    // MARK: - Binary Pack URLs

    /// URL to CoreHeroes pack (via Bundle.module or bundle search fallback)
    /// Returns nil if the pack cannot be verified to exist with a valid manifest
    static var characterPackURL: URL? {
        #if DEBUG
        print("🔍 TestContentLoader: Looking for CoreHeroes pack")
        print("🔍 CoreHeroesContent.packURL = \(String(describing: CoreHeroesContent.packURL))")
        #endif

        // Try Bundle.module first - expects .pack file
        if let url = CoreHeroesContent.packURL {
            if verifyPackFile(at: url) {
                return url
            }
            #if DEBUG
            print("⚠️ CoreHeroesContent.packURL exists but not a valid .pack file")
            #endif
        }

        // Fallback: search for the .pack file in the test bundle
        let fallback = findPackFile(bundleName: "CoreHeroes_CoreHeroesContent", resourceName: "CoreHeroes")
        #if DEBUG
        print("🔍 Fallback result = \(String(describing: fallback))")
        #endif

        // Verify fallback is valid .pack file
        if let url = fallback, verifyPackFile(at: url) {
            return url
        }

        #if DEBUG
        print("❌ TestContentLoader: No valid CoreHeroes pack found")
        #endif
        return nil
    }

    /// URL to TwilightMarchesActI pack (via Bundle.module or bundle search fallback)
    /// Returns nil if the pack cannot be verified to exist with a valid manifest
    static var storyPackURL: URL? {
        #if DEBUG
        print("🔍 TestContentLoader: Looking for TwilightMarchesActI pack")
        print("🔍 TwilightMarchesActIContent.packURL = \(String(describing: TwilightMarchesActIContent.packURL))")
        #endif

        // Try Bundle.module first - expects .pack file
        if let url = TwilightMarchesActIContent.packURL {
            if verifyPackFile(at: url) {
                return url
            }
            #if DEBUG
            print("⚠️ TwilightMarchesActIContent.packURL exists but not a valid .pack file")
            #endif
        }

        // Fallback: search for the .pack file in the test bundle
        let fallback = findPackFile(bundleName: "TwilightMarchesActI_TwilightMarchesActIContent", resourceName: "TwilightMarchesActI")
        #if DEBUG
        print("🔍 Fallback result = \(String(describing: fallback))")
        #endif

        // Verify fallback is valid .pack file
        if let url = fallback, verifyPackFile(at: url) {
            return url
        }

        #if DEBUG
        print("❌ TestContentLoader: No valid TwilightMarchesActI pack found")
        #endif
        return nil
    }

    /// Загрузить ContentPacks из пакетов
    /// Безопасно вызывать многократно - загрузка произойдёт только один раз
    static func loadContentPacksIfNeeded() {
        // Also reload if registry was reset externally
        guard !isLoaded || ContentRegistry.shared.loadedPackIds.isEmpty else { return }

        do {
            // Загружаем паки через ContentRegistry
            let registry = ContentRegistry.shared

            // Проверяем, не загружен ли уже
            if registry.loadedPackIds.isEmpty {
                var urls: [URL] = []

                // Load character pack first (priority order)
                if let heroesURL = characterPackURL {
                    urls.append(heroesURL)
                }

                // Load story pack
                if let storyURL = storyPackURL {
                    urls.append(storyURL)
                }

                guard !urls.isEmpty else {
                    print("⚠️ TestContentLoader: ContentPacks not found in packages")
                    return
                }

                try registry.loadPacks(from: urls)
                print("✅ TestContentLoader: Loaded \(urls.count) packs")
            }

            isLoaded = true
        } catch {
            print("❌ TestContentLoader: Failed to load packs: \(error)")
        }
    }

    /// Find .pack file by searching in test bundle and all related locations
    private static func findPackFile(bundleName: String, resourceName: String) -> URL? {
        let testBundle = Bundle(for: BundleToken.self)
        let packFileName = "\(resourceName).pack"

        #if DEBUG
        print("🔍 findPackFile: Looking for \(bundleName).bundle/\(packFileName)")
        print("🔍 Test bundle path: \(testBundle.bundlePath)")
        #endif

        // Method 1: Direct URL lookup in test bundle
        if let url = testBundle.url(forResource: bundleName, withExtension: "bundle") {
            let packPath = url.appendingPathComponent(packFileName)
            #if DEBUG
            print("🔍 Method 1: Found bundle at \(url)")
            print("🔍 Method 1: Checking \(packPath.path)")
            #endif
            if FileManager.default.fileExists(atPath: packPath.path) {
                #if DEBUG
                print("✅ Method 1: Found .pack file!")
                #endif
                return packPath
            }
        }

        // Method 2: Direct path construction in test bundle
        if let testBundlePath = testBundle.bundlePath as NSString? {
            let bundlePath = testBundlePath.appendingPathComponent("\(bundleName).bundle")
            let packPath = (bundlePath as NSString).appendingPathComponent(packFileName)
            #if DEBUG
            print("🔍 Method 2: Checking \(packPath)")
            #endif
            if FileManager.default.fileExists(atPath: packPath) {
                #if DEBUG
                print("✅ Method 2: Found .pack file!")
                #endif
                return URL(fileURLWithPath: packPath)
            }
        }

        // Method 3: Search in Frameworks folder
        if let testBundlePath = testBundle.bundlePath as NSString? {
            let frameworksPath = testBundlePath.appendingPathComponent("Frameworks")
            #if DEBUG
            print("🔍 Method 3: Checking frameworks at \(frameworksPath)")
            #endif
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: frameworksPath) {
                #if DEBUG
                print("🔍 Method 3: Found frameworks: \(contents)")
                #endif
                for item in contents where item.hasSuffix(".framework") {
                    let frameworkPath = (frameworksPath as NSString).appendingPathComponent(item)
                    let innerBundlePath = (frameworkPath as NSString).appendingPathComponent("\(bundleName).bundle")
                    let packPath = (innerBundlePath as NSString).appendingPathComponent(packFileName)
                    if FileManager.default.fileExists(atPath: packPath) {
                        #if DEBUG
                        print("✅ Method 3: Found .pack file at \(packPath)!")
                        #endif
                        return URL(fileURLWithPath: packPath)
                    }
                }
            }
        }

        // Method 4: Check main app bundle
        if let mainBundlePath = Bundle.main.bundlePath as NSString? {
            let bundlePath = mainBundlePath.appendingPathComponent("\(bundleName).bundle")
            let packPath = (bundlePath as NSString).appendingPathComponent(packFileName)
            #if DEBUG
            print("🔍 Method 4: Checking main bundle \(packPath)")
            #endif
            if FileManager.default.fileExists(atPath: packPath) {
                #if DEBUG
                print("✅ Method 4: Found .pack file!")
                #endif
                return URL(fileURLWithPath: packPath)
            }
        }

        #if DEBUG
        print("❌ findPackFile: Pack file not found for \(bundleName).bundle/\(packFileName)")
        #endif
        return nil
    }

    /// Verify that a URL points to a valid .pack file
    private static func verifyPackFile(at url: URL) -> Bool {
        #if DEBUG
        print("🔍 verifyPackFile: checking \(url.path)")
        #endif

        // Check file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            #if DEBUG
            print("❌ verifyPackFile: file does not exist")
            #endif
            return false
        }

        // Verify it's a valid .pack file using BinaryPackReader
        let isValid = BinaryPackReader.isValidPackFile(url)
        #if DEBUG
        print(isValid ? "✅ verifyPackFile: valid .pack file" : "❌ verifyPackFile: not a valid .pack file")
        #endif
        return isValid
    }

    /// Find JSON source directory (for PackLoader tests)
    private static func findJSONDirectory(bundleName: String, resourceName: String) -> URL? {
        let testBundle = Bundle(for: BundleToken.self)

        // Method 1: Direct URL lookup in test bundle
        if let url = testBundle.url(forResource: bundleName, withExtension: "bundle") {
            let jsonDirPath = url.appendingPathComponent(resourceName)
            let manifestPath = jsonDirPath.appendingPathComponent("manifest.json")
            if FileManager.default.fileExists(atPath: manifestPath.path) {
                return jsonDirPath
            }
        }

        // Method 2: Direct path construction
        if let testBundlePath = testBundle.bundlePath as NSString? {
            let bundlePath = testBundlePath.appendingPathComponent("\(bundleName).bundle")
            let jsonDirPath = (bundlePath as NSString).appendingPathComponent(resourceName)
            let manifestPath = (jsonDirPath as NSString).appendingPathComponent("manifest.json")
            if FileManager.default.fileExists(atPath: manifestPath) {
                return URL(fileURLWithPath: jsonDirPath)
            }
        }

        // Method 3: Search in Frameworks folder
        if let testBundlePath = testBundle.bundlePath as NSString? {
            let frameworksPath = testBundlePath.appendingPathComponent("Frameworks")
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: frameworksPath) {
                for item in contents where item.hasSuffix(".framework") {
                    let frameworkPath = (frameworksPath as NSString).appendingPathComponent(item)
                    let innerBundlePath = (frameworkPath as NSString).appendingPathComponent("\(bundleName).bundle")
                    let jsonDirPath = (innerBundlePath as NSString).appendingPathComponent(resourceName)
                    let manifestPath = (jsonDirPath as NSString).appendingPathComponent("manifest.json")
                    if FileManager.default.fileExists(atPath: manifestPath) {
                        return URL(fileURLWithPath: jsonDirPath)
                    }
                }
            }
        }

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

// Helper class to get the test bundle
private class BundleToken {}

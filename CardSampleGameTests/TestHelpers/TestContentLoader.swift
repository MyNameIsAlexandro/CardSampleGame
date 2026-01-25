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

    /// URL to CoreHeroes pack (via Bundle.module or bundle search fallback)
    /// Returns nil if the pack cannot be verified to exist with a valid manifest
    static var characterPackURL: URL? {
        #if DEBUG
        print("🔍 TestContentLoader: Looking for CoreHeroes pack")
        print("🔍 CoreHeroesContent.packURL = \(String(describing: CoreHeroesContent.packURL))")
        #endif

        // Try Bundle.module first
        if let url = CoreHeroesContent.packURL {
            if verifyPackHasManifest(at: url) {
                return url
            }
            #if DEBUG
            print("⚠️ CoreHeroesContent.packURL exists but manifest not readable")
            #endif
        }

        // Fallback: search for the resource bundle in the test bundle
        let fallback = findResourceBundle(bundleName: "CoreHeroes_CoreHeroesContent", resourceName: "CoreHeroes")
        #if DEBUG
        print("🔍 Fallback result = \(String(describing: fallback))")
        #endif

        // Verify fallback has valid manifest
        if let url = fallback, verifyPackHasManifest(at: url) {
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

        // Try Bundle.module first
        if let url = TwilightMarchesActIContent.packURL {
            if verifyPackHasManifest(at: url) {
                return url
            }
            #if DEBUG
            print("⚠️ TwilightMarchesActIContent.packURL exists but manifest not readable")
            #endif
        }

        // Fallback: search for the resource bundle in the test bundle
        let fallback = findResourceBundle(bundleName: "TwilightMarchesActI_TwilightMarchesActIContent", resourceName: "TwilightMarchesActI")
        #if DEBUG
        print("🔍 Fallback result = \(String(describing: fallback))")
        #endif

        // Verify fallback has valid manifest
        if let url = fallback, verifyPackHasManifest(at: url) {
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

    /// Find resource bundle by searching in test bundle and all related locations
    private static func findResourceBundle(bundleName: String, resourceName: String) -> URL? {
        let testBundle = Bundle(for: BundleToken.self)

        #if DEBUG
        print("🔍 findResourceBundle: Looking for \(bundleName).bundle/\(resourceName)")
        print("🔍 Test bundle path: \(testBundle.bundlePath)")
        #endif

        // Method 1: Direct URL lookup in test bundle
        if let url = testBundle.url(forResource: bundleName, withExtension: "bundle") {
            let resourcePath = url.appendingPathComponent(resourceName)
            #if DEBUG
            print("🔍 Method 1: Found bundle at \(url)")
            print("🔍 Method 1: Checking \(resourcePath.path)")
            #endif
            if FileManager.default.fileExists(atPath: resourcePath.path) {
                #if DEBUG
                print("✅ Method 1: Found resource!")
                #endif
                return resourcePath
            }
        }

        // Method 2: Direct path construction in test bundle
        if let testBundlePath = testBundle.bundlePath as NSString? {
            let bundlePath = testBundlePath.appendingPathComponent("\(bundleName).bundle")
            let resourcePath = (bundlePath as NSString).appendingPathComponent(resourceName)
            #if DEBUG
            print("🔍 Method 2: Checking \(resourcePath)")
            #endif
            if FileManager.default.fileExists(atPath: resourcePath) {
                #if DEBUG
                print("✅ Method 2: Found resource!")
                #endif
                return URL(fileURLWithPath: resourcePath)
            }
        }

        // Method 3: Search in Frameworks folder
        if let testBundlePath = testBundle.bundlePath as NSString? {
            let frameworksPath = testBundlePath.appendingPathComponent("Frameworks")
            #if DEBUG
            print("🔍 Method 3: Checking frameworks at \(frameworksPath)")
            #endif
            // Look for framework containing the bundle
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: frameworksPath) {
                #if DEBUG
                print("🔍 Method 3: Found frameworks: \(contents)")
                #endif
                for item in contents where item.hasSuffix(".framework") {
                    let frameworkPath = (frameworksPath as NSString).appendingPathComponent(item)
                    let innerBundlePath = (frameworkPath as NSString).appendingPathComponent("\(bundleName).bundle")
                    let resourcePath = (innerBundlePath as NSString).appendingPathComponent(resourceName)
                    if FileManager.default.fileExists(atPath: resourcePath) {
                        #if DEBUG
                        print("✅ Method 3: Found resource at \(resourcePath)!")
                        #endif
                        return URL(fileURLWithPath: resourcePath)
                    }
                }
            }
        }

        // Method 4: Check main app bundle
        if let mainBundlePath = Bundle.main.bundlePath as NSString? {
            let bundlePath = mainBundlePath.appendingPathComponent("\(bundleName).bundle")
            let resourcePath = (bundlePath as NSString).appendingPathComponent(resourceName)
            #if DEBUG
            print("🔍 Method 4: Checking main bundle \(resourcePath)")
            #endif
            if FileManager.default.fileExists(atPath: resourcePath) {
                #if DEBUG
                print("✅ Method 4: Found resource!")
                #endif
                return URL(fileURLWithPath: resourcePath)
            }
        }

        #if DEBUG
        print("❌ findResourceBundle: Resource not found for \(bundleName).bundle/\(resourceName)")
        #endif
        return nil
    }

    /// Verify that a pack URL contains a readable and decodable manifest.json
    private static func verifyPackHasManifest(at url: URL) -> Bool {
        let manifestURL = url.appendingPathComponent("manifest.json")

        #if DEBUG
        print("🔍 verifyPackHasManifest: checking \(manifestURL.path)")
        #endif

        // Check file exists
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            #if DEBUG
            print("❌ verifyPackHasManifest: file does not exist")
            #endif
            return false
        }

        // Try to actually read and decode the manifest
        do {
            let data = try Data(contentsOf: manifestURL)
            // Try to decode as JSON to verify it's valid
            _ = try JSONSerialization.jsonObject(with: data, options: [])
            #if DEBUG
            print("✅ verifyPackHasManifest: manifest is valid JSON (\(data.count) bytes)")
            #endif
            return true
        } catch {
            #if DEBUG
            print("❌ verifyPackHasManifest: failed to read/decode - \(error)")
            #endif
            return false
        }
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

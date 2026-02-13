/// Файл: CardSampleGameTests/TestHelpers/TestContentLoader.swift
/// Назначение: Содержит реализацию файла TestContentLoader.swift.
/// Зона ответственности: Фиксирует проверяемый контракт и не содержит production-логики.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import Foundation
import TwilightEngine
import PackAuthoring
import CoreHeroesContent
import TwilightMarchesActIContent

@testable import CardSampleGame

/// Helper для загрузки ContentPacks в тестовом окружении
/// Использует CoreHeroes и TwilightMarchesActI пакеты для получения контента
enum TestContentLoader {

    enum Error: Swift.Error, LocalizedError {
        case missingPackURLs

        var errorDescription: String? {
            switch self {
            case .missingPackURLs:
                return "Missing test pack URLs (CoreHeroes/TwilightMarchesActI)."
            }
        }
    }

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
        verboseLog("🔍 TestContentLoader: Looking for CoreHeroes pack")
        verboseLog("🔍 CoreHeroesContent.packURL = \(String(describing: CoreHeroesContent.packURL))")

        // Try Bundle.module first - expects .pack file
        if let url = CoreHeroesContent.packURL {
            if verifyPackFile(at: url) {
                return url
            }
            verboseLog("⚠️ CoreHeroesContent.packURL exists but not a valid .pack file")
        }

        // Fallback: search for the .pack file in the test bundle
        let fallback = findPackFile(bundleName: "CoreHeroes_CoreHeroesContent", resourceName: "CoreHeroes")
        verboseLog("🔍 Fallback result = \(String(describing: fallback))")

        // Verify fallback is valid .pack file
        if let url = fallback, verifyPackFile(at: url) {
            return url
        }

        verboseLog("❌ TestContentLoader: No valid CoreHeroes pack found")
        return nil
    }

    /// URL to TwilightMarchesActI pack (via Bundle.module or bundle search fallback)
    /// Returns nil if the pack cannot be verified to exist with a valid manifest
    static var storyPackURL: URL? {
        verboseLog("🔍 TestContentLoader: Looking for TwilightMarchesActI pack")
        verboseLog("🔍 TwilightMarchesActIContent.packURL = \(String(describing: TwilightMarchesActIContent.packURL))")

        // Try Bundle.module first - expects .pack file
        if let url = TwilightMarchesActIContent.packURL {
            if verifyPackFile(at: url) {
                return url
            }
            verboseLog("⚠️ TwilightMarchesActIContent.packURL exists but not a valid .pack file")
        }

        // Fallback: search for the .pack file in the test bundle
        let fallback = findPackFile(bundleName: "TwilightMarchesActI_TwilightMarchesActIContent", resourceName: "TwilightMarchesActI")
        verboseLog("🔍 Fallback result = \(String(describing: fallback))")

        // Verify fallback is valid .pack file
        if let url = fallback, verifyPackFile(at: url) {
            return url
        }

        verboseLog("❌ TestContentLoader: No valid TwilightMarchesActI pack found")
        return nil
    }

    /// Create a fresh ContentRegistry with the standard test packs loaded.
    /// Intent: avoid global shared registries (tests must be isolated/deterministic).
    static func makeStandardRegistry() throws -> ContentRegistry {
        var urls: [URL] = []
        if let heroesURL = characterPackURL { urls.append(heroesURL) }
        if let storyURL = storyPackURL { urls.append(storyURL) }
        guard !urls.isEmpty else { throw Error.missingPackURLs }

        let registry = ContentRegistry()
        try registry.loadPacks(from: urls)
        return registry
    }

    /// Create a fresh EngineServices configured for deterministic tests.
    static func makeStandardEngineServices(seed: UInt64 = 0) throws -> EngineServices {
        let registry = try makeStandardRegistry()
        let localizationManager = LocalizationManager()
        let rng = WorldRNG(seed: seed)
        return EngineServices(rng: rng, contentRegistry: registry, localizationManager: localizationManager)
    }

    /// Find .pack file by searching in test bundle and all related locations
    private static func findPackFile(bundleName: String, resourceName: String) -> URL? {
        let testBundle = Bundle(for: BundleToken.self)
        let packFileName = "\(resourceName).pack"

        verboseLog("🔍 findPackFile: Looking for \(bundleName).bundle/\(packFileName)")
        verboseLog("🔍 Test bundle path: \(testBundle.bundlePath)")

        // Method 1: Direct URL lookup in test bundle
        if let url = testBundle.url(forResource: bundleName, withExtension: "bundle") {
            let packPath = url.appendingPathComponent(packFileName)
            verboseLog("🔍 Method 1: Found bundle at \(url)")
            verboseLog("🔍 Method 1: Checking \(packPath.path)")
            if FileManager.default.fileExists(atPath: packPath.path) {
                verboseLog("✅ Method 1: Found .pack file!")
                return packPath
            }
        }

        // Method 2: Direct path construction in test bundle
        if let testBundlePath = testBundle.bundlePath as NSString? {
            let bundlePath = testBundlePath.appendingPathComponent("\(bundleName).bundle")
            let packPath = (bundlePath as NSString).appendingPathComponent(packFileName)
            verboseLog("🔍 Method 2: Checking \(packPath)")
            if FileManager.default.fileExists(atPath: packPath) {
                verboseLog("✅ Method 2: Found .pack file!")
                return URL(fileURLWithPath: packPath)
            }
        }

        // Method 3: Search in Frameworks folder
        if let testBundlePath = testBundle.bundlePath as NSString? {
            let frameworksPath = testBundlePath.appendingPathComponent("Frameworks")
            verboseLog("🔍 Method 3: Checking frameworks at \(frameworksPath)")
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: frameworksPath) {
                verboseLog("🔍 Method 3: Found frameworks: \(contents)")
                for item in contents where item.hasSuffix(".framework") {
                    let frameworkPath = (frameworksPath as NSString).appendingPathComponent(item)
                    let innerBundlePath = (frameworkPath as NSString).appendingPathComponent("\(bundleName).bundle")
                    let packPath = (innerBundlePath as NSString).appendingPathComponent(packFileName)
                    if FileManager.default.fileExists(atPath: packPath) {
                        verboseLog("✅ Method 3: Found .pack file at \(packPath)!")
                        return URL(fileURLWithPath: packPath)
                    }
                }
            }
        }

        // Method 4: Check main app bundle
        if let mainBundlePath = Bundle.main.bundlePath as NSString? {
            let bundlePath = mainBundlePath.appendingPathComponent("\(bundleName).bundle")
            let packPath = (bundlePath as NSString).appendingPathComponent(packFileName)
            verboseLog("🔍 Method 4: Checking main bundle \(packPath)")
            if FileManager.default.fileExists(atPath: packPath) {
                verboseLog("✅ Method 4: Found .pack file!")
                return URL(fileURLWithPath: packPath)
            }
        }

        verboseLog("❌ findPackFile: Pack file not found for \(bundleName).bundle/\(packFileName)")
        return nil
    }

    /// Verify that a URL points to a valid .pack file
    private static func verifyPackFile(at url: URL) -> Bool {
        verboseLog("🔍 verifyPackFile: checking \(url.path)")

        // Check file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            verboseLog("❌ verifyPackFile: file does not exist")
            return false
        }

        // Verify it's a valid .pack file using BinaryPackReader
        let isValid = BinaryPackReader.isValidPackFile(url)
        verboseLog(isValid ? "✅ verifyPackFile: valid .pack file" : "❌ verifyPackFile: not a valid .pack file")
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

    // NOTE: No global reset needed. Call `makeStandardRegistry()` per-test.
}

// Helper class to get the test bundle
private class BundleToken {}

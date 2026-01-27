import Foundation

/// Helper to locate pack JSON directories from SPM test context
enum PackAuthoringTestHelper {

    /// Project root, derived from this file's path
    static let projectRoot: URL = {
        // PackAuthoringTests/PackAuthoringTestHelper.swift
        //   → PackAuthoringTests → Tests → TwilightEngine → Packages → ProjectRoot
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // PackAuthoringTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // TwilightEngine
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // Project root
    }()

    /// URL to TwilightMarchesActI JSON source directory
    static var storyPackJSONURL: URL? {
        let url = projectRoot
            .appendingPathComponent("Packages/StoryPacks/Season1/TwilightMarchesActI/Sources/TwilightMarchesActIContent/Resources/TwilightMarchesActI")
        guard FileManager.default.fileExists(atPath: url.appendingPathComponent("manifest.json").path) else {
            return nil
        }
        return url
    }

    /// URL to CoreHeroes JSON source directory
    static var characterPackJSONURL: URL? {
        let url = projectRoot
            .appendingPathComponent("Packages/CharacterPacks/CoreHeroes/Sources/CoreHeroesContent/Resources/CoreHeroes")
        guard FileManager.default.fileExists(atPath: url.appendingPathComponent("manifest.json").path) else {
            return nil
        }
        return url
    }
}

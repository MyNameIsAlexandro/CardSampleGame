/// Файл: Packages/TwilightEngine/Tests/PackAuthoringTests/PackDecompilerTests.swift
/// Назначение: Содержит реализацию файла PackDecompilerTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
import TwilightEngine
import PackAuthoring

/// Tests for PackDecompiler functionality
/// PackDecompiler extracts binary .pack files back to JSON directory structure
final class PackDecompilerTests: XCTestCase {

    // MARK: - Properties

    private var characterPackURL: URL?
    private var storyPackURL: URL?
    private var compiledPackURL: URL!
    private var decompileOutputURL: URL!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        characterPackURL = PackAuthoringTestHelper.characterPackJSONURL
        storyPackURL = PackAuthoringTestHelper.storyPackJSONURL

        compiledPackURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DecompilerTest_\(UUID().uuidString)")
            .appendingPathExtension("pack")

        decompileOutputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DecompilerOutput_\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: compiledPackURL)
        try? FileManager.default.removeItem(at: decompileOutputURL)
        characterPackURL = nil
        storyPackURL = nil
        super.tearDown()
    }

    // MARK: - Basic Decompile Tests

    func testDecompileCreatesManifest() throws {
        let url = try XCTUnwrap(characterPackURL, "CoreHeroes JSON not available")

        // Compile first
        try PackCompiler.compile(from: url, to: compiledPackURL)

        // Decompile
        try PackDecompiler.decompile(from: compiledPackURL, to: decompileOutputURL)

        // Verify manifest exists
        let manifestURL = decompileOutputURL.appendingPathComponent("manifest.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: manifestURL.path), "Should create manifest.json")

        // Verify manifest is valid JSON
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONSerialization.jsonObject(with: manifestData) as? [String: Any]
        XCTAssertNotNil(manifest, "Manifest should be valid JSON")
        XCTAssertEqual(manifest?["id"] as? String, "core-heroes")
        XCTAssertEqual(manifest?["type"] as? String, "character")
    }

    func testDecompileCreatesCorrectDirectoryStructure() throws {
        let url = try XCTUnwrap(characterPackURL, "CoreHeroes JSON not available")

        try PackCompiler.compile(from: url, to: compiledPackURL)
        try PackDecompiler.decompile(from: compiledPackURL, to: decompileOutputURL)

        // Character pack should have Characters directory
        let charactersDir = decompileOutputURL.appendingPathComponent("Characters")
        XCTAssertTrue(FileManager.default.fileExists(atPath: charactersDir.path), "Should create Characters directory")

        // Should have heroes.json
        let heroesURL = charactersDir.appendingPathComponent("heroes.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: heroesURL.path), "Should create heroes.json")

        // Should have hero_abilities.json
        let abilitiesURL = charactersDir.appendingPathComponent("hero_abilities.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: abilitiesURL.path), "Should create hero_abilities.json")

        // Should have Cards directory
        let cardsDir = decompileOutputURL.appendingPathComponent("Cards")
        XCTAssertTrue(FileManager.default.fileExists(atPath: cardsDir.path), "Should create Cards directory")

        let cardsURL = cardsDir.appendingPathComponent("cards.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: cardsURL.path), "Should create cards.json")
    }

    func testDecompileStoryPackDirectoryStructure() throws {
        let url = try XCTUnwrap(storyPackURL, "TwilightMarchesActI JSON not available")

        try PackCompiler.compile(from: url, to: compiledPackURL)
        try PackDecompiler.decompile(from: compiledPackURL, to: decompileOutputURL)

        // Story pack should have Campaign directory
        let campaignDir = decompileOutputURL.appendingPathComponent("Campaign")
        XCTAssertTrue(FileManager.default.fileExists(atPath: campaignDir.path), "Should create Campaign directory")

        // Should have regions.json
        let regionsURL = campaignDir.appendingPathComponent("regions.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: regionsURL.path), "Should create regions.json")

        // Should have events.json
        let eventsURL = campaignDir.appendingPathComponent("events.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: eventsURL.path), "Should create events.json")

        // Should have Enemies directory
        let enemiesDir = decompileOutputURL.appendingPathComponent("Enemies")
        XCTAssertTrue(FileManager.default.fileExists(atPath: enemiesDir.path), "Should create Enemies directory")
    }

    // MARK: - Roundtrip Tests

    func testDecompileRoundTrip() throws {
        let url = try XCTUnwrap(characterPackURL, "CoreHeroes JSON not available")

        // Compile original
        try PackCompiler.compile(from: url, to: compiledPackURL)
        let originalContent = try BinaryPackReader.loadContent(from: compiledPackURL)

        // Decompile
        try PackDecompiler.decompile(from: compiledPackURL, to: decompileOutputURL)

        // Recompile from decompiled
        let recompiledURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Recompiled_\(UUID().uuidString)")
            .appendingPathExtension("pack")
        defer { try? FileManager.default.removeItem(at: recompiledURL) }

        try PackCompiler.compile(from: decompileOutputURL, to: recompiledURL)
        let recompiledContent = try BinaryPackReader.loadContent(from: recompiledURL)

        // Verify content matches
        XCTAssertEqual(recompiledContent.manifest.packId, originalContent.manifest.packId)
        XCTAssertEqual(recompiledContent.manifest.version, originalContent.manifest.version)
        XCTAssertEqual(recompiledContent.manifest.packType, originalContent.manifest.packType)
        XCTAssertEqual(recompiledContent.heroes.count, originalContent.heroes.count)
        XCTAssertEqual(recompiledContent.cards.count, originalContent.cards.count)
        XCTAssertEqual(recompiledContent.abilities.count, originalContent.abilities.count)

        // Verify hero IDs match
        let originalHeroIds = Set(originalContent.heroes.keys)
        let recompiledHeroIds = Set(recompiledContent.heroes.keys)
        XCTAssertEqual(recompiledHeroIds, originalHeroIds, "Hero IDs should match after roundtrip")
    }

    func testDecompileRoundTripStoryPack() throws {
        let url = try XCTUnwrap(storyPackURL, "TwilightMarchesActI JSON not available")

        // Compile original
        try PackCompiler.compile(from: url, to: compiledPackURL)
        let originalContent = try BinaryPackReader.loadContent(from: compiledPackURL)

        // Decompile
        try PackDecompiler.decompile(from: compiledPackURL, to: decompileOutputURL)

        // Recompile from decompiled
        let recompiledURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecompiledStory_\(UUID().uuidString)")
            .appendingPathExtension("pack")
        defer { try? FileManager.default.removeItem(at: recompiledURL) }

        try PackCompiler.compile(from: decompileOutputURL, to: recompiledURL)
        let recompiledContent = try BinaryPackReader.loadContent(from: recompiledURL)

        // Verify counts match
        XCTAssertEqual(recompiledContent.regions.count, originalContent.regions.count, "Region count should match")
        XCTAssertEqual(recompiledContent.events.count, originalContent.events.count, "Event count should match")
        XCTAssertEqual(recompiledContent.quests.count, originalContent.quests.count, "Quest count should match")
        XCTAssertEqual(recompiledContent.enemies.count, originalContent.enemies.count, "Enemy count should match")
    }

    // MARK: - DecompileWithResult Tests

    func testDecompileWithResultReportsSummary() throws {
        let url = try XCTUnwrap(characterPackURL, "CoreHeroes JSON not available")

        try PackCompiler.compile(from: url, to: compiledPackURL)

        let result = try PackDecompiler.decompileWithResult(from: compiledPackURL, to: decompileOutputURL)

        XCTAssertEqual(result.packId, "core-heroes")
        XCTAssertEqual(result.packType, .character)
        XCTAssertGreaterThan(result.filesWritten, 0, "Should report files written")
        XCTAssertFalse(result.summary.isEmpty, "Should have summary")
        XCTAssertTrue(result.summary.contains("core-heroes"), "Summary should contain pack ID")
    }

    // MARK: - Manifest Path Tests

    func testManifestContainsCorrectPaths() throws {
        let url = try XCTUnwrap(characterPackURL, "CoreHeroes JSON not available")

        try PackCompiler.compile(from: url, to: compiledPackURL)
        try PackDecompiler.decompile(from: compiledPackURL, to: decompileOutputURL)

        // Read manifest
        let manifestURL = decompileOutputURL.appendingPathComponent("manifest.json")
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONSerialization.jsonObject(with: manifestData) as? [String: Any]

        // Verify paths point to actual files
        if let heroesPath = manifest?["heroes_path"] as? String {
            let heroesURL = decompileOutputURL.appendingPathComponent(heroesPath)
            XCTAssertTrue(FileManager.default.fileExists(atPath: heroesURL.path),
                         "heroes_path should point to existing file")
        }

        if let cardsPath = manifest?["cards_path"] as? String {
            let cardsURL = decompileOutputURL.appendingPathComponent(cardsPath)
            XCTAssertTrue(FileManager.default.fileExists(atPath: cardsURL.path),
                         "cards_path should point to existing file")
        }

        if let abilitiesPath = manifest?["abilities_path"] as? String {
            let abilitiesURL = decompileOutputURL.appendingPathComponent(abilitiesPath)
            XCTAssertTrue(FileManager.default.fileExists(atPath: abilitiesURL.path),
                         "abilities_path should point to existing file")
        }
    }

    func testManifestOmitsEmptyPaths() throws {
        let url = try XCTUnwrap(characterPackURL, "CoreHeroes JSON not available")

        try PackCompiler.compile(from: url, to: compiledPackURL)
        try PackDecompiler.decompile(from: compiledPackURL, to: decompileOutputURL)

        // Read manifest
        let manifestURL = decompileOutputURL.appendingPathComponent("manifest.json")
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONSerialization.jsonObject(with: manifestData) as? [String: Any]

        // Character pack should NOT have regions_path (no regions)
        XCTAssertNil(manifest?["regions_path"], "Character pack should not have regions_path")
        XCTAssertNil(manifest?["events_path"], "Character pack should not have events_path")
        XCTAssertNil(manifest?["quests_path"], "Character pack should not have quests_path")
    }

    // MARK: - Error Tests

    func testDecompileNonExistentFileThrows() {
        let badURL = URL(fileURLWithPath: "/nonexistent/file.pack")

        XCTAssertThrowsError(try PackDecompiler.decompile(from: badURL, to: decompileOutputURL))
    }

    func testDecompileOverwritesExistingDirectory() throws {
        let url = try XCTUnwrap(characterPackURL, "CoreHeroes JSON not available")

        try PackCompiler.compile(from: url, to: compiledPackURL)

        // Create existing directory with some content
        try FileManager.default.createDirectory(at: decompileOutputURL, withIntermediateDirectories: true)
        let existingFile = decompileOutputURL.appendingPathComponent("existing.txt")
        try "test".write(to: existingFile, atomically: true, encoding: .utf8)

        // Decompile should replace directory
        try PackDecompiler.decompile(from: compiledPackURL, to: decompileOutputURL)

        // Old file should be gone
        XCTAssertFalse(FileManager.default.fileExists(atPath: existingFile.path),
                       "Decompile should replace existing directory")

        // New content should exist
        let manifestURL = decompileOutputURL.appendingPathComponent("manifest.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: manifestURL.path))
    }

    // MARK: - Content Integrity Tests

    func testDecompiledHeroesAreValidJSON() throws {
        let url = try XCTUnwrap(characterPackURL, "CoreHeroes JSON not available")

        try PackCompiler.compile(from: url, to: compiledPackURL)
        try PackDecompiler.decompile(from: compiledPackURL, to: decompileOutputURL)

        let heroesURL = decompileOutputURL.appendingPathComponent("Characters/heroes.json")
        let heroesData = try Data(contentsOf: heroesURL)
        let heroes = try JSONSerialization.jsonObject(with: heroesData) as? [[String: Any]]

        XCTAssertNotNil(heroes, "Heroes should be a JSON array")
        XCTAssertGreaterThan(heroes?.count ?? 0, 0, "Should have at least one hero")

        // Each hero should have required fields
        if let firstHero = heroes?.first {
            XCTAssertNotNil(firstHero["id"], "Hero should have id")
            XCTAssertNotNil(firstHero["name"], "Hero should have name")
        }
    }

    func testDecompiledCardsAreValidJSON() throws {
        let url = try XCTUnwrap(characterPackURL, "CoreHeroes JSON not available")

        try PackCompiler.compile(from: url, to: compiledPackURL)
        try PackDecompiler.decompile(from: compiledPackURL, to: decompileOutputURL)

        let cardsURL = decompileOutputURL.appendingPathComponent("Cards/cards.json")
        let cardsData = try Data(contentsOf: cardsURL)
        let cards = try JSONSerialization.jsonObject(with: cardsData) as? [[String: Any]]

        XCTAssertNotNil(cards, "Cards should be a JSON array")
        XCTAssertGreaterThan(cards?.count ?? 0, 0, "Should have at least one card")

        // Each card should have required fields
        if let firstCard = cards?.first {
            XCTAssertNotNil(firstCard["id"], "Card should have id")
            XCTAssertNotNil(firstCard["name"], "Card should have name")
        }
    }
}

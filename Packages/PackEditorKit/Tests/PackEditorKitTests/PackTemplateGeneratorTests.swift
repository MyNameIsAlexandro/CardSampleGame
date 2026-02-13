/// Файл: Packages/PackEditorKit/Tests/PackEditorKitTests/PackTemplateGeneratorTests.swift
/// Назначение: Содержит реализацию файла PackTemplateGeneratorTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import PackEditorKit
import TwilightEngine

final class PackTemplateGeneratorTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PackTemplateGenTests-\(ProcessInfo.processInfo.globallyUniqueString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testGenerateCampaignPack() throws {
        let opts = PackTemplateGenerator.Options(
            packId: "my-campaign",
            displayName: "My Campaign",
            packType: .campaign,
            author: "Test"
        )
        let packDir = try PackTemplateGenerator.generate(at: tempDir, options: opts)
        let fm = FileManager.default

        XCTAssertTrue(fm.fileExists(atPath: packDir.appendingPathComponent("manifest.json").path))
        XCTAssertTrue(fm.fileExists(atPath: packDir.appendingPathComponent("Campaign").path))
        XCTAssertTrue(fm.fileExists(atPath: packDir.appendingPathComponent("Enemies").path))
        XCTAssertTrue(fm.fileExists(atPath: packDir.appendingPathComponent("Cards").path))
        XCTAssertTrue(fm.fileExists(atPath: packDir.appendingPathComponent("Balance").path))
        XCTAssertTrue(fm.fileExists(atPath: packDir.appendingPathComponent("Localization").path))
    }

    func testGenerateCharacterPack() throws {
        let opts = PackTemplateGenerator.Options(
            packId: "my-hero",
            displayName: "My Hero",
            packType: .character,
            author: "Test"
        )
        let packDir = try PackTemplateGenerator.generate(at: tempDir, options: opts)
        let fm = FileManager.default

        XCTAssertTrue(fm.fileExists(atPath: packDir.appendingPathComponent("Characters").path))
        XCTAssertTrue(fm.fileExists(atPath: packDir.appendingPathComponent("Cards").path))
        XCTAssertTrue(fm.fileExists(atPath: packDir.appendingPathComponent("Localization").path))
        // Should NOT have campaign-specific dirs
        XCTAssertFalse(fm.fileExists(atPath: packDir.appendingPathComponent("Enemies").path))
        XCTAssertFalse(fm.fileExists(atPath: packDir.appendingPathComponent("Regions").path))
    }

    func testGeneratedManifestIsLoadable() throws {
        let opts = PackTemplateGenerator.Options(
            packId: "loadable-pack",
            displayName: "Loadable",
            packType: .campaign,
            author: "Test"
        )
        let packDir = try PackTemplateGenerator.generate(at: tempDir, options: opts)

        let manifest = try PackManifest.load(from: packDir)
        XCTAssertEqual(manifest.packId, "loadable-pack")
        XCTAssertEqual(manifest.packType, .campaign)
        XCTAssertEqual(manifest.displayName.en, "Loadable")
    }

    func testGeneratedPackIsLoadable() throws {
        let opts = PackTemplateGenerator.Options(
            packId: "full-load-test",
            displayName: "Full Load",
            packType: .campaign,
            author: "Test"
        )
        let packDir = try PackTemplateGenerator.generate(at: tempDir, options: opts)

        let store = PackStore()
        try store.loadPack(from: packDir)
        XCTAssertEqual(store.enemies.count, 0)
        XCTAssertEqual(store.cards.count, 0)
        XCTAssertEqual(store.regions.count, 0)
    }
}

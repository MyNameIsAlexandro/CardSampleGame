/// Файл: Packages/PackEditorKit/Tests/PackEditorKitTests/PackScannerTests.swift
/// Назначение: Содержит реализацию файла PackScannerTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import PackEditorKit
import TwilightEngine

final class PackScannerTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PackScannerTests-\(ProcessInfo.processInfo.globallyUniqueString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testScanFindsValidPack() throws {
        // Create a minimal pack with a valid manifest
        let packDir = tempDir.appendingPathComponent("test-pack")
        try FileManager.default.createDirectory(at: packDir, withIntermediateDirectories: true)

        let manifest = PackManifest(
            packId: "test-pack",
            displayName: LocalizedString(en: "Test Pack", ru: "Тест"),
            description: LocalizedString(en: "", ru: ""),
            version: SemanticVersion(major: 1, minor: 2, patch: 3),
            packType: .campaign,
            coreVersionMin: SemanticVersion(major: 1, minor: 0, patch: 0),
            author: "Tester"
        )
        try manifest.save(to: packDir)

        let results = PackScanner.scan(roots: [tempDir])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, "test-pack")
        XCTAssertEqual(results.first?.displayName, "Test Pack")
        XCTAssertEqual(results.first?.packType, .campaign)
        XCTAssertEqual(results.first?.version, SemanticVersion(major: 1, minor: 2, patch: 3))
        XCTAssertEqual(results.first?.url.lastPathComponent, "test-pack")
    }

    func testScanSkipsCorruptManifest() throws {
        let packDir = tempDir.appendingPathComponent("bad-pack")
        try FileManager.default.createDirectory(at: packDir, withIntermediateDirectories: true)
        try "NOT JSON".data(using: .utf8)!.write(to: packDir.appendingPathComponent("manifest.json"))

        let results = PackScanner.scan(roots: [tempDir])
        XCTAssertTrue(results.isEmpty)
    }

    func testScanMultiplePacks() throws {
        for name in ["alpha-pack", "beta-pack"] {
            let packDir = tempDir.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: packDir, withIntermediateDirectories: true)
            let manifest = PackManifest(
                packId: name,
                displayName: LocalizedString(en: name, ru: name),
                description: LocalizedString(en: "", ru: ""),
                version: SemanticVersion(major: 1, minor: 0, patch: 0),
                packType: .character,
                coreVersionMin: SemanticVersion(major: 1, minor: 0, patch: 0),
                author: "Tester"
            )
            try manifest.save(to: packDir)
        }

        let results = PackScanner.scan(roots: [tempDir])
        XCTAssertEqual(results.count, 2)
        // Sorted by id
        XCTAssertEqual(results[0].id, "alpha-pack")
        XCTAssertEqual(results[1].id, "beta-pack")
    }

    func testScanEmptyRootReturnsEmpty() {
        let results = PackScanner.scan(roots: [tempDir])
        XCTAssertTrue(results.isEmpty)
    }
}

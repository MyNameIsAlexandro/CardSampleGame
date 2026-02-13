/// Файл: Packages/TwilightEngine/Tests/PackAuthoringTests/PackCompilerTests.swift
/// Назначение: Содержит реализацию файла PackCompilerTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
import TwilightEngine
import PackAuthoring

/// Tests for PackCompiler functionality
/// PackCompiler converts JSON source directories to binary .pack files
final class PackCompilerTests: XCTestCase {

    // MARK: - Properties

    private var storyPackURL: URL?
    private var characterPackURL: URL?
    private var outputURL: URL!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        storyPackURL = PackAuthoringTestHelper.storyPackJSONURL
        characterPackURL = PackAuthoringTestHelper.characterPackJSONURL
        outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PackCompilerTests_\(UUID().uuidString)")
            .appendingPathExtension("pack")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: outputURL)
        storyPackURL = nil
        characterPackURL = nil
        super.tearDown()
    }

    // MARK: - Compile Tests

    func testCompileStoryPack() throws {
        let url = try XCTUnwrap(storyPackURL, "TwilightMarchesActI JSON not available")

        let result = try PackCompiler.compile(from: url, to: outputURL)

        XCTAssertEqual(result.packId, "twilight-marches-act1")
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertGreaterThan(result.outputSize, 0)
        XCTAssertGreaterThan(result.contentStats.regions, 0)
        XCTAssertGreaterThan(result.contentStats.events, 0)
    }

    func testCompileCharacterPack() throws {
        if characterPackURL == nil { XCTFail("CoreHeroes JSON not available"); return }
        let url = characterPackURL!

        let result = try PackCompiler.compile(from: url, to: outputURL)

        XCTAssertEqual(result.packId, "core-heroes")
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertGreaterThan(result.contentStats.heroes, 0)
        XCTAssertGreaterThan(result.contentStats.cards, 0)
    }

    func testCompileProducesValidPackFile() throws {
        let url = try XCTUnwrap(storyPackURL, "TwilightMarchesActI JSON not available")

        try PackCompiler.compile(from: url, to: outputURL)

        XCTAssertTrue(BinaryPackReader.isValidPackFile(outputURL))
        let content = try BinaryPackReader.loadContent(from: outputURL)
        XCTAssertGreaterThan(content.regions.count, 0)
    }

    func testCompilationResultHasStats() throws {
        let url = try XCTUnwrap(storyPackURL, "TwilightMarchesActI JSON not available")

        let result = try PackCompiler.compile(from: url, to: outputURL)

        XCTAssertGreaterThan(result.inputSize, 0, "Should report input size")
        XCTAssertGreaterThan(result.outputSize, 0, "Should report output size")
        XCTAssertGreaterThan(result.compilationTime, 0, "Should report compilation time")
        XCTAssertFalse(result.summary.isEmpty, "Should produce summary")
    }

    func testCompressionRatio() throws {
        let url = try XCTUnwrap(storyPackURL, "TwilightMarchesActI JSON not available")

        let result = try PackCompiler.compile(from: url, to: outputURL)

        XCTAssertGreaterThan(result.compressionRatio, 0, "Compression ratio should be positive")
    }

    // MARK: - Validate Tests

    func testValidateValidPack() throws {
        let url = try XCTUnwrap(storyPackURL, "TwilightMarchesActI JSON not available")

        let result = try PackCompiler.validate(at: url)

        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.coreCompatible)
        XCTAssertTrue(result.contentValid)
        XCTAssertNil(result.error)
    }

    func testValidateReportsSummary() throws {
        let url = try XCTUnwrap(storyPackURL, "TwilightMarchesActI JSON not available")

        let result = try PackCompiler.validate(at: url)

        XCTAssertFalse(result.summary.isEmpty)
        XCTAssertFalse(result.packId.isEmpty)
    }

    // MARK: - Error Tests

    func testCompileFromInvalidPathThrows() {
        let invalidURL = URL(fileURLWithPath: "/nonexistent/pack")
        XCTAssertThrowsError(try PackCompiler.compile(from: invalidURL, to: outputURL))
    }

    func testValidateFromInvalidPathThrows() {
        let invalidURL = URL(fileURLWithPath: "/nonexistent/pack")
        XCTAssertThrowsError(try PackCompiler.validate(at: invalidURL))
    }
}

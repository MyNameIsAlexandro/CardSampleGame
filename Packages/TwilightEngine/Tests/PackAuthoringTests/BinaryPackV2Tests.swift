/// Файл: Packages/TwilightEngine/Tests/PackAuthoringTests/BinaryPackV2Tests.swift
/// Назначение: Содержит реализацию файла BinaryPackV2Tests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
import TwilightEngine
import PackAuthoring

/// Tests for Binary Pack v2 format with SHA256 checksum verification
final class BinaryPackV2Tests: XCTestCase {

    // MARK: - Properties

    private var characterPackURL: URL?
    private var outputURL: URL!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        characterPackURL = PackAuthoringTestHelper.characterPackJSONURL
        outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("BinaryPackV2Tests_\(UUID().uuidString)")
            .appendingPathExtension("pack")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: outputURL)
        characterPackURL = nil
        super.tearDown()
    }

    // MARK: - V2 Format Tests

    func testV2WriteProducesValidHeader() throws {
        let url = try XCTUnwrap(characterPackURL, "CoreHeroes JSON not available")

        try PackCompiler.compile(from: url, to: outputURL)

        // Read raw file data
        let fileData = try Data(contentsOf: outputURL)

        // Verify minimum size for v2 header (42 bytes)
        XCTAssertGreaterThanOrEqual(fileData.count, 42, "V2 file should have at least 42-byte header")

        // Verify magic bytes "TWPK"
        let magic = Array(fileData[0..<4])
        XCTAssertEqual(magic, [0x54, 0x57, 0x50, 0x4B], "Magic should be 'TWPK'")

        // Verify version is 2
        let version = fileData[4..<6].withUnsafeBytes { $0.loadUnaligned(as: UInt16.self).littleEndian }
        XCTAssertEqual(version, 2, "Format version should be 2")

        // Verify original size is non-zero
        let originalSize = fileData[6..<10].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).littleEndian }
        XCTAssertGreaterThan(originalSize, 0, "Original size should be non-zero")

        // Verify checksum is present (32 bytes at offset 10)
        let checksum = fileData[10..<42]
        XCTAssertEqual(checksum.count, 32, "SHA256 checksum should be 32 bytes")
        XCTAssertFalse(checksum.allSatisfy { $0 == 0 }, "Checksum should not be all zeros")
    }

    func testV2ChecksumVerification() throws {
        let url = try XCTUnwrap(characterPackURL, "CoreHeroes JSON not available")

        try PackCompiler.compile(from: url, to: outputURL)

        // Get file info (includes checksum verification)
        let fileInfo = try BinaryPackReader.getFileInfo(from: outputURL)

        XCTAssertEqual(fileInfo.version, 2, "Should be v2 format")
        XCTAssertTrue(fileInfo.isValid, "Checksum should be valid")
        XCTAssertNotNil(fileInfo.checksumHex, "Should have checksum hex")
        XCTAssertEqual(fileInfo.checksumHex?.count, 64, "SHA256 hex should be 64 characters")
    }

    func testV2DetectsCorruptedData() throws {
        let url = try XCTUnwrap(characterPackURL, "CoreHeroes JSON not available")

        try PackCompiler.compile(from: url, to: outputURL)

        // Read and corrupt the file
        var fileData = try Data(contentsOf: outputURL)

        // Corrupt a byte in the compressed data (after 42-byte header)
        let corruptIndex = 50
        guard fileData.count > corruptIndex else {
            XCTFail("File too small to corrupt")
            return
        }
        fileData[corruptIndex] ^= 0xFF // Flip all bits

        // Write corrupted file
        let corruptedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("corrupted_\(UUID().uuidString)")
            .appendingPathExtension("pack")
        try fileData.write(to: corruptedURL)
        defer { try? FileManager.default.removeItem(at: corruptedURL) }

        // Verify getFileInfo reports invalid
        let fileInfo = try BinaryPackReader.getFileInfo(from: corruptedURL)
        XCTAssertFalse(fileInfo.isValid, "Corrupted file should fail checksum verification")

        // Verify loadContent throws checksumMismatch
        XCTAssertThrowsError(try BinaryPackReader.loadContent(from: corruptedURL)) { error in
            if case PackLoadError.checksumMismatch = error {
                // Expected
            } else {
                XCTFail("Expected checksumMismatch error, got: \(error)")
            }
        }
    }

    func testV2CompressionRatioReported() throws {
        let url = try XCTUnwrap(characterPackURL, "CoreHeroes JSON not available")

        try PackCompiler.compile(from: url, to: outputURL)

        let fileInfo = try BinaryPackReader.getFileInfo(from: outputURL)

        XCTAssertGreaterThan(fileInfo.originalSize, 0, "Original size should be positive")
        XCTAssertGreaterThan(fileInfo.compressedSize, 0, "Compressed size should be positive")
        XCTAssertGreaterThan(fileInfo.compressionRatio, 0, "Compression ratio should be positive")
        XCTAssertLessThan(fileInfo.compressionRatio, 1.0, "Compression should reduce size")
    }

    func testV2RoundTrip() throws {
        let url = try XCTUnwrap(characterPackURL, "CoreHeroes JSON not available")

        // Compile to v2
        try PackCompiler.compile(from: url, to: outputURL)

        // Load the pack
        let content = try BinaryPackReader.loadContent(from: outputURL)

        // Verify content integrity
        XCTAssertEqual(content.manifest.packId, "core-heroes")
        XCTAssertGreaterThan(content.heroes.count, 0, "Should have heroes")
        XCTAssertGreaterThan(content.cards.count, 0, "Should have cards")
    }

    // MARK: - Backward Compatibility Tests

    func testCanIdentifyPackVersion() throws {
        let url = try XCTUnwrap(characterPackURL, "CoreHeroes JSON not available")

        try PackCompiler.compile(from: url, to: outputURL)

        let fileInfo = try BinaryPackReader.getFileInfo(from: outputURL)

        // Current compiler always produces v2
        XCTAssertEqual(fileInfo.version, 2)
    }

    func testIsValidPackFileCheck() throws {
        let url = try XCTUnwrap(characterPackURL, "CoreHeroes JSON not available")

        try PackCompiler.compile(from: url, to: outputURL)

        XCTAssertTrue(BinaryPackReader.isValidPackFile(outputURL))

        // Non-pack file should return false
        let textFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test.txt")
        try "not a pack".write(to: textFileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: textFileURL) }

        XCTAssertFalse(BinaryPackReader.isValidPackFile(textFileURL))
    }

    // MARK: - Error Handling Tests

    func testLoadNonExistentFileThrows() {
        let badURL = URL(fileURLWithPath: "/nonexistent/file.pack")

        XCTAssertThrowsError(try BinaryPackReader.loadContent(from: badURL)) { error in
            if case PackLoadError.fileNotFound = error {
                // Expected
            } else {
                XCTFail("Expected fileNotFound error, got: \(error)")
            }
        }
    }

    func testLoadInvalidMagicThrows() throws {
        // Create file with invalid magic
        let badMagic = Data([0x00, 0x00, 0x00, 0x00, 0x02, 0x00])
        let badURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("badmagic_\(UUID().uuidString)")
            .appendingPathExtension("pack")
        try badMagic.write(to: badURL)
        defer { try? FileManager.default.removeItem(at: badURL) }

        XCTAssertThrowsError(try BinaryPackReader.loadContent(from: badURL)) { error in
            if case PackLoadError.invalidManifest = error {
                // Expected
            } else {
                XCTFail("Expected invalidManifest error, got: \(error)")
            }
        }
    }

    func testLoadFileTooSmallThrows() throws {
        // Create file smaller than minimum header
        let tooSmall = Data([0x54, 0x57, 0x50, 0x4B]) // Just magic, no version/size
        let smallURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("toosmall_\(UUID().uuidString)")
            .appendingPathExtension("pack")
        try tooSmall.write(to: smallURL)
        defer { try? FileManager.default.removeItem(at: smallURL) }

        XCTAssertThrowsError(try BinaryPackReader.loadContent(from: smallURL)) { error in
            if case PackLoadError.invalidManifest = error {
                // Expected
            } else {
                XCTFail("Expected invalidManifest error, got: \(error)")
            }
        }
    }
}

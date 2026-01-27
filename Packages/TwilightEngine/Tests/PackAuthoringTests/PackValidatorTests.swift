import XCTest
import TwilightEngine
import PackAuthoring

/// Tests for PackValidator functionality
/// PackValidator performs multi-phase validation of content packs
final class PackValidatorTests: XCTestCase {

    // MARK: - Properties

    private var storyPackURL: URL?
    private var characterPackURL: URL?

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        storyPackURL = PackAuthoringTestHelper.storyPackJSONURL
        characterPackURL = PackAuthoringTestHelper.characterPackJSONURL
    }

    override func tearDown() {
        storyPackURL = nil
        characterPackURL = nil
        super.tearDown()
    }

    // MARK: - Valid Pack Tests

    func testValidateStoryPackPasses() throws {
        let url = try XCTUnwrap(storyPackURL, "TwilightMarchesActI JSON not available")

        let validator = PackValidator(packURL: url)
        let summary = validator.validate()

        XCTAssertTrue(summary.isValid, "Story pack should pass validation. Errors: \(summary.results.filter { $0.severity == .error }.map { $0.description })")
        XCTAssertEqual(summary.errorCount, 0)
        XCTAssertEqual(summary.packId, "twilight-marches-act1")
    }

    func testValidateCharacterPackPasses() throws {
        if characterPackURL == nil { XCTFail("CoreHeroes JSON not available"); return }
        let url = characterPackURL!

        let validator = PackValidator(packURL: url)
        let summary = validator.validate()

        XCTAssertTrue(summary.isValid, "Character pack should pass validation. Errors: \(summary.results.filter { $0.severity == .error }.map { $0.description })")
        XCTAssertEqual(summary.errorCount, 0)
        XCTAssertEqual(summary.packId, "core-heroes")
    }

    // MARK: - Summary Structure Tests

    func testValidationSummaryHasDuration() throws {
        let url = try XCTUnwrap(storyPackURL, "TwilightMarchesActI JSON not available")

        let validator = PackValidator(packURL: url)
        let summary = validator.validate()

        XCTAssertGreaterThan(summary.duration, 0, "Validation should report duration")
    }

    func testValidationSummaryHasInfoMessages() throws {
        let url = try XCTUnwrap(storyPackURL, "TwilightMarchesActI JSON not available")

        let validator = PackValidator(packURL: url)
        let summary = validator.validate()

        XCTAssertGreaterThan(summary.infoCount, 0, "Should produce info messages about loaded content")
    }

    // MARK: - Quick Validate Tests

    func testQuickValidateReturnsZeroErrorsForValidPack() throws {
        let url = try XCTUnwrap(storyPackURL, "TwilightMarchesActI JSON not available")

        let (errors, _) = PackValidator.quickValidate(packURL: url)

        XCTAssertEqual(errors, 0)
    }

    // MARK: - Invalid Pack Tests

    func testValidateNonExistentPathReportsError() {
        let invalidURL = URL(fileURLWithPath: "/nonexistent/pack")

        let validator = PackValidator(packURL: invalidURL)
        let summary = validator.validate()

        XCTAssertFalse(summary.isValid)
        XCTAssertGreaterThan(summary.errorCount, 0)
    }

    func testValidateDirectoryWithoutManifestReportsError() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PackValidatorTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let validator = PackValidator(packURL: tempDir)
        let summary = validator.validate()

        XCTAssertFalse(summary.isValid)
        XCTAssertGreaterThan(summary.errorCount, 0)
    }

    func testValidateDirectoryWithInvalidManifestReportsError() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PackValidatorTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manifestURL = tempDir.appendingPathComponent("manifest.json")
        try "{ invalid json".data(using: .utf8)!.write(to: manifestURL)

        let validator = PackValidator(packURL: tempDir)
        let summary = validator.validate()

        XCTAssertFalse(summary.isValid)
        XCTAssertGreaterThan(summary.errorCount, 0)
    }

    // MARK: - Cross-Reference Validation

    func testStoryPackNeighborReferencesAreValid() throws {
        let url = try XCTUnwrap(storyPackURL, "TwilightMarchesActI JSON not available")

        let validator = PackValidator(packURL: url)
        let summary = validator.validate()

        let neighborErrors = summary.results.filter {
            $0.severity == .error && $0.message.contains("non-existent neighbor")
        }
        XCTAssertTrue(neighborErrors.isEmpty, "Should have no broken neighbor references: \(neighborErrors.map { $0.description })")
    }

    func testCharacterPackCardReferencesAreValid() throws {
        if characterPackURL == nil { XCTFail("CoreHeroes JSON not available"); return }
        let url = characterPackURL!

        let validator = PackValidator(packURL: url)
        let summary = validator.validate()

        let cardRefErrors = summary.results.filter {
            $0.severity == .error && $0.message.contains("non-existent card")
        }
        XCTAssertTrue(cardRefErrors.isEmpty, "Should have no broken card references: \(cardRefErrors.map { $0.description })")
    }
}

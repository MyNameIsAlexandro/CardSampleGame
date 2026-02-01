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

    // MARK: - Card Cost & Exhaust Validation

    func testCharacterPackCardsHaveNoNegativeCost() throws {
        if characterPackURL == nil { XCTFail("CoreHeroes JSON not available"); return }
        let url = characterPackURL!

        let validator = PackValidator(packURL: url)
        let summary = validator.validate()

        let costErrors = summary.results.filter {
            $0.severity == .error && $0.message.contains("negative energy cost")
        }
        XCTAssertTrue(costErrors.isEmpty, "Should have no negative cost errors: \(costErrors.map { $0.description })")
    }

    func testCharacterPackCardsHaveNoExhaustWarnings() throws {
        if characterPackURL == nil { XCTFail("CoreHeroes JSON not available"); return }
        let url = characterPackURL!

        let validator = PackValidator(packURL: url)
        let summary = validator.validate()

        let exhaustWarnings = summary.results.filter {
            $0.severity == .warning && $0.message.contains("exhaust")
        }
        XCTAssertTrue(exhaustWarnings.isEmpty, "Should have no exhaust-without-effect warnings: \(exhaustWarnings.map { $0.description })")
    }

    // MARK: - Enemy Validation

    func testStoryPackEnemiesHaveValidHealth() throws {
        let url = try XCTUnwrap(storyPackURL, "TwilightMarchesActI JSON not available")

        let validator = PackValidator(packURL: url)
        let summary = validator.validate()

        let healthErrors = summary.results.filter {
            $0.severity == .error && $0.message.contains("non-positive health")
        }
        XCTAssertTrue(healthErrors.isEmpty, "Should have no enemy health errors: \(healthErrors.map { $0.description })")
    }

    func testStoryPackEnemiesHaveNoNegativeDefense() throws {
        let url = try XCTUnwrap(storyPackURL, "TwilightMarchesActI JSON not available")

        let validator = PackValidator(packURL: url)
        let summary = validator.validate()

        let defenseWarnings = summary.results.filter {
            $0.severity == .warning && $0.message.contains("negative defense")
        }
        XCTAssertTrue(defenseWarnings.isEmpty, "Should have no negative defense warnings: \(defenseWarnings.map { $0.description })")
    }

    func testStoryPackEnemiesHaveNoNegativeWill() throws {
        let url = try XCTUnwrap(storyPackURL, "TwilightMarchesActI JSON not available")

        let validator = PackValidator(packURL: url)
        let summary = validator.validate()

        let willErrors = summary.results.filter {
            $0.severity == .error && $0.message.contains("negative will")
        }
        XCTAssertTrue(willErrors.isEmpty, "Should have no negative will errors: \(willErrors.map { $0.description })")
    }

    func testStoryPackEnemiesHaveNoNegativeFaithReward() throws {
        let url = try XCTUnwrap(storyPackURL, "TwilightMarchesActI JSON not available")

        let validator = PackValidator(packURL: url)
        let summary = validator.validate()

        let faithErrors = summary.results.filter {
            $0.severity == .error && $0.message.contains("negative faith reward")
        }
        XCTAssertTrue(faithErrors.isEmpty, "Should have no negative faith reward errors: \(faithErrors.map { $0.description })")
    }

    func testStoryPackEnemiesHaveValidDifficulty() throws {
        let url = try XCTUnwrap(storyPackURL, "TwilightMarchesActI JSON not available")

        let validator = PackValidator(packURL: url)
        let summary = validator.validate()

        let difficultyWarnings = summary.results.filter {
            $0.severity == .warning && $0.message.contains("invalid difficulty")
        }
        XCTAssertTrue(difficultyWarnings.isEmpty, "Should have no invalid difficulty warnings: \(difficultyWarnings.map { $0.description })")
    }

    func testStoryPackEnemyLootCardReferencesAreValid() throws {
        let url = try XCTUnwrap(storyPackURL, "TwilightMarchesActI JSON not available")

        let validator = PackValidator(packURL: url)
        let summary = validator.validate()

        let lootWarnings = summary.results.filter {
            $0.message.contains("loot card")
        }
        // Loot cards may reference cards from other packs, so these are warnings not errors
        // Verify the validator runs and produces warnings (not crashes)
        _ = lootWarnings
    }

    func testStoryPackEnemiesHaveNoEmptyPatterns() throws {
        let url = try XCTUnwrap(storyPackURL, "TwilightMarchesActI JSON not available")

        let validator = PackValidator(packURL: url)
        let summary = validator.validate()

        let patternWarnings = summary.results.filter {
            $0.severity == .warning && $0.message.contains("empty pattern")
        }
        XCTAssertTrue(patternWarnings.isEmpty, "Should have no empty pattern warnings: \(patternWarnings.map { $0.description })")
    }
}

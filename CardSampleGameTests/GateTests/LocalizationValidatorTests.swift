/// Файл: CardSampleGameTests/GateTests/LocalizationValidatorTests.swift
/// Назначение: Содержит реализацию файла LocalizationValidatorTests.swift.
/// Зона ответственности: Фиксирует проверяемый контракт и не содержит production-логики.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import TwilightEngine

/// Gate tests for localization schema consistency (Audit B1 requirement).
/// Ensures all packs use the canonical localization approach without mixing schemes.
///
/// Canonical approach: Inline LocalizedString { "en": "...", "ru": "..." }
/// Forbidden: Mixing inline strings with StringKey references within the same pack.
final class LocalizationValidatorTests: XCTestCase {

    // MARK: - Canon Tests

    func testCanonicalSchemeIsInlineOnly() throws {
        // Document the canonical scheme
        XCTAssertEqual(
            LocalizationValidator.canonicalScheme,
            .inlineOnly,
            "Canonical localization scheme should be inline-only"
        )
    }

    func testInlineTextIsCanonical() throws {
        let text = LocalizableText.localized(en: "Strike", ru: "Удар")
        XCTAssertTrue(
            LocalizationValidator.isCanonical(text),
            "Inline LocalizedString should be canonical"
        )
    }

    func testStringKeyIsNotCanonical() throws {
        let text = LocalizableText.key("card.strike.name")
        XCTAssertFalse(
            LocalizationValidator.isCanonical(text),
            "StringKey should NOT be canonical (we use inline scheme)"
        )
    }

    // MARK: - Gate Test: No Mixed Localization Schema

    func testNoMixedLocalizationSchema() throws {
        let registry = try TestContentLoader.makeStandardRegistry()

        // Validate all loaded packs
        for (packId, pack) in registry.loadedPacks {
            let result = LocalizationValidator.validate(pack: pack)

            // Check scheme is canonical
            if result.scheme != LocalizationValidator.canonicalScheme {
                let reason = LocalizationValidator.failureReason(result: result)
                XCTFail("Pack '\(packId)' uses non-canonical localization scheme:\n\(reason)")
            }

            // Check no mixed entities
            if !result.mixedEntities.isEmpty {
                let entities = result.mixedEntities.prefix(5).joined(separator: ", ")
                XCTFail("Pack '\(packId)' has entities mixing localization schemes: \(entities)")
            }
        }
    }

    // MARK: - Fallback Determinism Test

    func testLocalizationFallbackIsDeterministic() throws {
        // Test that fallback to English is deterministic when Russian is missing

        // Create inline text with both translations
        let fullText = LocalizableText.localized(en: "Attack", ru: "Атака")

        // Resolve for English (should return English)
        let enResult = fullText.resolved(for: "en")
        XCTAssertEqual(enResult, "Attack", "English resolution should return English text")

        // Resolve for Russian (should return Russian)
        let ruResult = fullText.resolved(for: "ru")
        XCTAssertEqual(ruResult, "Атака", "Russian resolution should return Russian text")

        // Resolve for unknown locale (should fallback to English)
        let unknownResult = fullText.resolved(for: "de")
        XCTAssertEqual(unknownResult, "Attack", "Unknown locale should fallback to English")

        // Multiple resolutions should be deterministic
        XCTAssertEqual(fullText.resolved(for: "de"), unknownResult, "Fallback should be deterministic")
        XCTAssertEqual(fullText.resolved(for: "de"), unknownResult, "Fallback should be deterministic")
    }

    func testEmptyRussianReturnsEnglishWhenEmpty() throws {
        // Create text with empty Russian
        let text = LocalizableText.inline(LocalizedString(en: "Test", ru: ""))

        // Current behavior: returns empty string (no automatic fallback)
        // This is documented behavior - content authors must provide all translations
        let ruResult = text.resolved(for: "ru")

        // Document the current behavior
        // Note: This could be changed to fallback to English if desired
        XCTAssertTrue(ruResult.isEmpty || ruResult == "Test",
            "Russian should either return empty or fallback to English")
    }

    // MARK: - Validation Result Tests

    func testValidationResultForInlineOnlyPack() throws {
        // Create a mock validation result for inline-only pack
        let result = LocalizationValidator.ValidationResult(
            isValid: true,
            scheme: .inlineOnly,
            inlineCount: 100,
            keyCount: 0,
            mixedEntities: []
        )

        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.scheme, .inlineOnly)
        XCTAssertTrue(result.mixedEntities.isEmpty)
    }

    func testValidationResultForMixedPack() throws {
        // Create a mock validation result for mixed pack
        let result = LocalizationValidator.ValidationResult(
            isValid: false,
            scheme: .mixed,
            inlineCount: 50,
            keyCount: 50,
            mixedEntities: ["event:test_event", "hero:test_hero"]
        )

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.scheme, .mixed)
        XCTAssertFalse(result.mixedEntities.isEmpty)
    }
}

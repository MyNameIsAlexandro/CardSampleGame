/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/LocalizationResolutionTests.swift
/// Назначение: Содержит реализацию файла LocalizationResolutionTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import TwilightEngine

final class LocalizationResolutionTests: XCTestCase {
    func testInlineTextResolveUsesResolverLocale() {
        let text = LocalizableText.localized(en: "Strike", ru: "Удар")
        let localizationManager = LocalizationManager()

        localizationManager.setLocale("ru")
        XCTAssertEqual(
            text.resolve(using: localizationManager),
            "Удар",
            "Inline localization must follow resolver locale instead of device locale"
        )

        localizationManager.setLocale("en")
        XCTAssertEqual(text.resolve(using: localizationManager), "Strike")
    }

    func testStandardCardDefinitionToCardUsesResolverLocaleForInlineFields() {
        let cardDefinition = StandardCardDefinition(
            id: "localization_test_card",
            name: .localized(en: "Focus", ru: "Концентрация"),
            cardType: .special,
            description: .localized(en: "Draw 1 card", ru: "Возьми 1 карту")
        )
        let localizationManager = LocalizationManager()

        localizationManager.setLocale("ru")
        let russianCard = cardDefinition.toCard(localizationManager: localizationManager)
        XCTAssertEqual(russianCard.name, "Концентрация")
        XCTAssertEqual(russianCard.description, "Возьми 1 карту")

        localizationManager.setLocale("en")
        let englishCard = cardDefinition.toCard(localizationManager: localizationManager)
        XCTAssertEqual(englishCard.name, "Focus")
        XCTAssertEqual(englishCard.description, "Draw 1 card")
    }
}

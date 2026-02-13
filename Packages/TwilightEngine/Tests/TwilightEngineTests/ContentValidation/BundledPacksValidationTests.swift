/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/ContentValidation/BundledPacksValidationTests.swift
/// Назначение: Содержит реализацию файла BundledPacksValidationTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import Foundation
import XCTest
@testable import TwilightEngine

/// Ensures the bundled `.pack` resources remain compatible with SafeContentAccess validation.
/// This protects the content pipeline as new validation rules are introduced.
final class BundledPacksValidationTests: XCTestCase {

    func testBundledPacksPassSafeContentValidation() throws {
        let packURLs = Self.findBundledPackURLs()
        XCTAssertEqual(packURLs.count, 2, "Expected 2 bundled .pack files (CoreHeroes + TwilightMarchesActI)")

        let registry = ContentRegistry()
        let safeAccess = SafeContentAccess(registry: registry)

        try registry.loadPacks(from: packURLs)

        let validation = safeAccess.validateAllContent()
        XCTAssertTrue(validation.errors.isEmpty, "Validation errors: \(validation.errors)")
    }

    func testBundledCoreHeroesStarterCardsKeepRussianLocalization() throws {
        let packURLs = Self.findBundledPackURLs()
        guard let coreHeroesURL = packURLs.first(where: { $0.lastPathComponent == "CoreHeroes.pack" }) else {
            XCTFail("CoreHeroes.pack not found in bundled resources")
            return
        }

        let content = try BinaryPackReader.loadContent(from: coreHeroesURL)
        let expectedRussianNames: [String: String] = [
            "strike_basic": "Удар Мечом",
            "defend_basic": "Защита",
            "heal_basic": "Исцеление",
            "draw_basic": "Концентрация",
            "rage_strike": "Удар Ярости"
        ]

        for (cardId, expectedRuName) in expectedRussianNames {
            guard let cardDefinition = content.cards[cardId] else {
                XCTFail("Missing expected starter card '\(cardId)' in CoreHeroes.pack")
                continue
            }

            guard case .inline(let localizedName) = cardDefinition.name else {
                XCTFail("Card '\(cardId)' name must use inline localization in bundled pack")
                continue
            }
            XCTAssertEqual(localizedName.ru, expectedRuName, "Unexpected ru name for '\(cardId)'")
            XCTAssertNotEqual(localizedName.en, localizedName.ru, "Card '\(cardId)' should not collapse en/ru values")

            guard case .inline(let localizedDescription) = cardDefinition.description else {
                XCTFail("Card '\(cardId)' description must use inline localization in bundled pack")
                continue
            }
            XCTAssertFalse(localizedDescription.ru.isEmpty, "Card '\(cardId)' must have non-empty ru description")
            XCTAssertNotEqual(
                localizedDescription.en,
                localizedDescription.ru,
                "Card '\(cardId)' should keep distinct en/ru descriptions"
            )
        }
    }

    func testBundledCoreHeroesStarterCardsResolveToRussianInRuntime() throws {
        let packURLs = Self.findBundledPackURLs()
        let registry = ContentRegistry()
        try registry.loadPacks(from: packURLs)

        let localizationManager = LocalizationManager()
        localizationManager.setLocale("ru")
        let cardFactory = CardFactory(contentRegistry: registry, localizationManager: localizationManager)

        let expectedRussianCards: [String: (name: String, description: String)] = [
            "strike_basic": ("Удар Мечом", "Удар воеводы. Наносит 3 урона."),
            "defend_basic": ("Защита", "Базовая защита. Блокирует 2 урона."),
            "heal_basic": ("Исцеление", "Базовое исцеление. Восстанавливает 2 здоровья."),
            "draw_basic": ("Концентрация", "Сосредоточься. Возьми 1 карту."),
            "rage_strike": ("Удар Ярости", "Мощный удар, питаемый яростью. Наносит 5 урона.")
        ]

        for (cardId, expected) in expectedRussianCards {
            guard let card = cardFactory.getCard(id: cardId) else {
                XCTFail("Missing expected starter card '\(cardId)' in runtime registry")
                continue
            }

            XCTAssertEqual(card.name, expected.name, "Unexpected localized runtime name for '\(cardId)'")
            XCTAssertEqual(card.description, expected.description, "Unexpected localized runtime description for '\(cardId)'")
        }
    }

    private static func findBundledPackURLs() -> [URL] {
        // Path from this file to project root:
        // TwilightEngineTests/ContentValidation/BundledPacksValidationTests.swift
        //   → TwilightEngineTests
        //   → Tests
        //   → TwilightEngine
        //   → Packages
        //   → ProjectRoot
        let testFilePath = URL(fileURLWithPath: #filePath)
        let projectRoot = testFilePath
            .deletingLastPathComponent()  // ContentValidation
            .deletingLastPathComponent()  // TwilightEngineTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // TwilightEngine
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // Project root

        var urls: [URL] = []

        // Character pack (CoreHeroes)
        let coreHeroesPath = projectRoot
            .appendingPathComponent("Packages")
            .appendingPathComponent("CharacterPacks")
            .appendingPathComponent("CoreHeroes")
            .appendingPathComponent("Sources")
            .appendingPathComponent("CoreHeroesContent")
            .appendingPathComponent("Resources")
            .appendingPathComponent("CoreHeroes.pack")
        if FileManager.default.fileExists(atPath: coreHeroesPath.path) {
            urls.append(coreHeroesPath)
        }

        // Story pack (TwilightMarchesActI)
        let storyPackPath = projectRoot
            .appendingPathComponent("Packages")
            .appendingPathComponent("StoryPacks")
            .appendingPathComponent("Season1")
            .appendingPathComponent("TwilightMarchesActI")
            .appendingPathComponent("Sources")
            .appendingPathComponent("TwilightMarchesActIContent")
            .appendingPathComponent("Resources")
            .appendingPathComponent("TwilightMarchesActI.pack")
        if FileManager.default.fileExists(atPath: storyPackPath.path) {
            urls.append(storyPackPath)
        }

        return urls
    }
}

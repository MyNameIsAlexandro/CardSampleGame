/// Файл: Packages/PackEditorKit/Sources/PackEditorKit/PackTemplateGenerator.swift
/// Назначение: Содержит реализацию файла PackTemplateGenerator.swift.
/// Зона ответственности: Реализует пакетный API редактора контента.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation
import TwilightEngine

/// Generates a new pack directory from a template, including manifest and empty content files.
public enum PackTemplateGenerator {

    public struct Options {
        public let packId: String
        public let displayName: String
        public let packType: PackType
        public let author: String

        public init(packId: String, displayName: String, packType: PackType, author: String = "Author") {
            self.packId = packId
            self.displayName = displayName
            self.packType = packType
            self.author = author
        }
    }

    /// Generates a pack directory at the given URL.
    /// - Returns: The URL of the generated pack directory.
    @discardableResult
    public static func generate(at parentURL: URL, options: Options) throws -> URL {
        let packDir = parentURL.appendingPathComponent(options.packId)
        let fm = FileManager.default
        try fm.createDirectory(at: packDir, withIntermediateDirectories: true)

        let emptyArray = "[]".data(using: .utf8)!

        switch options.packType {
        case .campaign:
            let dirs = ["Campaign", "Enemies", "Cards", "Balance", "Localization",
                        "Events", "Regions", "FateCards", "Quests", "Behaviors", "Anchors"]
            for dir in dirs {
                try fm.createDirectory(at: packDir.appendingPathComponent(dir), withIntermediateDirectories: true)
            }

            // Write empty content files
            try emptyArray.write(to: packDir.appendingPathComponent("Enemies/enemies.json"))
            try emptyArray.write(to: packDir.appendingPathComponent("Cards/cards.json"))
            try emptyArray.write(to: packDir.appendingPathComponent("Events/events.json"))
            try emptyArray.write(to: packDir.appendingPathComponent("Regions/regions.json"))
            try emptyArray.write(to: packDir.appendingPathComponent("FateCards/fate_cards.json"))
            try emptyArray.write(to: packDir.appendingPathComponent("Quests/quests.json"))
            try emptyArray.write(to: packDir.appendingPathComponent("Behaviors/behaviors.json"))
            try emptyArray.write(to: packDir.appendingPathComponent("Anchors/anchors.json"))
            try "{}".data(using: .utf8)!.write(to: packDir.appendingPathComponent("Balance/balance.json"))

            let manifest = PackManifest(
                packId: options.packId,
                displayName: LocalizedString(en: options.displayName, ru: options.displayName),
                description: LocalizedString(en: "", ru: ""),
                version: SemanticVersion(major: 1, minor: 0, patch: 0),
                packType: .campaign,
                coreVersionMin: CoreVersion.current,
                author: options.author,
                supportedLocales: ["en"],
                regionsPath: "Regions/regions.json",
                eventsPath: "Events/events.json",
                questsPath: "Quests/quests.json",
                anchorsPath: "Anchors/anchors.json",
                cardsPath: "Cards/cards.json",
                enemiesPath: "Enemies/enemies.json",
                fateDeckPath: "FateCards/fate_cards.json",
                behaviorsPath: "Behaviors/behaviors.json",
                localizationPath: "Localization"
            )
            try manifest.save(to: packDir)

        case .character:
            let dirs = ["Characters", "Cards", "Localization"]
            for dir in dirs {
                try fm.createDirectory(at: packDir.appendingPathComponent(dir), withIntermediateDirectories: true)
            }

            try emptyArray.write(to: packDir.appendingPathComponent("Characters/heroes.json"))
            try emptyArray.write(to: packDir.appendingPathComponent("Cards/cards.json"))

            let manifest = PackManifest(
                packId: options.packId,
                displayName: LocalizedString(en: options.displayName, ru: options.displayName),
                description: LocalizedString(en: "", ru: ""),
                version: SemanticVersion(major: 1, minor: 0, patch: 0),
                packType: .character,
                coreVersionMin: CoreVersion.current,
                author: options.author,
                supportedLocales: ["en"],
                heroesPath: "Characters/heroes.json",
                cardsPath: "Cards/cards.json",
                localizationPath: "Localization"
            )
            try manifest.save(to: packDir)

        default:
            // Full / rulesExtension / balance — generate all directories
            let dirs = ["Enemies", "Cards", "Events", "Regions", "Characters",
                        "FateCards", "Quests", "Behaviors", "Anchors", "Balance", "Localization"]
            for dir in dirs {
                try fm.createDirectory(at: packDir.appendingPathComponent(dir), withIntermediateDirectories: true)
            }

            try emptyArray.write(to: packDir.appendingPathComponent("Enemies/enemies.json"))
            try emptyArray.write(to: packDir.appendingPathComponent("Cards/cards.json"))
            try emptyArray.write(to: packDir.appendingPathComponent("Events/events.json"))
            try emptyArray.write(to: packDir.appendingPathComponent("Regions/regions.json"))
            try emptyArray.write(to: packDir.appendingPathComponent("Characters/heroes.json"))
            try emptyArray.write(to: packDir.appendingPathComponent("FateCards/fate_cards.json"))
            try emptyArray.write(to: packDir.appendingPathComponent("Quests/quests.json"))
            try emptyArray.write(to: packDir.appendingPathComponent("Behaviors/behaviors.json"))
            try emptyArray.write(to: packDir.appendingPathComponent("Anchors/anchors.json"))
            try "{}".data(using: .utf8)!.write(to: packDir.appendingPathComponent("Balance/balance.json"))

            let manifest = PackManifest(
                packId: options.packId,
                displayName: LocalizedString(en: options.displayName, ru: options.displayName),
                description: LocalizedString(en: "", ru: ""),
                version: SemanticVersion(major: 1, minor: 0, patch: 0),
                packType: options.packType,
                coreVersionMin: CoreVersion.current,
                author: options.author,
                supportedLocales: ["en"],
                regionsPath: "Regions/regions.json",
                eventsPath: "Events/events.json",
                questsPath: "Quests/quests.json",
                anchorsPath: "Anchors/anchors.json",
                heroesPath: "Characters/heroes.json",
                cardsPath: "Cards/cards.json",
                enemiesPath: "Enemies/enemies.json",
                fateDeckPath: "FateCards/fate_cards.json",
                behaviorsPath: "Behaviors/behaviors.json",
                localizationPath: "Localization"
            )
            try manifest.save(to: packDir)
        }

        return packDir
    }
}

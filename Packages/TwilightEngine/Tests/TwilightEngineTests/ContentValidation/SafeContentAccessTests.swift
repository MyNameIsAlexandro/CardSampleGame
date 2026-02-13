/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/ContentValidation/SafeContentAccessTests.swift
/// Назначение: Содержит реализацию файла SafeContentAccessTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@_spi(Testing) @testable import TwilightEngine

/// Comprehensive tests for SafeContentAccess
/// Tests all content types, validation, and error handling
final class SafeContentAccessTests: XCTestCase {

    var registry: ContentRegistry!
    var safeAccess: SafeContentAccess!

    override func setUp() {
        super.setUp()
        registry = ContentRegistry()
        safeAccess = SafeContentAccess(registry: registry)
    }

    override func tearDown() {
        registry.resetForTesting()
        safeAccess = nil
        registry = nil
        super.tearDown()
    }
    // MARK: - Mock Factories

    func createMockHero(
        id: String,
        startingDeckCardIDs: [String] = []
    ) -> StandardHeroDefinition {
        let stats = HeroStats(
            health: 20,
            maxHealth: 20,
            strength: 3,
            dexterity: 3,
            constitution: 3,
            intelligence: 3,
            wisdom: 3,
            charisma: 3,
            faith: 10,
            maxFaith: 10,
            startingBalance: 0
        )

        let ability = HeroAbility(
            id: "test-ability",
            name: .inline(LocalizedString(en: "Test Ability", ru: "Тестовая Способность")),
            description: .inline(LocalizedString(en: "Test", ru: "Тест")),
            icon: "⚔️",
            type: .active,
            trigger: .manual,
            condition: nil,
            effects: [],
            cooldown: 0,
            cost: nil
        )

        return StandardHeroDefinition(
            id: id,
            heroClass: .warrior,
            name: .inline(LocalizedString(en: "Test Hero", ru: "Тестовый Герой")),
            description: .inline(LocalizedString(en: "Test", ru: "Тест")),
            icon: "🦸",
            baseStats: stats,
            specialAbility: ability,
            startingDeckCardIDs: startingDeckCardIDs
        )
    }

    func createMockCard(id: String) -> StandardCardDefinition {
        StandardCardDefinition(
            id: id,
            name: .inline(LocalizedString(en: "Test Card", ru: "Тестовая Карта")),
            cardType: .attack,
            rarity: .common,
            description: .inline(LocalizedString(en: "Test", ru: "Тест"))
        )
    }

    func createMockEnemy(id: String) -> EnemyDefinition {
        EnemyDefinition(
            id: id,
            name: .inline(LocalizedString(en: "Test Enemy", ru: "Тестовый Враг")),
            description: .inline(LocalizedString(en: "Test", ru: "Тест")),
            health: 10,
            power: 5,
            defense: 0
        )
    }

    func createMockFateCard(id: String) -> FateCard {
        FateCard(
            id: id,
            modifier: 0,
            name: "Fate"
        )
    }

    func createMockRegion(id: String) -> RegionDefinition {
        RegionDefinition(
            id: id,
            title: .inline(LocalizedString(en: "Test Region", ru: "Тестовый Регион")),
            description: .inline(LocalizedString(en: "Test", ru: "Тест")),
            regionType: "test",
            neighborIds: []
        )
    }

    func createMockEvent(
        id: String,
        triggerEventId: String? = nil
    ) -> EventDefinition {
        var consequences = ChoiceConsequences()
        consequences.triggerEventId = triggerEventId

        let choice = ChoiceDefinition(
            id: "choice-1",
            label: .inline(LocalizedString(en: "Continue", ru: "Продолжить")),
            consequences: consequences
        )

        return EventDefinition(
            id: id,
            title: .inline(LocalizedString(en: "Test Event", ru: "Тестовое Событие")),
            body: .inline(LocalizedString(en: "Test", ru: "Тест")),
            eventKind: .inline,
            availability: .always,
            poolIds: [],
            choices: [choice]
        )
    }
}

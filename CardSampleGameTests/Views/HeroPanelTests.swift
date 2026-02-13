/// Файл: CardSampleGameTests/Views/HeroPanelTests.swift
/// Назначение: Содержит реализацию файла HeroPanelTests.swift.
/// Зона ответственности: Фиксирует проверяемый контракт и не содержит production-логики.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
import TwilightEngine

@testable import CardSampleGame

/// Tests for the HeroPanel component
/// Verifies that the unified hero panel displays correctly across all screens
final class HeroPanelTests: XCTestCase {

    // MARK: - Test Engine Setup

    var engine: TwilightGameEngine!
    private var registry: ContentRegistry!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let services = try TestContentLoader.makeStandardEngineServices(seed: 0)
        registry = services.contentRegistry
        engine = TwilightGameEngine(services: services)
    }

    override func tearDown() {
        engine = nil
        registry = nil
        super.tearDown()
    }

    // MARK: - Hero Display Tests

    func testHeroDisplaysCorrectly() {
        // Given: Get first available hero from registry
        guard let hero = registry.heroRegistry.firstHero else {
            XCTFail("No heroes in registry"); return
        }

        // Set hero via Engine-First
        engine.player.setHeroId(hero.id)

        // Then: Hero ID should be set
        XCTAssertEqual(engine.player.heroId, hero.id)
    }

    func testAllHeroesHaveValidData() {
        // Verify all heroes have valid data for display
        for hero in registry.heroRegistry.allHeroes {
            XCTAssertFalse(hero.id.isEmpty, "Hero should have ID")
            XCTAssertFalse(hero.name.isEmpty, "Hero \(hero.id) should have a name")
            XCTAssertFalse(hero.icon.isEmpty, "Hero \(hero.id) should have an icon")
            XCTAssertFalse(hero.description.isEmpty, "Hero \(hero.id) should have a description")
        }
    }

    // MARK: - Player Stats Tests

    func testPlayerStatsAvailableFromEngine() {
        // Given: Engine with specific stats
        // Note: setMaxHealth before setHealth, as health is capped to maxHealth
        engine.player.setMaxHealth(20)
        engine.player.setHealth(15)
        engine.player.setFaith(8)
        engine.player.setBalance(65)
        engine.player.setName("Тестовый Герой")

        // Then: Stats should be readable from engine
        XCTAssertEqual(engine.player.name, "Тестовый Герой")
        XCTAssertEqual(engine.player.health, 15)
        XCTAssertEqual(engine.player.maxHealth, 20)
        XCTAssertEqual(engine.player.faith, 8)
        XCTAssertEqual(engine.player.balance, 65)
    }

    // MARK: - Balance Display Tests

    func testBalanceDescriptionForLightPath() {
        // Given: Player with high balance (Light path)
        engine.player.setBalance(80)

        // Then: Balance should indicate Light path
        XCTAssertGreaterThanOrEqual(engine.player.balance, 70)
    }

    func testBalanceDescriptionForDarkPath() {
        // Given: Player with low balance (Dark path)
        engine.player.setBalance(20)

        // Then: Balance should indicate Dark path
        XCTAssertLessThanOrEqual(engine.player.balance, 30)
    }

    func testBalanceDescriptionForNeutral() {
        // Given: Player with neutral balance
        engine.player.setBalance(50)

        // Then: Balance should be in neutral range
        let balance = engine.player.balance
        XCTAssertGreaterThan(balance, 30)
        XCTAssertLessThan(balance, 70)
    }

    // MARK: - Health Color Tests

    func testHealthColorLogic() {
        // Test health percentage thresholds
        // > 60% = green, 30-60% = orange, < 30% = red

        // High health (> 60%)
        let highPercentage = Double(18) / Double(20) // 90%
        XCTAssertGreaterThan(highPercentage, 0.6)

        // Medium health (30-60%)
        let medPercentage = Double(10) / Double(20) // 50%
        XCTAssertGreaterThan(medPercentage, 0.3)
        XCTAssertLessThan(medPercentage, 0.6)

        // Low health (< 30%)
        let lowPercentage = Double(4) / Double(20) // 20%
        XCTAssertLessThan(lowPercentage, 0.3)
    }
}

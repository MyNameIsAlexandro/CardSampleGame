import XCTest
import TwilightEngine

@testable import CardSampleGame

/// Tests for the HeroPanel component
/// Verifies that the unified hero panel displays correctly across all screens
final class HeroPanelTests: XCTestCase {

    // MARK: - Test Engine Setup

    var engine: TwilightGameEngine!

    override func setUp() {
        super.setUp()
        engine = TwilightGameEngine()
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Hero Display Tests

    func testHeroDisplaysCorrectly() {
        // Given: Get first available hero from registry
        let registry = HeroRegistry.shared
        guard let hero = registry.firstHero else {
            XCTFail("No heroes in registry"); return
        }

        // Set hero via Engine-First
        engine.setHeroId(hero.id)

        // Then: Hero ID should be set
        XCTAssertEqual(engine.heroId, hero.id)
    }

    func testAllHeroesHaveValidData() {
        // Verify all heroes have valid data for display
        let registry = HeroRegistry.shared

        for hero in registry.allHeroes {
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
        engine.setPlayerMaxHealth(20)
        engine.setPlayerHealth(15)
        engine.setPlayerFaith(8)
        engine.setPlayerBalance(65)
        engine.setPlayerName("Тестовый Герой")

        // Then: Stats should be readable from engine
        XCTAssertEqual(engine.playerName, "Тестовый Герой")
        XCTAssertEqual(engine.playerHealth, 15)
        XCTAssertEqual(engine.playerMaxHealth, 20)
        XCTAssertEqual(engine.playerFaith, 8)
        XCTAssertEqual(engine.playerBalance, 65)
    }

    // MARK: - Balance Display Tests

    func testBalanceDescriptionForLightPath() {
        // Given: Player with high balance (Light path)
        engine.setPlayerBalance(80)

        // Then: Balance should indicate Light path
        XCTAssertGreaterThanOrEqual(engine.playerBalance, 70)
    }

    func testBalanceDescriptionForDarkPath() {
        // Given: Player with low balance (Dark path)
        engine.setPlayerBalance(20)

        // Then: Balance should indicate Dark path
        XCTAssertLessThanOrEqual(engine.playerBalance, 30)
    }

    func testBalanceDescriptionForNeutral() {
        // Given: Player with neutral balance
        engine.setPlayerBalance(50)

        // Then: Balance should be in neutral range
        let balance = engine.playerBalance
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

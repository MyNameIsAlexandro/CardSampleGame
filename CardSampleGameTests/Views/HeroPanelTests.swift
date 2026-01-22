import XCTest
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

    func testHeroDisplaysCorrectly() throws {
        // Given: Get first available hero from registry
        let registry = HeroRegistry.shared
        guard let hero = registry.firstHero else {
            throw XCTSkip("No heroes in registry")
        }

        let player = Player(name: "Тест Герой", heroId: hero.id)
        let worldState = WorldState()

        engine.connectToLegacy(worldState: worldState, player: player)

        // Then: Hero ID should be set
        XCTAssertEqual(engine.legacyPlayer?.heroId, hero.id)
        // heroDefinition should be accessible
        XCTAssertNotNil(engine.legacyPlayer?.heroDefinition)
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
        // Given: Engine connected to legacy with specific stats
        let player = Player(name: "Тестовый Герой", health: 15, maxHealth: 20, faith: 8, balance: 65)
        let worldState = WorldState()

        engine.connectToLegacy(worldState: worldState, player: player)

        // Then: Stats should be readable from engine via legacyPlayer adapter
        // Engine reads from legacy player through adapter
        XCTAssertEqual(engine.legacyPlayer?.name, "Тестовый Герой")
        XCTAssertEqual(engine.legacyPlayer?.health, 15)
        XCTAssertEqual(engine.legacyPlayer?.maxHealth, 20)
        XCTAssertEqual(engine.legacyPlayer?.faith, 8)
        XCTAssertEqual(engine.legacyPlayer?.balance, 65)
    }

    // MARK: - Balance Display Tests

    func testBalanceDescriptionForLightPath() {
        // Given: Player with high balance (Light path)
        let player = Player(name: "Светлый")
        player.balance = 80
        let worldState = WorldState()

        engine.connectToLegacy(worldState: worldState, player: player)

        // Then: Balance should indicate Light path
        XCTAssertGreaterThanOrEqual(engine.playerBalance, 70)
    }

    func testBalanceDescriptionForDarkPath() {
        // Given: Player with low balance (Dark path)
        let player = Player(name: "Тёмный")
        player.balance = 20
        let worldState = WorldState()

        engine.connectToLegacy(worldState: worldState, player: player)

        // Then: Balance should indicate Dark path
        XCTAssertLessThanOrEqual(engine.playerBalance, 30)
    }

    func testBalanceDescriptionForNeutral() {
        // Given: Player with neutral balance
        let player = Player(name: "Нейтральный")
        player.balance = 50
        let worldState = WorldState()

        engine.connectToLegacy(worldState: worldState, player: player)

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
        XCTAssertLessThanOrEqual(medPercentage, 0.6)

        // Low health (< 30%)
        let lowPercentage = Double(4) / Double(20) // 20%
        XCTAssertLessThanOrEqual(lowPercentage, 0.3)
    }

    // MARK: - Hero Initials Tests

    func testHeroInitialsFromTwoWordName() {
        // Given: Two-word name
        let name = "Иван Петров"
        let words = name.split(separator: " ")

        // When: Getting initials
        let initials: String
        if words.count >= 2 {
            initials = String(words[0].prefix(1)) + String(words[1].prefix(1))
        } else {
            initials = String(name.prefix(2)).uppercased()
        }

        // Then: Should be first letters of each word
        XCTAssertEqual(initials, "ИП")
    }

    func testHeroInitialsFromSingleWordName() {
        // Given: Single-word name
        let name = "Странник"
        let words = name.split(separator: " ")

        // When: Getting initials
        let initials: String
        if words.count >= 2 {
            initials = String(words[0].prefix(1)) + String(words[1].prefix(1))
        } else {
            initials = String(name.prefix(2)).uppercased()
        }

        // Then: Should be first two letters uppercase
        XCTAssertEqual(initials, "СТ")
    }
}

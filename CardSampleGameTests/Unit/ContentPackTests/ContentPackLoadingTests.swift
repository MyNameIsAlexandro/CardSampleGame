import XCTest
@testable import CardSampleGame

/// Comprehensive tests for ContentPack loading
/// These tests verify that ALL content files can be loaded and used by the game
/// Tests run through public API to ensure content works in actual gameplay scenarios
final class ContentPackLoadingTests: XCTestCase {

    // MARK: - Properties

    private var testPackURL: URL!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        ContentRegistry.shared.resetForTesting()
        AbilityRegistry.shared.reload()

        // Point to the TwilightMarches pack
        // From: CardSampleGameTests/Unit/ContentPackTests/ContentPackLoadingTests.swift
        // Need to go up 4 levels to reach project root:
        // 1. removes ContentPackLoadingTests.swift → ContentPackTests/
        // 2. removes ContentPackTests → Unit/
        // 3. removes Unit → CardSampleGameTests/
        // 4. removes CardSampleGameTests → project root
        testPackURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // ContentPackLoadingTests.swift → ContentPackTests
            .deletingLastPathComponent() // ContentPackTests → Unit
            .deletingLastPathComponent() // Unit → CardSampleGameTests
            .deletingLastPathComponent() // CardSampleGameTests → project root
            .appendingPathComponent("ContentPacks/TwilightMarches")
    }

    override func tearDown() {
        ContentRegistry.shared.resetForTesting()
        AbilityRegistry.shared.reload()
        testPackURL = nil
        super.tearDown()
    }

    // MARK: - Pack Loading Gate Test

    /// This is the main gate test - if this fails, the game won't start
    func testContentPackLoadsSuccessfully() throws {
        // Verify path
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: testPackURL.path),
            "ContentPack path must exist: \(testPackURL.path)"
        )

        // When
        let pack: LoadedPack
        do {
            pack = try ContentRegistry.shared.loadPack(from: testPackURL)
        } catch {
            XCTFail("Failed to load content pack: \(error)")
            return
        }

        // Then
        XCTAssertEqual(pack.manifest.packId, "twilight-marches-act1")
        XCTAssertFalse(pack.heroes.isEmpty, "Heroes must be loaded (got \(pack.heroes.count))")
        XCTAssertFalse(pack.regions.isEmpty, "Regions must be loaded (got \(pack.regions.count))")
        XCTAssertFalse(pack.events.isEmpty, "Events must be loaded (got \(pack.events.count))")
        XCTAssertFalse(pack.quests.isEmpty, "Quests must be loaded (got \(pack.quests.count))")
        XCTAssertFalse(pack.cards.isEmpty, "Cards must be loaded (got \(pack.cards.count))")
        XCTAssertFalse(pack.enemies.isEmpty, "Enemies must be loaded (got \(pack.enemies.count))")
        XCTAssertFalse(pack.anchors.isEmpty, "Anchors must be loaded (got \(pack.anchors.count))")
        XCTAssertNotNil(pack.balanceConfig, "Balance config must be loaded")
    }

    // MARK: - Heroes Tests

    func testAllHeroesLoadWithValidAbilities() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)

        // When
        let heroes = ContentRegistry.shared.getAllHeroes()

        // Then
        XCTAssertGreaterThanOrEqual(heroes.count, 5, "Should have at least 5 heroes")

        for hero in heroes {
            XCTAssertFalse(hero.id.isEmpty, "Hero \(hero.name) must have ID")
            XCTAssertFalse(hero.name.isEmpty, "Hero \(hero.id) must have name")
            XCTAssertFalse(hero.icon.isEmpty, "Hero \(hero.id) must have icon")

            // Verify ability is loaded and accessible
            let ability = hero.specialAbility
            XCTAssertFalse(ability.id.isEmpty, "Hero \(hero.id) ability must have ID")
            XCTAssertFalse(ability.name.isEmpty, "Hero \(hero.id) ability must have name")

            // Verify stats are valid
            XCTAssertGreaterThan(hero.baseStats.maxHealth, 0, "Hero \(hero.id) must have positive max health")
            XCTAssertGreaterThan(hero.baseStats.health, 0, "Hero \(hero.id) must have positive health")
            XCTAssertGreaterThanOrEqual(hero.baseStats.faith, 0, "Hero \(hero.id) must have non-negative faith")

            // Verify starting deck
            XCTAssertFalse(hero.startingDeckCardIDs.isEmpty, "Hero \(hero.id) must have starting deck")
        }
    }

    func testHeroStartingDecksReferenceValidCards() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)

        // When
        let heroes = ContentRegistry.shared.getAllHeroes()
        let allCards = ContentRegistry.shared.getAllCards()
        let cardIds = Set(allCards.map { $0.id })

        // Then
        for hero in heroes {
            for cardId in hero.startingDeckCardIDs {
                XCTAssertTrue(
                    cardIds.contains(cardId),
                    "Hero \(hero.id) references non-existent card '\(cardId)'"
                )
            }
        }
    }

    func testGetHeroByIdWorks() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)

        // When/Then - Test specific heroes
        let ragnar = ContentRegistry.shared.getHero(id: "warrior_ragnar")
        XCTAssertNotNil(ragnar, "Should find warrior_ragnar")
        XCTAssertEqual(ragnar?.id, "warrior_ragnar")

        let elvira = ContentRegistry.shared.getHero(id: "mage_elvira")
        XCTAssertNotNil(elvira, "Should find mage_elvira")

        let thorin = ContentRegistry.shared.getHero(id: "ranger_thorin")
        XCTAssertNotNil(thorin, "Should find ranger_thorin")

        let aurelius = ContentRegistry.shared.getHero(id: "priest_aurelius")
        XCTAssertNotNil(aurelius, "Should find priest_aurelius")

        let umbra = ContentRegistry.shared.getHero(id: "shadow_umbra")
        XCTAssertNotNil(umbra, "Should find shadow_umbra")
    }

    // MARK: - Abilities Tests

    func testAllAbilitiesLoadFromJSON() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)

        // When
        let abilities = AbilityRegistry.shared.allAbilities

        // Then
        XCTAssertGreaterThanOrEqual(abilities.count, 5, "Should have at least 5 abilities")

        for ability in abilities {
            XCTAssertFalse(ability.id.isEmpty, "Ability must have ID")
            XCTAssertFalse(ability.name.isEmpty, "Ability \(ability.id) must have name")
            XCTAssertFalse(ability.icon.isEmpty, "Ability \(ability.id) must have icon")
        }
    }

    func testAbilityLookupWorks() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)

        // When/Then
        let warriorRage = HeroAbility.forAbilityId("warrior_rage")
        XCTAssertNotNil(warriorRage, "Should find warrior_rage ability")

        let mageMeditation = HeroAbility.forAbilityId("mage_meditation")
        XCTAssertNotNil(mageMeditation, "Should find mage_meditation ability")

        let rangerTracking = HeroAbility.forAbilityId("ranger_tracking")
        XCTAssertNotNil(rangerTracking, "Should find ranger_tracking ability")

        let priestBlessing = HeroAbility.forAbilityId("priest_blessing")
        XCTAssertNotNil(priestBlessing, "Should find priest_blessing ability")

        let shadowAmbush = HeroAbility.forAbilityId("shadow_ambush")
        XCTAssertNotNil(shadowAmbush, "Should find shadow_ambush ability")
    }

    // MARK: - Cards Tests

    func testAllCardsLoadWithValidStructure() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)

        // When
        let cards = ContentRegistry.shared.getAllCards()

        // Then
        XCTAssertGreaterThanOrEqual(cards.count, 10, "Should have at least 10 cards")

        for card in cards {
            XCTAssertFalse(card.id.isEmpty, "Card must have ID")
            XCTAssertFalse(card.name.isEmpty, "Card \(card.id) must have name")
            XCTAssertFalse(card.icon.isEmpty, "Card \(card.id) must have icon")
            XCTAssertGreaterThanOrEqual(card.faithCost, 0, "Card \(card.id) must have non-negative faith cost")
        }
    }

    func testGetCardByIdWorks() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)

        // When/Then - Test basic cards
        let strikeBasic = ContentRegistry.shared.getCard(id: "strike_basic")
        XCTAssertNotNil(strikeBasic, "Should find strike_basic card")

        let defendBasic = ContentRegistry.shared.getCard(id: "defend_basic")
        XCTAssertNotNil(defendBasic, "Should find defend_basic card")
    }

    func testCardAbilitiesDecodeCorrectly() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)

        // When
        let cards = ContentRegistry.shared.getAllCards()
        let cardsWithAbilities = cards.filter { !$0.abilities.isEmpty }

        // Then - At least some cards should have abilities
        XCTAssertFalse(cardsWithAbilities.isEmpty, "Some cards should have abilities")

        for card in cardsWithAbilities {
            for ability in card.abilities {
                XCTAssertFalse(ability.name.isEmpty, "Card \(card.id) ability must have name")
            }
        }
    }

    // MARK: - Enemies Tests

    func testAllEnemiesLoadWithValidStructure() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)

        // When
        let enemies = ContentRegistry.shared.getAllEnemies()

        // Then
        XCTAssertGreaterThanOrEqual(enemies.count, 5, "Should have at least 5 enemies")

        for enemy in enemies {
            XCTAssertFalse(enemy.id.isEmpty, "Enemy must have ID")
            XCTAssertFalse(enemy.name.localized.isEmpty, "Enemy \(enemy.id) must have name")
            XCTAssertGreaterThan(enemy.health, 0, "Enemy \(enemy.id) must have positive health")
            XCTAssertGreaterThan(enemy.power, 0, "Enemy \(enemy.id) must have positive power")
            XCTAssertGreaterThanOrEqual(enemy.defense, 0, "Enemy \(enemy.id) must have non-negative defense")
        }
    }

    func testGetEnemyByIdWorks() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)

        // When/Then
        let leshy = ContentRegistry.shared.getEnemy(id: "leshy")
        XCTAssertNotNil(leshy, "Should find leshy enemy")

        let wildBeast = ContentRegistry.shared.getEnemy(id: "wild_beast")
        XCTAssertNotNil(wildBeast, "Should find wild_beast enemy")

        let boss = ContentRegistry.shared.getEnemy(id: "leshy_guardian_boss")
        XCTAssertNotNil(boss, "Should find leshy_guardian_boss enemy")
    }

    // MARK: - Regions Tests

    func testAllRegionsLoadWithValidStructure() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)

        // When
        let regions = ContentRegistry.shared.getAllRegions()

        // Then
        XCTAssertGreaterThanOrEqual(regions.count, 5, "Should have at least 5 regions")

        for region in regions {
            XCTAssertFalse(region.id.isEmpty, "Region must have ID")
            XCTAssertFalse(region.title.localized.isEmpty, "Region \(region.id) must have title")
        }
    }

    func testGetRegionByIdWorks() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)

        // When/Then
        let village = ContentRegistry.shared.getRegion(id: "village")
        XCTAssertNotNil(village, "Should find village region")

        let forest = ContentRegistry.shared.getRegion(id: "forest")
        XCTAssertNotNil(forest, "Should find forest region")
    }

    // MARK: - Events Tests

    func testAllEventsLoadWithValidStructure() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)

        // When
        let events = ContentRegistry.shared.getAllEvents()

        // Then
        XCTAssertGreaterThanOrEqual(events.count, 5, "Should have at least 5 events")

        for event in events {
            XCTAssertFalse(event.id.isEmpty, "Event must have ID")
            XCTAssertFalse(event.title.localized.isEmpty, "Event \(event.id) must have title")
        }
    }

    // MARK: - Quests Tests

    func testAllQuestsLoadWithValidStructure() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)

        // When
        let quests = ContentRegistry.shared.getAllQuests()

        // Then
        XCTAssertGreaterThanOrEqual(quests.count, 1, "Should have at least 1 quest")

        for quest in quests {
            XCTAssertFalse(quest.id.isEmpty, "Quest must have ID")
            XCTAssertFalse(quest.title.localized.isEmpty, "Quest \(quest.id) must have title")
        }
    }

    // MARK: - Anchors Tests

    func testAllAnchorsLoadWithValidStructure() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)

        // When
        let anchors = ContentRegistry.shared.getAllAnchors()

        // Then
        XCTAssertGreaterThanOrEqual(anchors.count, 5, "Should have at least 5 anchors")

        for anchor in anchors {
            XCTAssertFalse(anchor.id.isEmpty, "Anchor must have ID")
            XCTAssertFalse(anchor.title.localized.isEmpty, "Anchor \(anchor.id) must have title")
            XCTAssertFalse(anchor.regionId.isEmpty, "Anchor \(anchor.id) must have regionId")
            XCTAssertGreaterThan(anchor.maxIntegrity, 0, "Anchor \(anchor.id) must have positive max integrity")
        }
    }

    func testAnchorRegionIdsReferenceValidRegions() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)

        // When
        let anchors = ContentRegistry.shared.getAllAnchors()
        let regions = ContentRegistry.shared.getAllRegions()
        let regionIds = Set(regions.map { $0.id })

        // Then
        for anchor in anchors {
            XCTAssertTrue(
                regionIds.contains(anchor.regionId),
                "Anchor \(anchor.id) references non-existent region '\(anchor.regionId)'"
            )
        }
    }

    // MARK: - Balance Config Tests

    func testBalanceConfigLoadsWithValidValues() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)

        // When
        let config = ContentRegistry.shared.getBalanceConfig()

        // Then
        XCTAssertNotNil(config, "Balance config must be loaded")
        guard let config = config else { return }

        // Resources
        XCTAssertGreaterThan(config.resources.maxHealth, 0, "Max health must be positive")
        XCTAssertGreaterThan(config.resources.maxFaith, 0, "Max faith must be positive")

        // Pressure
        XCTAssertGreaterThanOrEqual(config.pressure.minPressure, 0, "Min pressure must be non-negative")
        XCTAssertGreaterThan(config.pressure.maxPressure, 0, "Max pressure must be positive")

        // Anchor
        XCTAssertGreaterThan(config.anchor.maxIntegrity, 0, "Anchor max integrity must be positive")
    }

    // MARK: - Content Validation Tests

    func testNoContentValidationErrors() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)

        // When
        let errors = ContentRegistry.shared.validateAllContent()

        // Then - Filter only critical errors (broken references)
        let brokenReferences = errors.filter { $0.type == .brokenReference }
        if !brokenReferences.isEmpty {
            let errorMessages = brokenReferences.map { "[\($0.definitionId)] \($0.message)" }
            XCTFail("Content has broken references:\n\(errorMessages.joined(separator: "\n"))")
        }
    }

    // MARK: - Game Startup Simulation Tests

    func testCanCreateStartingDeckForAllHeroes() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)

        // When
        let heroes = ContentRegistry.shared.getAllHeroes()

        // Then
        for hero in heroes {
            let deck = ContentRegistry.shared.getStartingDeck(forHero: hero.id)
            XCTAssertFalse(deck.isEmpty, "Hero \(hero.id) starting deck should not be empty")
            XCTAssertEqual(
                deck.count,
                hero.startingDeckCardIDs.count,
                "Hero \(hero.id) deck should have \(hero.startingDeckCardIDs.count) cards"
            )
        }
    }

    func testCanCreatePlayerFromHeroDefinition() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)
        guard let heroDefinition = ContentRegistry.shared.getHero(id: "warrior_ragnar") else {
            XCTFail("Should find warrior_ragnar hero")
            return
        }

        // When - Create player using hero stats
        let player = Player(
            name: heroDefinition.name,
            health: heroDefinition.baseStats.health,
            maxHealth: heroDefinition.baseStats.maxHealth,
            strength: heroDefinition.baseStats.strength,
            dexterity: heroDefinition.baseStats.dexterity,
            constitution: heroDefinition.baseStats.constitution,
            intelligence: heroDefinition.baseStats.intelligence,
            wisdom: heroDefinition.baseStats.wisdom,
            charisma: heroDefinition.baseStats.charisma,
            faith: heroDefinition.baseStats.faith,
            maxFaith: heroDefinition.baseStats.maxFaith,
            balance: heroDefinition.baseStats.startingBalance,
            heroId: heroDefinition.id
        )

        // Load starting deck
        let startingDeck = ContentRegistry.shared.getStartingDeck(forHero: heroDefinition.id)
        for card in startingDeck {
            player.deck.append(card.toCard())
        }

        // Then
        XCTAssertEqual(player.name, heroDefinition.name)
        XCTAssertEqual(player.health, heroDefinition.baseStats.health)
        XCTAssertEqual(player.maxHealth, heroDefinition.baseStats.maxHealth)
        XCTAssertFalse(player.deck.isEmpty, "Player should have cards in deck")
    }

    func testCanConvertEnemyDefinitionToCard() throws {
        // Given
        try ContentRegistry.shared.loadPack(from: testPackURL)
        guard let enemyDefinition = ContentRegistry.shared.getEnemy(id: "leshy") else {
            XCTFail("Should find leshy enemy")
            return
        }

        // When
        let card = enemyDefinition.toCard()

        // Then
        XCTAssertEqual(card.name, enemyDefinition.name.localized)
        XCTAssertEqual(card.health, enemyDefinition.health)
        XCTAssertEqual(card.power, enemyDefinition.power)
        XCTAssertEqual(card.type, .monster)
    }

    // MARK: - Performance Tests

    func testContentLoadingPerformance() throws {
        measure {
            ContentRegistry.shared.resetForTesting()
            AbilityRegistry.shared.reload()
            _ = try? ContentRegistry.shared.loadPack(from: testPackURL)
        }
    }
}

import XCTest
import TwilightEngine
import CoreHeroesContent
import TwilightMarchesActIContent

@testable import CardSampleGame

/// Tests for ContentRegistry functionality
final class ContentRegistryTests: XCTestCase {

    // MARK: - Properties

    private var characterPackURL: URL?
    private var storyPackURL: URL?

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        // Reset registry before each test
        ContentRegistry.shared.resetForTesting()

        // Use TestContentLoader for robust URL discovery (with file path fallback)
        characterPackURL = TestContentLoader.characterPackURL
        storyPackURL = TestContentLoader.storyPackURL
    }

    override func tearDown() {
        ContentRegistry.shared.resetForTesting()
        characterPackURL = nil
        storyPackURL = nil
        super.tearDown()
    }

    // MARK: - Pack Loading Tests

    func testLoadMultiplePacks() throws {
        // Skip if packs not available (Bundle.module resolution issue in tests)
        try XCTSkipIf(characterPackURL == nil, "CoreHeroes pack not available - Bundle.module resolution issue")
        try XCTSkipIf(storyPackURL == nil, "TwilightMarchesActI pack not available")

        // When - Load both packs using multi-pack loader
        let packs = try ContentRegistry.shared.loadPacks(from: [characterPackURL!, storyPackURL!])

        // Then
        XCTAssertEqual(packs.count, 2)
        XCTAssertTrue(ContentRegistry.shared.loadedPackIds.contains("core-heroes"))
        XCTAssertTrue(ContentRegistry.shared.loadedPackIds.contains("twilight-marches-act1"))
    }

    func testLoadPackRegistersContent() throws {
        // Skip if packs not available
        try XCTSkipIf(characterPackURL == nil, "CoreHeroes pack not available - Bundle.module resolution issue")
        try XCTSkipIf(storyPackURL == nil, "TwilightMarchesActI pack not available")

        // When
        try ContentRegistry.shared.loadPacks(from: [characterPackURL!, storyPackURL!])

        // Then
        XCTAssertGreaterThan(ContentRegistry.shared.getAllCards().count, 0)
        XCTAssertGreaterThan(ContentRegistry.shared.getAllHeroes().count, 0)
        XCTAssertGreaterThan(ContentRegistry.shared.getAllRegions().count, 0)
    }

    func testLoadPackUpdatesBalanceConfig() throws {
        // Given - No balance config before loading
        XCTAssertNil(ContentRegistry.shared.getBalanceConfig())

        // Skip if packs not available
        try XCTSkipIf(characterPackURL == nil, "CoreHeroes pack not available - Bundle.module resolution issue")
        try XCTSkipIf(storyPackURL == nil, "TwilightMarchesActI pack not available")

        // When
        try ContentRegistry.shared.loadPacks(from: [characterPackURL!, storyPackURL!])

        // Then
        XCTAssertNotNil(ContentRegistry.shared.getBalanceConfig())
    }

    func testCannotLoadSamePackTwice() throws {
        // Skip if character pack not available
        try XCTSkipIf(characterPackURL == nil, "CoreHeroes pack not available - Bundle.module resolution issue")

        // Given
        try ContentRegistry.shared.loadPack(from: characterPackURL!)

        // Then - Should throw when trying to load again
        XCTAssertThrowsError(try ContentRegistry.shared.loadPack(from: characterPackURL!)) { error in
            if case PackLoadError.packAlreadyLoaded(let packId) = error {
                XCTAssertEqual(packId, "core-heroes")
            } else {
                XCTFail("Expected packAlreadyLoaded error")
            }
        }
    }

    // MARK: - Content Access Tests

    func testGetCardById() throws {
        // Skip if packs not available
        try XCTSkipIf(characterPackURL == nil, "CoreHeroes pack not available - Bundle.module resolution issue")
        try XCTSkipIf(storyPackURL == nil, "TwilightMarchesActI pack not available")

        // Given
        try ContentRegistry.shared.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When - Try to get a known card
        let allCards = ContentRegistry.shared.getAllCards()
        guard let firstCard = allCards.first else {
            XCTFail("No cards loaded")
            return
        }

        // Then
        let fetchedCard = ContentRegistry.shared.getCard(id: firstCard.id)
        XCTAssertNotNil(fetchedCard)
        XCTAssertEqual(fetchedCard?.id, firstCard.id)
    }

    func testGetHeroById() throws {
        // Skip if packs not available
        try XCTSkipIf(characterPackURL == nil, "CoreHeroes pack not available - Bundle.module resolution issue")
        try XCTSkipIf(storyPackURL == nil, "TwilightMarchesActI pack not available")

        // Given
        try ContentRegistry.shared.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When
        let allHeroes = ContentRegistry.shared.getAllHeroes()
        guard let firstHero = allHeroes.first else {
            XCTFail("No heroes loaded")
            return
        }

        // Then
        let fetchedHero = ContentRegistry.shared.getHero(id: firstHero.id)
        XCTAssertNotNil(fetchedHero)
        XCTAssertEqual(fetchedHero?.id, firstHero.id)
    }

    func testGetNonExistentContent() throws {
        // Skip if packs not available
        try XCTSkipIf(characterPackURL == nil, "CoreHeroes pack not available - Bundle.module resolution issue")
        try XCTSkipIf(storyPackURL == nil, "TwilightMarchesActI pack not available")

        // Given
        try ContentRegistry.shared.loadPacks(from: [characterPackURL!, storyPackURL!])

        // Then
        XCTAssertNil(ContentRegistry.shared.getCard(id: "nonexistent_card"))
        XCTAssertNil(ContentRegistry.shared.getHero(id: "nonexistent_hero"))
        XCTAssertNil(ContentRegistry.shared.getRegion(id: "nonexistent_region"))
    }

    // MARK: - Starting Deck Tests

    func testGetStartingDeckForHero() throws {
        // Skip if packs not available
        try XCTSkipIf(characterPackURL == nil, "CoreHeroes pack not available - Bundle.module resolution issue")
        try XCTSkipIf(storyPackURL == nil, "TwilightMarchesActI pack not available")

        // Given
        try ContentRegistry.shared.loadPacks(from: [characterPackURL!, storyPackURL!])
        let allHeroes = ContentRegistry.shared.getAllHeroes()
        guard let hero = allHeroes.first else {
            XCTFail("No heroes loaded")
            return
        }

        // When
        let startingDeck = ContentRegistry.shared.getStartingDeck(forHero: hero.id)

        // Then
        XCTAssertFalse(startingDeck.isEmpty, "Hero should have starting deck")
        XCTAssertEqual(startingDeck.count, hero.startingDeckCardIDs.count)
    }

    // MARK: - Unload Tests

    func testUnloadPack() throws {
        // Skip if packs not available
        try XCTSkipIf(characterPackURL == nil, "CoreHeroes pack not available - Bundle.module resolution issue")
        try XCTSkipIf(storyPackURL == nil, "TwilightMarchesActI pack not available")

        // Given
        try ContentRegistry.shared.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When - Unload character pack
        ContentRegistry.shared.unloadPack("core-heroes")

        // Then - Only character pack content should be gone
        XCTAssertFalse(ContentRegistry.shared.loadedPackIds.contains("core-heroes"))
        XCTAssertTrue(ContentRegistry.shared.loadedPackIds.contains("twilight-marches-act1"))
    }

    func testUnloadAllPacks() throws {
        // Skip if packs not available
        try XCTSkipIf(characterPackURL == nil, "CoreHeroes pack not available - Bundle.module resolution issue")
        try XCTSkipIf(storyPackURL == nil, "TwilightMarchesActI pack not available")

        // Given
        try ContentRegistry.shared.loadPacks(from: [characterPackURL!, storyPackURL!])
        XCTAssertGreaterThan(ContentRegistry.shared.getAllCards().count, 0)

        // When
        ContentRegistry.shared.unloadAllPacks()

        // Then
        XCTAssertEqual(ContentRegistry.shared.getAllCards().count, 0)
        XCTAssertEqual(ContentRegistry.shared.getAllHeroes().count, 0)
        XCTAssertTrue(ContentRegistry.shared.loadedPackIds.isEmpty)
    }

    // MARK: - Validation Tests

    func testValidateLoadedContent() throws {
        // Skip if packs not available
        try XCTSkipIf(characterPackURL == nil, "CoreHeroes pack not available - Bundle.module resolution issue")
        try XCTSkipIf(storyPackURL == nil, "TwilightMarchesActI pack not available")

        // Given
        try ContentRegistry.shared.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When
        let errors = ContentRegistry.shared.validateAllContent()

        // Then - Should have no critical errors (warnings are OK)
        let criticalErrors = errors.filter { $0.type == .brokenReference }
        XCTAssertTrue(criticalErrors.isEmpty, "Should have no broken references: \(criticalErrors)")
    }

    // MARK: - Inventory Tests

    func testTotalInventory() throws {
        // Skip if packs not available
        try XCTSkipIf(characterPackURL == nil, "CoreHeroes pack not available - Bundle.module resolution issue")
        try XCTSkipIf(storyPackURL == nil, "TwilightMarchesActI pack not available")

        // Given
        try ContentRegistry.shared.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When
        let inventory = ContentRegistry.shared.totalInventory

        // Then
        XCTAssertGreaterThan(inventory.cardCount, 0)
        XCTAssertGreaterThan(inventory.heroCount, 0)
        XCTAssertTrue(inventory.hasBalanceConfig)
    }

    // MARK: - ContentProvider Protocol Tests

    func testContentProviderProtocolConformance() throws {
        // Skip if packs not available
        try XCTSkipIf(characterPackURL == nil, "CoreHeroes pack not available - Bundle.module resolution issue")
        try XCTSkipIf(storyPackURL == nil, "TwilightMarchesActI pack not available")

        // Given
        try ContentRegistry.shared.loadPacks(from: [characterPackURL!, storyPackURL!])
        let provider: ContentProvider = ContentRegistry.shared

        // When/Then - Should work as ContentProvider
        XCTAssertFalse(provider.getAllRegionDefinitions().isEmpty, "Should have regions")
        XCTAssertFalse(provider.getAllEventDefinitions().isEmpty, "Should have events")
        XCTAssertFalse(provider.getAllQuestDefinitions().isEmpty, "Should have quests")
    }

    // MARK: - Pack Type Query Tests

    func testGetCharacterPacks() throws {
        // Skip if packs not available
        try XCTSkipIf(characterPackURL == nil, "CoreHeroes pack not available - Bundle.module resolution issue")
        try XCTSkipIf(storyPackURL == nil, "TwilightMarchesActI pack not available")

        // Given
        try ContentRegistry.shared.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When
        let characterPacks = ContentRegistry.shared.getCharacterPacks()

        // Then
        XCTAssertEqual(characterPacks.count, 1)
        XCTAssertEqual(characterPacks.first?.manifest.packId, "core-heroes")
    }

    func testGetStoryPacks() throws {
        // Skip if packs not available
        try XCTSkipIf(characterPackURL == nil, "CoreHeroes pack not available - Bundle.module resolution issue")
        try XCTSkipIf(storyPackURL == nil, "TwilightMarchesActI pack not available")

        // Given
        try ContentRegistry.shared.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When
        let storyPacks = ContentRegistry.shared.getStoryPacks()

        // Then
        XCTAssertEqual(storyPacks.count, 1)
        XCTAssertEqual(storyPacks.first?.manifest.packId, "twilight-marches-act1")
    }

    func testIsReadyForGameplay() throws {
        // Given - No packs loaded
        XCTAssertFalse(ContentRegistry.shared.isReadyForGameplay)

        // Skip if packs not available
        try XCTSkipIf(characterPackURL == nil, "CoreHeroes pack not available - Bundle.module resolution issue")
        try XCTSkipIf(storyPackURL == nil, "TwilightMarchesActI pack not available")

        // When - Load only character pack
        try ContentRegistry.shared.loadPack(from: characterPackURL!)
        XCTAssertFalse(ContentRegistry.shared.isReadyForGameplay)

        // When - Load story pack
        try ContentRegistry.shared.loadPack(from: storyPackURL!)
        XCTAssertTrue(ContentRegistry.shared.isReadyForGameplay)
    }

    // MARK: - Season/Campaign Query Tests

    func testGetPacksBySeason() throws {
        // Skip if packs not available
        try XCTSkipIf(characterPackURL == nil, "CoreHeroes pack not available - Bundle.module resolution issue")
        try XCTSkipIf(storyPackURL == nil, "TwilightMarchesActI pack not available")

        // Given
        try ContentRegistry.shared.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When
        let season1Packs = ContentRegistry.shared.getPacksBySeason("season1")

        // Then - TwilightMarchesActI should be in season1
        XCTAssertEqual(season1Packs.count, 1)
        XCTAssertEqual(season1Packs.first?.manifest.packId, "twilight-marches-act1")
    }

    func testGetPacksByCampaign() throws {
        // Skip if packs not available
        try XCTSkipIf(characterPackURL == nil, "CoreHeroes pack not available - Bundle.module resolution issue")
        try XCTSkipIf(storyPackURL == nil, "TwilightMarchesActI pack not available")

        // Given
        try ContentRegistry.shared.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When
        let campaignPacks = ContentRegistry.shared.getPacksByCampaign("twilight-marches")

        // Then
        XCTAssertEqual(campaignPacks.count, 1)
        XCTAssertEqual(campaignPacks.first?.manifest.packId, "twilight-marches-act1")
        XCTAssertEqual(campaignPacks.first?.manifest.campaignOrder, 1)
    }

    func testGetAvailableSeasons() throws {
        // Skip if packs not available
        try XCTSkipIf(characterPackURL == nil, "CoreHeroes pack not available - Bundle.module resolution issue")
        try XCTSkipIf(storyPackURL == nil, "TwilightMarchesActI pack not available")

        // Given
        try ContentRegistry.shared.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When
        let seasons = ContentRegistry.shared.getAvailableSeasons()

        // Then - Should include season1 from TwilightMarchesActI
        XCTAssertTrue(seasons.contains("season1"))
    }

    func testGetCampaignsInSeason() throws {
        // Skip if packs not available
        try XCTSkipIf(characterPackURL == nil, "CoreHeroes pack not available - Bundle.module resolution issue")
        try XCTSkipIf(storyPackURL == nil, "TwilightMarchesActI pack not available")

        // Given
        try ContentRegistry.shared.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When
        let campaigns = ContentRegistry.shared.getCampaignsInSeason("season1")

        // Then
        XCTAssertTrue(campaigns.contains("twilight-marches"))
    }

    func testIsCampaignCompleteWithSingleAct() throws {
        // Skip if packs not available
        try XCTSkipIf(characterPackURL == nil, "CoreHeroes pack not available - Bundle.module resolution issue")
        try XCTSkipIf(storyPackURL == nil, "TwilightMarchesActI pack not available")

        // Given
        try ContentRegistry.shared.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When - With only Act I loaded, campaign is "complete" (sequential from 1)
        let isComplete = ContentRegistry.shared.isCampaignComplete("twilight-marches")

        // Then - Act I starts at order 1, so it's complete for what's loaded
        XCTAssertTrue(isComplete)
    }

    func testGetNextPackInCampaignReturnsNilForLastAct() throws {
        // Skip if packs not available
        try XCTSkipIf(characterPackURL == nil, "CoreHeroes pack not available - Bundle.module resolution issue")
        try XCTSkipIf(storyPackURL == nil, "TwilightMarchesActI pack not available")

        // Given
        try ContentRegistry.shared.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When - Try to get next pack after Act I (Act II not loaded)
        let nextPack = ContentRegistry.shared.getNextPackInCampaign(after: "twilight-marches-act1")

        // Then - Should be nil since Act II isn't loaded
        XCTAssertNil(nextPack)
    }

    func testHasAllRequiredPacksForFirstAct() throws {
        // Skip if packs not available
        try XCTSkipIf(characterPackURL == nil, "CoreHeroes pack not available - Bundle.module resolution issue")
        try XCTSkipIf(storyPackURL == nil, "TwilightMarchesActI pack not available")

        // Given
        try ContentRegistry.shared.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When - Check if Act I has all required packs (it shouldn't require any)
        let hasRequired = ContentRegistry.shared.hasAllRequiredPacks(for: "twilight-marches-act1")

        // Then - Act I is the first act, so no required packs
        XCTAssertTrue(hasRequired)
    }

    func testCharacterPackHasNoSeason() throws {
        // Skip if packs not available
        try XCTSkipIf(characterPackURL == nil, "CoreHeroes pack not available - Bundle.module resolution issue")
        try XCTSkipIf(storyPackURL == nil, "TwilightMarchesActI pack not available")

        // Given
        try ContentRegistry.shared.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When - Get packs for non-existent season
        let noSeasonPacks = ContentRegistry.shared.getPacksBySeason("nonexistent")

        // Then - Should be empty
        XCTAssertTrue(noSeasonPacks.isEmpty)

        // And - CoreHeroes should not appear in season1 (it has no season)
        let characterPacks = ContentRegistry.shared.getCharacterPacks()
        XCTAssertNil(characterPacks.first?.manifest.season)
    }

    // MARK: - Mock Content Tests

    func testRegisterMockContent() {
        // Given
        let mockRegion = RegionDefinition(
            id: "test_region",
            title: .inline(LocalizedString(en: "Test", ru: "Тест")),
            description: .inline(LocalizedString(en: "Test region", ru: "Тестовый регион")),
            neighborIds: []
        )

        // When
        ContentRegistry.shared.registerMockContent(
            regions: ["test_region": mockRegion]
        )

        // Then
        XCTAssertNotNil(ContentRegistry.shared.getRegion(id: "test_region"))
        XCTAssertEqual(ContentRegistry.shared.getAllRegions().count, 1)
    }
}

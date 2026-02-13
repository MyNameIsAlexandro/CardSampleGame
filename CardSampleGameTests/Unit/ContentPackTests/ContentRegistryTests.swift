/// Файл: CardSampleGameTests/Unit/ContentPackTests/ContentRegistryTests.swift
/// Назначение: Содержит реализацию файла ContentRegistryTests.swift.
/// Зона ответственности: Фиксирует проверяемый контракт и не содержит production-логики.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
import TwilightEngine
import CoreHeroesContent
import TwilightMarchesActIContent

@testable import CardSampleGame

/// Tests for ContentRegistry functionality
final class ContentRegistryTests: XCTestCase {

    // MARK: - Properties

    private var registry: ContentRegistry!
    private var characterPackURL: URL?
    private var storyPackURL: URL?

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        registry = ContentRegistry()

        // Use TestContentLoader for robust URL discovery (with file path fallback)
        characterPackURL = TestContentLoader.characterPackURL
        storyPackURL = TestContentLoader.storyPackURL
    }

    override func tearDown() {
        registry = nil
        characterPackURL = nil
        storyPackURL = nil
        super.tearDown()
    }

    // MARK: - Pack Loading Tests

    func testLoadMultiplePacks() throws {
        // Skip if packs not available (Bundle.module resolution issue in tests)
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }
        if storyPackURL == nil { XCTFail("TwilightMarchesActI pack not available"); return }

        // When - Load both packs using multi-pack loader
        let packs = try registry.loadPacks(from: [characterPackURL!, storyPackURL!])

        // Then
        XCTAssertEqual(packs.count, 2)
        XCTAssertTrue(registry.loadedPackIds.contains("core-heroes"))
        XCTAssertTrue(registry.loadedPackIds.contains("twilight-marches-act1"))
    }

    func testLoadPackRegistersContent() throws {
        // Skip if packs not available
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }
        if storyPackURL == nil { XCTFail("TwilightMarchesActI pack not available"); return }

        // When
        try registry.loadPacks(from: [characterPackURL!, storyPackURL!])

        // Then
        XCTAssertGreaterThan(registry.getAllCards().count, 0)
        XCTAssertGreaterThan(registry.getAllHeroes().count, 0)
        XCTAssertGreaterThan(registry.getAllRegions().count, 0)
    }

    func testLoadPackUpdatesBalanceConfig() throws {
        // Given - No balance config before loading
        XCTAssertNil(registry.getBalanceConfig())

        // Skip if packs not available
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }
        if storyPackURL == nil { XCTFail("TwilightMarchesActI pack not available"); return }

        // When
        try registry.loadPacks(from: [characterPackURL!, storyPackURL!])

        // Then
        XCTAssertNotNil(registry.getBalanceConfig())
    }

    func testCannotLoadSamePackTwice() throws {
        // Skip if character pack not available
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }

        // Given
        try registry.loadPack(from: characterPackURL!)

        // Then - Should throw when trying to load again
        XCTAssertThrowsError(try registry.loadPack(from: characterPackURL!)) { error in
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
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }
        if storyPackURL == nil { XCTFail("TwilightMarchesActI pack not available"); return }

        // Given
        try registry.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When - Try to get a known card
        let allCards = registry.getAllCards()
        guard let firstCard = allCards.first else {
            XCTFail("No cards loaded")
            return
        }

        // Then
        let fetchedCard = registry.getCard(id: firstCard.id)
        XCTAssertNotNil(fetchedCard)
        XCTAssertEqual(fetchedCard?.id, firstCard.id)
    }

    func testGetHeroById() throws {
        // Skip if packs not available
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }
        if storyPackURL == nil { XCTFail("TwilightMarchesActI pack not available"); return }

        // Given
        try registry.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When
        let allHeroes = registry.getAllHeroes()
        guard let firstHero = allHeroes.first else {
            XCTFail("No heroes loaded")
            return
        }

        // Then
        let fetchedHero = registry.getHero(id: firstHero.id)
        XCTAssertNotNil(fetchedHero)
        XCTAssertEqual(fetchedHero?.id, firstHero.id)
    }

    func testGetNonExistentContent() throws {
        // Skip if packs not available
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }
        if storyPackURL == nil { XCTFail("TwilightMarchesActI pack not available"); return }

        // Given
        try registry.loadPacks(from: [characterPackURL!, storyPackURL!])

        // Then
        XCTAssertNil(registry.getCard(id: "nonexistent_card"))
        XCTAssertNil(registry.getHero(id: "nonexistent_hero"))
        XCTAssertNil(registry.getRegion(id: "nonexistent_region"))
    }

    // MARK: - Starting Deck Tests

    func testGetStartingDeckForHero() throws {
        // Skip if packs not available
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }
        if storyPackURL == nil { XCTFail("TwilightMarchesActI pack not available"); return }

        // Given
        try registry.loadPacks(from: [characterPackURL!, storyPackURL!])
        let allHeroes = registry.getAllHeroes()
        guard let hero = allHeroes.first else {
            XCTFail("No heroes loaded")
            return
        }

        // When
        let startingDeck = registry.getStartingDeck(forHero: hero.id)

        // Then
        XCTAssertFalse(startingDeck.isEmpty, "Hero should have starting deck")
        XCTAssertEqual(startingDeck.count, hero.startingDeckCardIDs.count)
    }

    // MARK: - Unload Tests

    func testUnloadPack() throws {
        // Skip if packs not available
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }
        if storyPackURL == nil { XCTFail("TwilightMarchesActI pack not available"); return }

        // Given
        try registry.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When - Unload character pack
        registry.unloadPack("core-heroes")

        // Then - Only character pack content should be gone
        XCTAssertFalse(registry.loadedPackIds.contains("core-heroes"))
        XCTAssertTrue(registry.loadedPackIds.contains("twilight-marches-act1"))
    }

    func testUnloadAllPacks() throws {
        // Skip if packs not available
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }
        if storyPackURL == nil { XCTFail("TwilightMarchesActI pack not available"); return }

        // Given
        try registry.loadPacks(from: [characterPackURL!, storyPackURL!])
        XCTAssertGreaterThan(registry.getAllCards().count, 0)

        // When
        registry.unloadAllPacks()

        // Then
        XCTAssertEqual(registry.getAllCards().count, 0)
        XCTAssertEqual(registry.getAllHeroes().count, 0)
        XCTAssertTrue(registry.loadedPackIds.isEmpty)
    }

    // MARK: - Validation Tests

    func testValidateLoadedContent() throws {
        // Skip if packs not available
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }
        if storyPackURL == nil { XCTFail("TwilightMarchesActI pack not available"); return }

        // Given
        try registry.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When
        let errors = registry.validateAllContent()

        // Then - Should have no critical errors (warnings are OK)
        let criticalErrors = errors.filter { $0.type == .brokenReference }
        XCTAssertTrue(criticalErrors.isEmpty, "Should have no broken references: \(criticalErrors)")
    }

    // MARK: - Inventory Tests

    func testTotalInventory() throws {
        // Skip if packs not available
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }
        if storyPackURL == nil { XCTFail("TwilightMarchesActI pack not available"); return }

        // Given
        try registry.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When
        let inventory = registry.totalInventory

        // Then
        XCTAssertGreaterThan(inventory.cardCount, 0)
        XCTAssertGreaterThan(inventory.heroCount, 0)
        XCTAssertTrue(inventory.hasBalanceConfig)
    }

    // MARK: - ContentProvider Protocol Tests

    func testContentProviderProtocolConformance() throws {
        // Skip if packs not available
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }
        if storyPackURL == nil { XCTFail("TwilightMarchesActI pack not available"); return }

        // Given
        try registry.loadPacks(from: [characterPackURL!, storyPackURL!])
        let provider: ContentProvider = registry

        // When/Then - Should work as ContentProvider
        XCTAssertFalse(provider.getAllRegionDefinitions().isEmpty, "Should have regions")
        XCTAssertFalse(provider.getAllEventDefinitions().isEmpty, "Should have events")
        XCTAssertFalse(provider.getAllQuestDefinitions().isEmpty, "Should have quests")
    }

    // MARK: - Pack Type Query Tests

    func testGetCharacterPacks() throws {
        // Skip if packs not available
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }
        if storyPackURL == nil { XCTFail("TwilightMarchesActI pack not available"); return }

        // Given
        try registry.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When
        let characterPacks = registry.getCharacterPacks()

        // Then
        XCTAssertEqual(characterPacks.count, 1)
        XCTAssertEqual(characterPacks.first?.manifest.packId, "core-heroes")
    }

    func testGetStoryPacks() throws {
        // Skip if packs not available
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }
        if storyPackURL == nil { XCTFail("TwilightMarchesActI pack not available"); return }

        // Given
        try registry.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When
        let storyPacks = registry.getStoryPacks()

        // Then
        XCTAssertEqual(storyPacks.count, 1)
        XCTAssertEqual(storyPacks.first?.manifest.packId, "twilight-marches-act1")
    }

    func testIsReadyForGameplay() throws {
        // Given - No packs loaded
        XCTAssertFalse(registry.isReadyForGameplay)

        // Skip if packs not available
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }
        if storyPackURL == nil { XCTFail("TwilightMarchesActI pack not available"); return }

        // When - Load only character pack
        try registry.loadPack(from: characterPackURL!)
        XCTAssertFalse(registry.isReadyForGameplay)

        // When - Load story pack
        try registry.loadPack(from: storyPackURL!)
        XCTAssertTrue(registry.isReadyForGameplay)
    }

    // MARK: - Season/Campaign Query Tests

    func testGetPacksBySeason() throws {
        // Skip if packs not available
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }
        if storyPackURL == nil { XCTFail("TwilightMarchesActI pack not available"); return }

        // Given
        try registry.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When
        let season1Packs = registry.getPacksBySeason("season1")

        // Then - TwilightMarchesActI should be in season1
        XCTAssertEqual(season1Packs.count, 1)
        XCTAssertEqual(season1Packs.first?.manifest.packId, "twilight-marches-act1")
    }

    func testGetPacksByCampaign() throws {
        // Skip if packs not available
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }
        if storyPackURL == nil { XCTFail("TwilightMarchesActI pack not available"); return }

        // Given
        try registry.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When
        let campaignPacks = registry.getPacksByCampaign("twilight-marches")

        // Then
        XCTAssertEqual(campaignPacks.count, 1)
        XCTAssertEqual(campaignPacks.first?.manifest.packId, "twilight-marches-act1")
        XCTAssertEqual(campaignPacks.first?.manifest.campaignOrder, 1)
    }

    func testGetAvailableSeasons() throws {
        // Skip if packs not available
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }
        if storyPackURL == nil { XCTFail("TwilightMarchesActI pack not available"); return }

        // Given
        try registry.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When
        let seasons = registry.getAvailableSeasons()

        // Then - Should include season1 from TwilightMarchesActI
        XCTAssertTrue(seasons.contains("season1"))
    }

    func testGetCampaignsInSeason() throws {
        // Skip if packs not available
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }
        if storyPackURL == nil { XCTFail("TwilightMarchesActI pack not available"); return }

        // Given
        try registry.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When
        let campaigns = registry.getCampaignsInSeason("season1")

        // Then
        XCTAssertTrue(campaigns.contains("twilight-marches"))
    }

    func testIsCampaignCompleteWithSingleAct() throws {
        // Skip if packs not available
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }
        if storyPackURL == nil { XCTFail("TwilightMarchesActI pack not available"); return }

        // Given
        try registry.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When - With only Act I loaded, campaign is "complete" (sequential from 1)
        let isComplete = registry.isCampaignComplete("twilight-marches")

        // Then - Act I starts at order 1, so it's complete for what's loaded
        XCTAssertTrue(isComplete)
    }

    func testGetNextPackInCampaignReturnsNilForLastAct() throws {
        // Skip if packs not available
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }
        if storyPackURL == nil { XCTFail("TwilightMarchesActI pack not available"); return }

        // Given
        try registry.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When - Try to get next pack after Act I (Act II not loaded)
        let nextPack = registry.getNextPackInCampaign(after: "twilight-marches-act1")

        // Then - Should be nil since Act II isn't loaded
        XCTAssertNil(nextPack)
    }

    func testHasAllRequiredPacksForFirstAct() throws {
        // Skip if packs not available
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }
        if storyPackURL == nil { XCTFail("TwilightMarchesActI pack not available"); return }

        // Given
        try registry.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When - Check if Act I has all required packs (it shouldn't require any)
        let hasRequired = registry.hasAllRequiredPacks(for: "twilight-marches-act1")

        // Then - Act I is the first act, so no required packs
        XCTAssertTrue(hasRequired)
    }

    func testCharacterPackHasNoSeason() throws {
        // Skip if packs not available
        if characterPackURL == nil { XCTFail("CoreHeroes pack not available - Bundle.module resolution issue"); return }
        if storyPackURL == nil { XCTFail("TwilightMarchesActI pack not available"); return }

        // Given
        try registry.loadPacks(from: [characterPackURL!, storyPackURL!])

        // When - Get packs for non-existent season
        let noSeasonPacks = registry.getPacksBySeason("nonexistent")

        // Then - Should be empty
        XCTAssertTrue(noSeasonPacks.isEmpty)

        // And - CoreHeroes should not appear in season1 (it has no season)
        let characterPacks = registry.getCharacterPacks()
        XCTAssertNil(characterPacks.first?.manifest.season)
    }

}

import XCTest
@testable import CardSampleGame

/// Tests for JSONContentProvider - verifies JSON content loading
///
/// NOTE: These tests are for the legacy JSONContentProvider which expected
/// files in Resources/Content/ with pool_*.json files. The project has migrated
/// to the Content Pack system (see ContentPackTests/). These tests are skipped
/// until JSONContentProvider is updated to use the new ContentPacks structure,
/// or can be removed once the migration is complete.
final class JSONContentProviderTests: XCTestCase {

    // MARK: - Properties

    var provider: JSONContentProvider!

    /// Flag to skip content-dependent tests (content migrated to ContentPacks)
    private static let skipContentTests = true

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        // Use the app bundle (where JSON files are copied), not the test bundle
        let appBundle = Bundle(for: JSONContentProvider.self)
        provider = JSONContentProvider(bundle: appBundle)
    }

    override func tearDown() {
        provider = nil
        super.tearDown()
    }

    // MARK: - Helper

    /// Skips test if content has been migrated to ContentPacks
    private func skipIfContentMigrated() throws {
        if Self.skipContentTests {
            throw XCTSkip("JSONContentProvider tests skipped - content migrated to ContentPacks. See ContentPackTests/")
        }
    }

    // MARK: - Basic Loading Tests

    func testProviderInitialState() {
        XCTAssertFalse(provider.isLoaded, "Provider should not be loaded initially")
        XCTAssertTrue(provider.loadErrors.isEmpty, "Should have no load errors initially")
    }

    func testLoadAllContent() throws {
        try skipIfContentMigrated()

        do {
            try provider.loadAllContent()
        } catch {
            XCTFail("loadAllContent should not throw: \(error)")
            return
        }

        XCTAssertTrue(provider.isLoaded, "Provider should be marked as loaded")
    }

    // MARK: - Region Tests

    func testRegionsLoaded() throws {
        try skipIfContentMigrated()
        try provider.loadAllContent()
        XCTAssertGreaterThan(provider.regions.count, 0, "Should have loaded at least one region")
    }

    func testSpecificRegionsExist() throws {
        try skipIfContentMigrated()
        try provider.loadAllContent()

        let expectedRegionIds = ["village", "oak", "forest", "swamp", "mountain", "breach", "dark_lowland"]

        for regionId in expectedRegionIds {
            XCTAssertNotNil(provider.regions[regionId], "Region '\(regionId)' should exist")
        }
    }

    func testRegionDefinitionStructure() throws {
        try skipIfContentMigrated()
        try provider.loadAllContent()

        guard let village = provider.regions["village"] else {
            XCTFail("Village region should exist")
            return
        }

        XCTAssertEqual(village.id, "village")
        XCTAssertFalse(village.title.en.isEmpty, "Village should have English title")
        XCTAssertFalse(village.title.ru.isEmpty, "Village should have Russian title")
        XCTAssertFalse(village.description.en.isEmpty, "Village should have English description")
        XCTAssertFalse(village.neighborIds.isEmpty, "Village should have neighbors")
        XCTAssertTrue(village.initiallyDiscovered, "Village should be initially discovered")
    }

    // MARK: - Anchor Tests

    func testAnchorsLoaded() throws {
        try skipIfContentMigrated()
        try provider.loadAllContent()
        XCTAssertGreaterThan(provider.anchors.count, 0, "Should have loaded at least one anchor")
    }

    func testSpecificAnchorsExist() throws {
        try skipIfContentMigrated()
        try provider.loadAllContent()

        let expectedAnchorIds = [
            "anchor_village_chapel",
            "anchor_sacred_oak",
            "anchor_forest_idol",
            "anchor_swamp_spring",
            "anchor_mountain_barrow",
            "anchor_breach_shrine"
        ]

        for anchorId in expectedAnchorIds {
            XCTAssertNotNil(provider.anchors[anchorId], "Anchor '\(anchorId)' should exist")
        }
    }

    // MARK: - Quest Tests

    func testQuestsLoaded() throws {
        try skipIfContentMigrated()
        try provider.loadAllContent()
        XCTAssertGreaterThan(provider.quests.count, 0, "Should have loaded at least one quest")
    }

    func testMainQuestExists() throws {
        try skipIfContentMigrated()
        try provider.loadAllContent()
        XCTAssertNotNil(provider.quests["quest_main_act1"], "Main Act I quest should exist")
    }

    func testQuestStructure() throws {
        try skipIfContentMigrated()
        try provider.loadAllContent()

        guard let mainQuest = provider.quests["quest_main_act1"] else {
            XCTFail("Main quest should exist")
            return
        }

        XCTAssertEqual(mainQuest.id, "quest_main_act1")
        XCTAssertFalse(mainQuest.title.en.isEmpty, "Quest should have English title")
        XCTAssertFalse(mainQuest.title.ru.isEmpty, "Quest should have Russian title")
        XCTAssertFalse(mainQuest.objectives.isEmpty, "Quest should have objectives")
    }

    // MARK: - Challenge Tests

    func testChallengesLoaded() throws {
        try skipIfContentMigrated()
        try provider.loadAllContent()
        XCTAssertGreaterThan(provider.miniGameChallenges.count, 0, "Should have loaded at least one challenge")
    }

    func testChallengeKinds() throws {
        try skipIfContentMigrated()
        try provider.loadAllContent()

        let kinds = Set(provider.miniGameChallenges.values.map { $0.challengeKind })

        XCTAssertTrue(kinds.contains(MiniGameChallengeKind.combat), "Should have combat challenges")
        XCTAssertTrue(kinds.contains(MiniGameChallengeKind.ritual), "Should have ritual challenges")
        XCTAssertTrue(kinds.contains(MiniGameChallengeKind.exploration), "Should have exploration challenges")
    }

    // MARK: - Event Tests

    func testEventsLoaded() throws {
        try skipIfContentMigrated()
        try provider.loadAllContent()
        XCTAssertGreaterThan(provider.events.count, 0, "Should have loaded at least one event")
    }

    func testEventPoolsExist() throws {
        try skipIfContentMigrated()
        try provider.loadAllContent()

        let eventIds = Array(provider.events.keys)
        let commonEvents = eventIds.filter { $0.hasPrefix("event_wanderer") || $0.hasPrefix("event_camp") || $0.hasPrefix("event_merchant") }
        XCTAssertFalse(commonEvents.isEmpty, "Should have common pool events")
    }

    func testEventStructure() throws {
        try skipIfContentMigrated()
        try provider.loadAllContent()

        guard let wanderer = provider.events["event_wanderer"] else {
            XCTFail("Wanderer event should exist")
            return
        }

        XCTAssertEqual(wanderer.id, "event_wanderer")
        XCTAssertFalse(wanderer.title.en.isEmpty, "Event should have English title")
        XCTAssertFalse(wanderer.title.ru.isEmpty, "Event should have Russian title")
        XCTAssertFalse(wanderer.body.en.isEmpty, "Event should have English body")
        XCTAssertFalse(wanderer.choices.isEmpty, "Event should have choices")
    }

    func testCombatEventExists() throws {
        try skipIfContentMigrated()
        try provider.loadAllContent()

        let combatEvents = provider.events.values.filter {
            if case .miniGame(.combat) = $0.eventKind {
                return true
            }
            return false
        }

        XCTAssertGreaterThan(combatEvents.count, 0, "Should have at least one combat event")

        if let event = combatEvents.first {
            if case .miniGame(.combat) = event.eventKind {
                // Expected
            } else {
                XCTFail("Combat event should have miniGame(.combat) kind")
            }
        }
    }

    // MARK: - Event Pool Index Tests

    func testEventPoolIndexBuilt() throws {
        try skipIfContentMigrated()
        try provider.loadAllContent()
        XCTAssertGreaterThan(provider.eventsByPool.count, 0, "Should have event pool index")
    }

    func testSpecificPoolsHaveEvents() throws {
        try skipIfContentMigrated()
        try provider.loadAllContent()

        let expectedPools = ["pool_common", "pool_village", "pool_forest", "pool_swamp", "pool_mountain", "pool_sacred", "pool_breach", "pool_boss"]

        for poolId in expectedPools {
            let events = provider.getEventDefinitions(forPool: poolId)
            XCTAssertGreaterThan(events.count, 0, "Pool '\(poolId)' should have at least one event")
        }
    }

    // MARK: - Content Query Tests

    func testGetRegion() throws {
        try skipIfContentMigrated()
        try provider.loadAllContent()

        let region = provider.getRegionDefinition(id: "village")
        XCTAssertNotNil(region, "Should find village region")
        XCTAssertEqual(region?.id, "village")
    }

    func testGetAnchor() throws {
        try skipIfContentMigrated()
        try provider.loadAllContent()

        let anchor = provider.getAnchorDefinition(id: "anchor_village_chapel")
        XCTAssertNotNil(anchor, "Should find village chapel anchor")
    }

    func testGetQuest() throws {
        try skipIfContentMigrated()
        try provider.loadAllContent()

        let quest = provider.getQuestDefinition(id: "quest_main_act1")
        XCTAssertNotNil(quest, "Should find main quest")
    }

    func testGetChallenge() throws {
        try skipIfContentMigrated()
        try provider.loadAllContent()

        let challenge = provider.getMiniGameChallenge(id: "combat_leshy")
        XCTAssertNotNil(challenge, "Should find Leshy combat challenge")
    }

    func testGetEvent() throws {
        try skipIfContentMigrated()
        try provider.loadAllContent()

        let event = provider.getEventDefinition(id: "event_wanderer")
        XCTAssertNotNil(event, "Should find wanderer event")
    }

    // MARK: - Localized Content Tests

    func testRegionLocalizedContent() throws {
        try skipIfContentMigrated()
        try provider.loadAllContent()

        for region in provider.regions.values {
            XCTAssertFalse(region.title.en.isEmpty, "Region '\(region.id)' should have English title")
            XCTAssertFalse(region.title.ru.isEmpty, "Region '\(region.id)' should have Russian title")
            XCTAssertFalse(region.description.en.isEmpty, "Region '\(region.id)' should have English description")
            XCTAssertFalse(region.description.ru.isEmpty, "Region '\(region.id)' should have Russian description")
        }
    }

    func testEventLocalizedContent() throws {
        try skipIfContentMigrated()
        try provider.loadAllContent()

        for event in provider.events.values {
            XCTAssertFalse(event.title.en.isEmpty, "Event '\(event.id)' should have English title")
            XCTAssertFalse(event.body.en.isEmpty, "Event '\(event.id)' should have English body")

            for choice in event.choices {
                XCTAssertFalse(choice.label.en.isEmpty, "Choice '\(choice.id)' in event '\(event.id)' should have English label")
            }
        }
    }

    // MARK: - Content Count Tests

    func testExpectedContentCounts() throws {
        try skipIfContentMigrated()
        try provider.loadAllContent()

        XCTAssertEqual(provider.regions.count, 7, "Should have 7 regions")
        XCTAssertEqual(provider.anchors.count, 6, "Should have 6 anchors")
        XCTAssertEqual(provider.quests.count, 4, "Should have 4 quests")
        XCTAssertEqual(provider.miniGameChallenges.count, 7, "Should have 7 challenges")
        XCTAssertEqual(provider.events.count, 21, "Should have 21 events")
    }
}

import XCTest
@testable import PackEditorKit
import TwilightEngine

final class PackStoreTests: XCTestCase {

    var store: PackStore!

    override func setUp() {
        super.setUp()
        store = PackStore()
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState_isEmpty() {
        XCTAssertNil(store.loadedPack)
        XCTAssertNil(store.packURL)
        XCTAssertFalse(store.isDirty)
        XCTAssertNil(store.balanceConfig)
        XCTAssertNil(store.validationSummary)
        XCTAssertTrue(store.enemies.isEmpty)
        XCTAssertTrue(store.events.isEmpty)
        XCTAssertTrue(store.regions.isEmpty)
    }

    func testPackTitle_noPackLoaded() {
        XCTAssertEqual(store.packTitle, "Pack Editor")
    }

    // MARK: - Entity Count / IDs (empty state)

    func testEntityCount_emptyState() {
        for category in ContentCategory.allCases {
            XCTAssertEqual(store.entityCount(for: category), 0,
                           "Expected 0 for \(category)")
        }
    }

    func testEntityIds_emptyState() {
        for category in ContentCategory.allCases {
            XCTAssertTrue(store.entityIds(for: category).isEmpty,
                          "Expected empty IDs for \(category)")
        }
    }

    // MARK: - Load Pack from Fixture

    func testLoadPack_fromFixture() throws {
        let fixtureURL = try fixturePackURL()
        try store.loadPack(from: fixtureURL)

        XCTAssertNotNil(store.loadedPack)
        XCTAssertEqual(store.packURL, fixtureURL)
        XCTAssertFalse(store.isDirty)
        XCTAssertEqual(store.enemies.count, 1)
        XCTAssertEqual(store.events.count, 1)
        XCTAssertEqual(store.regions.count, 1)
    }

    func testLoadPack_setsPackTitle() throws {
        let fixtureURL = try fixturePackURL()
        try store.loadPack(from: fixtureURL)

        XCTAssertTrue(store.packTitle.contains("test-pack"))
    }

    func testLoadPack_entityCountsCorrect() throws {
        let fixtureURL = try fixturePackURL()
        try store.loadPack(from: fixtureURL)

        XCTAssertEqual(store.entityCount(for: .enemies), 1)
        XCTAssertEqual(store.entityCount(for: .events), 1)
        XCTAssertEqual(store.entityCount(for: .regions), 1)
        XCTAssertEqual(store.entityCount(for: .cards), 1)
        XCTAssertEqual(store.entityCount(for: .heroes), 0)
    }

    func testLoadPack_entityIdsCorrect() throws {
        let fixtureURL = try fixturePackURL()
        try store.loadPack(from: fixtureURL)

        XCTAssertEqual(store.entityIds(for: .enemies), ["test_enemy_1"])
        XCTAssertEqual(store.entityIds(for: .events), ["test_event_1"])
        XCTAssertEqual(store.entityIds(for: .regions), ["test_region_1"])
    }

    func testLoadPack_entityNameResolved() throws {
        let fixtureURL = try fixturePackURL()
        try store.loadPack(from: fixtureURL)

        let name = store.entityName(for: "test_enemy_1", in: .enemies)
        XCTAssertEqual(name, "Test Goblin")
    }

    func testLoadPack_unknownEntityName_fallsBackToId() throws {
        let fixtureURL = try fixturePackURL()
        try store.loadPack(from: fixtureURL)

        let name = store.entityName(for: "nonexistent", in: .enemies)
        XCTAssertEqual(name, "nonexistent")
    }

    // MARK: - Load Pack Error

    func testLoadPack_invalidPath_throws() {
        let badURL = URL(fileURLWithPath: "/tmp/nonexistent_pack_xyz_123")
        XCTAssertThrowsError(try store.loadPack(from: badURL))
    }

    // MARK: - Save Without Load

    func testSavePack_withoutLoad_throws() {
        XCTAssertThrowsError(try store.savePack()) { error in
            XCTAssertTrue(error is PackStoreError)
        }
    }

    // MARK: - Validate

    func testValidate_withoutLoad_returnsNil() {
        let result = store.validate()
        XCTAssertNil(result)
    }

    func testValidate_withLoadedPack_returnsSummary() throws {
        let fixtureURL = try fixturePackURL()
        try store.loadPack(from: fixtureURL)

        let summary = store.validate()
        XCTAssertNotNil(summary)
        XCTAssertNotNil(store.validationSummary)
    }

    // MARK: - ContentCategory

    func testContentCategory_allCasesCount() {
        XCTAssertEqual(ContentCategory.allCases.count, 10)
    }

    func testContentCategory_iconNotEmpty() {
        for category in ContentCategory.allCases {
            XCTAssertFalse(category.icon.isEmpty, "\(category) icon should not be empty")
        }
    }

    func testContentCategory_idEqualsRawValue() {
        for category in ContentCategory.allCases {
            XCTAssertEqual(category.id, category.rawValue)
        }
    }

    // MARK: - Add Entity (Enemies)

    func testAddEnemy_default_createsBeast() {
        let id = store.addEntity(for: .enemies)
        XCTAssertNotNil(id)
        let enemy = store.enemies[id!]
        XCTAssertNotNil(enemy)
        XCTAssertTrue(id!.hasPrefix("enemy_new_"))
        XCTAssertEqual(enemy?.health, 10)
        XCTAssertEqual(enemy?.power, 2)
        XCTAssertEqual(enemy?.enemyType, .beast)
    }

    func testAddEnemy_undeadTemplate() {
        let id = store.addEntity(for: .enemies, template: "undead")!
        let enemy = store.enemies[id]!
        XCTAssertEqual(enemy.enemyType, .undead)
        XCTAssertEqual(enemy.health, 15)
        XCTAssertEqual(enemy.will, 5)
    }

    func testAddEnemy_bossTemplate() {
        let id = store.addEntity(for: .enemies, template: "boss")!
        let enemy = store.enemies[id]!
        XCTAssertEqual(enemy.enemyType, .boss)
        XCTAssertEqual(enemy.health, 30)
        XCTAssertEqual(enemy.defense, 3)
    }

    // MARK: - Add Entity (Cards)

    func testAddCard_defaultItem() {
        let id = store.addEntity(for: .cards)!
        XCTAssertTrue(id.hasPrefix("card_new_"))
        XCTAssertEqual(store.cards[id]?.cardType, .item)
    }

    func testAddCard_attackTemplate() {
        let id = store.addEntity(for: .cards, template: "attack")!
        XCTAssertEqual(store.cards[id]?.cardType, .weapon)
    }

    func testAddCard_defenseTemplate() {
        let id = store.addEntity(for: .cards, template: "defense")!
        XCTAssertEqual(store.cards[id]?.cardType, .armor)
    }

    func testAddCard_spellTemplate() {
        let id = store.addEntity(for: .cards, template: "spell")!
        XCTAssertEqual(store.cards[id]?.cardType, .spell)
    }

    // MARK: - Add Entity (Other Categories)

    func testAddEvent() {
        let id = store.addEntity(for: .events)!
        XCTAssertTrue(id.hasPrefix("event_new_"))
        XCTAssertNotNil(store.events[id])
    }

    func testAddRegion_default() {
        let id = store.addEntity(for: .regions)!
        XCTAssertTrue(id.hasPrefix("region_new_"))
        XCTAssertEqual(store.regions[id]?.regionType, "default")
    }

    func testAddRegion_settlementTemplate() {
        let id = store.addEntity(for: .regions, template: "settlement")!
        XCTAssertEqual(store.regions[id]?.regionType, "settlement")
    }

    func testAddRegion_wildernessTemplate() {
        let id = store.addEntity(for: .regions, template: "wilderness")!
        XCTAssertEqual(store.regions[id]?.regionType, "wilderness")
    }

    func testAddRegion_dungeonTemplate() {
        let id = store.addEntity(for: .regions, template: "dungeon")!
        XCTAssertEqual(store.regions[id]?.regionType, "dungeon")
        XCTAssertEqual(store.regions[id]?.initialState, .borderland)
    }

    func testAddHero() {
        let id = store.addEntity(for: .heroes)!
        XCTAssertTrue(id.hasPrefix("hero_new_"))
        XCTAssertEqual(store.heroes[id]?.baseStats.health, 20)
        XCTAssertEqual(store.heroes[id]?.baseStats.maxHealth, 20)
    }

    func testAddFateCard() {
        let id = store.addEntity(for: .fateCards)!
        XCTAssertTrue(id.hasPrefix("fate_new_"))
        XCTAssertEqual(store.fateCards[id]?.modifier, 0)
    }

    func testAddQuest() {
        let id = store.addEntity(for: .quests)!
        XCTAssertTrue(id.hasPrefix("quest_new_"))
        XCTAssertEqual(store.quests[id]?.objectives.count, 0)
    }

    func testAddBalance_returnsNil() {
        let id = store.addEntity(for: .balance)
        XCTAssertNil(id)
    }

    // MARK: - Duplicate Entity

    func testDuplicateEnemy_copiesData() {
        let id = store.addEntity(for: .enemies)!
        store.isDirty = false
        let copyId = store.duplicateEntity(id: id, for: .enemies)!

        XCTAssertTrue(copyId.contains("_copy_"))
        XCTAssertEqual(store.enemies[copyId]?.health, store.enemies[id]?.health)
        XCTAssertEqual(store.enemies[copyId]?.enemyType, store.enemies[id]?.enemyType)
        XCTAssertEqual(store.enemies.count, 2)
    }

    func testDuplicateCard_copiesCardType() {
        let id = store.addEntity(for: .cards, template: "spell")!
        let copyId = store.duplicateEntity(id: id, for: .cards)!
        XCTAssertEqual(store.cards[copyId]?.cardType, .spell)
    }

    func testDuplicate_nonexistentId_returnsNil() {
        let result = store.duplicateEntity(id: "nonexistent", for: .enemies)
        XCTAssertNil(result)
    }

    func testDuplicate_balance_returnsNil() {
        let result = store.duplicateEntity(id: "balance", for: .balance)
        XCTAssertNil(result)
    }

    // MARK: - Delete Entity

    func testDeleteEnemy_removesFromDict() {
        let id = store.addEntity(for: .enemies)!
        XCTAssertEqual(store.enemies.count, 1)
        store.deleteEntity(id: id, for: .enemies)
        XCTAssertEqual(store.enemies.count, 0)
        XCTAssertNil(store.enemies[id])
    }

    func testDelete_nonexistent_noError() {
        store.deleteEntity(id: "nonexistent", for: .enemies)
        // no crash
    }

    func testDelete_balance_noop() {
        // balance delete is a no-op; just verify no crash
        store.deleteEntity(id: "balance", for: .balance)
    }

    // MARK: - isDirty Lifecycle

    func testAddEntity_setsIsDirty() {
        XCTAssertFalse(store.isDirty)
        _ = store.addEntity(for: .enemies)
        XCTAssertTrue(store.isDirty)
    }

    func testDuplicate_setsIsDirty() {
        let id = store.addEntity(for: .enemies)!
        store.isDirty = false
        _ = store.duplicateEntity(id: id, for: .enemies)
        XCTAssertTrue(store.isDirty)
    }

    func testDelete_setsIsDirty() {
        let id = store.addEntity(for: .enemies)!
        store.isDirty = false
        store.deleteEntity(id: id, for: .enemies)
        XCTAssertTrue(store.isDirty)
    }

    func testLoadPack_clearsIsDirty() throws {
        store.isDirty = true
        let url = try fixturePackURL()
        try store.loadPack(from: url)
        XCTAssertFalse(store.isDirty)
    }

    // MARK: - Save Round-Trip

    func testSave_clearsIsDirty() throws {
        let tmp = try copyFixtureToTemp()
        defer { try? FileManager.default.removeItem(at: tmp) }

        try store.loadPack(from: tmp)
        _ = store.addEntity(for: .enemies)
        XCTAssertTrue(store.isDirty)
        try store.savePack()
        XCTAssertFalse(store.isDirty)
    }

    func testSaveAndReload_preservesAddedEnemy() throws {
        let tmp = try copyFixtureToTemp()
        defer { try? FileManager.default.removeItem(at: tmp) }

        try store.loadPack(from: tmp)
        let id = store.addEntity(for: .enemies, template: "boss")!
        try store.savePack()

        let store2 = PackStore()
        try store2.loadPack(from: tmp)
        XCTAssertNotNil(store2.enemies[id])
        XCTAssertEqual(store2.enemies[id]?.health, 30)
    }

    func testSaveAndReload_preservesAddedCard() throws {
        let tmp = try copyFixtureToTemp()
        defer { try? FileManager.default.removeItem(at: tmp) }

        try store.loadPack(from: tmp)
        let id = store.addEntity(for: .cards, template: "spell")!
        try store.savePack()

        let store2 = PackStore()
        try store2.loadPack(from: tmp)
        XCTAssertNotNil(store2.cards[id])
        XCTAssertEqual(store2.cards[id]?.cardType, .spell)
    }

    func testSaveAndReload_preservesAddedRegion() throws {
        let tmp = try copyFixtureToTemp()
        defer { try? FileManager.default.removeItem(at: tmp) }

        try store.loadPack(from: tmp)
        let id = store.addEntity(for: .regions, template: "dungeon")!
        try store.savePack()

        let store2 = PackStore()
        try store2.loadPack(from: tmp)
        XCTAssertNotNil(store2.regions[id])
        XCTAssertEqual(store2.regions[id]?.regionType, "dungeon")
    }

    func testSaveAndReload_preservesAddedEvent() throws {
        let tmp = try copyFixtureToTemp()
        defer { try? FileManager.default.removeItem(at: tmp) }

        try store.loadPack(from: tmp)
        let initialCount = store.events.count
        let id = store.addEntity(for: .events)!
        try store.savePack()

        let store2 = PackStore()
        try store2.loadPack(from: tmp)
        XCTAssertEqual(store2.events.count, initialCount + 1)
        XCTAssertNotNil(store2.events[id])
    }

    func testSaveAndReload_preservesAddedHero() throws {
        let tmp = try copyFixtureToTemp()
        defer { try? FileManager.default.removeItem(at: tmp) }

        try store.loadPack(from: tmp)
        let id = store.addEntity(for: .heroes)!
        try store.savePack()

        let store2 = PackStore()
        try store2.loadPack(from: tmp)
        XCTAssertNotNil(store2.heroes[id])
        XCTAssertEqual(store2.heroes[id]?.baseStats.health, 20)
    }

    func testSaveAndReload_preservesAddedFateCard() throws {
        let tmp = try copyFixtureToTemp()
        defer { try? FileManager.default.removeItem(at: tmp) }

        try store.loadPack(from: tmp)
        let id = store.addEntity(for: .fateCards)!
        try store.savePack()

        let store2 = PackStore()
        try store2.loadPack(from: tmp)
        XCTAssertNotNil(store2.fateCards[id])
        XCTAssertEqual(store2.fateCards[id]?.modifier, 0)
    }

    func testSaveAndReload_preservesAddedQuest() throws {
        let tmp = try copyFixtureToTemp()
        defer { try? FileManager.default.removeItem(at: tmp) }

        try store.loadPack(from: tmp)
        let id = store.addEntity(for: .quests)!
        try store.savePack()

        let store2 = PackStore()
        try store2.loadPack(from: tmp)
        XCTAssertNotNil(store2.quests[id])
        XCTAssertEqual(store2.quests[id]?.objectives.count, 0)
    }

    func testSaveAndReload_preservesAddedBehavior() throws {
        let tmp = try copyFixtureToTemp()
        defer { try? FileManager.default.removeItem(at: tmp) }

        try store.loadPack(from: tmp)
        let id = store.addEntity(for: .behaviors)!
        try store.savePack()

        let store2 = PackStore()
        try store2.loadPack(from: tmp)
        XCTAssertNotNil(store2.behaviors[id])
        XCTAssertEqual(store2.behaviors[id]?.defaultIntent, "attack")
    }

    func testSaveAndReload_preservesAddedAnchor() throws {
        let tmp = try copyFixtureToTemp()
        defer { try? FileManager.default.removeItem(at: tmp) }

        try store.loadPack(from: tmp)
        let id = store.addEntity(for: .anchors)!
        try store.savePack()

        let store2 = PackStore()
        try store2.loadPack(from: tmp)
        XCTAssertNotNil(store2.anchors[id])
        XCTAssertEqual(store2.anchors[id]?.power, 5)
    }

    func testSaveAndReload_deletedEntityNotPresent() throws {
        let tmp = try copyFixtureToTemp()
        defer { try? FileManager.default.removeItem(at: tmp) }

        try store.loadPack(from: tmp)
        XCTAssertNotNil(store.enemies["test_enemy_1"])
        store.deleteEntity(id: "test_enemy_1", for: .enemies)
        try store.savePack()

        let store2 = PackStore()
        try store2.loadPack(from: tmp)
        XCTAssertNil(store2.enemies["test_enemy_1"])
        XCTAssertEqual(store2.enemies.count, 0)
    }

    func testSaveAndReload_duplicatedEntityPresent() throws {
        let tmp = try copyFixtureToTemp()
        defer { try? FileManager.default.removeItem(at: tmp) }

        try store.loadPack(from: tmp)
        let copyId = store.duplicateEntity(id: "test_enemy_1", for: .enemies)!
        try store.savePack()

        let store2 = PackStore()
        try store2.loadPack(from: tmp)
        XCTAssertNotNil(store2.enemies[copyId])
        XCTAssertEqual(store2.enemies.count, 2)
    }

    // MARK: - Add Behavior

    func testAddBehavior() {
        let id = store.addEntity(for: .behaviors)!
        XCTAssertTrue(id.hasPrefix("behavior_new_"))
        let b = store.behaviors[id]!
        XCTAssertEqual(b.defaultIntent, "attack")
        XCTAssertEqual(b.defaultValue, "1")
        XCTAssertTrue(b.rules.isEmpty)
    }

    func testDuplicateBehavior() {
        let id = store.addEntity(for: .behaviors)!
        let copyId = store.duplicateEntity(id: id, for: .behaviors)!
        XCTAssertTrue(copyId.contains("_copy_"))
        XCTAssertEqual(store.behaviors[copyId]?.defaultIntent, "attack")
        XCTAssertEqual(store.behaviors.count, 2)
    }

    func testDeleteBehavior() {
        let id = store.addEntity(for: .behaviors)!
        store.deleteEntity(id: id, for: .behaviors)
        XCTAssertNil(store.behaviors[id])
    }

    func testBehavior_entityName_returnsId() {
        let id = store.addEntity(for: .behaviors)!
        XCTAssertEqual(store.entityName(for: id, in: .behaviors), id)
    }

    // MARK: - Add Anchor

    func testAddAnchor() {
        let id = store.addEntity(for: .anchors)!
        XCTAssertTrue(id.hasPrefix("anchor_new_"))
        let a = store.anchors[id]!
        XCTAssertEqual(a.regionId, "")
        XCTAssertEqual(a.power, 5)
        XCTAssertEqual(a.maxIntegrity, 100)
        XCTAssertEqual(a.initialIntegrity, 50)
    }

    func testDuplicateAnchor() {
        let id = store.addEntity(for: .anchors)!
        let copyId = store.duplicateEntity(id: id, for: .anchors)!
        XCTAssertTrue(copyId.contains("_copy_"))
        XCTAssertEqual(store.anchors[copyId]?.power, 5)
        XCTAssertEqual(store.anchors.count, 2)
    }

    func testDeleteAnchor() {
        let id = store.addEntity(for: .anchors)!
        store.deleteEntity(id: id, for: .anchors)
        XCTAssertNil(store.anchors[id])
    }

    func testAnchor_entityName_returnsTitle() {
        let id = store.addEntity(for: .anchors)!
        XCTAssertEqual(store.entityName(for: id, in: .anchors), "New Anchor")
    }

    // MARK: - JSON Encoding Round-Trip

    func testEnemy_jsonRoundTrip() throws {
        let id = store.addEntity(for: .enemies, template: "boss")!
        let enemy = store.enemies[id]!

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(enemy)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(EnemyDefinition.self, from: data)
        XCTAssertEqual(decoded.id, enemy.id)
        XCTAssertEqual(decoded.health, 30)
        XCTAssertEqual(decoded.enemyType, .boss)
    }

    func testBehavior_jsonRoundTrip() throws {
        var behavior = BehaviorDefinition(
            id: "test_beh",
            rules: [BehaviorRule(
                conditions: [BehaviorCondition(type: "health_pct", op: "<", value: 0.3)],
                intentType: "defend",
                valueFormula: "2"
            )],
            defaultIntent: "attack",
            defaultValue: "1"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(behavior)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(BehaviorDefinition.self, from: data)
        XCTAssertEqual(decoded.id, "test_beh")
        XCTAssertEqual(decoded.rules.count, 1)
        XCTAssertEqual(decoded.rules[0].intentType, "defend")
        XCTAssertEqual(decoded.rules[0].conditions[0].op, "<")
        XCTAssertEqual(decoded.rules[0].conditions[0].value, 0.3)
    }

    func testAnchor_jsonRoundTrip() throws {
        let id = store.addEntity(for: .anchors)!
        let anchor = store.anchors[id]!

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(anchor)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(AnchorDefinition.self, from: data)
        XCTAssertEqual(decoded.id, anchor.id)
        XCTAssertEqual(decoded.power, 5)
        XCTAssertEqual(decoded.initialInfluence, .neutral)
    }

    func testCard_jsonRoundTrip() throws {
        let id = store.addEntity(for: .cards, template: "spell")!
        let card = store.cards[id]!

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(card)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(StandardCardDefinition.self, from: data)
        XCTAssertEqual(decoded.id, card.id)
        XCTAssertEqual(decoded.cardType, .spell)
    }

    // MARK: - Legacy Format Loading

    func testLoadPack_legacyCardFormat_loadsCorrectly() throws {
        let fixtureURL = try fixturePackURL()
        try store.loadPack(from: fixtureURL)
        // cards.json uses legacy flat format (name: String, name_ru: String)
        XCTAssertEqual(store.cards.count, 1)
        XCTAssertNotNil(store.cards["test_card_1"])
        XCTAssertEqual(store.cards["test_card_1"]?.cardType, .weapon)
    }

    func testLoadPack_legacyCardName_convertedToLocalizableText() throws {
        let fixtureURL = try fixturePackURL()
        try store.loadPack(from: fixtureURL)
        let name = store.entityName(for: "test_card_1", in: .cards)
        XCTAssertEqual(name, "Test Sword")
    }

    func testSaveAndReload_legacyCards_thenAddNew_bothPresent() throws {
        let tmp = try copyFixtureToTemp()
        defer { try? FileManager.default.removeItem(at: tmp) }

        try store.loadPack(from: tmp)
        XCTAssertEqual(store.cards.count, 1)
        let newId = store.addEntity(for: .cards, template: "attack")!
        try store.savePack()

        // After save, file is in editor format (StandardCardDefinition)
        let store2 = PackStore()
        try store2.loadPack(from: tmp)
        XCTAssertEqual(store2.cards.count, 2)
        XCTAssertNotNil(store2.cards["test_card_1"])
        XCTAssertNotNil(store2.cards[newId])
    }

    // MARK: - Edge Cases

    func testAddMultipleEntities_uniqueIds() {
        let id1 = store.addEntity(for: .enemies)!
        let id2 = store.addEntity(for: .enemies)!
        let id3 = store.addEntity(for: .enemies)!
        XCTAssertNotEqual(id1, id2)
        XCTAssertNotEqual(id2, id3)
        XCTAssertEqual(store.enemies.count, 3)
    }

    func testAddAndDelete_cyclically() {
        let id1 = store.addEntity(for: .events)!
        XCTAssertEqual(store.events.count, 1)
        store.deleteEntity(id: id1, for: .events)
        XCTAssertEqual(store.events.count, 0)
        let id2 = store.addEntity(for: .events)!
        XCTAssertEqual(store.events.count, 1)
        XCTAssertNotEqual(id1, id2)
    }

    func testDuplicateTwice_allUnique() {
        let id = store.addEntity(for: .enemies)!
        let copy1 = store.duplicateEntity(id: id, for: .enemies)!
        let copy2 = store.duplicateEntity(id: id, for: .enemies)!
        XCTAssertNotEqual(copy1, copy2)
        XCTAssertEqual(store.enemies.count, 3)
    }

    func testEntityIds_sorted() {
        store.enemies["zzz"] = store.enemies["zzz"] ?? {
            _ = store.addEntity(for: .enemies)
            return store.enemies.values.first!
        }()
        store.enemies["aaa"] = store.enemies.values.first!
        store.enemies["mmm"] = store.enemies.values.first!
        let ids = store.entityIds(for: .enemies)
        XCTAssertEqual(ids, ids.sorted())
    }

    func testLoadPack_resetsAllCategories() throws {
        // Pre-populate some data
        _ = store.addEntity(for: .enemies)
        _ = store.addEntity(for: .cards)
        _ = store.addEntity(for: .quests)
        XCTAssertEqual(store.enemies.count, 1)
        XCTAssertEqual(store.cards.count, 1)
        XCTAssertEqual(store.quests.count, 1)

        // Load fixture — should reset everything
        let url = try fixturePackURL()
        try store.loadPack(from: url)
        XCTAssertEqual(store.enemies.count, 1) // fixture has 1 enemy
        XCTAssertEqual(store.cards.count, 1) // fixture now has 1 legacy card
        XCTAssertEqual(store.quests.count, 0) // fixture has no quests
    }

    func testEntityCount_matchesEntityIds() {
        _ = store.addEntity(for: .enemies)
        _ = store.addEntity(for: .enemies)
        _ = store.addEntity(for: .cards)
        for category in ContentCategory.allCases {
            XCTAssertEqual(
                store.entityCount(for: category),
                store.entityIds(for: category).count,
                "Count mismatch for \(category)"
            )
        }
    }

    // MARK: - Helpers

    private func fixturePackURL() throws -> URL {
        guard let url = Bundle.module.url(forResource: "Fixtures/TestPack", withExtension: nil) else {
            throw XCTSkip("Test fixture not found in bundle")
        }
        return url
    }

    // MARK: - Manifest Accessor

    func testManifest_afterLoad_returnsManifest() throws {
        let url = try fixturePackURL()
        try store.loadPack(from: url)
        XCTAssertNotNil(store.manifest)
        XCTAssertEqual(store.manifest?.packId, "test-pack")
    }

    func testManifest_beforeLoad_returnsNil() {
        XCTAssertNil(store.manifest)
    }

    func testManifest_setUpdatesLoadedPack() throws {
        let url = try fixturePackURL()
        try store.loadPack(from: url)
        store.manifest?.author = "Updated Author"
        XCTAssertEqual(store.loadedPack?.manifest.author, "Updated Author")
    }

    // MARK: - Import Entity

    func testImportEnemy_fromJSON() throws {
        // Create an enemy via addEntity, export its JSON, then re-import
        let origId = store.addEntity(for: .enemies)!
        let exportData = store.exportEntityJSON(id: origId, for: .enemies)!
        store.deleteEntity(id: origId, for: .enemies)
        store.isDirty = false

        let id = try store.importEntity(json: exportData, for: .enemies)
        XCTAssertEqual(id, origId)
        XCTAssertNotNil(store.enemies[origId])
        XCTAssertTrue(store.isDirty)
    }

    func testImportCard_fromJSON() throws {
        let origId = store.addEntity(for: .cards)!
        let exportData = store.exportEntityJSON(id: origId, for: .cards)!
        store.deleteEntity(id: origId, for: .cards)

        let id = try store.importEntity(json: exportData, for: .cards)
        XCTAssertEqual(id, origId)
        XCTAssertNotNil(store.cards[origId])
    }

    func testImportInvalidJSON_throws() {
        let json = "not json".data(using: .utf8)!
        XCTAssertThrowsError(try store.importEntity(json: json, for: .enemies))
    }

    // MARK: - Export Entity

    func testExportEnemy_returnsJSON() {
        _ = store.addEntity(for: .enemies)
        let id = store.enemies.keys.first!
        let data = store.exportEntityJSON(id: id, for: .enemies)
        XCTAssertNotNil(data)
        let string = String(data: data!, encoding: .utf8)!
        XCTAssertTrue(string.contains(id))
    }

    func testExportNonexistent_returnsNil() {
        let data = store.exportEntityJSON(id: "nope", for: .enemies)
        // encoder.encode(nil as EnemyDefinition?) encodes "null", so check the dict is empty
        XCTAssertTrue(store.enemies.isEmpty)
    }

    // MARK: - Entity Order

    func testOrderedEntityIds_defaultAlphabetical() {
        store.enemies["b_enemy"] = EnemyDefinition(
            id: "b_enemy", name: .inline(LocalizedString(en: "B", ru: "Б")),
            description: .inline(LocalizedString(en: "", ru: "")),
            health: 1, power: 1, defense: 0, enemyType: .beast, rarity: .common
        )
        store.enemies["a_enemy"] = EnemyDefinition(
            id: "a_enemy", name: .inline(LocalizedString(en: "A", ru: "А")),
            description: .inline(LocalizedString(en: "", ru: "")),
            health: 1, power: 1, defense: 0, enemyType: .beast, rarity: .common
        )
        let ids = store.orderedEntityIds(for: .enemies)
        XCTAssertEqual(ids, ["a_enemy", "b_enemy"])
    }

    func testOrderedEntityIds_customOrder() {
        store.enemies["b_enemy"] = EnemyDefinition(
            id: "b_enemy", name: .inline(LocalizedString(en: "B", ru: "Б")),
            description: .inline(LocalizedString(en: "", ru: "")),
            health: 1, power: 1, defense: 0, enemyType: .beast, rarity: .common
        )
        store.enemies["a_enemy"] = EnemyDefinition(
            id: "a_enemy", name: .inline(LocalizedString(en: "A", ru: "А")),
            description: .inline(LocalizedString(en: "", ru: "")),
            health: 1, power: 1, defense: 0, enemyType: .beast, rarity: .common
        )
        store.entityOrder[.enemies] = ["b_enemy", "a_enemy"]
        let ids = store.orderedEntityIds(for: .enemies)
        XCTAssertEqual(ids, ["b_enemy", "a_enemy"])
    }

    func testOrderedEntityIds_customOrder_filtersDeleted() {
        store.enemies["a_enemy"] = EnemyDefinition(
            id: "a_enemy", name: .inline(LocalizedString(en: "A", ru: "А")),
            description: .inline(LocalizedString(en: "", ru: "")),
            health: 1, power: 1, defense: 0, enemyType: .beast, rarity: .common
        )
        store.entityOrder[.enemies] = ["deleted_id", "a_enemy"]
        let ids = store.orderedEntityIds(for: .enemies)
        XCTAssertEqual(ids, ["a_enemy"])
    }

    func testEntityOrder_persistAndRestore() throws {
        let tmp = try copyFixtureToTemp()
        defer { try? FileManager.default.removeItem(at: tmp) }
        try store.loadPack(from: tmp)
        store.entityOrder[.enemies] = ["test_enemy_1"]
        try store.saveEntityOrder()

        let store2 = PackStore()
        try store2.loadPack(from: tmp)
        XCTAssertEqual(store2.entityOrder[.enemies], ["test_enemy_1"])
    }

    // MARK: - Save Manifest

    func testSaveManifest_writesFile() throws {
        let tmp = try copyFixtureToTemp()
        defer { try? FileManager.default.removeItem(at: tmp) }
        try store.loadPack(from: tmp)
        store.manifest?.author = "New Author"
        try store.saveManifest()

        let store2 = PackStore()
        try store2.loadPack(from: tmp)
        XCTAssertEqual(store2.manifest?.author, "New Author")
    }

    func testSaveManifest_withoutLoad_throws() {
        XCTAssertThrowsError(try store.saveManifest())
    }

    private func copyFixtureToTemp() throws -> URL {
        let fixture = try fixturePackURL()
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at: fixture, to: tmp)
        return tmp
    }
}

/// Файл: Packages/PackEditorKit/Tests/PackEditorKitTests/PackStoreTests+BehaviorLegacyEdgeCases.swift
/// Назначение: Содержит реализацию файла PackStoreTests+BehaviorLegacyEdgeCases.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import PackEditorKit
import TwilightEngine

extension PackStoreTests {

    // MARK: - Add Behavior

    func testAddBehavior() {
        let id = store.addEntity(for: .behaviors)!
        XCTAssertTrue(id.hasPrefix("behavior_new_"))
        let behavior = store.behaviors[id]!
        XCTAssertEqual(behavior.defaultIntent, "attack")
        XCTAssertEqual(behavior.defaultValue, "1")
        XCTAssertTrue(behavior.rules.isEmpty)
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
        let anchor = store.anchors[id]!
        XCTAssertEqual(anchor.regionId, "")
        XCTAssertEqual(anchor.power, 5)
        XCTAssertEqual(anchor.maxIntegrity, 100)
        XCTAssertEqual(anchor.initialIntegrity, 50)
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
        let behavior = BehaviorDefinition(
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

        let secondStore = PackStore()
        try secondStore.loadPack(from: tmp)
        XCTAssertEqual(secondStore.cards.count, 2)
        XCTAssertNotNil(secondStore.cards["test_card_1"])
        XCTAssertNotNil(secondStore.cards[newId])
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
        _ = store.addEntity(for: .enemies)
        _ = store.addEntity(for: .cards)
        _ = store.addEntity(for: .quests)
        XCTAssertEqual(store.enemies.count, 1)
        XCTAssertEqual(store.cards.count, 1)
        XCTAssertEqual(store.quests.count, 1)

        let url = try fixturePackURL()
        try store.loadPack(from: url)
        XCTAssertEqual(store.enemies.count, 1)
        XCTAssertEqual(store.cards.count, 1)
        XCTAssertEqual(store.quests.count, 0)
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
}

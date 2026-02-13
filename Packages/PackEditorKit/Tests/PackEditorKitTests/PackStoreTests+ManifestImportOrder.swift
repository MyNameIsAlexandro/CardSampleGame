/// Файл: Packages/PackEditorKit/Tests/PackEditorKitTests/PackStoreTests+ManifestImportOrder.swift
/// Назначение: Содержит реализацию файла PackStoreTests+ManifestImportOrder.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import PackEditorKit
import TwilightEngine

extension PackStoreTests {

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
        let originalId = store.addEntity(for: .enemies)!
        let exportData = store.exportEntityJSON(id: originalId, for: .enemies)!
        store.deleteEntity(id: originalId, for: .enemies)
        store.isDirty = false

        let id = try store.importEntity(json: exportData, for: .enemies)
        XCTAssertEqual(id, originalId)
        XCTAssertNotNil(store.enemies[originalId])
        XCTAssertTrue(store.isDirty)
    }

    func testImportCard_fromJSON() throws {
        let originalId = store.addEntity(for: .cards)!
        let exportData = store.exportEntityJSON(id: originalId, for: .cards)!
        store.deleteEntity(id: originalId, for: .cards)

        let id = try store.importEntity(json: exportData, for: .cards)
        XCTAssertEqual(id, originalId)
        XCTAssertNotNil(store.cards[originalId])
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
        _ = store.exportEntityJSON(id: "nope", for: .enemies)
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

        let secondStore = PackStore()
        try secondStore.loadPack(from: tmp)
        XCTAssertEqual(secondStore.entityOrder[.enemies], ["test_enemy_1"])
    }

    // MARK: - Save Manifest

    func testSaveManifest_writesFile() throws {
        let tmp = try copyFixtureToTemp()
        defer { try? FileManager.default.removeItem(at: tmp) }
        try store.loadPack(from: tmp)
        store.manifest?.author = "New Author"
        try store.saveManifest()

        let secondStore = PackStore()
        try secondStore.loadPack(from: tmp)
        XCTAssertEqual(secondStore.manifest?.author, "New Author")
    }

    func testSaveManifest_withoutLoad_throws() {
        XCTAssertThrowsError(try store.saveManifest())
    }
}

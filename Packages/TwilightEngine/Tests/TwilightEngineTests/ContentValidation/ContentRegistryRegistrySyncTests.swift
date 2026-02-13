/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/ContentValidation/ContentRegistryRegistrySyncTests.swift
/// Назначение: Содержит реализацию файла ContentRegistryRegistrySyncTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@_spi(Testing) @testable import TwilightEngine

final class ContentRegistryRegistrySyncTests: XCTestCase {

    func testUnloadPackRebuildsGlobalRegistries() {
        let registry = TestContentLoader.makeLoadedRegistry()
        guard let coreHeroesPack = registry.loadedPacks["core-heroes"] else {
            XCTFail("core-heroes pack should be loaded")
            return
        }

        guard let coreHero = coreHeroesPack.heroes.values.first else {
            XCTFail("core-heroes pack should provide at least one hero")
            return
        }

        let coreHeroId = coreHero.id
        let coreAbilityId = coreHero.specialAbility.id

        XCTAssertNotNil(registry.getHero(id: coreHeroId))
        XCTAssertNotNil(registry.heroRegistry.hero(id: coreHeroId))

        XCTAssertNotNil(registry.getAbility(id: coreAbilityId))
        XCTAssertNotNil(registry.abilityRegistry.ability(id: coreAbilityId))

        registry.unloadPack("core-heroes")

        XCTAssertNil(registry.getHero(id: coreHeroId))
        XCTAssertNil(registry.heroRegistry.hero(id: coreHeroId))

        XCTAssertNil(registry.getAbility(id: coreAbilityId))
        XCTAssertNil(registry.abilityRegistry.ability(id: coreAbilityId))
    }

    func testUnloadAllPacksClearsRegistries() {
        let registry = TestContentLoader.makeLoadedRegistry()

        XCTAssertGreaterThan(registry.getAllHeroes().count, 0)
        XCTAssertGreaterThan(registry.getAllAbilities().count, 0)
        XCTAssertGreaterThan(registry.heroRegistry.allHeroes.count, 0)
        XCTAssertGreaterThan(registry.abilityRegistry.count, 0)

        registry.unloadAllPacks()

        XCTAssertEqual(registry.getAllHeroes().count, 0)
        XCTAssertEqual(registry.getAllAbilities().count, 0)
        XCTAssertEqual(registry.heroRegistry.allHeroes.count, 0)
        XCTAssertEqual(registry.abilityRegistry.count, 0)
    }

    func testSafeReloadRollsBackGlobalRegistriesOnFailure() throws {
        let registry = TestContentLoader.makeLoadedRegistry()
        let initialHeroIds = Set(registry.getAllHeroes().map(\.id))
        let initialAbilityIds = Set(registry.getAllAbilities().map(\.id))
        XCTAssertFalse(initialHeroIds.isEmpty)
        XCTAssertFalse(initialAbilityIds.isEmpty)

        let invalidPackURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pack")
        try Data("BAD!".utf8).write(to: invalidPackURL)
        defer { try? FileManager.default.removeItem(at: invalidPackURL) }

        let result = registry.safeReloadPack("core-heroes", from: invalidPackURL)
        if case .success = result {
            XCTFail("safeReloadPack should fail for invalid .pack")
        }

        XCTAssertEqual(Set(registry.getAllHeroes().map(\.id)), initialHeroIds)
        XCTAssertEqual(Set(registry.getAllAbilities().map(\.id)), initialAbilityIds)

        XCTAssertEqual(Set(registry.heroRegistry.allHeroes.map(\.id)), initialHeroIds)
        XCTAssertEqual(Set(registry.abilityRegistry.allAbilities.map(\.id)), initialAbilityIds)
    }
}

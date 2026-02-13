/// Файл: CardSampleGameTests/Unit/HeroRegistryTests.swift
/// Назначение: Содержит реализацию файла HeroRegistryTests.swift.
/// Зона ответственности: Фиксирует проверяемый контракт и не содержит production-логики.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
import TwilightEngine
import CoreHeroesContent
import TwilightMarchesActIContent

@testable import CardSampleGame

/// Тесты для загрузки героев из Content Pack через ContentRegistry
final class HeroRegistryTests: XCTestCase {

    private var registry: ContentRegistry!

    override func setUpWithError() throws {
        try super.setUpWithError()
        registry = try TestContentLoader.makeStandardRegistry()
    }

    override func tearDown() {
        registry = nil
        super.tearDown()
    }

    // MARK: - Базовые тесты

    func testRegistryHasHeroes() {
        let heroes = registry.getAllHeroes()
        XCTAssertGreaterThan(heroes.count, 0, "Реестр должен содержать героев из контент пака")
    }

    func testHeroHasValidStats() {
        let heroes = registry.getAllHeroes()

        for hero in heroes {
            XCTAssertGreaterThan(hero.baseStats.maxHealth, 0, "Герой \(hero.id) должен иметь maxHealth > 0")
            XCTAssertGreaterThan(hero.baseStats.maxFaith, 0, "Герой \(hero.id) должен иметь maxFaith > 0")
        }
    }

    func testHeroHasSpecialAbility() {
        let heroes = registry.getAllHeroes()

        for hero in heroes {
            XCTAssertFalse(hero.specialAbility.id.isEmpty, "Герой \(hero.id) должен иметь способность")
        }
    }

    // MARK: - Тесты поиска по ID

    func testHeroLookupById() {
        let heroes = registry.getAllHeroes()

        guard let firstHero = heroes.first else {
            XCTFail("Нет героев в реестре")
            return
        }

        let foundHero = registry.getHero(id: firstHero.id)
        XCTAssertNotNil(foundHero)
        XCTAssertEqual(foundHero?.id, firstHero.id)
    }

    func testNonExistentHeroReturnsNil() {
        let hero = registry.getHero(id: "nonexistent_hero_12345")
        XCTAssertNil(hero)
    }

    // MARK: - Тесты доступности

    func testAvailableHeroes() {
        let heroes = registry.getAllHeroes()
        let available = heroes.filter { hero in
            if case .alwaysAvailable = hero.availability {
                return true
            }
            return false
        }

        XCTAssertGreaterThan(available.count, 0, "Должны быть доступные герои")
    }

    // MARK: - Тесты стартовых колод

    func testHeroesHaveStartingDecks() {
        let heroes = registry.getAllHeroes()

        for hero in heroes {
            XCTAssertFalse(hero.startingDeckCardIDs.isEmpty,
                          "Герой \(hero.id) должен иметь стартовую колоду")
        }
    }

    // MARK: - Тесты первого героя

    func testFirstHeroExists() {
        let heroes = registry.getAllHeroes()
        XCTAssertFalse(heroes.isEmpty, "Должен быть хотя бы один герой")
    }
}

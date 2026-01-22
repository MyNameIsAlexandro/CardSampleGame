import XCTest
@testable import CardSampleGame

/// Тесты для HeroRegistry - загрузка героев из Content Pack
final class HeroRegistryTests: XCTestCase {

    // MARK: - Базовые тесты

    func testRegistryHasHeroes() {
        let registry = HeroRegistry.shared
        XCTAssertGreaterThan(registry.count, 0, "Реестр должен содержать героев из контент пака")
    }

    func testHeroHasValidStats() {
        let registry = HeroRegistry.shared

        for hero in registry.allHeroes {
            XCTAssertGreaterThan(hero.baseStats.maxHealth, 0, "Герой \(hero.id) должен иметь maxHealth > 0")
            XCTAssertGreaterThan(hero.baseStats.maxFaith, 0, "Герой \(hero.id) должен иметь maxFaith > 0")
        }
    }

    func testHeroHasSpecialAbility() {
        let registry = HeroRegistry.shared

        for hero in registry.allHeroes {
            XCTAssertFalse(hero.specialAbility.id.isEmpty, "Герой \(hero.id) должен иметь способность")
        }
    }

    // MARK: - Тесты поиска по ID

    func testHeroLookupById() {
        let registry = HeroRegistry.shared
        let allHeroes = registry.allHeroes

        guard let firstHero = allHeroes.first else {
            XCTFail("Нет героев в реестре")
            return
        }

        let foundHero = registry.hero(id: firstHero.id)
        XCTAssertNotNil(foundHero)
        XCTAssertEqual(foundHero?.id, firstHero.id)
    }

    func testNonExistentHeroReturnsNil() {
        let registry = HeroRegistry.shared
        let hero = registry.hero(id: "nonexistent_hero_12345")
        XCTAssertNil(hero)
    }

    // MARK: - Тесты доступности

    func testAvailableHeroes() {
        let registry = HeroRegistry.shared
        let available = registry.availableHeroes()

        XCTAssertGreaterThan(available.count, 0, "Должны быть доступные герои")

        for hero in available {
            if case .alwaysAvailable = hero.availability {
                // OK
            } else {
                XCTFail("Герой \(hero.id) не должен быть в списке доступных без условий")
            }
        }
    }

    // MARK: - Тесты стартовых колод

    func testHeroesHaveStartingDecks() {
        let registry = HeroRegistry.shared

        for hero in registry.allHeroes {
            XCTAssertFalse(hero.startingDeckCardIDs.isEmpty,
                          "Герой \(hero.id) должен иметь стартовую колоду")
        }
    }

    // MARK: - Тесты firstHero

    func testFirstHeroExists() {
        let registry = HeroRegistry.shared
        XCTAssertNotNil(registry.firstHero, "Должен быть хотя бы один герой")
    }
}

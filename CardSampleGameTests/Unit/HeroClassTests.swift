import XCTest
@testable import CardSampleGame

/// Тесты системы героев
/// Тестирует СТРУКТУРУ и ПОВЕДЕНИЕ, а не конкретные значения (значения загружаются из JSON)
final class HeroTests: XCTestCase {

    // MARK: - Тесты структуры героев

    func testHeroesExistInRegistry() {
        let registry = HeroRegistry.shared
        XCTAssertGreaterThan(registry.count, 0, "Должен быть хотя бы один герой в реестре")
    }

    func testHeroHasValidData() {
        let registry = HeroRegistry.shared

        for hero in registry.allHeroes {
            XCTAssertFalse(hero.id.isEmpty, "Герой должен иметь ID")
            XCTAssertFalse(hero.name.isEmpty, "Герой \(hero.id) должен иметь name")
            XCTAssertFalse(hero.icon.isEmpty, "Герой \(hero.id) должен иметь icon")
        }
    }

    // MARK: - Тесты создания Player с heroId

    func testPlayerCreationWithHeroId() {
        let registry = HeroRegistry.shared

        for hero in registry.allHeroes {
            let player = Player(name: "Тест", heroId: hero.id)
            XCTAssertEqual(player.heroId, hero.id)
            // Статы должны загрузиться из HeroRegistry
            XCTAssertGreaterThan(player.health, 0, "Герой \(hero.id) должен иметь health > 0")
            XCTAssertGreaterThan(player.maxHealth, 0, "Герой \(hero.id) должен иметь maxHealth > 0")
        }
    }

    func testPlayerCreationWithoutHeroId() {
        let player = Player(name: "Тест")

        XCTAssertNil(player.heroId, "Без heroId heroId = nil")
        XCTAssertEqual(player.health, 10, "Дефолтное HP = 10")
        XCTAssertEqual(player.strength, 5, "Дефолтная сила = 5")
    }

    // MARK: - Тесты способностей (поведение, не конкретные значения)

    func testHeroAbilityDamageBonus() throws {
        let registry = HeroRegistry.shared

        // Находим героя со способностью на бонус урона
        let heroWithDamageBonus = registry.allHeroes.first { hero in
            hero.specialAbility.trigger == .onDamageDealt &&
            hero.specialAbility.effects.contains { $0.type == .bonusDamage }
        }

        guard let hero = heroWithDamageBonus else {
            throw XCTSkip("Нет героя со способностью на бонус урона")
        }

        let player = Player(name: "Тест", heroId: hero.id)

        // Проверяем условия способности
        if let condition = hero.specialAbility.condition {
            switch condition.type {
            case .hpBelowPercent:
                // При полном HP нет бонуса
                let bonusAtFullHP = player.getHeroDamageBonus()
                XCTAssertEqual(bonusAtFullHP, 0, "При HP >= порога бонуса нет")

                // Уменьшаем HP ниже порога - должен появиться бонус
                let threshold = condition.value ?? 50
                player.health = player.maxHealth * threshold / 100 - 1
                let bonusAtLowHP = player.getHeroDamageBonus()
                XCTAssertGreaterThan(bonusAtLowHP, 0, "При HP < порога должен быть бонус урона")

            case .targetFullHP:
                let bonusVsFullHP = player.getHeroDamageBonus(targetFullHP: true)
                let bonusVsDamaged = player.getHeroDamageBonus(targetFullHP: false)
                XCTAssertGreaterThan(bonusVsFullHP, 0, "По цели с полным HP: должен быть бонус")
                XCTAssertEqual(bonusVsDamaged, 0, "По повреждённой цели: нет бонуса")

            default:
                break
            }
        }
    }

    func testHeroAbilityFaithGain() throws {
        let registry = HeroRegistry.shared

        // Находим героя со способностью на получение веры в конце хода
        let heroWithFaithGain = registry.allHeroes.first { hero in
            hero.specialAbility.trigger == .turnEnd &&
            hero.specialAbility.effects.contains { $0.type == .gainFaith }
        }

        guard let hero = heroWithFaithGain else {
            throw XCTSkip("Нет героя со способностью на получение веры")
        }

        let player = Player(name: "Тест", heroId: hero.id)
        XCTAssertTrue(player.shouldGainFaithEndOfTurn, "Герой \(hero.id) должен получать веру в конце хода")
    }

    func testHeroAbilityBonusDice() throws {
        let registry = HeroRegistry.shared

        // Находим героя со способностью на бонусные кубики
        let heroWithBonusDice = registry.allHeroes.first { hero in
            hero.specialAbility.trigger == .onAttack &&
            hero.specialAbility.effects.contains { $0.type == .bonusDice }
        }

        guard let hero = heroWithBonusDice else {
            throw XCTSkip("Нет героя со способностью на бонусные кубики")
        }

        let player = Player(name: "Тест", heroId: hero.id)

        // Проверяем условия способности
        if let condition = hero.specialAbility.condition, condition.type == .firstAttack {
            let bonusOnFirstAttack = player.getHeroBonusDice(isFirstAttack: true)
            let bonusOnOtherAttacks = player.getHeroBonusDice(isFirstAttack: false)

            XCTAssertGreaterThan(bonusOnFirstAttack, 0, "Первая атака: должен быть бонус кубиков")
            XCTAssertEqual(bonusOnOtherAttacks, 0, "Не первая атака: 0 бонусных кубиков")
        }
    }

    func testHeroAbilityDamageReduction() throws {
        let registry = HeroRegistry.shared

        // Находим героя со способностью на снижение урона
        let heroWithReduction = registry.allHeroes.first { hero in
            hero.specialAbility.trigger == .onDamageReceived &&
            hero.specialAbility.effects.contains { $0.type == .damageReduction }
        }

        guard let hero = heroWithReduction else {
            throw XCTSkip("Нет героя со способностью на снижение урона")
        }

        let player = Player(name: "Тест", heroId: hero.id)

        // Проверяем условия способности
        if let condition = hero.specialAbility.condition, condition.type == .damageSourceDark {
            let reductionFromDark = player.getHeroDamageReduction(fromDarkSource: true)
            let reductionFromNormal = player.getHeroDamageReduction(fromDarkSource: false)

            XCTAssertGreaterThan(reductionFromDark, 0, "От тёмного урона: должно быть снижение")
            XCTAssertEqual(reductionFromNormal, 0, "От обычного урона: нет снижения")
        }
    }

    // MARK: - Тесты расчёта урона с модификаторами

    func testTotalDamageIncludesAbilityBonus() throws {
        let registry = HeroRegistry.shared

        // Находим героя со способностью на бонус урона при низком HP
        let heroWithDamageBonus = registry.allHeroes.first { hero in
            hero.specialAbility.trigger == .onDamageDealt &&
            hero.specialAbility.effects.contains { $0.type == .bonusDamage } &&
            hero.specialAbility.condition?.type == .hpBelowPercent
        }

        guard let hero = heroWithDamageBonus else {
            throw XCTSkip("Нет героя со способностью на бонус урона при низком HP")
        }

        let player = Player(name: "Тест", heroId: hero.id)
        let threshold = hero.specialAbility.condition?.value ?? 50
        player.health = player.maxHealth * threshold / 100 - 1  // Активируем способность

        let baseDamage = 10
        let abilityBonus = player.getHeroDamageBonus()
        let totalDamage = player.calculateTotalDamageDealt(baseDamage)

        XCTAssertEqual(totalDamage, baseDamage + abilityBonus, "Урон = база + бонус способности")
    }

    func testTotalDamageIncludesCurseModifier() throws {
        let registry = HeroRegistry.shared

        // Находим героя со способностью на бонус урона при низком HP
        let heroWithDamageBonus = registry.allHeroes.first { hero in
            hero.specialAbility.trigger == .onDamageDealt &&
            hero.specialAbility.effects.contains { $0.type == .bonusDamage } &&
            hero.specialAbility.condition?.type == .hpBelowPercent
        }

        guard let hero = heroWithDamageBonus else {
            throw XCTSkip("Нет героя со способностью на бонус урона при низком HP")
        }

        let player = Player(name: "Тест", heroId: hero.id)
        let threshold = hero.specialAbility.condition?.value ?? 50
        player.health = player.maxHealth * threshold / 100 - 1  // Способность активна
        player.applyCurse(type: .weakness, duration: 2)  // Проклятие слабости

        let baseDamage = 10
        let abilityBonus = player.getHeroDamageBonus()
        let curseModifier = player.getDamageDealtModifier()
        let expectedDamage = max(0, baseDamage + abilityBonus + curseModifier)
        let actualDamage = player.calculateTotalDamageDealt(baseDamage)

        XCTAssertEqual(actualDamage, expectedDamage, "Урон = база + бонус + модификатор проклятия")
    }

    // MARK: - Тесты что каждый герой имеет способность

    func testAllHeroesHaveAbilities() {
        let registry = HeroRegistry.shared

        for hero in registry.allHeroes {
            XCTAssertFalse(hero.specialAbility.id.isEmpty,
                          "Герой \(hero.id) должен иметь способность")
        }
    }
}

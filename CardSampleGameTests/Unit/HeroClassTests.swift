import XCTest
@testable import CardSampleGame

/// Тесты системы классов героев
final class HeroClassTests: XCTestCase {

    // MARK: - Тесты базовых характеристик классов

    func testWarriorStats() {
        let stats = HeroClass.warrior.baseStats
        XCTAssertEqual(stats.health, 12, "Воин: HP = 12")
        XCTAssertEqual(stats.strength, 7, "Воин: сила = 7")
        XCTAssertEqual(stats.faith, 2, "Воин: вера = 2")
        XCTAssertEqual(stats.startingBalance, 50, "Воин: баланс = 50 (нейтральный)")
    }

    func testMageStats() {
        let stats = HeroClass.mage.baseStats
        XCTAssertEqual(stats.health, 7, "Маг: HP = 7")
        XCTAssertEqual(stats.strength, 2, "Маг: сила = 2")
        XCTAssertEqual(stats.faith, 5, "Маг: вера = 5")
        XCTAssertEqual(stats.maxFaith, 15, "Маг: maxFaith = 15")
    }

    func testRangerStats() {
        let stats = HeroClass.ranger.baseStats
        XCTAssertEqual(stats.health, 10, "Следопыт: HP = 10")
        XCTAssertEqual(stats.strength, 4, "Следопыт: сила = 4")
        XCTAssertEqual(stats.dexterity, 6, "Следопыт: ловкость = 6")
    }

    func testPriestStats() {
        let stats = HeroClass.priest.baseStats
        XCTAssertEqual(stats.health, 9, "Жрец: HP = 9")
        XCTAssertEqual(stats.wisdom, 6, "Жрец: мудрость = 6")
        XCTAssertEqual(stats.startingBalance, 70, "Жрец: баланс = 70 (склонен к Свету)")
    }

    func testShadowStats() {
        let stats = HeroClass.shadow.baseStats
        XCTAssertEqual(stats.health, 8, "Тень: HP = 8")
        XCTAssertEqual(stats.dexterity, 5, "Тень: ловкость = 5")
        XCTAssertEqual(stats.startingBalance, 30, "Тень: баланс = 30 (склонен к Тьме)")
    }

    // MARK: - Тесты создания Player с HeroClass

    func testPlayerCreationWithWarriorClass() {
        let player = Player(name: "Тест", heroClass: .warrior)

        XCTAssertEqual(player.heroClass, .warrior)
        XCTAssertEqual(player.health, 12, "Воин должен иметь 12 HP")
        XCTAssertEqual(player.strength, 7, "Воин должен иметь силу 7")
        XCTAssertEqual(player.faith, 2, "Воин должен иметь 2 веры")
    }

    func testPlayerCreationWithMageClass() {
        let player = Player(name: "Тест", heroClass: .mage)

        XCTAssertEqual(player.heroClass, .mage)
        XCTAssertEqual(player.health, 7, "Маг должен иметь 7 HP")
        XCTAssertEqual(player.strength, 2, "Маг должен иметь силу 2")
        XCTAssertEqual(player.maxFaith, 15, "Маг должен иметь maxFaith 15")
    }

    func testPlayerCreationWithoutClass() {
        let player = Player(name: "Тест")

        XCTAssertNil(player.heroClass, "Без класса heroClass = nil")
        XCTAssertEqual(player.health, 10, "Дефолтное HP = 10")
        XCTAssertEqual(player.strength, 5, "Дефолтная сила = 5")
    }

    // MARK: - Тесты особых способностей классов

    func testWarriorRageAbility() {
        let player = Player(name: "Воин", heroClass: .warrior)

        // При полном HP нет бонуса
        XCTAssertEqual(player.getHeroClassDamageBonus(), 0, "При HP >= 50% бонуса нет")

        // Уменьшаем HP ниже 50%
        player.health = 5  // 5/12 < 50%
        XCTAssertEqual(player.getHeroClassDamageBonus(), 2, "При HP < 50% бонус = +2")
    }

    func testMageMeditationAbility() {
        let player = Player(name: "Маг", heroClass: .mage)
        XCTAssertTrue(player.shouldGainFaithEndOfTurn, "Маг должен получать веру в конце хода")

        let warrior = Player(name: "Воин", heroClass: .warrior)
        XCTAssertFalse(warrior.shouldGainFaithEndOfTurn, "Воин не получает веру в конце хода")
    }

    func testRangerTrackingAbility() {
        let player = Player(name: "Следопыт", heroClass: .ranger)

        XCTAssertEqual(player.getHeroClassBonusDice(isFirstAttack: true), 1, "Первая атака: +1 кубик")
        XCTAssertEqual(player.getHeroClassBonusDice(isFirstAttack: false), 0, "Не первая атака: 0 кубиков")
    }

    func testPriestBlessingAbility() {
        let player = Player(name: "Жрец", heroClass: .priest)

        XCTAssertEqual(player.getHeroClassDamageReduction(fromDarkSource: true), 1, "От тёмного урона: -1")
        XCTAssertEqual(player.getHeroClassDamageReduction(fromDarkSource: false), 0, "От обычного урона: 0")
    }

    func testShadowAmbushAbility() {
        let player = Player(name: "Тень", heroClass: .shadow)

        XCTAssertEqual(player.getHeroClassDamageBonus(targetFullHP: true), 3, "По полному HP: +3")
        XCTAssertEqual(player.getHeroClassDamageBonus(targetFullHP: false), 0, "По неполному HP: 0")
    }

    // MARK: - Тесты полного расчёта урона

    func testTotalDamageCalculation() {
        let warrior = Player(name: "Воин", heroClass: .warrior)
        warrior.health = 5  // Активируем Ярость

        // Базовый урон 10, проклятий нет, бонус класса +2 = 12
        let damage = warrior.calculateTotalDamageDealt(10)
        XCTAssertEqual(damage, 12, "10 + 2 (Ярость) = 12")
    }

    func testTotalDamageWithCurse() {
        let warrior = Player(name: "Воин", heroClass: .warrior)
        warrior.health = 5  // Ярость активна
        warrior.applyCurse(type: .weakness, duration: 2)  // -1 урон

        // 10 + 2 (Ярость) - 1 (Слабость) = 11
        let damage = warrior.calculateTotalDamageDealt(10)
        XCTAssertEqual(damage, 11, "10 + 2 - 1 = 11")
    }

    // MARK: - Тесты стартовых путей

    func testStartingDeckPaths() {
        XCTAssertEqual(HeroClass.warrior.startingDeckType, .balance)
        XCTAssertEqual(HeroClass.mage.startingDeckType, .balance)
        XCTAssertEqual(HeroClass.ranger.startingDeckType, .balance)
        XCTAssertEqual(HeroClass.priest.startingDeckType, .light)
        XCTAssertEqual(HeroClass.shadow.startingDeckType, .dark)
    }

    // MARK: - Тесты всех классов существуют

    func testAllHeroClassesExist() {
        let allClasses = HeroClass.allCases
        XCTAssertEqual(allClasses.count, 5, "Должно быть 5 классов")

        XCTAssertTrue(allClasses.contains(.warrior))
        XCTAssertTrue(allClasses.contains(.mage))
        XCTAssertTrue(allClasses.contains(.ranger))
        XCTAssertTrue(allClasses.contains(.priest))
        XCTAssertTrue(allClasses.contains(.shadow))
    }
}

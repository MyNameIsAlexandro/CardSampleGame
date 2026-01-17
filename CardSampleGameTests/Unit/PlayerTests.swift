import XCTest
@testable import CardSampleGame

/// Unit тесты для Player
/// Покрывает: проклятия, колода, баланс, вера
/// См. QA_ACT_I_CHECKLIST.md, тесты TEST-013, TEST-014
final class PlayerTests: XCTestCase {

    var player: Player!

    override func setUp() {
        super.setUp()
        player = Player(name: "Тестовый игрок")
    }

    override func tearDown() {
        player = nil
        super.tearDown()
    }

    // MARK: - Инициализация

    func testInitialHealth() {
        XCTAssertEqual(player.health, 10, "Начальное здоровье должно быть 10")
        XCTAssertEqual(player.maxHealth, 10, "Максимальное здоровье должно быть 10")
    }

    func testInitialBalance() {
        XCTAssertEqual(player.balance, 50, "Начальный баланс должен быть 50 (нейтральный)")
    }

    func testInitialFaith() {
        XCTAssertEqual(player.faith, 3, "Начальная вера должна быть 3")
        XCTAssertEqual(player.maxFaith, 10, "Максимальная вера должна быть 10")
    }

    func testInitialDeckEmpty() {
        XCTAssertTrue(player.deck.isEmpty, "Начальная колода должна быть пустой")
        XCTAssertTrue(player.hand.isEmpty, "Начальная рука должна быть пустой")
        XCTAssertTrue(player.discard.isEmpty, "Начальный сброс должен быть пустым")
    }

    func testNoCursesAtStart() {
        XCTAssertTrue(player.activeCurses.isEmpty, "Игрок не должен иметь проклятий при старте")
    }

    // MARK: - TEST-014: Проклятия

    func testApplyCurse() {
        player.applyCurse(type: .weakness, duration: 3)
        XCTAssertTrue(player.hasCurse(.weakness), "Проклятие должно быть применено")
        XCTAssertEqual(player.activeCurses.count, 1, "Должно быть одно проклятие")
    }

    func testRemoveSpecificCurse() {
        player.applyCurse(type: .weakness, duration: 3)
        player.applyCurse(type: .fear, duration: 2)

        player.removeCurse(type: .weakness)

        XCTAssertFalse(player.hasCurse(.weakness), "Weakness должен быть удалён")
        XCTAssertTrue(player.hasCurse(.fear), "Fear должен остаться")
    }

    func testRemoveAnyCurse() {
        player.applyCurse(type: .weakness, duration: 3)
        player.applyCurse(type: .fear, duration: 2)

        player.removeCurse(type: nil)

        XCTAssertEqual(player.activeCurses.count, 1, "Должно остаться одно проклятие")
    }

    func testCurseRemovalCost() {
        // Проверяем стоимость снятия проклятий в вере
        XCTAssertEqual(CurseType.weakness.removalCost, 2)
        XCTAssertEqual(CurseType.fear.removalCost, 2)
        XCTAssertEqual(CurseType.exhaustion.removalCost, 3)
        XCTAssertEqual(CurseType.greed.removalCost, 4)
        XCTAssertEqual(CurseType.shadowOfNav.removalCost, 5)
        XCTAssertEqual(CurseType.bloodCurse.removalCost, 6)
        XCTAssertEqual(CurseType.sealOfNav.removalCost, 8)
    }

    func testCurseTickReducesDuration() {
        player.applyCurse(type: .weakness, duration: 3)
        let initialDuration = player.activeCurses[0].duration

        player.tickCurses()

        XCTAssertEqual(player.activeCurses[0].duration, initialDuration - 1, "Длительность должна уменьшиться")
    }

    func testCurseExpiresWhenDurationZero() {
        player.applyCurse(type: .weakness, duration: 1)

        player.tickCurses()

        XCTAssertTrue(player.activeCurses.isEmpty, "Проклятие должно исчезнуть при duration = 0")
    }

    // MARK: - Модификаторы урона от проклятий

    func testWeaknessDamageModifier() {
        // weakness: -1 к наносимому урону
        player.applyCurse(type: .weakness, duration: 3)
        XCTAssertEqual(player.getDamageDealtModifier(), -1, "Weakness должен давать -1 к урону")
    }

    func testFearDamageModifier() {
        // fear: +1 к получаемому урону
        player.applyCurse(type: .fear, duration: 3)
        XCTAssertEqual(player.getDamageTakenModifier(), 1, "Fear должен давать +1 к получаемому урону")
    }

    func testShadowOfNavDamageModifier() {
        // shadowOfNav: +3 к наносимому урону
        player.applyCurse(type: .shadowOfNav, duration: 3)
        XCTAssertEqual(player.getDamageDealtModifier(), 3, "ShadowOfNav должен давать +3 к урону")
    }

    func testCombinedDamageModifiers() {
        // weakness + shadowOfNav = -1 + 3 = +2
        player.applyCurse(type: .weakness, duration: 3)
        player.applyCurse(type: .shadowOfNav, duration: 3)
        XCTAssertEqual(player.getDamageDealtModifier(), 2, "Комбинация weakness + shadowOfNav = +2")
    }

    func testCalculateDamageDealt() {
        player.applyCurse(type: .weakness, duration: 3)
        let baseDamage = 5
        let actualDamage = player.calculateDamageDealt(baseDamage)
        XCTAssertEqual(actualDamage, 4, "5 - 1 (weakness) = 4")
    }

    func testTakeDamageWithCurses() {
        player.applyCurse(type: .fear, duration: 3)
        let initialHealth = player.health
        player.takeDamageWithCurses(3) // 3 + 1 (fear) = 4
        XCTAssertEqual(player.health, initialHealth - 4, "Урон с fear должен быть 4")
    }

    func testDamageCannotBeBelowZero() {
        player.applyCurse(type: .weakness, duration: 3)
        let damage = player.calculateDamageDealt(0)
        XCTAssertGreaterThanOrEqual(damage, 0, "Урон не может быть отрицательным")
    }

    // MARK: - Баланс Light/Dark

    func testShiftBalanceTowardsLight() {
        player.balance = 50
        player.shiftBalance(towards: .light, amount: 10)
        XCTAssertEqual(player.balance, 60, "Баланс должен сдвинуться к Свету")
    }

    func testShiftBalanceTowardsDark() {
        player.balance = 50
        player.shiftBalance(towards: .dark, amount: 10)
        XCTAssertEqual(player.balance, 40, "Баланс должен сдвинуться к Тьме")
    }

    func testShiftBalanceTowardsNeutral() {
        player.balance = 70
        player.shiftBalance(towards: .neutral, amount: 10)
        XCTAssertEqual(player.balance, 60, "Баланс должен сдвинуться к нейтральному")
    }

    func testBalanceLimits() {
        player.balance = 95
        player.shiftBalance(towards: .light, amount: 20)
        XCTAssertEqual(player.balance, 100, "Баланс не должен превышать 100")

        player.balance = 5
        player.shiftBalance(towards: .dark, amount: 20)
        XCTAssertEqual(player.balance, 0, "Баланс не должен быть ниже 0")
    }

    func testBalanceState() {
        player.balance = 80
        XCTAssertEqual(player.balanceState, .light, "80 = Путь Света")

        player.balance = 50
        XCTAssertEqual(player.balanceState, .neutral, "50 = Нейтральный")

        player.balance = 20
        XCTAssertEqual(player.balanceState, .dark, "20 = Путь Тьмы")
    }

    func testBalanceDescription() {
        player.balance = 80
        XCTAssertEqual(player.balanceDescription, "Путь Света")

        player.balance = 50
        XCTAssertEqual(player.balanceDescription, "Нейтральный")

        player.balance = 20
        XCTAssertEqual(player.balanceDescription, "Путь Тьмы")
    }

    // MARK: - Вера (Faith)

    func testGainFaith() {
        player.faith = 3
        player.gainFaith(2)
        XCTAssertEqual(player.faith, 5, "Вера должна увеличиться")
    }

    func testFaithCannotExceedMax() {
        player.faith = 9
        player.gainFaith(5)
        XCTAssertEqual(player.faith, player.maxFaith, "Вера не должна превышать максимум")
    }

    func testSpendFaithSuccess() {
        player.faith = 5
        let result = player.spendFaith(3)
        XCTAssertTrue(result, "Трата веры должна быть успешной")
        XCTAssertEqual(player.faith, 2, "Осталось 2 веры")
    }

    func testSpendFaithFailure() {
        player.faith = 2
        let result = player.spendFaith(5)
        XCTAssertFalse(result, "Трата веры должна быть неуспешной")
        XCTAssertEqual(player.faith, 2, "Вера не должна измениться")
    }

    // MARK: - Колода

    func testDrawCard() {
        let testCard = Card(name: "Тест", type: .spell, description: "Тест")
        player.deck = [testCard]

        player.drawCard()

        XCTAssertTrue(player.deck.isEmpty, "Колода должна быть пустой")
        XCTAssertEqual(player.hand.count, 1, "В руке должна быть 1 карта")
    }

    func testDrawFromEmptyDeckReshuffles() {
        let testCard = Card(name: "Тест", type: .spell, description: "Тест")
        player.deck = []
        player.discard = [testCard]

        player.drawCard()

        XCTAssertTrue(player.discard.isEmpty, "Сброс должен быть пуст после перемешивания")
        XCTAssertEqual(player.hand.count, 1, "В руке должна быть карта")
    }

    func testPlayCard() {
        let testCard = Card(name: "Тест", type: .spell, description: "Тест")
        player.hand = [testCard]

        player.playCard(testCard)

        XCTAssertTrue(player.hand.isEmpty, "Рука должна быть пустой")
        XCTAssertEqual(player.discard.count, 1, "Карта должна быть в сбросе")
    }

    func testReshuffleDiscard() {
        let card1 = Card(name: "Карта1", type: .spell, description: "")
        let card2 = Card(name: "Карта2", type: .spell, description: "")
        player.discard = [card1, card2]

        player.reshuffleDiscard()

        XCTAssertEqual(player.deck.count, 2, "Колода должна содержать 2 карты")
        XCTAssertTrue(player.discard.isEmpty, "Сброс должен быть пуст")
    }

    // MARK: - Здоровье

    func testTakeDamage() {
        let initialHealth = player.health
        player.takeDamage(3)
        XCTAssertEqual(player.health, initialHealth - 3, "Здоровье должно уменьшиться")
    }

    func testHealthCannotBeBelowZero() {
        player.takeDamage(100)
        XCTAssertEqual(player.health, 0, "Здоровье не может быть отрицательным")
    }

    func testHeal() {
        player.health = 5
        player.heal(3)
        XCTAssertEqual(player.health, 8, "Здоровье должно увеличиться")
    }

    func testHealCannotExceedMax() {
        player.health = 9
        player.heal(5)
        XCTAssertEqual(player.health, player.maxHealth, "Здоровье не должно превышать максимум")
    }

    // MARK: - Духи (Spirits)

    func testSummonSpirit() {
        let spirit = Card(name: "Дух", type: .spirit, description: "")
        player.summonSpirit(spirit)
        XCTAssertEqual(player.spirits.count, 1, "Дух должен быть призван")
    }

    func testDismissSpirit() {
        let spirit = Card(name: "Дух", type: .spirit, description: "")
        player.spirits = [spirit]

        player.dismissSpirit(spirit)

        XCTAssertTrue(player.spirits.isEmpty, "Дух должен быть изгнан")
    }

    // MARK: - Realm

    func testTravelToRealm() {
        XCTAssertEqual(player.currentRealm, .yav, "Начальный realm должен быть Yav")

        player.travelToRealm(.nav)

        XCTAssertEqual(player.currentRealm, .nav, "Realm должен быть Nav")
    }
}

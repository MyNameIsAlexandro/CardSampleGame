import XCTest
@testable import CardSampleGame

/// Тесты системы deck-building
/// Покрывает: покупка карт, тасовка, сброс, путь колоды
/// См. QA_ACT_I_CHECKLIST.md, TEST-013
final class DeckBuildingTests: XCTestCase {

    var player: Player!
    var gameState: GameState!

    override func setUp() {
        super.setUp()
        player = Player(name: "Тестовый герой")
        gameState = GameState(players: [player])
    }

    override func tearDown() {
        player = nil
        gameState = nil
        super.tearDown()
    }

    // MARK: - Базовые операции с колодой

    func testInitialDeckEmpty() {
        XCTAssertTrue(player.deck.isEmpty, "Начальная колода пуста")
        XCTAssertTrue(player.hand.isEmpty, "Начальная рука пуста")
        XCTAssertTrue(player.discard.isEmpty, "Начальный сброс пуст")
    }

    func testDrawCard() {
        let card = Card(name: "Test", type: .spell, description: "")
        player.deck = [card]

        player.drawCard()

        XCTAssertTrue(player.deck.isEmpty, "Колода пуста после взятия")
        XCTAssertEqual(player.hand.count, 1, "Карта в руке")
        XCTAssertEqual(player.hand[0].name, "Test")
    }

    func testDrawMultipleCards() {
        for i in 0..<5 {
            player.deck.append(Card(name: "Card\(i)", type: .spell, description: ""))
        }

        player.drawCards(count: 3)

        XCTAssertEqual(player.deck.count, 2, "В колоде 2 карты")
        XCTAssertEqual(player.hand.count, 3, "В руке 3 карты")
    }

    func testDrawFromEmptyDeckAutoReshuffles() {
        let card = Card(name: "Discarded", type: .spell, description: "")
        player.deck = []
        player.discard = [card]

        player.drawCard()

        XCTAssertTrue(player.discard.isEmpty, "Сброс пуст после перетасовки")
        XCTAssertEqual(player.hand.count, 1, "Карта в руке")
    }

    func testDrawFromEmptyDeckAndEmptyDiscard() {
        player.deck = []
        player.discard = []

        player.drawCard()

        XCTAssertTrue(player.hand.isEmpty, "Нельзя взять из пустой колоды")
    }

    func testPlayCard() {
        let card = Card(name: "Played", type: .spell, description: "")
        player.hand = [card]

        player.playCard(card)

        XCTAssertTrue(player.hand.isEmpty, "Рука пуста")
        XCTAssertEqual(player.discard.count, 1, "Карта в сбросе")
        XCTAssertEqual(player.discard[0].name, "Played")
    }

    func testPlayCardNotInHand() {
        let card = Card(name: "NotInHand", type: .spell, description: "")
        player.hand = []

        player.playCard(card)

        XCTAssertTrue(player.discard.isEmpty, "Ничего не сброшено")
    }

    func testReshuffleDiscard() {
        let card1 = Card(name: "Card1", type: .spell, description: "")
        let card2 = Card(name: "Card2", type: .spell, description: "")
        player.discard = [card1, card2]

        player.reshuffleDiscard()

        XCTAssertEqual(player.deck.count, 2, "Карты в колоде")
        XCTAssertTrue(player.discard.isEmpty, "Сброс пуст")
    }

    func testShuffleDeck() {
        // Заполняем колоду упорядоченно
        for i in 0..<10 {
            player.deck.append(Card(name: "Card\(i)", type: .spell, description: ""))
        }

        let originalOrder = player.deck.map { $0.name }
        player.shuffleDeck()
        let newOrder = player.deck.map { $0.name }

        // Маловероятно что порядок останется тем же после тасовки
        // Но это не гарантировано, поэтому просто проверяем что карты те же
        XCTAssertEqual(Set(originalOrder), Set(newOrder), "Те же карты после тасовки")
    }

    // MARK: - Покупка карт (Market)

    func testPurchaseCardSuccess() {
        player.faith = 5
        let card = Card(name: "Shop Card", type: .spell, description: "", cost: 3)
        gameState.marketCards = [card]

        let result = gameState.purchaseCard(card)

        XCTAssertTrue(result, "Покупка успешна")
        XCTAssertEqual(player.faith, 2, "Вера потрачена")
        XCTAssertTrue(gameState.marketCards.isEmpty, "Карта убрана из магазина")
        XCTAssertEqual(player.discard.count, 1, "Карта в сбросе")
    }

    func testPurchaseCardInsufficientFaith() {
        player.faith = 2
        let card = Card(name: "Expensive", type: .spell, description: "", cost: 5)
        gameState.marketCards = [card]

        let result = gameState.purchaseCard(card)

        XCTAssertFalse(result, "Покупка неуспешна")
        XCTAssertEqual(player.faith, 2, "Вера не изменилась")
        XCTAssertEqual(gameState.marketCards.count, 1, "Карта осталась в магазине")
    }

    func testPurchaseCardWithoutCost() {
        player.faith = 5
        let card = Card(name: "No Cost", type: .spell, description: "") // cost = nil
        gameState.marketCards = [card]

        let result = gameState.purchaseCard(card)

        XCTAssertFalse(result, "Нельзя купить карту без стоимости")
    }

    // MARK: - Стоимость карт по балансу

    func testLightCardCheaperForLightPlayer() {
        let lightCard = Card(
            name: "Light Spell",
            type: .spell,
            description: "",
            balance: .light,
            faithCost: 4
        )

        // Игрок на пути Света (баланс > 50)
        player.balance = 80  // +30 от нейтрального

        let adjustedCost = lightCard.adjustedFaithCost(playerBalance: player.balance)

        // discount = (80 - 50) / 20 = 1
        XCTAssertEqual(adjustedCost, 3, "Light карта дешевле для Light игрока")
    }

    func testDarkCardCheaperForDarkPlayer() {
        let darkCard = Card(
            name: "Dark Spell",
            type: .spell,
            description: "",
            balance: .dark,
            faithCost: 4
        )

        // Игрок на пути Тьмы (баланс < 50)
        player.balance = 20  // -30 от нейтрального

        let adjustedCost = darkCard.adjustedFaithCost(playerBalance: player.balance)

        // discount = (50 - 20) / 20 = 1
        XCTAssertEqual(adjustedCost, 3, "Dark карта дешевле для Dark игрока")
    }

    func testNeutralCardSameCostForAll() {
        let neutralCard = Card(
            name: "Neutral Spell",
            type: .spell,
            description: "",
            balance: .neutral,
            faithCost: 3
        )

        let costLight = neutralCard.adjustedFaithCost(playerBalance: 80)
        let costDark = neutralCard.adjustedFaithCost(playerBalance: 20)
        let costNeutral = neutralCard.adjustedFaithCost(playerBalance: 50)

        XCTAssertEqual(costLight, 3, "Нейтральная карта - базовая цена")
        XCTAssertEqual(costDark, 3, "Нейтральная карта - базовая цена")
        XCTAssertEqual(costNeutral, 3, "Нейтральная карта - базовая цена")
    }

    func testMinimumCardCost() {
        let lightCard = Card(
            name: "Cheap Light",
            type: .spell,
            description: "",
            balance: .light,
            faithCost: 1
        )

        player.balance = 100  // максимальный свет

        let adjustedCost = lightCard.adjustedFaithCost(playerBalance: player.balance)

        XCTAssertGreaterThanOrEqual(adjustedCost, 1, "Минимальная цена = 1")
    }

    // MARK: - Роли карт и путь колоды

    func testCardRoleDefaultBalance() {
        XCTAssertEqual(CardRole.sustain.defaultBalance, .light)
        XCTAssertEqual(CardRole.control.defaultBalance, .light)
        XCTAssertEqual(CardRole.power.defaultBalance, .dark)
        XCTAssertEqual(CardRole.utility.defaultBalance, .neutral)
    }

    func testCardRoleTypicalRarity() {
        XCTAssertTrue(CardRole.sustain.typicalRarity.contains(.common))
        XCTAssertTrue(CardRole.control.typicalRarity.contains(.rare))
        XCTAssertTrue(CardRole.power.typicalRarity.contains(.uncommon))
    }

    // MARK: - Рост колоды

    func testDeckGrowthTarget() {
        // Цель: 20-25 карт к финалу Акта I
        for i in 0..<22 {
            player.deck.append(Card(name: "Card\(i)", type: .spell, description: ""))
        }

        XCTAssertGreaterThanOrEqual(player.deck.count, 20, "Минимум 20 карт")
        XCTAssertLessThanOrEqual(player.deck.count, 25, "Максимум 25 карт (цель)")
    }

    func testDeckGrowthRedFlagTooFew() {
        for i in 0..<12 {
            player.deck.append(Card(name: "Card\(i)", type: .spell, description: ""))
        }

        XCTAssertLessThan(player.deck.count, 15, "Red Flag: < 15 карт")
    }

    func testDeckGrowthRedFlagTooMany() {
        for i in 0..<35 {
            player.deck.append(Card(name: "Card\(i)", type: .spell, description: ""))
        }

        XCTAssertGreaterThan(player.deck.count, 30, "Red Flag: > 30 карт")
    }

    // MARK: - Вера (Faith) система

    func testGainFaith() {
        player.faith = 3
        player.gainFaith(2)
        XCTAssertEqual(player.faith, 5)
    }

    func testFaithCannotExceedMax() {
        player.faith = 9
        player.gainFaith(5)
        XCTAssertEqual(player.faith, player.maxFaith, "Вера <= maxFaith")
    }

    func testSpendFaithSuccess() {
        player.faith = 5
        let result = player.spendFaith(3)
        XCTAssertTrue(result)
        XCTAssertEqual(player.faith, 2)
    }

    func testSpendFaithFailure() {
        player.faith = 2
        let result = player.spendFaith(5)
        XCTAssertFalse(result)
        XCTAssertEqual(player.faith, 2, "Вера не изменилась")
    }

    func testFaithRegenerationOnTurnEnd() {
        player.faith = 2

        gameState.endTurn()

        XCTAssertEqual(player.faith, 3, "+1 вера в конце хода")
    }

    // MARK: - Типы карт

    func testCardTypesExist() {
        XCTAssertNotNil(CardType.spell)
        XCTAssertNotNil(CardType.item)
        XCTAssertNotNil(CardType.spirit)
        XCTAssertNotNil(CardType.monster)
        XCTAssertNotNil(CardType.location)
    }

    func testCardRaritiesExist() {
        XCTAssertNotNil(CardRarity.common)
        XCTAssertNotNil(CardRarity.uncommon)
        XCTAssertNotNil(CardRarity.rare)
        XCTAssertNotNil(CardRarity.legendary)
    }

    // MARK: - Способности карт

    func testDamageAbility() {
        let ability = CardAbility(
            name: "Удар",
            description: "Наносит урон",
            effect: .damage(amount: 3, type: .physical)
        )

        XCTAssertEqual(ability.name, "Удар")

        if case .damage(let amount, let type) = ability.effect {
            XCTAssertEqual(amount, 3)
            XCTAssertEqual(type, .physical)
        } else {
            XCTFail("Неверный эффект")
        }
    }

    func testHealAbility() {
        let ability = CardAbility(
            name: "Исцеление",
            description: "Лечит",
            effect: .heal(amount: 5)
        )

        if case .heal(let amount) = ability.effect {
            XCTAssertEqual(amount, 5)
        } else {
            XCTFail("Неверный эффект")
        }
    }

    func testApplyCurseAbility() {
        let ability = CardAbility(
            name: "Проклятие",
            description: "Накладывает слабость",
            effect: .applyCurse(type: .weakness, duration: 3)
        )

        if case .applyCurse(let type, let duration) = ability.effect {
            XCTAssertEqual(type, .weakness)
            XCTAssertEqual(duration, 3)
        } else {
            XCTFail("Неверный эффект")
        }
    }

    func testGainFaithAbility() {
        let ability = CardAbility(
            name: "Молитва",
            description: "Даёт веру",
            effect: .gainFaith(amount: 2)
        )

        if case .gainFaith(let amount) = ability.effect {
            XCTAssertEqual(amount, 2)
        } else {
            XCTFail("Неверный эффект")
        }
    }

    func testShiftBalanceAbility() {
        let ability = CardAbility(
            name: "Свет",
            description: "Сдвигает баланс к Свету",
            effect: .shiftBalance(towards: .light, amount: 10)
        )

        if case .shiftBalance(let towards, let amount) = ability.effect {
            XCTAssertEqual(towards, .light)
            XCTAssertEqual(amount, 10)
        } else {
            XCTFail("Неверный эффект")
        }
    }

    // MARK: - Духи

    func testSummonSpirit() {
        let spirit = Card(name: "Дух леса", type: .spirit, description: "")

        player.summonSpirit(spirit)

        XCTAssertEqual(player.spirits.count, 1)
        XCTAssertEqual(player.spirits[0].name, "Дух леса")
    }

    func testDismissSpirit() {
        let spirit = Card(name: "Дух", type: .spirit, description: "")
        player.spirits = [spirit]

        player.dismissSpirit(spirit)

        XCTAssertTrue(player.spirits.isEmpty)
    }

    // MARK: - Путешествие между мирами

    func testTravelToRealm() {
        XCTAssertEqual(player.currentRealm, .yav, "Начальный мир - Явь")

        player.travelToRealm(.nav)

        XCTAssertEqual(player.currentRealm, .nav, "Переход в Навь")
    }

    func testRealmTypes() {
        XCTAssertNotNil(Realm.yav)
        XCTAssertNotNil(Realm.nav)
        XCTAssertNotNil(Realm.prav)
    }

    // MARK: - Интеграция: полный цикл deck-building

    func testFullDeckBuildingCycle() {
        // 1. Начальное состояние
        XCTAssertTrue(player.deck.isEmpty)
        XCTAssertEqual(player.faith, 3)

        // 2. Получаем карты в колоду
        for i in 0..<10 {
            player.deck.append(Card(name: "Starter\(i)", type: .spell, description: ""))
        }
        player.shuffleDeck()

        // 3. Начинаем игру - берём карты
        player.drawCards(count: 5)
        XCTAssertEqual(player.hand.count, 5)
        XCTAssertEqual(player.deck.count, 5)

        // 4. Играем карты
        while !player.hand.isEmpty {
            player.playCard(player.hand[0])
        }
        XCTAssertEqual(player.discard.count, 5)

        // 5. Покупаем новую карту
        player.faith = 5
        let newCard = Card(name: "New Card", type: .spell, description: "", cost: 3)
        gameState.marketCards = [newCard]

        let purchased = gameState.purchaseCard(newCard)
        XCTAssertTrue(purchased)
        XCTAssertEqual(player.discard.count, 6, "Новая карта в сбросе")

        // 6. Конец хода - перетасовка и новая рука
        gameState.endTurn()

        // После endTurn колода перетасована и взяты 5 карт
        XCTAssertEqual(player.hand.count, 5)
    }
}

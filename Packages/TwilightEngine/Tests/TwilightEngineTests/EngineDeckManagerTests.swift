/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/EngineDeckManagerTests.swift
/// Назначение: Содержит реализацию файла EngineDeckManagerTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import Testing
@testable import TwilightEngine

@Suite("EngineDeckManager Tests", .serialized)
struct EngineDeckManagerTests {

    private func makeEngine() -> TwilightGameEngine {
        TestEngineFactory.makeEngine(seed: 42)
    }

    private func makeCards(_ count: Int) -> [Card] {
        (0..<count).map { i in
            Card(id: "card_\(i)", name: "Card \(i)", type: .spell, description: "Test card \(i)")
        }
    }

    @Test("Setup starting deck shuffles cards")
    func testSetupStartingDeck() {
        let engine = makeEngine()
        let cards = makeCards(10)
        engine.deck.setupStartingDeck(cards)

        #expect(engine.deck.playerDeck.count == 10)
        #expect(engine.deck.playerHand.isEmpty)
        #expect(engine.deck.playerDiscard.isEmpty)
    }

    @Test("Draw cards moves from deck to hand")
    func testDrawCards() {
        let engine = makeEngine()
        engine.deck.setupStartingDeck(makeCards(10))
        engine.deck.drawCards(count: 3)

        #expect(engine.deck.playerHand.count == 3)
        #expect(engine.deck.playerDeck.count == 7)
    }

    @Test("Draw cards recycles discard when deck is empty")
    func testDrawCardsRecyclesDiscard() {
        let engine = makeEngine()
        let cards = makeCards(3)
        engine.deck.setDiscard(cards)

        #expect(engine.deck.playerDeck.isEmpty)
        engine.deck.drawCards(count: 2)

        #expect(engine.deck.playerHand.count == 2)
        #expect(engine.deck.playerDeck.count == 1)
        #expect(engine.deck.playerDiscard.isEmpty)
    }

    @Test("Draw cards stops when both deck and discard empty")
    func testDrawCardsStopsWhenEmpty() {
        let engine = makeEngine()
        engine.deck.drawCards(count: 5)

        #expect(engine.deck.playerHand.isEmpty)
    }

    @Test("Mulligan returns cards and redraws")
    func testMulligan() {
        let engine = makeEngine()
        let cards = makeCards(10)
        engine.deck.setupStartingDeck(cards)
        engine.deck.drawCards(count: 5)

        let handBefore = engine.deck.playerHand
        let mulliganIds = [handBefore[0].id, handBefore[1].id]
        engine.deck.performMulligan(cardIds: mulliganIds)

        #expect(engine.deck.playerHand.count == 5)
    }

    @Test("Initialize combat merges all piles and draws 5")
    func testInitializeCombat() {
        let engine = makeEngine()
        engine.deck.setDeck(makeCards(3))
        engine.deck.setHand([Card(id: "h1", name: "H1", type: .spell, description: "x")])
        engine.deck.setDiscard([Card(id: "d1", name: "D1", type: .spell, description: "x")])

        engine.deck.initializeCombat()

        #expect(engine.deck.playerHand.count == 5)
        #expect(engine.deck.playerDiscard.isEmpty)
        // total cards = 3 + 1 + 1 = 5, all drawn
        #expect(engine.deck.playerDeck.isEmpty)
    }

    @Test("Add to deck appends card")
    func testAddToDeck() {
        let engine = makeEngine()
        let card = Card(id: "loot", name: "Loot", type: .spell, description: "x")
        engine.deck.addToDeck(card)

        #expect(engine.deck.playerDeck.count == 1)
        #expect(engine.deck.playerDeck.first?.id == "loot")
    }

    @Test("Reset state clears all piles")
    func testResetState() {
        let engine = makeEngine()
        engine.deck.setupStartingDeck(makeCards(5))
        engine.deck.drawCards(count: 2)
        engine.deck.resetState()

        #expect(engine.deck.playerDeck.isEmpty)
        #expect(engine.deck.playerHand.isEmpty)
        #expect(engine.deck.playerDiscard.isEmpty)
    }

}

/// Файл: Packages/EchoEngine/Tests/EchoEngineTests/DeckSystemTests.swift
/// Назначение: Содержит реализацию файла DeckSystemTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import Testing
import FirebladeECS
import TwilightEngine
@testable import EchoEngine

@Suite("DeckSystem Tests")
struct DeckSystemTests {

    private func makeCards(_ count: Int) -> [Card] {
        (0..<count).map { i in
            Card(id: "card_\(i)", name: "Card \(i)", type: .spell, description: "Test card \(i)")
        }
    }

    private func makeNexusWithPlayer(deckCards: [Card], rng: WorldRNG) -> (Nexus, Entity) {
        let nexus = Nexus()
        let player = nexus.createEntity()
        player.assign(PlayerTagComponent(name: "Test", strength: 5))
        player.assign(DeckComponent(drawPile: deckCards))
        return (nexus, player)
    }

    @Test("Draw cards moves from drawPile to hand")
    func testDrawCards() {
        let rng = WorldRNG(seed: 42)
        let cards = makeCards(10)
        let (nexus, player) = makeNexusWithPlayer(deckCards: cards, rng: rng)
        let system = DeckSystem(rng: rng)

        system.drawCards(count: 3, for: player, nexus: nexus)

        let deck: DeckComponent = nexus.get(unsafe: player.identifier)
        #expect(deck.hand.count == 3)
        #expect(deck.drawPile.count == 7)
    }

    @Test("Draw cards recycles discard when deck is empty")
    func testDrawRecyclesDiscard() {
        let rng = WorldRNG(seed: 42)
        let nexus = Nexus()
        let player = nexus.createEntity()
        player.assign(PlayerTagComponent(name: "Test", strength: 5))
        player.assign(DeckComponent(discardPile: makeCards(3)))

        let system = DeckSystem(rng: rng)
        system.drawCards(count: 2, for: player, nexus: nexus)

        let deck: DeckComponent = nexus.get(unsafe: player.identifier)
        #expect(deck.hand.count == 2)
        #expect(deck.drawPile.count == 1)
        #expect(deck.discardPile.isEmpty)
    }

    @Test("Draw cards stops when both empty")
    func testDrawStopsWhenEmpty() {
        let rng = WorldRNG(seed: 42)
        let (nexus, player) = makeNexusWithPlayer(deckCards: [], rng: rng)
        let system = DeckSystem(rng: rng)

        system.drawCards(count: 5, for: player, nexus: nexus)

        let deck: DeckComponent = nexus.get(unsafe: player.identifier)
        #expect(deck.hand.isEmpty)
    }

    @Test("Mulligan returns cards and redraws")
    func testMulligan() {
        let rng = WorldRNG(seed: 42)
        let cards = makeCards(10)
        let (nexus, player) = makeNexusWithPlayer(deckCards: cards, rng: rng)
        let system = DeckSystem(rng: rng)

        system.drawCards(count: 5, for: player, nexus: nexus)

        let deck: DeckComponent = nexus.get(unsafe: player.identifier)
        let mulliganIds = [deck.hand[0].id, deck.hand[1].id]

        system.mulligan(cardIds: mulliganIds, for: player, nexus: nexus)

        #expect(deck.hand.count == 5)
    }

    @Test("Initialize combat hand merges all piles and draws 5")
    func testInitializeCombatHand() {
        let rng = WorldRNG(seed: 42)
        let nexus = Nexus()
        let player = nexus.createEntity()
        player.assign(PlayerTagComponent(name: "Test", strength: 5))
        player.assign(DeckComponent(
            drawPile: makeCards(3),
            hand: [Card(id: "h1", name: "H1", type: .spell, description: "x")],
            discardPile: [Card(id: "d1", name: "D1", type: .spell, description: "x")]
        ))

        let system = DeckSystem(rng: rng)
        system.initializeCombatHand(for: player, nexus: nexus)

        let deck: DeckComponent = nexus.get(unsafe: player.identifier)
        #expect(deck.hand.count == 5)
        #expect(deck.discardPile.isEmpty)
        #expect(deck.drawPile.isEmpty) // total 5 cards, all drawn
    }

    @Test("Discard card moves from hand to discardPile")
    func testDiscardCard() {
        let rng = WorldRNG(seed: 42)
        let cards = makeCards(5)
        let (nexus, player) = makeNexusWithPlayer(deckCards: cards, rng: rng)
        let system = DeckSystem(rng: rng)

        system.drawCards(count: 3, for: player, nexus: nexus)
        let deck: DeckComponent = nexus.get(unsafe: player.identifier)
        let cardToDiscard = deck.hand[0].id

        system.discardCard(id: cardToDiscard, for: player, nexus: nexus)

        #expect(deck.hand.count == 2)
        #expect(deck.discardPile.count == 1)
        #expect(deck.discardPile[0].id == cardToDiscard)
    }

    @Test("Draw is deterministic with same seed")
    func testDeterministic() {
        let cards = makeCards(10)

        let rng1 = WorldRNG(seed: 123)
        let nexus1 = Nexus()
        let p1 = nexus1.createEntity()
        p1.assign(DeckComponent(drawPile: cards))
        let sys1 = DeckSystem(rng: rng1)
        sys1.initializeCombatHand(for: p1, nexus: nexus1)
        let d1: DeckComponent = nexus1.get(unsafe: p1.identifier)
        let hand1 = d1.hand.map(\.id)

        let rng2 = WorldRNG(seed: 123)
        let nexus2 = Nexus()
        let p2 = nexus2.createEntity()
        p2.assign(DeckComponent(drawPile: cards))
        let sys2 = DeckSystem(rng: rng2)
        sys2.initializeCombatHand(for: p2, nexus: nexus2)
        let d2: DeckComponent = nexus2.get(unsafe: p2.identifier)
        let hand2 = d2.hand.map(\.id)

        #expect(hand1 == hand2)
    }
}

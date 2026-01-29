import XCTest
@testable import TwilightEngine

/// Tests for FateDeckManager — fate card draw/discard/reshuffle mechanics
final class FateDeckManagerTests: XCTestCase {

    // MARK: - Helpers

    private func makeTestCards() -> [FateCard] {
        [
            FateCard(id: "fate_plus1", modifier: 1, name: "+1"),
            FateCard(id: "fate_zero", modifier: 0, name: "0"),
            FateCard(id: "fate_minus1", modifier: -1, name: "-1"),
            FateCard(id: "fate_crit", modifier: 2, isCritical: true, name: "Crit"),
        ]
    }

    private func makeRNG(seed: UInt64 = 42) -> WorldRNG {
        WorldRNG(seed: seed)
    }

    // MARK: - Basic Draw

    func testDrawReturnsCard() {
        let rng = makeRNG()
        let deck = FateDeckManager(cards: makeTestCards(), rng: rng)

        let card = deck.draw()
        XCTAssertNotNil(card)
        XCTAssertEqual(deck.drawPile.count, 3)
        XCTAssertEqual(deck.discardPile.count, 1)
    }

    func testDrawAllCards() {
        let rng = makeRNG()
        let cards = makeTestCards()
        let deck = FateDeckManager(cards: cards, rng: rng)

        var drawn: [FateCard] = []
        for _ in 0..<4 {
            if let card = deck.draw() {
                drawn.append(card)
            }
        }
        XCTAssertEqual(drawn.count, 4)
        XCTAssertEqual(deck.drawPile.count, 0)
        XCTAssertEqual(deck.discardPile.count, 4)
    }

    // MARK: - Depletion & Reshuffle

    func testDeckDepletionReshuffles() {
        let rng = makeRNG()
        let deck = FateDeckManager(cards: makeTestCards(), rng: rng)

        // Draw all 4
        for _ in 0..<4 { _ = deck.draw() }
        XCTAssertEqual(deck.drawPile.count, 0)

        // Next draw triggers reshuffle
        let card = deck.draw()
        XCTAssertNotNil(card)
        // After reshuffle + draw: 3 in draw, 1 in discard
        XCTAssertEqual(deck.drawPile.count, 3)
        XCTAssertEqual(deck.discardPile.count, 1)
    }

    func testDrawFromEmptyDeckReturnsNil() {
        let rng = makeRNG()
        let deck = FateDeckManager(cards: [], rng: rng)
        XCTAssertNil(deck.draw())
    }

    // MARK: - Sticky Cards

    func testStickyCardsReturn() {
        let rng = makeRNG()
        let cards = [
            FateCard(id: "curse", modifier: -1, isSticky: true, name: "Curse"),
            FateCard(id: "normal", modifier: 0, name: "Normal"),
        ]
        let deck = FateDeckManager(cards: cards, rng: rng)

        // Draw both
        _ = deck.draw()
        _ = deck.draw()
        XCTAssertEqual(deck.discardPile.count, 2)

        // Reshuffle — sticky cards stay in deck
        deck.reshuffle()
        XCTAssertEqual(deck.drawPile.count, 2)
        XCTAssertTrue(deck.drawPile.contains(where: { $0.id == "curse" }))
    }

    // MARK: - Remove Card

    func testRemoveCard() {
        let rng = makeRNG()
        let deck = FateDeckManager(cards: makeTestCards(), rng: rng)
        let totalBefore = deck.drawPile.count + deck.discardPile.count

        let removed = deck.removeCard(id: "fate_crit")
        XCTAssertTrue(removed)

        let totalAfter = deck.drawPile.count + deck.discardPile.count
        XCTAssertEqual(totalAfter, totalBefore - 1)
    }

    func testRemoveNonexistentCard() {
        let rng = makeRNG()
        let deck = FateDeckManager(cards: makeTestCards(), rng: rng)
        XCTAssertFalse(deck.removeCard(id: "nonexistent"))
    }

    func testRemoveCardFromDiscard() {
        let rng = makeRNG()
        let deck = FateDeckManager(cards: makeTestCards(), rng: rng)

        // Draw a card so it goes to discard
        let drawn = deck.draw()!
        let removed = deck.removeCard(id: drawn.id)
        XCTAssertTrue(removed)
        XCTAssertFalse(deck.discardPile.contains(where: { $0.id == drawn.id }))
    }

    // MARK: - Deterministic Shuffle

    func testDeterministicShuffle() {
        let cards = makeTestCards()

        // Same seed → same order
        let rng1 = makeRNG(seed: 123)
        let deck1 = FateDeckManager(cards: cards, rng: rng1)
        let order1 = deck1.drawPile.map(\.id)

        let rng2 = makeRNG(seed: 123)
        let deck2 = FateDeckManager(cards: cards, rng: rng2)
        let order2 = deck2.drawPile.map(\.id)

        XCTAssertEqual(order1, order2)
    }

    // MARK: - Save/Restore

    func testSaveRestore() {
        let rng = makeRNG()
        let deck = FateDeckManager(cards: makeTestCards(), rng: rng)

        // Draw 2 cards
        _ = deck.draw()
        _ = deck.draw()

        let state = deck.getState()
        XCTAssertEqual(state.drawPile.count, 2)
        XCTAssertEqual(state.discardPile.count, 2)

        // Create new deck and restore
        let rng2 = makeRNG()
        let deck2 = FateDeckManager(cards: [], rng: rng2)
        deck2.restoreState(state)

        XCTAssertEqual(deck2.drawPile.map(\.id), deck.drawPile.map(\.id))
        XCTAssertEqual(deck2.discardPile.map(\.id), deck.discardPile.map(\.id))
    }

    // MARK: - Add Card

    func testAddCard() {
        let rng = makeRNG()
        let deck = FateDeckManager(cards: makeTestCards(), rng: rng)
        let countBefore = deck.drawPile.count

        let blessing = FateCard(id: "blessing", modifier: 2, name: "Blessing")
        deck.addCard(blessing)

        XCTAssertEqual(deck.drawPile.count, countBefore + 1)
        XCTAssertTrue(deck.drawPile.contains(where: { $0.id == "blessing" }))
    }

    // MARK: - Draw and Resolve (Resonance-Aware)

    func testDrawAndResolveBasicValue() {
        let rng = makeRNG()
        let cards = [FateCard(id: "f1", modifier: 2, name: "Fortune", suit: .prav)]
        let deck = FateDeckManager(cards: cards, rng: rng)

        let result = deck.drawAndResolve(worldResonance: 0.0)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.effectiveValue, 2, "No matching rule → effectiveValue == baseValue")
        XCTAssertNil(result!.appliedRule)
    }

    func testDrawAndResolveAppliesResonanceRule() {
        let rng = makeRNG()
        let rule = FateResonanceRule(zone: .deepPrav, modifyValue: 3)
        let cards = [FateCard(id: "f1", modifier: 1, name: "Fortune", suit: .prav, resonanceRules: [rule])]
        let deck = FateDeckManager(cards: cards, rng: rng)

        // deepPrav zone: resonance 70
        let result = deck.drawAndResolve(worldResonance: 70.0)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.effectiveValue, 4, "baseValue(1) + rule(3) = 4")
        XCTAssertEqual(result!.appliedRule, rule)
    }

    func testDrawAndResolveNoMatchingRule() {
        let rng = makeRNG()
        let rule = FateResonanceRule(zone: .deepNav, modifyValue: -2)
        let cards = [FateCard(id: "f1", modifier: 1, name: "Fortune", suit: .prav, resonanceRules: [rule])]
        let deck = FateDeckManager(cards: cards, rng: rng)

        // yav zone: resonance 0 — rule doesn't match
        let result = deck.drawAndResolve(worldResonance: 0.0)
        XCTAssertEqual(result!.effectiveValue, 1, "No matching rule → baseValue only")
        XCTAssertNil(result!.appliedRule)
    }

    func testDrawAndResolveReturnsDrawEffects() {
        let rng = makeRNG()
        let effects = [FateDrawEffect(type: .shiftResonance, value: -5), FateDrawEffect(type: .shiftTension, value: 3)]
        let cards = [FateCard(id: "curse", modifier: -2, isSticky: true, name: "Curse", suit: .nav, onDrawEffects: effects)]
        let deck = FateDeckManager(cards: cards, rng: rng)

        let result = deck.drawAndResolve(worldResonance: 0.0)
        XCTAssertEqual(result!.drawEffects.count, 2)
        XCTAssertEqual(result!.drawEffects[0].type, .shiftResonance)
        XCTAssertEqual(result!.drawEffects[0].value, -5)
        XCTAssertEqual(result!.drawEffects[1].type, .shiftTension)
        XCTAssertEqual(result!.drawEffects[1].value, 3)
    }

    func testDrawAndResolveEmptyDeckReturnsNil() {
        let rng = makeRNG()
        let deck = FateDeckManager(cards: [], rng: rng)
        XCTAssertNil(deck.drawAndResolve(worldResonance: 0.0))
    }

    // MARK: - FateCard Suit

    func testFateCardSuit() {
        let navCard = FateCard(id: "n", modifier: -1, name: "Nav", suit: .nav)
        let pravCard = FateCard(id: "p", modifier: 1, name: "Prav", suit: .prav)
        let neutralCard = FateCard(id: "y", modifier: 0, name: "Neutral")

        XCTAssertEqual(navCard.suit, .nav)
        XCTAssertEqual(pravCard.suit, .prav)
        XCTAssertNil(neutralCard.suit)
    }
}

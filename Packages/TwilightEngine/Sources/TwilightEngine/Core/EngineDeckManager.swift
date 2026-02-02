import Foundation

/// Manages player deck, hand, and discard pile.
/// Views access deck state via `engine.deck.X`.
public final class EngineDeckManager {

    // MARK: - Back-reference

    unowned let engine: TwilightGameEngine

    // MARK: - State

    /// Player's hand cards
    public private(set) var playerHand: [Card] = []

    // MARK: - Internal State

    /// Player draw deck
    private(set) var deck: [Card] = []

    /// Player discard pile
    private(set) var discard: [Card] = []

    /// Public read-only accessors
    public var playerDeck: [Card] { deck }
    public var playerDiscard: [Card] { discard }

    // MARK: - Init

    init(engine: TwilightGameEngine) {
        self.engine = engine
    }

    // MARK: - Setup

    /// Set starting deck and shuffle
    func setupStartingDeck(_ cards: [Card]) {
        deck = cards
        engine.services.rng.shuffle(&deck)
    }

    /// Reset all deck state
    func resetState() {
        playerHand = []
        deck = []
        discard = []
    }

    // MARK: - Card Operations

    /// Draw cards with deck recycling (discard → deck when empty)
    public func drawCards(count: Int) {
        var remaining = count
        while remaining > 0 {
            if deck.isEmpty && !discard.isEmpty {
                deck = discard
                discard.removeAll()
                engine.services.rng.shuffle(&deck)
            }
            if deck.isEmpty { break }
            playerHand.append(deck.removeFirst())
            remaining -= 1
        }
    }

    /// Mulligan: return specified cards from hand, shuffle them into deck, redraw same count
    func performMulligan(cardIds: [String]) {
        var cardsToReturn: [Card] = []
        for cardId in cardIds {
            if let index = playerHand.firstIndex(where: { $0.id == cardId }) {
                cardsToReturn.append(playerHand.remove(at: index))
            }
        }
        if !cardsToReturn.isEmpty {
            deck.append(contentsOf: cardsToReturn)
            engine.services.rng.shuffle(&deck)
            let drawCount = min(cardsToReturn.count, deck.count)
            let newCards = Array(deck.prefix(drawCount))
            deck.removeFirst(drawCount)
            playerHand.append(contentsOf: newCards)
        }
    }

    /// Initialize combat deck: merge all piles, shuffle, draw 5
    func initializeCombat() {
        deck.append(contentsOf: playerHand)
        deck.append(contentsOf: discard)
        playerHand.removeAll()
        discard.removeAll()
        engine.services.rng.shuffle(&deck)
        let drawCount = min(5, deck.count)
        playerHand = Array(deck.prefix(drawCount))
        deck.removeFirst(drawCount)
    }

    /// Add a card to the deck
    public func addToDeck(_ card: Card) {
        deck.append(card)
    }

    // MARK: - Save/Load Support

    func setDeck(_ cards: [Card]) { deck = cards }
    func setHand(_ cards: [Card]) { playerHand = cards }
    func setDiscard(_ cards: [Card]) { discard = cards }
}

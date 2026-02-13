/// Файл: Packages/EchoEngine/Sources/EchoEngine/Systems/DeckSystem.swift
/// Назначение: Содержит реализацию файла DeckSystem.swift.
/// Зона ответственности: Реализует боевой пакет EchoEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import FirebladeECS
import TwilightEngine

/// Manages player deck operations: draw, mulligan, combat initialization.
public struct DeckSystem: EchoSystem {
    public let rng: WorldRNG

    public init(rng: WorldRNG) {
        self.rng = rng
    }

    public func update(nexus: Nexus) {
        // No per-tick behavior; all operations are explicit.
    }

    /// Draw cards from drawPile into hand, recycling discard when empty.
    public func drawCards(count: Int, for entity: Entity, nexus: Nexus) {
        let deck: DeckComponent = nexus.get(unsafe: entity.identifier)
        var remaining = count
        while remaining > 0 {
            if deck.drawPile.isEmpty && !deck.discardPile.isEmpty {
                deck.drawPile = deck.discardPile
                deck.discardPile.removeAll()
                rng.shuffle(&deck.drawPile)
            }
            if deck.drawPile.isEmpty { break }
            deck.hand.append(deck.drawPile.removeFirst())
            remaining -= 1
        }
    }

    /// Mulligan: return specified cards from hand, shuffle into drawPile, redraw same count.
    public func mulligan(cardIds: [String], for entity: Entity, nexus: Nexus) {
        let deck: DeckComponent = nexus.get(unsafe: entity.identifier)
        var cardsToReturn: [Card] = []
        for cardId in cardIds {
            if let index = deck.hand.firstIndex(where: { $0.id == cardId }) {
                cardsToReturn.append(deck.hand.remove(at: index))
            }
        }
        if !cardsToReturn.isEmpty {
            deck.drawPile.append(contentsOf: cardsToReturn)
            rng.shuffle(&deck.drawPile)
            let drawCount = min(cardsToReturn.count, deck.drawPile.count)
            let newCards = Array(deck.drawPile.prefix(drawCount))
            deck.drawPile.removeFirst(drawCount)
            deck.hand.append(contentsOf: newCards)
        }
    }

    /// Initialize combat hand: merge all piles, shuffle, draw 5.
    public func initializeCombatHand(for entity: Entity, nexus: Nexus) {
        let deck: DeckComponent = nexus.get(unsafe: entity.identifier)
        deck.drawPile.append(contentsOf: deck.hand)
        deck.drawPile.append(contentsOf: deck.discardPile)
        deck.hand.removeAll()
        deck.discardPile.removeAll()
        deck.exhaustPile.removeAll()
        rng.shuffle(&deck.drawPile)
        let drawCount = min(5, deck.drawPile.count)
        deck.hand = Array(deck.drawPile.prefix(drawCount))
        deck.drawPile.removeFirst(drawCount)
    }

    /// Discard a card from hand by id.
    public func discardCard(id: String, for entity: Entity, nexus: Nexus) {
        let deck: DeckComponent = nexus.get(unsafe: entity.identifier)
        if let index = deck.hand.firstIndex(where: { $0.id == id }) {
            let card = deck.hand.remove(at: index)
            deck.discardPile.append(card)
        }
    }

    /// Exhaust a card from hand by id (removed for rest of combat).
    public func exhaustCard(id: String, for entity: Entity, nexus: Nexus) {
        let deck: DeckComponent = nexus.get(unsafe: entity.identifier)
        if let index = deck.hand.firstIndex(where: { $0.id == id }) {
            let card = deck.hand.remove(at: index)
            deck.exhaustPile.append(card)
        }
    }
}

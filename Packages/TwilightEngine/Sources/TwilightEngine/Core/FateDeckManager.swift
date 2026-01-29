import Foundation

// MARK: - Fate Draw Result

/// Result of drawing and resolving a Fate Card against world resonance
public struct FateDrawResult {
    /// The drawn card
    public let card: FateCard

    /// Effective modifier after resonance rules (baseValue + rule bonus)
    public let effectiveValue: Int

    /// Which rule was applied (nil if none matched)
    public let appliedRule: FateResonanceRule?

    /// Side effects to be applied by the engine
    public let drawEffects: [FateDrawEffect]

    /// Visual effect hint from matched resonance rule (nil if no rule matched)
    public let visualEffect: String?

    /// Whether this is a critical draw
    public var isCritical: Bool { card.isCritical }
}

// MARK: - Fate Deck State (Save/Load)

/// Serializable state of the Fate Deck
public struct FateDeckState: Codable, Equatable {
    public let drawPile: [FateCard]
    public let discardPile: [FateCard]

    public init(drawPile: [FateCard], discardPile: [FateCard]) {
        self.drawPile = drawPile
        self.discardPile = discardPile
    }
}

// MARK: - Fate Deck Manager

/// Manages a deck of Fate Cards for outcome modification.
/// Default deck is loaded from Campaign Pack; this class only manages draw/discard/reshuffle.
/// Uses WorldRNG for deterministic shuffling.
public final class FateDeckManager {

    /// Cards available to draw (top = index 0)
    public private(set) var drawPile: [FateCard]

    /// Discarded cards
    public private(set) var discardPile: [FateCard]

    /// RNG used for shuffling
    private let rng: WorldRNG

    // MARK: - Initialization

    /// Initialize with a set of cards and an RNG instance.
    /// Cards are shuffled into the draw pile immediately.
    public init(cards: [FateCard], rng: WorldRNG = .shared) {
        self.rng = rng
        self.drawPile = cards
        self.discardPile = []
        rng.shuffle(&drawPile)
    }

    // MARK: - Draw

    /// Draw the top card. If draw pile is empty, auto-reshuffles first.
    /// Returns nil only if both piles are completely empty.
    public func draw() -> FateCard? {
        if drawPile.isEmpty {
            reshuffle()
        }
        guard !drawPile.isEmpty else { return nil }
        let card = drawPile.removeFirst()
        discardPile.append(card)
        return card
    }

    /// Draw a card and resolve its effective value based on world resonance.
    /// Returns nil only if deck is completely empty.
    public func drawAndResolve(worldResonance: Float) -> FateDrawResult? {
        guard let card = draw() else { return nil }

        let currentZone = ResonanceEngine.zone(for: worldResonance)
        let matchingRule = card.resonanceRules.first { $0.zone == currentZone }

        let effectiveValue: Int
        if let rule = matchingRule {
            effectiveValue = card.baseValue + rule.modifyValue
        } else {
            effectiveValue = card.baseValue
        }

        return FateDrawResult(
            card: card,
            effectiveValue: effectiveValue,
            appliedRule: matchingRule,
            drawEffects: card.onDrawEffects,
            visualEffect: matchingRule?.visualEffect
        )
    }

    // MARK: - Reshuffle

    /// Move discard pile back to draw pile and shuffle.
    /// Sticky cards remain in the deck after reshuffle (they represent curses).
    public func reshuffle() {
        drawPile.append(contentsOf: discardPile)
        discardPile.removeAll()
        rng.shuffle(&drawPile)
    }

    // MARK: - Card Manipulation

    /// Add a card (blessing/curse) to the draw pile and reshuffle.
    public func addCard(_ card: FateCard) {
        drawPile.append(card)
        rng.shuffle(&drawPile)
    }

    /// Remove a card by ID from both piles (e.g., lifting a curse).
    /// Returns true if a card was found and removed.
    @discardableResult
    public func removeCard(id: String) -> Bool {
        if let idx = drawPile.firstIndex(where: { $0.id == id }) {
            drawPile.remove(at: idx)
            return true
        }
        if let idx = discardPile.firstIndex(where: { $0.id == id }) {
            discardPile.remove(at: idx)
            return true
        }
        return false
    }

    // MARK: - Save/Load

    /// Get current state for serialization
    public func getState() -> FateDeckState {
        FateDeckState(drawPile: drawPile, discardPile: discardPile)
    }

    /// Restore state from save (no reshuffle — preserves exact order)
    public func restoreState(_ state: FateDeckState) {
        drawPile = state.drawPile
        discardPile = state.discardPile
    }
}

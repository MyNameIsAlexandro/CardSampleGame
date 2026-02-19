/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Combat/FateDeck.swift
/// Назначение: Lightweight value-type fate deck for disposition combat.
/// Зона ответственности: Draw/reshuffle fate keywords deterministically via WorldRNG.
/// Контекст: Epic 18 — Fate Keywords for Disposition Combat Phase 3. Distinct from FateDeckManager (class-based, world engine).

import Foundation

// MARK: - DispositionFateDeck

/// Lightweight fate deck for disposition combat. Value-type, deterministic via RNG.
/// Standard distribution: 4x each keyword = 20 cards total.
public struct DispositionFateDeck: Equatable {

    /// Cards available to draw.
    public private(set) var drawPile: [FateKeyword]

    /// Cards already drawn.
    public private(set) var discardPile: [FateKeyword]

    /// Deterministic RNG (reference type, excluded from Equatable).
    public let rng: WorldRNG

    // MARK: - Init

    /// Initialize with standard keyword distribution and shuffle.
    public init(rng: WorldRNG) {
        drawPile = Array(repeating: FateKeyword.surge, count: 4)
            + Array(repeating: .focus, count: 4)
            + Array(repeating: .echo, count: 4)
            + Array(repeating: .shadow, count: 4)
            + Array(repeating: .ward, count: 4)
        discardPile = []
        self.rng = rng
        rng.shuffle(&drawPile)
    }

    // MARK: - Draw

    /// Draw a fate keyword. Auto-reshuffles when draw pile is empty.
    public mutating func draw() -> FateKeyword {
        if drawPile.isEmpty { reshuffle() }
        let card = drawPile.removeFirst()
        discardPile.append(card)
        return card
    }

    /// Reshuffle discard pile back into draw pile.
    public mutating func reshuffle() {
        drawPile.append(contentsOf: discardPile)
        discardPile.removeAll()
        rng.shuffle(&drawPile)
    }

    // MARK: - Queries

    /// Number of cards remaining in draw pile.
    public var remainingCount: Int { drawPile.count }

    /// Number of cards in discard pile.
    public var discardCount: Int { discardPile.count }

    // MARK: - Equatable (WorldRNG excluded — compared by pile contents)

    public static func == (lhs: DispositionFateDeck, rhs: DispositionFateDeck) -> Bool {
        return lhs.drawPile == rhs.drawPile
            && lhs.discardPile == rhs.discardPile
    }
}

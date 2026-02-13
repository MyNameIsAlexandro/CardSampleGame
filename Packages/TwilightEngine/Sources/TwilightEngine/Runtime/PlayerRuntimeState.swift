/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Runtime/PlayerRuntimeState.swift
/// Назначение: Содержит реализацию файла PlayerRuntimeState.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Player Runtime State
// Reference: Docs/ENGINE_ARCHITECTURE.md, Section 4.2
// Reference: Docs/MIGRATION_PLAN.md, Feature A2

/// Mutable runtime state of the player.
/// Tracks resources, deck, balance, curses, etc.
public struct PlayerRuntimeState: Codable, Equatable {
    // MARK: - Resources

    /// Player resources (health, faith, etc.)
    public var resources: [String: Int]

    // MARK: - Balance/Path

    /// Balance between Nav and Prav (-100 to +100)
    /// Negative = Nav (chaos), Positive = Prav (order)
    public var balance: Int

    // MARK: - Deck State

    /// Cards in draw pile (by card ID)
    public var drawPile: [String]

    /// Cards in hand
    public var hand: [String]

    /// Cards in discard pile
    public var discardPile: [String]

    /// Cards in exile (removed from game)
    public var exilePile: [String]

    // MARK: - Curses

    /// Active curse IDs
    public var activeCurses: Set<String>

    // MARK: - Player Flags

    /// Player-specific flags
    public var flags: [String: Bool]

    // MARK: - Initialization

    public init(
        resources: [String: Int] = [:],
        balance: Int = 0,
        drawPile: [String] = [],
        hand: [String] = [],
        discardPile: [String] = [],
        exilePile: [String] = [],
        activeCurses: Set<String> = [],
        flags: [String: Bool] = [:]
    ) {
        self.resources = resources
        self.balance = balance
        self.drawPile = drawPile
        self.hand = hand
        self.discardPile = discardPile
        self.exilePile = exilePile
        self.activeCurses = activeCurses
        self.flags = flags
    }

    // MARK: - Resource Operations

    /// Get resource value (0 if not set)
    public func getResource(_ resourceId: String) -> Int {
        return resources[resourceId] ?? 0
    }

    /// Set resource value
    public mutating func setResource(_ resourceId: String, value: Int) {
        resources[resourceId] = value
    }

    /// Modify resource by delta
    public mutating func modifyResource(_ resourceId: String, by delta: Int) {
        resources[resourceId] = (resources[resourceId] ?? 0) + delta
    }

    /// Check if player can afford a cost
    public func canAfford(_ costs: [String: Int]) -> Bool {
        for (resourceId, cost) in costs {
            if getResource(resourceId) < cost {
                return false
            }
        }
        return true
    }

    // MARK: - Balance Operations

    /// Shift balance (clamped to -100...100)
    public mutating func shiftBalance(by delta: Int) {
        balance = max(-100, min(100, balance + delta))
    }

    /// Check if balance is within range
    public func isBalanceInRange(_ range: ClosedRange<Int>) -> Bool {
        return range.contains(balance)
    }

    /// Balance alignment
    public var alignment: BalanceAlignment {
        if balance < -30 {
            return .nav
        } else if balance > 30 {
            return .prav
        } else {
            return .neutral
        }
    }

    // MARK: - Deck Operations

    /// Total cards in deck (all zones)
    public var totalCardCount: Int {
        return drawPile.count + hand.count + discardPile.count + exilePile.count
    }

    /// Add card to draw pile
    mutating func addCardToDrawPile(_ cardId: String) {
        drawPile.append(cardId)
    }

    /// Add card to discard pile
    mutating func addCardToDiscard(_ cardId: String) {
        discardPile.append(cardId)
    }

    /// Move card from hand to discard
    mutating func discardFromHand(_ cardId: String) -> Bool {
        if let index = hand.firstIndex(of: cardId) {
            hand.remove(at: index)
            discardPile.append(cardId)
            return true
        }
        return false
    }

    /// Exile a card (remove from game)
    mutating func exileCard(_ cardId: String, from zone: DeckZone) -> Bool {
        switch zone {
        case .draw:
            if let index = drawPile.firstIndex(of: cardId) {
                drawPile.remove(at: index)
                exilePile.append(cardId)
                return true
            }
        case .hand:
            if let index = hand.firstIndex(of: cardId) {
                hand.remove(at: index)
                exilePile.append(cardId)
                return true
            }
        case .discard:
            if let index = discardPile.firstIndex(of: cardId) {
                discardPile.remove(at: index)
                exilePile.append(cardId)
                return true
            }
        case .exile:
            return false // Already exiled
        }
        return false
    }

    /// Shuffle discard into draw pile
    /// Uses deterministic RNG for reproducibility
    mutating func shuffleDiscardIntoDraw(rng: WorldRNG) {
        drawPile.append(contentsOf: discardPile)
        discardPile.removeAll()
        rng.shuffle(&drawPile)
    }

    // MARK: - Curse Operations

    /// Add a curse
    public mutating func addCurse(_ curseId: String) {
        activeCurses.insert(curseId)
    }

    /// Remove a curse
    public mutating func removeCurse(_ curseId: String) {
        activeCurses.remove(curseId)
    }

    /// Check if player has a curse
    public func hasCurse(_ curseId: String) -> Bool {
        return activeCurses.contains(curseId)
    }
}

// MARK: - Supporting Types

/// Deck zones
public enum DeckZone: String, Codable, Hashable {
    case draw
    case hand
    case discard
    case exile
}

/// Balance alignment
public enum BalanceAlignment: String, Codable, Hashable {
    case nav      // Chaos side
    case neutral
    case prav     // Order side
}

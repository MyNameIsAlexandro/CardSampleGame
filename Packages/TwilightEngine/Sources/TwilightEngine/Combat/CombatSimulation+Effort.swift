/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Combat/CombatSimulation+Effort.swift
/// Назначение: Effort mechanic — burn/undo карт для усиления атаки.
/// Зона ответственности: Мутации hand/discardPile/effortBonus без затрат energy и без касания FateDeck.
/// Контекст: R1 Effort mechanic. Reference: RITUAL_COMBAT_TEST_MODEL.md §3.2

import Foundation

// MARK: - Effort Mechanics

extension CombatSimulation {

    /// Burn a card from hand for +1 effort bonus.
    ///
    /// Rules:
    /// - Cannot burn the selected card (INV-EFF-006)
    /// - Cannot exceed maxEffort (INV-EFF-007)
    /// - Card moves to discardPile, not exhaustPile (INV-EFF-001)
    /// - Does not spend energy (INV-EFF-002)
    /// - Does not affect Fate Deck (INV-EFF-003)
    ///
    /// - Parameter cardId: ID of the card to burn
    /// - Returns: `true` if burn succeeded, `false` if rejected
    @discardableResult
    public func burnForEffort(_ cardId: String) -> Bool {
        guard phase == .playerAction else { return false }
        guard !selectedCardIds.contains(cardId) else { return false }
        guard effortBonus < maxEffort else { return false }
        guard let index = hand.firstIndex(where: { $0.id == cardId }) else { return false }

        let card = hand.remove(at: index)
        discardPile.append(card)
        effortBonus += 1
        effortCardIds.append(cardId)
        return true
    }

    /// Undo a previous effort burn, returning the card to hand.
    ///
    /// - Parameter cardId: ID of the card to undo
    /// - Returns: `true` if undo succeeded, `false` if card was not burned
    @discardableResult
    public func undoBurnForEffort(_ cardId: String) -> Bool {
        guard let effortIndex = effortCardIds.firstIndex(of: cardId) else { return false }
        guard let discardIndex = discardPile.firstIndex(where: { $0.id == cardId }) else { return false }

        let card = discardPile.remove(at: discardIndex)
        hand.append(card)
        effortBonus -= 1
        effortCardIds.remove(at: effortIndex)
        return true
    }
}

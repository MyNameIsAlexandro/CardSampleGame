import Foundation
import TwilightEngine
import EchoEngine

// MARK: - EchoCombatResult → TwilightGameEngine Bridge

extension TwilightGameEngine {

    /// Apply EchoCombatResult back to engine state (HP, resonance, fate deck, faith, loot).
    /// Mirrors `applyEncounterResult(_:)` from EncounterBridge.
    func applyEchoCombatResult(_ result: EchoCombatResult) {
        // 1. HP delta
        if result.hpDelta != 0 {
            let newHP = max(0, player.health + result.hpDelta)
            player.setHealth(newHP)
        }

        // 2. Resonance
        if result.resonanceDelta != 0 {
            adjustResonance(by: Float(result.resonanceDelta))
        }

        // 3. Fate deck sync
        if let deckState = result.updatedFateDeckState {
            if let fd = fateDeck {
                fd.restoreState(deckState)
            } else {
                let cards = deckState.drawPile + deckState.discardPile
                if !cards.isEmpty {
                    setupFateDeck(cards: cards)
                    fateDeck?.restoreState(deckState)
                }
            }
        }

        // 4. Faith reward
        if result.faithDelta > 0 {
            player.applyFaithDelta(result.faithDelta)
        }

        // 5. Loot cards
        for cardId in result.lootCardIds {
            if let card = CardFactory.shared.getCard(id: cardId) {
                deck.addToDeck(card)
            }
        }

        // 6. End combat
        combat.endCombat()
    }
}

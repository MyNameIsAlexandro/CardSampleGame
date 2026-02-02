import Foundation
import TwilightEngine
import EchoEngine

// MARK: - Echo Combat Configuration

/// Configuration for launching an EchoEngine combat encounter.
struct EchoCombatConfig {
    let enemyDefinition: EnemyDefinition
    let playerName: String
    let playerHealth: Int
    let playerMaxHealth: Int
    let playerStrength: Int
    let playerDeck: [Card]
    let fateCards: [FateCard]
    let resonance: Float
    let seed: UInt64
}

// MARK: - EchoEncounterBridge

extension TwilightGameEngine {

    /// Build an EchoCombatConfig from current engine state for SpriteKit combat.
    func makeEchoCombatConfig() -> EchoCombatConfig? {
        guard let state = combat.combatState else { return nil }
        let enemy = state.enemy

        guard let enemyDef = ContentRegistry.shared.getEnemy(id: enemy.id) else {
            return nil
        }

        // Gather player cards
        let heroCards: [Card] = deck.playerDeck + deck.playerHand + deck.playerDiscard

        // Gather fate cards
        let fateCards: [FateCard]
        if let fd = fateDeck {
            let state = fd.getState()
            fateCards = state.drawPile + state.discardPile
        } else {
            fateCards = ContentRegistry.shared.allFateCards
        }

        return EchoCombatConfig(
            enemyDefinition: enemyDef,
            playerName: player.name,
            playerHealth: player.health,
            playerMaxHealth: player.maxHealth,
            playerStrength: player.strength,
            playerDeck: heroCards,
            fateCards: fateCards,
            resonance: resonanceValue,
            seed: WorldRNG.shared.nextSeed()
        )
    }

    /// Apply the result of an EchoEngine combat back to the game engine.
    func applyEchoCombatResult(_ result: EchoCombatResult) {
        // Apply resonance delta
        if result.resonanceDelta != 0 {
            adjustResonance(by: Float(result.resonanceDelta))
        }

        // Restore fate deck state
        if let fateDeckState = result.updatedFateDeckState {
            if let fd = fateDeck {
                fd.restoreState(fateDeckState)
            } else {
                let cards = fateDeckState.drawPile + fateDeckState.discardPile
                if !cards.isEmpty {
                    setupFateDeck(cards: cards)
                    fateDeck?.restoreState(fateDeckState)
                }
            }
        }

        // Apply faith reward
        if result.faithDelta > 0 {
            player.applyFaithDelta(result.faithDelta)
        }

        // Apply loot: add cards to player's deck
        for cardId in result.lootCardIds {
            if let card = CardFactory.shared.getCard(id: cardId) {
                deck.addToDeck(card)
            }
        }

        // Exit combat mode
        combat.endCombat()
    }
}

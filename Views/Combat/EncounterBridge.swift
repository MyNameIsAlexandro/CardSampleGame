import Foundation
import TwilightEngine

// MARK: - EncounterContext Factory

extension TwilightGameEngine {

    /// Build EncounterContext from current engine state for the active combat enemy
    func makeEncounterContext() -> EncounterContext? {
        guard let state = combatState else { return nil }
        let enemy = state.enemy

        let encounterHero = EncounterHero(
            id: heroId ?? "hero",
            hp: playerHealth,
            maxHp: playerMaxHealth,
            strength: playerStrength,
            armor: 0, // No equipment system yet; armor comes from cards in combat
            wisdom: playerWisdom,
            willDefense: 0
        )

        let enemyDef = ContentRegistry.shared.getEnemy(id: enemy.id)
        let encounterEnemy = EncounterEnemy(
            id: enemy.id,
            name: enemy.name,
            hp: state.enemyHealth,
            maxHp: state.enemyMaxHealth,
            wp: state.hasSpiritTrack ? state.enemyWill : nil,
            maxWp: state.hasSpiritTrack ? state.enemyMaxWill : nil,
            power: state.enemyPower,
            defense: state.enemyDefense,
            behaviorId: enemy.id, // behavior ID matches enemy ID
            lootCardIds: enemyDef?.lootCardIds ?? [],
            faithReward: enemyDef?.faithReward ?? 0
        )

        // Fate deck: use engine state, or load fresh from content registry if empty
        var fateDeckSnapshot = fateDeck?.getState() ?? FateDeckState(drawPile: [], discardPile: [])
        if fateDeckSnapshot.drawPile.isEmpty && fateDeckSnapshot.discardPile.isEmpty {
            let allFateCards = ContentRegistry.shared.getAllFateCards()
            if !allFateCards.isEmpty {
                fateDeckSnapshot = FateDeckState(drawPile: allFateCards, discardPile: [])
                // Also initialize the engine's fateDeck so it persists
                setupFateDeck(cards: allFateCards)
            }
        }

        // Resolve hero cards from player's current hand/deck/discard (full pool)
        let heroCards = playerHand + playerDeck + playerDiscard

        // Assign unique instance IDs to duplicate cards
        var idCounts: [String: Int] = [:]
        let uniqueHeroCards = heroCards.map { card -> Card in
            let count = (idCounts[card.id] ?? 0) + 1
            idCounts[card.id] = count
            if count > 1 {
                return card.withInstanceId("\(card.id)_\(count)")
            }
            return card
        }

        #if DEBUG
        print("[EncounterBridge] heroCards=\(heroCards.count) (hand=\(playerHand.count), deck=\(playerDeck.count), discard=\(playerDiscard.count))")
        print("[EncounterBridge] fateDeck drawPile=\(fateDeckSnapshot.drawPile.count), discardPile=\(fateDeckSnapshot.discardPile.count)")
        print("[EncounterBridge] heroFaith=\(playerFaith)")
        #endif

        return EncounterContext(
            hero: encounterHero,
            enemies: [encounterEnemy],
            fateDeckSnapshot: fateDeckSnapshot,
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: WorldRNG.shared.next(),
            worldResonance: resonanceValue,
            balanceConfig: ContentRegistry.shared.getBalanceConfig()?.combat,
            behaviors: buildBehaviorMap(),
            heroCards: uniqueHeroCards,
            heroFaith: playerFaith
        )
    }

    private func buildBehaviorMap() -> [String: BehaviorDefinition] {
        var map: [String: BehaviorDefinition] = [:]
        for behavior in ContentRegistry.shared.allBehaviors {
            map[behavior.id] = behavior
        }
        return map
    }

    /// Apply encounter result back to engine state
    func applyEncounterResult(_ result: EncounterResult) {
        // Apply HP delta
        let newHP = max(0, playerHealth + result.transaction.hpDelta)
        setPlayerHealth(newHP)

        // Apply resonance delta
        if result.transaction.resonanceDelta != 0 {
            adjustResonance(by: result.transaction.resonanceDelta)
        }

        // Restore fate deck state
        if let fd = fateDeck {
            fd.restoreState(result.updatedFateDeck)
        } else {
            // Initialize fateDeck if it was nil
            let cards = result.updatedFateDeck.drawPile + result.updatedFateDeck.discardPile
            if !cards.isEmpty {
                setupFateDeck(cards: cards)
                fateDeck?.restoreState(result.updatedFateDeck)
            }
        }

        // Apply faith reward
        if result.transaction.faithDelta > 0 {
            applyFaithDelta(result.transaction.faithDelta)
        }

        // Apply loot: add cards to player's deck
        for cardId in result.transaction.lootCardIds {
            if let card = CardFactory.shared.getCard(id: cardId) {
                addToDeck(card)
            }
        }

        // Apply world flags
        if !result.transaction.worldFlags.isEmpty {
            mergeWorldFlags(result.transaction.worldFlags)
        }

        // Exit combat mode so next battle can start fresh
        endCombat()
    }
}

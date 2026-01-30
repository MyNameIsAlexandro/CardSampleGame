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
            armor: 0, // TODO: derive from equipment
            wisdom: playerWisdom,
            willDefense: 0
        )

        let encounterEnemy = EncounterEnemy(
            id: enemy.id,
            name: enemy.name,
            hp: state.enemyHealth,
            maxHp: state.enemyMaxHealth,
            wp: state.hasSpiritTrack ? state.enemyWill : nil,
            maxWp: state.hasSpiritTrack ? state.enemyMaxWill : nil,
            power: state.enemyPower,
            defense: state.enemyDefense,
            behaviorId: enemy.id // behavior ID matches enemy ID
        )

        let fateDeckSnapshot = fateDeck?.getState() ?? FateDeckState(drawPile: [], discardPile: [])

        // Resolve hero cards from player's current hand/deck
        let heroCards = playerHand + playerDeck

        return EncounterContext(
            hero: encounterHero,
            enemies: [encounterEnemy],
            fateDeckSnapshot: fateDeckSnapshot,
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42, // TODO: use world RNG seed
            worldResonance: resonanceValue,
            balanceConfig: ContentRegistry.shared.getBalanceConfig()?.combat,
            behaviors: buildBehaviorMap(),
            heroCards: heroCards
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
        fateDeck?.restoreState(result.updatedFateDeck)

        // Apply world flags
        if !result.transaction.worldFlags.isEmpty {
            mergeWorldFlags(result.transaction.worldFlags)
        }

        // Exit combat mode so next battle can start fresh
        endCombat()
    }
}

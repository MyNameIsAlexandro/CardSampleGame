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

// MARK: - Card → EnemyDefinition Bridge

extension EnemyDefinition {
    /// Synthesize an EnemyDefinition from a legacy Card (monster type).
    /// Used when ContentRegistry doesn't have a matching EnemyDefinition.
    static func from(card: Card) -> EnemyDefinition {
        EnemyDefinition(
            id: card.id,
            name: .inline(LocalizedString(en: card.name, ru: card.name)),
            description: .inline(LocalizedString(en: card.description, ru: card.description)),
            health: card.health ?? 10,
            power: card.power ?? 5,
            defense: card.defense ?? 0,
            difficulty: 1,
            enemyType: .beast,
            rarity: card.rarity,
            will: card.will
        )
    }
}

// MARK: - EchoEncounterBridge

extension TwilightGameEngine {

    /// Build an EchoCombatConfig from a saved encounter state (for mid-combat resume).
    /// Restarts combat from the saved HP/deck state (turn-level resume not supported in SpriteKit).
    func makeEchoCombatConfig(from saved: EncounterSaveState) -> EchoCombatConfig? {
        guard let firstEnemy = saved.context.enemies.first else { return nil }

        let enemyDef = ContentRegistry.shared.getEnemy(id: firstEnemy.id)
            ?? EnemyDefinition(
                id: firstEnemy.id,
                name: .inline(LocalizedString(en: firstEnemy.name, ru: firstEnemy.name)),
                description: .inline(LocalizedString(en: "", ru: "")),
                health: firstEnemy.hp,
                power: firstEnemy.power,
                defense: firstEnemy.defense,
                will: firstEnemy.wp
            )

        let fateCards = saved.fateDeckState.drawPile + saved.fateDeckState.discardPile

        return EchoCombatConfig(
            enemyDefinition: enemyDef,
            playerName: player.name,
            playerHealth: saved.heroHP,
            playerMaxHealth: saved.context.hero.maxHp,
            playerStrength: saved.context.hero.strength,
            playerDeck: saved.context.heroCards,
            fateCards: fateCards,
            resonance: saved.context.worldResonance,
            seed: saved.rngState
        )
    }

    /// Build an EchoCombatConfig from current engine state for SpriteKit combat.
    /// Falls back to synthesizing EnemyDefinition from Card if not in ContentRegistry.
    func makeEchoCombatConfig() -> EchoCombatConfig? {
        guard let state = combat.combatState else { return nil }
        let enemy = state.enemy

        let enemyDef = ContentRegistry.shared.getEnemy(id: enemy.id)
            ?? EnemyDefinition.from(card: enemy)

        return makeEchoCombatConfigInternal(enemyDef: enemyDef)
    }

    /// Build an EchoCombatConfig directly from a Card (no combatState dependency).
    /// Used when combat routing needs config before engine combat state is fully set up.
    func makeEchoCombatConfig(for monsterCard: Card) -> EchoCombatConfig {
        let enemyDef = ContentRegistry.shared.getEnemy(id: monsterCard.id)
            ?? EnemyDefinition.from(card: monsterCard)

        return makeEchoCombatConfigInternal(enemyDef: enemyDef)
    }

    private func makeEchoCombatConfigInternal(enemyDef: EnemyDefinition) -> EchoCombatConfig {

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

}

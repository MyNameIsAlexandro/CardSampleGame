import FirebladeECS
import TwilightEngine

/// Builds a Nexus configured for a combat encounter.
public struct CombatNexusBuilder {

    /// Build a combat Nexus with player, enemy, and combat state entities.
    public static func build(
        enemyDefinition: EnemyDefinition,
        playerName: String,
        playerHealth: Int,
        playerMaxHealth: Int,
        playerStrength: Int,
        playerDeck: [Card],
        playerEnergy: Int = 3,
        fateDeck: FateDeckManager,
        resonance: Float,
        rng: WorldRNG
    ) -> Nexus {
        let nexus = Nexus()

        // Combat state entity (holds shared combat data)
        let combatEntity = nexus.createEntity()
        combatEntity.assign(CombatStateComponent())
        combatEntity.assign(ResonanceComponent(value: resonance))
        combatEntity.assign(FateDeckComponent(fateDeck: fateDeck))

        // Player entity
        let playerEntity = nexus.createEntity()
        playerEntity.assign(PlayerTagComponent(name: playerName, strength: playerStrength))
        playerEntity.assign(HealthComponent(current: playerHealth, max: playerMaxHealth))
        playerEntity.assign(DeckComponent(drawPile: rng.shuffled(playerDeck)))
        playerEntity.assign(EnergyComponent(current: playerEnergy, max: playerEnergy))
        playerEntity.assign(StatusEffectComponent())

        // Enemy entity
        let enemyEntity = nexus.createEntity()
        enemyEntity.assign(EnemyTagComponent(
            definitionId: enemyDefinition.id,
            power: enemyDefinition.power,
            defense: enemyDefinition.defense,
            pattern: enemyDefinition.pattern
        ))
        enemyEntity.assign(HealthComponent(
            current: enemyDefinition.health,
            max: enemyDefinition.health,
            will: enemyDefinition.will ?? 0,
            maxWill: enemyDefinition.will ?? 0
        ))
        enemyEntity.assign(IntentComponent())
        enemyEntity.assign(StatusEffectComponent())

        return nexus
    }
}

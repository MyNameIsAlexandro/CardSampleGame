/// Файл: Packages/EchoEngine/Sources/EchoEngine/CombatSimulation+Builders.swift
/// Назначение: Содержит реализацию файла CombatSimulation+Builders.swift.
/// Зона ответственности: Реализует боевой пакет EchoEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import FirebladeECS
import TwilightEngine

extension CombatSimulation {

    /// Create a CombatSimulation from an enemy definition and player stats.
    public static func create(
        enemyDefinition: EnemyDefinition,
        playerName: String = "Hero",
        playerHealth: Int = 10,
        playerMaxHealth: Int = 10,
        playerStrength: Int = 5,
        playerDeck: [Card] = [],
        playerEnergy: Int = 3,
        fateCards: [FateCard] = [],
        resonance: Float = 0,
        seed: UInt64 = 42
    ) -> CombatSimulation {
        let rng = WorldRNG(seed: seed)
        let fateDeck = FateDeckManager(cards: fateCards, rng: rng)
        let nexus = CombatNexusBuilder.build(
            enemyDefinition: enemyDefinition,
            playerName: playerName,
            playerHealth: playerHealth,
            playerMaxHealth: playerMaxHealth,
            playerStrength: playerStrength,
            playerDeck: playerDeck,
            playerEnergy: playerEnergy,
            fateDeck: fateDeck,
            resonance: resonance,
            rng: rng
        )
        return CombatSimulation(nexus: nexus, rng: rng)
    }
}


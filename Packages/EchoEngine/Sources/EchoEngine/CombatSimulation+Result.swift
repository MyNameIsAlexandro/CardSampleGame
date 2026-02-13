/// Файл: Packages/EchoEngine/Sources/EchoEngine/CombatSimulation+Result.swift
/// Назначение: Содержит реализацию файла CombatSimulation+Result.swift.
/// Зона ответственности: Реализует боевой пакет EchoEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import FirebladeECS
import TwilightEngine

extension CombatSimulation {

    /// Build a EchoCombatResult from the current combat state. Call after combat ends.
    public var combatResult: EchoCombatResult? {
        guard let outcome = outcome else { return nil }
        guard let enemy = enemyEntity else { return nil }
        let enemyTag: EnemyTagComponent = nexus.get(unsafe: enemy.identifier)

        let resonanceDelta: Int
        let faithDelta: Int
        switch outcome {
        case .victory(.killed):
            resonanceDelta = -5  // Nav shift
            faithDelta = enemyTag.faithReward
        case .victory(.pacified):
            resonanceDelta = 5   // Prav shift
            faithDelta = enemyTag.faithReward
        case .defeat:
            resonanceDelta = 0
            faithDelta = 0
        }

        var fateDeckState: FateDeckState?
        let combatFamily = nexus.family(requires: CombatStateComponent.self)
        for combatEntity in combatFamily.entities {
            if combatEntity.has(FateDeckComponent.self) {
                let fateDeckComp: FateDeckComponent = nexus.get(unsafe: combatEntity.identifier)
                fateDeckState = fateDeckComp.fateDeck.getState()
                break
            }
        }

        return EchoCombatResult(
            outcome: outcome,
            resonanceDelta: resonanceDelta,
            faithDelta: faithDelta,
            lootCardIds: enemyTag.lootCardIds,
            updatedFateDeckState: fateDeckState,
            hpDelta: playerHealth - playerMaxHealth,
            turnsPlayed: round,
            totalDamageDealt: statDamageDealt,
            totalDamageTaken: statDamageTaken,
            cardsPlayed: statCardsPlayed
        )
    }
}


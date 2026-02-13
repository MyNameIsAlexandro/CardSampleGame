/// Файл: Packages/EchoEngine/Sources/EchoEngine/Systems/AISystem.swift
/// Назначение: Содержит реализацию файла AISystem.swift.
/// Зона ответственности: Реализует боевой пакет EchoEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import FirebladeECS
import TwilightEngine

/// Generates enemy intents using EnemyIntentGenerator.
public struct AISystem: EchoSystem {
    public let rng: WorldRNG

    public init(rng: WorldRNG) {
        self.rng = rng
    }

    public func update(nexus: Nexus) {
        let enemies = nexus.family(requiresAll: EnemyTagComponent.self, HealthComponent.self, IntentComponent.self)
        // Find combat state for round number
        let combatFamily = nexus.family(requires: CombatStateComponent.self)
        var round = 1
        for state in combatFamily { round = state.round; break }

        for (tag, health, intent) in enemies {
            if intent.intent == nil && health.isAlive {
                if let pattern = tag.pattern, !pattern.isEmpty {
                    intent.intent = EnemyIntentGenerator.intentFromPattern(
                        pattern, round: round, enemyPower: tag.power
                    )
                } else {
                    intent.intent = EnemyIntentGenerator.generateIntent(
                        enemyPower: tag.power,
                        enemyHealth: health.current,
                        enemyMaxHealth: health.max,
                        turnNumber: round,
                        rng: rng
                    )
                }
            }
        }
    }

    /// Generate intent for a specific enemy entity.
    public func generateIntent(for entity: Entity, nexus: Nexus) {
        let tag: EnemyTagComponent = nexus.get(unsafe: entity.identifier)
        let health: HealthComponent = nexus.get(unsafe: entity.identifier)
        let intent: IntentComponent = nexus.get(unsafe: entity.identifier)
        let combatFamily = nexus.family(requires: CombatStateComponent.self)
        var round = 1
        for state in combatFamily { round = state.round; break }

        if let pattern = tag.pattern, !pattern.isEmpty {
            intent.intent = EnemyIntentGenerator.intentFromPattern(
                pattern, round: round, enemyPower: tag.power
            )
        } else {
            intent.intent = EnemyIntentGenerator.generateIntent(
                enemyPower: tag.power,
                enemyHealth: health.current,
                enemyMaxHealth: health.max,
                turnNumber: round,
                rng: rng
            )
        }
    }
}

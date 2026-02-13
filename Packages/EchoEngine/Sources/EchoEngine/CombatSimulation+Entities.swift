/// Файл: Packages/EchoEngine/Sources/EchoEngine/CombatSimulation+Entities.swift
/// Назначение: Содержит реализацию файла CombatSimulation+Entities.swift.
/// Зона ответственности: Реализует боевой пакет EchoEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import FirebladeECS
import TwilightEngine

extension CombatSimulation {

    public var playerEntity: Entity? {
        nexus.family(requires: PlayerTagComponent.self).firstEntity
    }

    public var enemyEntity: Entity? {
        nexus.family(requires: EnemyTagComponent.self).firstEntity
    }
}


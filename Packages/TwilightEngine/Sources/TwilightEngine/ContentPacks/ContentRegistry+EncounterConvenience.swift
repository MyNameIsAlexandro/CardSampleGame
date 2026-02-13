/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/ContentPacks/ContentRegistry+EncounterConvenience.swift
/// Назначение: Содержит реализацию файла ContentRegistry+EncounterConvenience.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

extension ContentRegistry {
    public var allFateCards: [FateCard] {
        getAllFateCards()
    }

    public var allEnemies: [EnemyDefinition] {
        getAllEnemies()
    }

    public var balancePack: BalancePackAccess {
        BalancePackAccess(config: getBalanceConfig())
    }

    public var allBehaviorIds: [String] {
        Array(mergedBehaviors.keys)
    }

    public var allBehaviors: [BehaviorDefinition] {
        Array(mergedBehaviors.values)
    }

    public func getBehavior(id: String) -> BehaviorDefinition? {
        mergedBehaviors[id]
    }
}

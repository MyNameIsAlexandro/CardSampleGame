/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Encounter/EncounterEnemyState.swift
/// Назначение: Содержит реализацию файла EncounterEnemyState.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// Mutable enemy state within an encounter
public struct EncounterEnemyState: Equatable, Codable {
    public let id: String
    public let name: String
    public var hp: Int
    public let maxHp: Int
    public var wp: Int?
    public let maxWp: Int?
    public var power: Int
    public var defense: Int
    public var spiritDefense: Int
    public var rageShield: Int
    public var outcome: EntityOutcome?
    public let resonanceBehavior: [String: EnemyModifier]?
    public let lootCardIds: [String]
    public let faithReward: Int
    public let weaknesses: [String]
    public let strengths: [String]
    public let abilities: [EnemyAbility]

    public var hasSpiritTrack: Bool { wp != nil }
    public var isAlive: Bool { hp > 0 }
    public var isPacified: Bool { (wp.map { $0 <= 0 } ?? false) && hp > 0 }

    public init(from enemy: EncounterEnemy) {
        self.id = enemy.id
        self.name = enemy.name
        self.hp = enemy.hp
        self.maxHp = enemy.maxHp
        self.wp = enemy.wp
        self.maxWp = enemy.maxWp
        self.power = enemy.power
        self.defense = enemy.defense
        self.spiritDefense = enemy.spiritDefense
        self.rageShield = 0
        self.outcome = nil
        self.resonanceBehavior = enemy.resonanceBehavior
        self.lootCardIds = enemy.lootCardIds
        self.faithReward = enemy.faithReward
        self.weaknesses = enemy.weaknesses
        self.strengths = enemy.strengths
        self.abilities = enemy.abilities
    }
}

/// Which track was last attacked (for escalation/de-escalation)
public enum AttackTrack: String, Codable, Equatable {
    case physical
    case spiritual
}

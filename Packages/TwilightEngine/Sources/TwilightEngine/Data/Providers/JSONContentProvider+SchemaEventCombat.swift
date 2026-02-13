/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Data/Providers/JSONContentProvider+SchemaEventCombat.swift
/// Назначение: Содержит реализацию файла JSONContentProvider+SchemaEventCombat.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// Данные боя, встроенные в JSON-событие.
struct JSONCombatData: Codable {
    public let enemyId: String?
    public let enemyName: String?
    public let enemyPower: Int?
    public let enemyDefense: Int?
    public let enemyHealth: Int?
    public let isBoss: Bool?
}

/// JSON-представление `mini_game_challenge` у события.
struct JSONMiniGameChallenge: Codable {
    public let enemyId: String?
    public let difficulty: Int?
    public let rewards: JSONChallengeConsequences?
    public let penalties: JSONChallengeConsequences?

    enum CodingKeys: String, CodingKey {
        case enemyId = "enemy_id"
        case difficulty, rewards, penalties
    }
}

/// JSON-формат rewards/penalties внутри `mini_game_challenge`.
struct JSONChallengeConsequences: Codable {
    public let resourceChanges: [String: Int]?
    public let setFlags: [String]?
    public let balanceShift: Int?

    enum CodingKeys: String, CodingKey {
        case resourceChanges = "resource_changes"
        case setFlags = "set_flags"
        case balanceShift = "balance_shift"
    }

    public func toConsequences() -> ChoiceConsequences {
        ChoiceConsequences(
            resourceChanges: resourceChanges ?? [:],
            setFlags: setFlags ?? [],
            clearFlags: [],
            balanceDelta: balanceShift ?? 0
        )
    }
}

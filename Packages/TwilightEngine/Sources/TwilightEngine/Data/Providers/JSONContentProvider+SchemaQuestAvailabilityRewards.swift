/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Data/Providers/JSONContentProvider+SchemaQuestAvailabilityRewards.swift
/// Назначение: Содержит реализацию файла JSONContentProvider+SchemaQuestAvailabilityRewards.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// Ограничения доступности квеста в JSON-схеме.
struct JSONQuestAvailability: Codable {
    public let requiredFlags: [String]?
    public let forbiddenFlags: [String]?
    public let minPressure: Int?
    public let maxPressure: Int?
    public let minBalance: Int?
    public let maxBalance: Int?
    public let regionStates: [String]?
    public let regionIds: [String]?

    enum CodingKeys: String, CodingKey {
        case requiredFlags = "required_flags"
        case forbiddenFlags = "forbidden_flags"
        case minPressure = "min_pressure"
        case maxPressure = "max_pressure"
        case minBalance = "min_balance"
        case maxBalance = "max_balance"
        case regionStates = "region_states"
        case regionIds = "region_ids"
    }

    public func toAvailability() -> Availability {
        Availability(
            requiredFlags: requiredFlags ?? [],
            forbiddenFlags: forbiddenFlags ?? [],
            minPressure: minPressure,
            maxPressure: maxPressure,
            minBalance: minBalance,
            maxBalance: maxBalance,
            regionStates: regionStates,
            regionIds: regionIds
        )
    }
}

/// Награды/штрафы завершения квеста в доменной модели `QuestCompletionRewards`.
struct JSONQuestCompletionRewards: Codable {
    public let resourceChanges: [String: Int]?
    public let setFlags: [String]?
    public let cardIds: [String]?
    public let balanceDelta: Int?

    enum CodingKeys: String, CodingKey {
        case resourceChanges = "resource_changes"
        case setFlags = "set_flags"
        case cardIds = "card_ids"
        case balanceDelta = "balance_delta"
    }

    public func toRewards() -> QuestCompletionRewards {
        QuestCompletionRewards(
            resourceChanges: resourceChanges ?? [:],
            setFlags: setFlags ?? [],
            cardIds: cardIds ?? [],
            balanceDelta: balanceDelta ?? 0
        )
    }
}

/// Legacy rewards-структура (используется при чтении старых JSON-форматов).
struct JSONQuestRewards: Codable {
    public let resourceChanges: [String: Int]?
    public let setFlags: [String: Bool]?
    public let balanceShift: Int?
    public let tensionChange: Int?
    public let reputationChange: Int?
    public let giveArtifact: String?
    public let unlockRegions: [String]?
    public let addCurse: String?
}

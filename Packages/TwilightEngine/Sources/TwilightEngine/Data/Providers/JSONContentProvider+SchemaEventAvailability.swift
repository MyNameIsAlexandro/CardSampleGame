/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Data/Providers/JSONContentProvider+SchemaEventAvailability.swift
/// Назначение: Содержит реализацию файла JSONContentProvider+SchemaEventAvailability.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// Ограничения доступности события в JSON-схеме.
struct JSONAvailability: Codable {
    public let regionStates: [String]?
    public let regionIds: [String]?
    public let minPressure: Int?
    public let maxPressure: Int?
    public let minBalance: Int?
    public let maxBalance: Int?
    public let requiredFlags: [String]?
    public let forbiddenFlags: [String]?

    enum CodingKeys: String, CodingKey {
        case regionStates = "region_states"
        case regionIds = "region_ids"
        case minPressure = "min_pressure"
        case maxPressure = "max_pressure"
        case minBalance = "min_balance"
        case maxBalance = "max_balance"
        case requiredFlags = "required_flags"
        case forbiddenFlags = "forbidden_flags"
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

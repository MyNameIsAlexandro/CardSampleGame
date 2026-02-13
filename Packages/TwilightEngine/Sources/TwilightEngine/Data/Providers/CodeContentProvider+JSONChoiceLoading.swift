/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Data/Providers/CodeContentProvider+JSONChoiceLoading.swift
/// Назначение: Содержит реализацию файла CodeContentProvider+JSONChoiceLoading.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// JSON-схема выбора события и её преобразование в доменные модели.
public struct JSONChoiceForLoading: Codable {
    public let id: String
    public let label: LocalizedString
    public let tooltip: LocalizedString?
    public let requirements: JSONChoiceRequirementsForLoading?
    public let consequences: JSONChoiceConsequencesForLoading?

    public func toDefinition() -> ChoiceDefinition {
        ChoiceDefinition(
            id: id,
            label: .inline(label),
            tooltip: tooltip.map { .inline($0) },
            requirements: requirements?.toRequirements(),
            consequences: consequences?.toConsequences() ?? .none
        )
    }
}

/// JSON-схема требований к выбору события.
public struct JSONChoiceRequirementsForLoading: Codable {
    public let minResources: [String: Int]?
    public let minFaith: Int?
    public let minHealth: Int?
    public let minBalance: Int?
    public let maxBalance: Int?
    public let requiredFlags: [String]?
    public let forbiddenFlags: [String]?

    enum CodingKeys: String, CodingKey {
        case minResources = "min_resources"
        case minFaith = "min_faith"
        case minHealth = "min_health"
        case minBalance = "min_balance"
        case maxBalance = "max_balance"
        case requiredFlags = "required_flags"
        case forbiddenFlags = "forbidden_flags"
    }

    public func toRequirements() -> ChoiceRequirements {
        var resources = minResources ?? [:]
        if let faith = minFaith { resources["faith"] = faith }
        if let health = minHealth { resources["health"] = health }
        return ChoiceRequirements(
            minResources: resources,
            requiredFlags: requiredFlags ?? [],
            forbiddenFlags: forbiddenFlags ?? [],
            minBalance: minBalance,
            maxBalance: maxBalance
        )
    }
}

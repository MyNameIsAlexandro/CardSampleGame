/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Data/Providers/JSONContentProvider+SchemaEventChoices.swift
/// Назначение: Содержит реализацию файла JSONContentProvider+SchemaEventChoices.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// JSON-представление выбора в событии.
struct JSONChoice: Codable {
    public let id: String
    public let label: LocalizedString
    public let tooltip: LocalizedString?
    public let requirements: JSONChoiceRequirements?
    public let consequences: JSONChoiceConsequences?

    public func toDefinition() -> ChoiceDefinition {
        let reqs = requirements?.toRequirements()
        let cons = consequences?.toConsequences() ?? .none

        return ChoiceDefinition(
            id: id,
            label: .inline(label),
            tooltip: tooltip.map { .inline($0) },
            requirements: reqs,
            consequences: cons
        )
    }
}

/// Ограничения выбора события.
struct JSONChoiceRequirements: Codable {
    public let minFaith: Int?
    public let minHealth: Int?
    public let minBalance: Int?
    public let maxBalance: Int?
    public let requiredFlags: [String]?
    public let forbiddenFlags: [String]?

    public func toRequirements() -> ChoiceRequirements {
        var minResources: [String: Int] = [:]
        if let faith = minFaith { minResources["faith"] = faith }
        if let health = minHealth { minResources["health"] = health }

        return ChoiceRequirements(
            minResources: minResources,
            requiredFlags: requiredFlags ?? [],
            forbiddenFlags: forbiddenFlags ?? [],
            minBalance: minBalance,
            maxBalance: maxBalance
        )
    }
}

/// Последствия выбора события.
struct JSONChoiceConsequences: Codable {
    public let resourceChanges: [String: Int]?
    public let setFlags: [String: Bool]?
    public let clearFlags: [String]?
    public let balanceShift: Int?
    public let tensionChange: Int?
    public let reputationChange: Int?
    public let anchorIntegrityChange: Int?
    public let addCards: [String]?
    public let addCurse: String?
    public let giveArtifact: String?
    public let startCombat: Bool?
    public let startQuest: String?
    public let messageKey: String?

    public func toConsequences() -> ChoiceConsequences {
        let resources = resourceChanges ?? [:]
        let flags = setFlags?.filter { $0.value }.map { $0.key } ?? []
        let clear = clearFlags ?? []

        return ChoiceConsequences(
            resourceChanges: resources,
            setFlags: flags,
            clearFlags: clear,
            balanceDelta: balanceShift ?? 0,
            resultKey: messageKey
        )
    }
}

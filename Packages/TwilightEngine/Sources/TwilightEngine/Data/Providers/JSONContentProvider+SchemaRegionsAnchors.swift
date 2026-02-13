/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Data/Providers/JSONContentProvider+SchemaRegionsAnchors.swift
/// Назначение: Содержит реализацию файла JSONContentProvider+SchemaRegionsAnchors.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// JSON-схема региона, загружаемого из контент-пака.
struct JSONRegion: Codable {
    public let id: String
    public let title: LocalizedString
    public let description: LocalizedString
    public let regionType: String?
    public let neighborIds: [String]
    public let initiallyDiscovered: Bool?
    public let anchorId: String?
    public let eventPoolIds: [String]?
    public let initialState: String?
    public let degradationWeight: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, description, neighborIds, initiallyDiscovered, anchorId
        case eventPoolIds, initialState, degradationWeight
        case regionType = "region_type"
    }

    public func toDefinition() -> RegionDefinition {
        let state: RegionStateType
        switch initialState?.lowercased() {
        case "stable": state = .stable
        case "borderland": state = .borderland
        case "breach": state = .breach
        default: state = .stable
        }

        return RegionDefinition(
            id: id,
            title: .inline(title),
            description: .inline(description),
            regionType: regionType ?? "unknown",
            neighborIds: neighborIds,
            initiallyDiscovered: initiallyDiscovered ?? false,
            anchorId: anchorId,
            eventPoolIds: eventPoolIds ?? [],
            initialState: state,
            degradationWeight: degradationWeight ?? 1
        )
    }
}

/// JSON-схема якоря региона.
struct JSONAnchor: Codable {
    public let id: String
    public let title: LocalizedString
    public let description: LocalizedString
    public let regionId: String
    public let anchorType: String?
    public let initialInfluence: String?
    public let power: Int?
    public let initialIntegrity: Int?

    public func toDefinition() -> AnchorDefinition {
        let influence: AnchorInfluence
        switch initialInfluence?.lowercased() {
        case "light": influence = .light
        case "dark": influence = .dark
        default: influence = .neutral
        }

        return AnchorDefinition(
            id: id,
            title: .inline(title),
            description: .inline(description),
            regionId: regionId,
            anchorType: anchorType ?? "shrine",
            initialInfluence: influence,
            power: power ?? 5,
            initialIntegrity: initialIntegrity ?? 100
        )
    }
}

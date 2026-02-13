/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/MarketState.swift
/// Назначение: Содержит реализацию файла MarketState.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// Persisted market state for deterministic save/load.
/// Stores non-localized card definition IDs; UI resolves via ContentRegistry/CardFactory.
public struct MarketSaveState: Codable, Equatable, Sendable {
    public var global: GlobalMarketState?
    public var regions: [String: RegionalMarketState]

    public init(global: GlobalMarketState? = nil, regions: [String: RegionalMarketState] = [:]) {
        self.global = global
        self.regions = regions
    }

    public var isEmpty: Bool {
        global == nil && regions.isEmpty
    }
}

public struct GlobalMarketState: Codable, Equatable, Sendable {
    public let day: Int
    public var cardIds: [String]

    public init(day: Int, cardIds: [String]) {
        self.day = day
        self.cardIds = cardIds
    }
}

public struct RegionalMarketState: Codable, Equatable, Sendable {
    public let day: Int
    public var cardIds: [String]
    public var storyCardId: String?

    public init(day: Int, cardIds: [String], storyCardId: String? = nil) {
        self.day = day
        self.cardIds = cardIds
        self.storyCardId = storyCardId
    }
}


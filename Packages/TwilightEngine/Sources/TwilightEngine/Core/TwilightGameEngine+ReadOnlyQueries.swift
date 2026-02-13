/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/TwilightGameEngine+ReadOnlyQueries.swift
/// Назначение: Содержит реализацию файла TwilightGameEngine+ReadOnlyQueries.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

extension TwilightGameEngine {
    /// Get regions as sorted array for UI iteration.
    public var regionsArray: [EngineRegionState] {
        publishedRegions.values.sorted { $0.name < $1.name }
    }

    /// Get current region.
    public var currentRegion: EngineRegionState? {
        guard let id = currentRegionId else { return nil }
        return publishedRegions[id]
    }

    /// Check if region is neighbor to current region.
    public func isNeighbor(regionId: String) -> Bool {
        guard let current = currentRegion else { return false }
        return current.neighborIds.contains(regionId)
    }

    /// Calculate travel cost to target region (1 = neighbor, 2 = distant).
    public func calculateTravelCost(to targetId: String) -> Int {
        isNeighbor(regionId: targetId) ? 1 : 2
    }

    /// Check if travel to region is allowed (only neighbors allowed).
    public func canTravelTo(regionId: String) -> Bool {
        guard regionId != currentRegionId else { return false }
        return isNeighbor(regionId: regionId)
    }

    /// Get neighboring region names that connect to target (for routing hints).
    public func getRoutingHint(to targetId: String) -> [String] {
        guard let current = currentRegion else { return [] }

        if current.neighborIds.contains(targetId) {
            return []
        }

        var connectingNeighbors: [String] = []
        for neighborId in current.neighborIds {
            guard let neighbor = publishedRegions[neighborId] else { continue }
            if neighbor.neighborIds.contains(targetId) {
                connectingNeighbors.append(neighbor.name)
            }
        }
        return connectingNeighbors
    }

    /// World balance description.
    public var worldBalanceDescription: String {
        switch lightDarkBalance {
        case 70...100:
            return L10n.worldBalanceYavStrong.localized
        case 31..<70:
            return L10n.worldBalanceTwilight.localized
        default:
            return L10n.worldBalanceNavAdvances.localized
        }
    }

    /// Check if region can rest.
    public func canRestInCurrentRegion() -> Bool {
        guard let region = currentRegion else { return false }
        return region.state == .stable
    }

    /// Check if region can trade.
    public func canTradeInCurrentRegion() -> Bool {
        guard let region = currentRegion else { return false }
        return region.canTrade
    }
}

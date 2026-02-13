/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/TwilightGameEngine+ExplorationQueries.swift
/// Назначение: Содержит реализацию файла TwilightGameEngine+ExplorationQueries.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

extension TwilightGameEngine {
    /// Check whether exploration can surface scripted or random encounters in current region.
    public func hasAvailableEventsInCurrentRegion() -> Bool {
        guard let regionId = currentRegionId,
              let region = publishedRegions[regionId] else { return false }

        let events = services.contentRegistry.getAvailableEvents(
            forRegion: region.id,
            pressure: worldTension,
            regionState: eventQueryRegionStateString(region.state)
        )

        let completedEventIds = getCompletedEventIds()
        let availableEvents = events.filter { eventDef in
            !eventDef.isOneTime || !completedEventIds.contains(eventDef.id)
        }
        if !availableEvents.isEmpty { return true }

        return !services.contentRegistry.getAllEnemies().isEmpty
    }

    private func eventQueryRegionStateString(_ state: RegionState) -> String {
        switch state {
        case .stable: return "stable"
        case .borderland: return "borderland"
        case .breach: return "breach"
        }
    }
}

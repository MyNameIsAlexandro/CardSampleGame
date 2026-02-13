/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/ContentPacks/ContentRegistry+ProviderConformance.swift
/// Назначение: Содержит реализацию файла ContentRegistry+ProviderConformance.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

extension ContentRegistry: ContentProvider {
    public func getAllRegionDefinitions() -> [RegionDefinition] {
        getAllRegions()
    }

    public func getRegionDefinition(id: String) -> RegionDefinition? {
        getRegion(id: id)
    }

    public func getAllAnchorDefinitions() -> [AnchorDefinition] {
        getAllAnchors()
    }

    public func getAnchorDefinition(id: String) -> AnchorDefinition? {
        getAnchor(id: id)
    }

    public func getAnchorDefinition(forRegion regionId: String) -> AnchorDefinition? {
        getAnchor(forRegion: regionId)
    }

    public func getAllEventDefinitions() -> [EventDefinition] {
        getAllEvents()
    }

    public func getEventDefinition(id: String) -> EventDefinition? {
        getEvent(id: id)
    }

    public func getEventDefinitions(forRegion regionId: String) -> [EventDefinition] {
        mergedEvents.values.filter { event in
            event.availability.regionIds?.contains(regionId) ?? false
        }
    }

    public func getEventDefinitions(forPool poolId: String) -> [EventDefinition] {
        mergedEvents.values.filter { event in
            event.poolIds.contains(poolId)
        }
    }

    public func getAllQuestDefinitions() -> [QuestDefinition] {
        getAllQuests()
    }

    public func getQuestDefinition(id: String) -> QuestDefinition? {
        getQuest(id: id)
    }

    public func getAllMiniGameChallenges() -> [MiniGameChallengeDefinition] {
        mergedEvents.values.compactMap(\.miniGameChallenge)
    }

    public func getMiniGameChallenge(id: String) -> MiniGameChallengeDefinition? {
        mergedEvents.values
            .compactMap(\.miniGameChallenge)
            .first(where: { $0.id == id })
    }

    public func validate() -> [ContentValidationError] {
        ContentValidator(provider: self).validate()
    }
}

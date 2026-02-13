/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/TwilightGameEngine+WorldSetupAndPublishedState.swift
/// Назначение: Содержит реализацию файла TwilightGameEngine+WorldSetupAndPublishedState.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

extension TwilightGameEngine {

    /// Setup regions from content registry.
    func setupRegionsFromRegistry() {
        let regionDefs = contentRegistry.getAllRegions()
        var newRegions: [String: EngineRegionState] = [:]

        currentRegionId = nil
        let entryRegionId = contentRegistry.loadedPacks.values
            .first(where: { $0.manifest.entryRegionId != nil })?
            .manifest.entryRegionId

        for def in regionDefs {
            let anchor = contentRegistry.getAnchor(forRegion: def.id).map { anchorDef in
                EngineAnchorState(
                    id: anchorDef.id,
                    name: anchorDef.title.localized,
                    integrity: anchorDef.initialIntegrity,
                    alignment: anchorDef.initialInfluence
                )
            }

            let regionType = mapRegionType(fromString: def.regionType)
            let regionState = mapRegionState(def.initialState)

            let engineRegion = EngineRegionState(
                id: def.id,
                name: def.title.localized,
                type: regionType,
                state: regionState,
                anchor: anchor,
                neighborIds: def.neighborIds,
                canTrade: regionState == .stable && regionType == .settlement
            )
            newRegions[def.id] = engineRegion

            if def.id == entryRegionId {
                currentRegionId = def.id
            }
        }

        regions = newRegions
        publishedRegions = newRegions

        if currentRegionId == nil {
            currentRegionId = newRegions.values.first(where: { $0.state == .stable })?.id
                ?? newRegions.values.first(where: { $0.state != .breach })?.id
                ?? newRegions.keys.first
        }
    }

    /// Engine-First quest progress hook.
    func checkQuestProgress() -> [StateChange] {
        []
    }

    /// Victory/defeat checks performed after each action.
    func checkEndConditions() -> GameEndResult? {
        if worldTension >= 100 {
            return .defeat(reason: .worldTensionMax)
        }

        if player.health <= 0 {
            return .defeat(reason: .heroDied)
        }

        if let victoryFlag = balanceConfig.endConditions.mainQuestCompleteFlag,
           worldFlags[victoryFlag] == true {
            return .victory(endingId: "main_quest_complete")
        }

        return nil
    }

    /// Rebuild published snapshots used by app-layer view models.
    func updatePublishedState() {
        publishedRegions = regions
        publishedWorldFlags = worldFlags
        publishedActiveQuests = activeQuests
        refreshPublishedEventLog()

        if currentEventId == nil {
            currentEvent = nil
        }

        onStateChanged?()
    }

    /// Sync published log mirror from canonical core event log.
    func refreshPublishedEventLog() {
        publishedEventLog = Array(eventLog.suffix(100))
    }

    /// Append user-visible event log entry.
    public func addLogEntry(
        regionName: String,
        eventTitle: String,
        choiceMade: String,
        outcome: String,
        type: EventLogType
    ) {
        let entry = EventLogEntry(
            dayNumber: currentDay,
            regionName: regionName,
            eventTitle: eventTitle,
            choiceMade: choiceMade,
            outcome: outcome,
            type: type
        )

        eventLog.append(entry)
        if eventLog.count > 100 {
            eventLog.removeFirst(eventLog.count - 100)
        }

        publishedEventLog = Array(eventLog.suffix(100))
        onStateChanged?()
    }

    /// Get completed quest IDs for save.
    public func getCompletedQuestIds() -> Set<String> {
        completedQuestIds
    }

    /// Get quest stages for save.
    public func getQuestStages() -> [String: Int] {
        questStages
    }

    /// Get completed event IDs (definition IDs) for save.
    public func getCompletedEventIds() -> Set<String> {
        completedEventIds
    }

    /// Set regions from save.
    public func setRegions(_ newRegions: [String: EngineRegionState]) {
        regions = newRegions
        publishedRegions = newRegions
    }

    /// Set world flags from save.
    public func setWorldFlags(_ newFlags: [String: Bool]) {
        worldFlags = newFlags
        publishedWorldFlags = newFlags
    }

    /// Merge world flags from save/resume path.
    public func mergeWorldFlags(_ flags: [String: Bool]) {
        for (key, value) in flags {
            worldFlags[key] = value
        }
        publishedWorldFlags = worldFlags
    }

    /// Set completed event IDs (definition IDs) from save.
    public func setCompletedEventIds(_ ids: Set<String>) {
        completedEventIds = ids
    }

    /// Set event log from save.
    public func setEventLog(_ log: [EventLogEntry]) {
        eventLog = log
        publishedEventLog = Array(log.suffix(100))
    }

    /// Set main quest stage from save.
    public func setMainQuestStage(_ stage: Int) {
        mainQuestStage = stage
    }

    /// Set completed quest IDs from save.
    public func setCompletedQuestIds(_ ids: Set<String>) {
        completedQuestIds = ids
    }

    /// Set quest stages from save.
    public func setQuestStages(_ stages: [String: Int]) {
        questStages = stages
    }

    /// Recompute published snapshots after loading save.
    public func updatePublishedStateAfterLoad() {
        updatePublishedState()
    }
}

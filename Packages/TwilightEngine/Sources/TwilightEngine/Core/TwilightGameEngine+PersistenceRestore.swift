/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/TwilightGameEngine+PersistenceRestore.swift
/// Назначение: Содержит реализацию файла TwilightGameEngine+PersistenceRestore.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

extension TwilightGameEngine {

    /// Restore engine state from a save (Engine-First architecture).
    public func restoreFromEngineSave(_ save: EngineSave) {
        let compatibility = save.validateCompatibility(with: services.contentRegistry)

        #if DEBUG
        switch compatibility {
        case .fullyCompatible:
            print("✅ Save is fully compatible")
        case .compatible(let warnings):
            print("⚠️ Save is compatible with warnings:")
            warnings.forEach { print("   - \($0)") }
        case .incompatible(let errors):
            print("❌ Save is incompatible:")
            errors.forEach { print("   - \($0)") }
        }
        #endif

        guard compatibility.isLoadable else {
            initializeFallbackState()
            return
        }

        // Player and deck.
        player.restoreFromSave(save)
        let cardFactory = CardFactory(
            contentRegistry: services.contentRegistry,
            localizationManager: services.localizationManager
        )
        deck.setDeck(save.deckCardIds.compactMap { cardFactory.getCard(id: $0) })
        deck.setHand(save.handCardIds.compactMap { cardFactory.getCard(id: $0) })
        deck.setDiscard(save.discardCardIds.compactMap { cardFactory.getCard(id: $0) })

        // Core world state.
        currentDay = save.currentDay
        worldTension = save.worldTension
        lightDarkBalance = save.lightDarkBalance

        var restoredRegions: [String: EngineRegionState] = [:]
        for regionSave in save.regions {
            var anchor: EngineAnchorState? = nil
            if let anchorId = regionSave.anchorDefinitionId {
                let anchorDef = contentRegistry.getAnchor(id: anchorId)
                let anchorName = anchorDef?.title.resolve(using: services.localizationManager) ?? anchorId
                let restoredAlignment = regionSave.anchorAlignment.flatMap { AnchorAlignment(rawValue: $0) } ?? .neutral
                anchor = EngineAnchorState(
                    id: anchorId,
                    name: anchorName,
                    integrity: regionSave.anchorIntegrity ?? 100,
                    alignment: restoredAlignment
                )
            }

            let region = EngineRegionState(
                id: regionSave.definitionId,
                name: regionSave.name,
                type: RegionType(rawValue: regionSave.type) ?? .settlement,
                state: RegionState(rawValue: regionSave.state) ?? .stable,
                anchor: anchor,
                neighborIds: regionSave.neighborDefinitionIds,
                canTrade: regionSave.canTrade,
                visited: regionSave.visited,
                reputation: regionSave.reputation
            )
            restoredRegions[regionSave.definitionId] = region
        }
        setRegions(restoredRegions)
        currentRegionId = save.currentRegionId

        // Quests and progression.
        setMainQuestStage(save.mainQuestStage)
        setCompletedQuestIds(Set(save.completedQuestIds))

        var restoredQuests: [Quest] = []
        for questId in save.activeQuestIds {
            guard let questDef = contentRegistry.getQuest(id: questId) else { continue }
            var quest = questDef.toQuest()
            if let savedStage = save.questStages[questId] {
                quest.stage = savedStage
            }
            restoredQuests.append(quest)
        }
        activeQuests = restoredQuests
        publishedActiveQuests = restoredQuests

        // Events and flags.
        setCompletedEventIds(Set(save.completedEventIds))
        setEventLog(save.eventLog.map { $0.toEventLogEntry() })
        setWorldFlags(save.worldFlags)

        // Fate deck and external-combat resume snapshot.
        if let deckState = save.fateDeckState {
            fateDeck?.restoreState(deckState)
        }
        assignPendingEncounterState(save.encounterState)

        // Deterministic runtime continuity.
        previousSessionsDuration = save.gameDuration
        gameStartDate = Date()
        services.rng.restoreState(save.rngState)

        isGameOver = false
        gameResult = nil
        updatePublishedState()
    }

    /// Initialize a minimal fallback state when save loading is incompatible.
    func initializeFallbackState() {
        resetGameState()

        player.setName("Герой")
        player.setMaxHealth(20)
        player.setHealth(20)
        player.setFaith(10)
        player.maxFaith = 15
        player.setBalance(50)
        player.strength = 5

        currentDay = 1
        worldTension = 30
        lightDarkBalance = 50

        setupRegionsFromRegistry()
        updatePublishedState()
    }
}

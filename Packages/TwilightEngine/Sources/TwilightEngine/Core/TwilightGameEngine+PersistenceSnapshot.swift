/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/TwilightGameEngine+PersistenceSnapshot.swift
/// Назначение: Содержит реализацию файла TwilightGameEngine+PersistenceSnapshot.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

public extension TwilightGameEngine {

    /// Create a save state from current engine state (Engine-First Architecture)
    /// This replaces GameState-based saves.
    func createEngineSave() -> EngineSave {
        let snapshotDate = Date()

        var activePackSet: [String: String] = [:]
        var primaryCampaignPackId: String? = nil
        for (packId, pack) in services.contentRegistry.loadedPacks {
            activePackSet[packId] = pack.manifest.version.description
            if primaryCampaignPackId == nil &&
                (pack.manifest.packType == .campaign || pack.manifest.packType == .full) {
                primaryCampaignPackId = packId
            }
        }

        return EngineSave(
            version: EngineSave.currentVersion,
            savedAt: snapshotDate,
            gameDuration: totalGameDuration(at: snapshotDate),

            coreVersion: EngineSave.currentCoreVersion,
            activePackSet: activePackSet,
            formatVersion: EngineSave.currentFormatVersion,
            primaryCampaignPackId: primaryCampaignPackId,

            playerName: player.name,
            heroId: player.heroId,
            playerHealth: player.health,
            playerMaxHealth: player.maxHealth,
            playerFaith: player.faith,
            playerMaxFaith: player.maxFaith,
            playerBalance: player.balance,

            deckCardIds: deck.playerDeck.map { $0.id },
            handCardIds: deck.playerHand.map { $0.id },
            discardCardIds: deck.playerDiscard.map { $0.id },

            currentDay: currentDay,
            worldTension: worldTension,
            lightDarkBalance: lightDarkBalance,
            currentRegionId: currentRegionId,
            regions: publishedRegions.values.map { RegionSaveState(from: $0) },

            mainQuestStage: mainQuestStage,
            activeQuestIds: publishedActiveQuests.map { $0.id },
            completedQuestIds: Array(getCompletedQuestIds()),
            questStages: Dictionary(uniqueKeysWithValues: publishedActiveQuests.map { ($0.id, $0.stage) }),

            completedEventIds: Array(getCompletedEventIds()),
            eventLog: publishedEventLog.map { EventLogEntrySave(from: $0) },
            worldFlags: publishedWorldFlags,

            fateDeckState: fateDeck?.getState(),
            encounterState: pendingEncounterState,

            rngSeed: services.rng.currentSeed(),
            rngState: services.rng.currentState()
        )
    }
}

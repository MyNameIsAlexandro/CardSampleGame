/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Migration/QuestDefinitionAdapter.swift
/// Назначение: Содержит реализацию файла QuestDefinitionAdapter.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Quest Definition Adapter
// Converts QuestDefinition (new data-driven) to Quest (legacy UI-compatible)
// This enables using content packs while maintaining compatibility with existing UI

extension QuestDefinition {

    /// Convert QuestDefinition to legacy Quest for UI compatibility
    /// - Returns: Quest compatible with existing UI
    public func toQuest() -> Quest {
        // Map quest kind to legacy quest type
        let questType = mapQuestKind(questKind)

        // Convert objectives
        let legacyObjectives = objectives.map { $0.toQuestObjective() }

        // Convert rewards
        let rewards = completionRewards.toQuestRewards()

        return Quest(
            id: id,
            title: title.localized,
            description: description.localized,
            questType: questType,
            stage: 0,
            objectives: legacyObjectives,
            rewards: rewards,
            completed: false
        )
    }

    // MARK: - Private Mapping Helpers

    private func mapQuestKind(_ kind: QuestKind) -> QuestType {
        switch kind {
        case .main:
            return .main
        case .side, .exploration, .challenge:
            return .side
        }
    }
}

// MARK: - Objective Definition to Quest Objective

extension ObjectiveDefinition {

    /// Convert ObjectiveDefinition to legacy QuestObjective
    public func toQuestObjective() -> QuestObjective {
        // Extract required flags from completion condition
        let requiredFlags = extractRequiredFlags(from: completionCondition)

        return QuestObjective(
            id: id,
            description: description.localized,
            completed: false,
            requiredFlags: requiredFlags
        )
    }

    private func extractRequiredFlags(from condition: CompletionCondition) -> [String]? {
        switch condition {
        case .flagSet(let flag):
            return [flag]
        case .eventCompleted(let eventId):
            return ["\(eventId)_completed"]
        case .choiceMade(let eventId, let choiceId):
            return ["\(eventId)_\(choiceId)_chosen"]
        case .visitRegion(let regionId):
            return ["visited_\(regionId)"]
        case .defeatEnemy(let enemyId):
            return ["defeated_\(enemyId)"]
        case .collectItem(let itemId):
            return ["collected_\(itemId)"]
        case .resourceThreshold, .manual:
            return nil
        }
    }
}

// MARK: - Quest Completion Rewards to Quest Rewards

extension QuestCompletionRewards {

    /// Convert to legacy QuestRewards
    public func toQuestRewards() -> QuestRewards {
        let faith = resourceChanges["faith"]
        let cards = cardIds.isEmpty ? nil : cardIds

        return QuestRewards(
            faith: faith,
            cards: cards,
            artifact: nil,  // Artifacts not supported in new format yet
            experience: nil  // Experience not supported in new format yet
        )
    }
}


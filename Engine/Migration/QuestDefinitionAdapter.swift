import Foundation

// MARK: - Quest Definition Adapter
// Converts QuestDefinition (new data-driven) to Quest (legacy UI-compatible)
// This enables using content packs while maintaining compatibility with existing UI

extension QuestDefinition {

    /// Convert QuestDefinition to legacy Quest for UI compatibility
    /// - Returns: Quest compatible with existing UI
    func toQuest() -> Quest {
        // Generate deterministic UUID from string ID for consistency
        let questUUID = UUID(uuidString: id.md5UUID) ?? UUID()

        // Map quest kind to legacy quest type
        let questType = mapQuestKind(questKind)

        // Convert objectives
        let legacyObjectives = objectives.map { $0.toQuestObjective() }

        // Convert rewards
        let rewards = completionRewards.toQuestRewards()

        return Quest(
            id: questUUID,
            definitionId: id,  // Content Pack ID for QuestTriggerEngine
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
    func toQuestObjective() -> QuestObjective {
        // Generate deterministic UUID from string ID
        let objectiveUUID = UUID(uuidString: id.md5UUID) ?? UUID()

        // Extract required flags from completion condition
        let requiredFlags = extractRequiredFlags(from: completionCondition)

        return QuestObjective(
            id: objectiveUUID,
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
    func toQuestRewards() -> QuestRewards {
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

// MARK: - String UUID Extension (reuse from EventDefinitionAdapter)

private extension String {
    /// Generate a deterministic UUID-like string from this string
    var md5UUID: String {
        // Simple hash-based UUID generation for determinism
        var hash: UInt64 = 5381
        for char in self.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(char)
        }

        // Format as UUID string (simplified)
        let hex = String(format: "%016llX", hash)
        let padded = hex.padding(toLength: 32, withPad: "0", startingAt: 0)

        // Insert dashes: 8-4-4-4-12
        let chars = Array(padded)
        return "\(String(chars[0..<8]))-\(String(chars[8..<12]))-\(String(chars[12..<16]))-\(String(chars[16..<20]))-\(String(chars[20..<32]))"
    }
}

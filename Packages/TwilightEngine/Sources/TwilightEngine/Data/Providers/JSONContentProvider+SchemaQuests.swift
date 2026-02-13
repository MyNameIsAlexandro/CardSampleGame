/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Data/Providers/JSONContentProvider+SchemaQuests.swift
/// Назначение: Содержит реализацию файла JSONContentProvider+SchemaQuests.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// Quest-схема для JSON-контента: верхний уровень квеста и его objectives.
struct JSONQuest: Codable {
    public let id: String
    public let title: LocalizedString
    public let description: LocalizedString
    public let questKind: String?
    public let availability: JSONQuestAvailability?
    public let autoStart: Bool?
    public let objectives: [JSONObjective]?
    public let completionRewards: JSONQuestCompletionRewards?
    public let failurePenalties: JSONQuestCompletionRewards?

    enum CodingKeys: String, CodingKey {
        case id, title, description, objectives, availability
        case questKind = "quest_kind"
        case autoStart = "auto_start"
        case completionRewards = "completion_rewards"
        case failurePenalties = "failure_penalties"
    }

    public func toDefinition() -> QuestDefinition {
        let objDefs = objectives?.map { $0.toDefinition() } ?? []

        let kind: QuestKind
        switch questKind?.lowercased() {
        case "main": kind = .main
        case "side": kind = .side
        case "exploration": kind = .exploration
        case "challenge": kind = .challenge
        default: kind = .side
        }

        let avail = availability?.toAvailability() ?? .always
        let rewards = completionRewards?.toRewards() ?? .none
        let penalties = failurePenalties?.toRewards() ?? .none

        return QuestDefinition(
            id: id,
            title: .inline(title),
            description: .inline(description),
            objectives: objDefs,
            questKind: kind,
            availability: avail,
            autoStart: autoStart ?? false,
            completionRewards: rewards,
            failurePenalties: penalties
        )
    }
}

struct JSONObjective: Codable {
    public let id: String
    public let description: LocalizedString
    public let hint: LocalizedString?
    public let completionCondition: JSONCompletionCondition?
    public let targetValue: Int?
    public let isOptional: Bool?
    public let nextObjectiveId: String?
    public let alternativeNextIds: [String]?

    enum CodingKeys: String, CodingKey {
        case id, description, hint
        case completionCondition = "completion_condition"
        case targetValue = "target_value"
        case isOptional = "is_optional"
        case nextObjectiveId = "next_objective_id"
        case alternativeNextIds = "alternative_next_ids"
    }

    public func toDefinition() -> ObjectiveDefinition {
        let condition = completionCondition?.toCondition() ?? .manual

        return ObjectiveDefinition(
            id: id,
            description: .inline(description),
            hint: hint.map { .inline($0) },
            completionCondition: condition,
            targetValue: targetValue ?? 1,
            isOptional: isOptional ?? false,
            nextObjectiveId: nextObjectiveId,
            alternativeNextIds: alternativeNextIds ?? []
        )
    }
}

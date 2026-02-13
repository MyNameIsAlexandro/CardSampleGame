/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Data/Providers/CodeContentProvider+JSONConsequences.swift
/// Назначение: Содержит реализацию файла CodeContentProvider+JSONConsequences.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

public struct JSONChoiceConsequencesForLoading: Codable {
    public let resourceChanges: [String: Int]?
    public let setFlags: [String]?
    public let clearFlags: [String]?
    public let balanceDelta: Int?
    public let regionStateChange: JSONRegionStateChangeForLoading?
    public let questProgress: JSONQuestProgressForLoading?
    public let triggerEventId: String?
    public let resultKey: String?

    enum CodingKeys: String, CodingKey {
        case resourceChanges = "resource_changes"
        case setFlags = "set_flags"
        case clearFlags = "clear_flags"
        case balanceDelta = "balance_delta"
        case regionStateChange = "region_state_change"
        case questProgress = "quest_progress"
        case triggerEventId = "trigger_event_id"
        case resultKey = "result_key"
    }

    public func toConsequences() -> ChoiceConsequences {
        let stateChange: RegionStateChange?
        if let rsc = regionStateChange {
            let transition: RegionStateChange.StateTransition?
            switch rsc.transition?.lowercased() {
            case "restore": transition = .restore
            case "degrade": transition = .degrade
            default: transition = nil
            }
            stateChange = RegionStateChange(
                regionId: rsc.regionId,
                newState: nil,
                transition: transition
            )
        } else { stateChange = nil }

        let questProg: QuestProgressTrigger?
        if let qp = questProgress {
            let action: QuestProgressTrigger.QuestAction
            switch qp.action?.lowercased() {
            case "complete": action = .complete
            case "unlock": action = .unlock
            case "fail": action = .fail
            case "advance": action = .advance
            default: action = .complete
            }
            questProg = QuestProgressTrigger(
                questId: qp.questId ?? "",
                objectiveId: qp.objectiveId,
                action: action
            )
        } else { questProg = nil }

        return ChoiceConsequences(
            resourceChanges: resourceChanges ?? [:],
            setFlags: setFlags ?? [],
            clearFlags: clearFlags ?? [],
            balanceDelta: balanceDelta ?? 0,
            regionStateChange: stateChange,
            questProgress: questProg,
            resultKey: resultKey
        )
    }
}

public struct JSONRegionStateChangeForLoading: Codable {
    public let regionId: String?
    public let newState: String?
    public let transition: String?

    enum CodingKeys: String, CodingKey {
        case regionId = "region_id"
        case newState = "new_state"
        case transition
    }
}

public struct JSONQuestProgressForLoading: Codable {
    public let questId: String?
    public let objectiveId: String?
    public let action: String?

    enum CodingKeys: String, CodingKey {
        case questId = "quest_id"
        case objectiveId = "objective_id"
        case action
    }
}

public struct JSONMiniGameChallengeForLoading: Codable {
    public let enemyId: String?
    public let difficulty: Int?
    public let rewards: JSONChallengeConsequencesForLoading?
    public let penalties: JSONChallengeConsequencesForLoading?

    enum CodingKeys: String, CodingKey {
        case enemyId = "enemy_id"
        case difficulty, rewards, penalties
    }
}

public struct JSONChallengeConsequencesForLoading: Codable {
    public let resourceChanges: [String: Int]?
    public let setFlags: [String]?
    public let balanceShift: Int?

    enum CodingKeys: String, CodingKey {
        case resourceChanges = "resource_changes"
        case setFlags = "set_flags"
        case balanceShift = "balance_shift"
    }

    public func toConsequences() -> ChoiceConsequences {
        ChoiceConsequences(
            resourceChanges: resourceChanges ?? [:],
            setFlags: setFlags ?? [],
            clearFlags: [],
            balanceDelta: balanceShift ?? 0
        )
    }
}

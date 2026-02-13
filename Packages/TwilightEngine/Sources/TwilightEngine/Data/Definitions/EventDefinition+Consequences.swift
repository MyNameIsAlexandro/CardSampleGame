/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Data/Definitions/EventDefinition+Consequences.swift
/// Назначение: Содержит реализацию файла EventDefinition+Consequences.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Supporting Types

/// Region state change triggered by choice
public struct RegionStateChange: Codable, Hashable, Sendable {
    /// Target region ID (nil = current region)
    public var regionId: String?

    /// New state to set
    public var newState: RegionStateType?

    /// State transition (degrade/restore)
    public var transition: StateTransition?

    public enum StateTransition: String, Codable, Hashable, Sendable {
        case degrade
        case restore
    }
}

/// Quest progress trigger
public struct QuestProgressTrigger: Codable, Hashable, Sendable {
    public var questId: String
    public var objectiveId: String?
    public var action: QuestAction

    public enum QuestAction: String, Codable, Hashable, Sendable {
        case advance      // Move to next objective
        case complete     // Complete specific objective
        case fail         // Fail the quest
        case unlock       // Unlock the quest
    }
}

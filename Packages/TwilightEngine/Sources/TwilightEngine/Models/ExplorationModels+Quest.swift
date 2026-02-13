/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Models/ExplorationModels+Quest.swift
/// Назначение: Содержит реализацию файла ExplorationModels+Quest.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Quest Type

public enum QuestType: String, Codable {
    case main       // Main quest
    case side       // Side quest
}

// MARK: - Quest Objective

public struct QuestObjective: Identifiable, Codable {
    public let id: String
    public let description: String
    public var completed: Bool
    public var requiredFlags: [String]?  // Flags required to complete objective

    public init(id: String, description: String, completed: Bool = false, requiredFlags: [String]? = nil) {
        self.id = id
        self.description = description
        self.completed = completed
        self.requiredFlags = requiredFlags
    }
}

// MARK: - Quest Rewards

public struct QuestRewards: Codable {
    public var faith: Int?
    public var cards: [String]?
    public var artifact: String?
    public var experience: Int?

    public init(faith: Int? = nil, cards: [String]? = nil, artifact: String? = nil, experience: Int? = nil) {
        self.faith = faith
        self.cards = cards
        self.artifact = artifact
        self.experience = experience
    }
}

// MARK: - Quest

/// Quest in game
/// For side quests use theme to define narrative theme
/// See EXPLORATION_CORE_DESIGN.md, section 30 (Side quests as "world mirrors")
public struct Quest: Identifiable, Codable {
    public let id: String
    public let title: String
    public let description: String
    public let questType: QuestType
    public var stage: Int                      // Current quest stage (0 = not started)
    public var objectives: [QuestObjective]
    public let rewards: QuestRewards
    public var completed: Bool

    // Narrative System properties (see EXPLORATION_CORE_DESIGN.md, section 30)
    public var theme: SideQuestTheme?          // Quest theme (for side quests): consequence/warning/temptation
    public var mirrorFlag: String?             // Which player choice this quest "mirrors"

    public init(
        id: String,
        title: String,
        description: String,
        questType: QuestType,
        stage: Int = 0,
        objectives: [QuestObjective],
        rewards: QuestRewards,
        completed: Bool = false,
        theme: SideQuestTheme? = nil,
        mirrorFlag: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.questType = questType
        self.stage = stage
        self.objectives = objectives
        self.rewards = rewards
        self.completed = completed
        self.theme = theme
        self.mirrorFlag = mirrorFlag
    }

    // Check if all objectives completed
    public var allObjectivesCompleted: Bool {
        return objectives.allSatisfy { $0.completed }
    }

    /// Check if quest "mirrors" given flag
    public func mirrors(flag: String) -> Bool {
        return mirrorFlag == flag
    }
}

// MARK: - Side Quest Theme

/// Side quest theme (affects tone and consequences)
/// See EXPLORATION_CORE_DESIGN.md, section 30.2
public enum SideQuestTheme: String, Codable {
    case consequence    // Consequence - world already suffered
    case warning        // Warning - can prevent degradation
    case temptation     // Temptation - quick gains for long-term damage
}

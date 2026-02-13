/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Models/ExplorationModels+MainQuest.swift
/// Назначение: Содержит реализацию файла ExplorationModels+MainQuest.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Main Quest Step

/// Main quest step
/// See EXPLORATION_CORE_DESIGN.md, section 29.3
public struct MainQuestStep: Identifiable, Codable {
    public let id: String
    public let title: String
    public let goal: String
    public let unlockConditions: QuestConditions
    public let completionConditions: QuestConditions
    public let effects: QuestEffects?

    public init(
        id: String,
        title: String,
        goal: String,
        unlockConditions: QuestConditions,
        completionConditions: QuestConditions,
        effects: QuestEffects? = nil
    ) {
        self.id = id
        self.title = title
        self.goal = goal
        self.unlockConditions = unlockConditions
        self.completionConditions = completionConditions
        self.effects = effects
    }
}

/// Conditions for quest (unlock or completion)
/// See EXPLORATION_CORE_DESIGN.md, section 29
public struct QuestConditions: Codable {
    public var requiredFlags: [String]?    // Flags that must be set
    public var forbiddenFlags: [String]?   // Flags that must NOT be set
    public var minTension: Int?            // Minimum WorldTension
    public var maxTension: Int?            // Maximum WorldTension
    public var minBalance: Int?            // Minimum lightDarkBalance
    public var maxBalance: Int?            // Maximum lightDarkBalance
    public var visitedRegions: [String]?   // Visited regions

    public init(
        requiredFlags: [String]? = nil,
        forbiddenFlags: [String]? = nil,
        minTension: Int? = nil,
        maxTension: Int? = nil,
        minBalance: Int? = nil,
        maxBalance: Int? = nil,
        visitedRegions: [String]? = nil
    ) {
        self.requiredFlags = requiredFlags
        self.forbiddenFlags = forbiddenFlags
        self.minTension = minTension
        self.maxTension = maxTension
        self.minBalance = minBalance
        self.maxBalance = maxBalance
        self.visitedRegions = visitedRegions
    }
}

/// Effects of completing quest step
public struct QuestEffects: Codable {
    public var unlockRegions: [String]?    // Unlock regions
    public var setFlags: [String]?         // Set flags
    public var tensionChange: Int?         // WorldTension change
    public var addCards: [String]?         // Add cards

    public init(
        unlockRegions: [String]? = nil,
        setFlags: [String]? = nil,
        tensionChange: Int? = nil,
        addCards: [String]? = nil
    ) {
        self.unlockRegions = unlockRegions
        self.setFlags = setFlags
        self.tensionChange = tensionChange
        self.addCards = addCards
    }
}

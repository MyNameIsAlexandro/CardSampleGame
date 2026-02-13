/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Models/ExplorationModels+Ending.swift
/// Назначение: Содержит реализацию файла ExplorationModels+Ending.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Deck Path (for Ending calculation)

/// Dominant deck path of player
/// See EXPLORATION_CORE_DESIGN.md, section 32.5
public enum DeckPath: String, Codable {
    case light      // Light cards dominant (>60%)
    case dark       // Dark cards dominant (>60%)
    case balance    // No clear dominance
}

// MARK: - Ending Profile

/// Campaign ending profile
/// See EXPLORATION_CORE_DESIGN.md, section 32.4
public struct EndingProfile: Identifiable, Codable {
    public let id: String
    public let title: String
    public let conditions: EndingConditions
    public let summary: String
    public let epilogue: EndingEpilogue
    public let unlocksForNextRun: [String]?

    public init(
        id: String,
        title: String,
        conditions: EndingConditions,
        summary: String,
        epilogue: EndingEpilogue,
        unlocksForNextRun: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.conditions = conditions
        self.summary = summary
        self.epilogue = epilogue
        self.unlocksForNextRun = unlocksForNextRun
    }
}

/// Conditions for obtaining ending
/// See EXPLORATION_CORE_DESIGN.md, section 32
public struct EndingConditions: Codable {
    // WorldTension conditions
    public let minTension: Int?                    // Minimum WorldTension
    public let maxTension: Int?                    // Maximum WorldTension

    // Deck path condition
    public let deckPath: DeckPath?                 // Required deck path

    // Flag conditions
    public let requiredFlags: [String]?            // Required flags
    public let forbiddenFlags: [String]?           // Forbidden flags

    // Anchor conditions
    public let minStableAnchors: Int?              // Minimum stable anchors
    public let maxBreachAnchors: Int?              // Maximum breach regions

    // Balance conditions
    public let minBalance: Int?                    // Minimum lightDarkBalance
    public let maxBalance: Int?                    // Maximum lightDarkBalance

    public init(
        minTension: Int? = nil,
        maxTension: Int? = nil,
        deckPath: DeckPath? = nil,
        requiredFlags: [String]? = nil,
        forbiddenFlags: [String]? = nil,
        minStableAnchors: Int? = nil,
        maxBreachAnchors: Int? = nil,
        minBalance: Int? = nil,
        maxBalance: Int? = nil
    ) {
        self.minTension = minTension
        self.maxTension = maxTension
        self.deckPath = deckPath
        self.requiredFlags = requiredFlags
        self.forbiddenFlags = forbiddenFlags
        self.minStableAnchors = minStableAnchors
        self.maxBreachAnchors = maxBreachAnchors
        self.minBalance = minBalance
        self.maxBalance = maxBalance
    }
}

/// Ending epilogue
public struct EndingEpilogue: Codable {
    public let anchors: String     // Fate of anchors
    public let hero: String        // Fate of hero
    public let world: String       // Fate of world

    public init(anchors: String, hero: String, world: String) {
        self.anchors = anchors
        self.hero = hero
        self.world = world
    }
}

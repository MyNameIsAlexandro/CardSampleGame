import Foundation

// MARK: - Region State

public enum RegionState: String, Codable, Hashable, CaseIterable {
    case stable         // Стабильная Явь - безопасно
    case borderland     // Пограничье - повышенный риск
    case breach         // Прорыв Нави - опасно

    /// Initialize from Engine's RegionStateType
    /// Used by data-driven content loading
    public init(from engineState: RegionStateType) {
        switch engineState {
        case .stable: self = .stable
        case .borderland: self = .borderland
        case .breach: self = .breach
        }
    }

    public var displayName: String {
        switch self {
        case .stable: return L10n.regionStateStable.localized
        case .borderland: return L10n.regionStateBorderland.localized
        case .breach: return L10n.regionStateBreach.localized
        }
    }

    public var emoji: String {
        switch self {
        case .stable: return "🟢"
        case .borderland: return "🟡"
        case .breach: return "🔴"
        }
    }

    // MARK: - Combat Modifiers

    /// Бонус к силе врага в этом регионе
    public var enemyPowerBonus: Int {
        switch self {
        case .stable: return 0
        case .borderland: return 1
        case .breach: return 2
        }
    }

    /// Бонус к здоровью врага в этом регионе
    public var enemyHealthBonus: Int {
        switch self {
        case .stable: return 0
        case .borderland: return 2
        case .breach: return 5
        }
    }

    /// Бонус к защите врага в этом регионе
    public var enemyDefenseBonus: Int {
        switch self {
        case .stable: return 0
        case .borderland: return 1
        case .breach: return 2
        }
    }
}

// MARK: - Combat Context

/// Контекст боя с учётом региона и проклятий
public struct CombatContext {
    public let regionState: RegionState
    public let playerCurses: [CurseType]

    public init(regionState: RegionState, playerCurses: [CurseType]) {
        self.regionState = regionState
        self.playerCurses = playerCurses
    }

    /// Рассчитать эффективную силу врага
    public func adjustedEnemyPower(_ basePower: Int) -> Int {
        return basePower + regionState.enemyPowerBonus
    }

    /// Рассчитать эффективное здоровье врага
    public func adjustedEnemyHealth(_ baseHealth: Int) -> Int {
        return baseHealth + regionState.enemyHealthBonus
    }

    /// Рассчитать эффективную защиту врага
    public func adjustedEnemyDefense(_ baseDefense: Int) -> Int {
        return baseDefense + regionState.enemyDefenseBonus
    }

    /// Описание модификаторов региона для UI
    public var regionModifierDescription: String? {
        switch regionState {
        case .stable:
            return nil
        case .borderland:
            return L10n.combatModifierBorderland.localized
        case .breach:
            return L10n.combatModifierBreach.localized
        }
    }
}

// MARK: - Region Type

public enum RegionType: String, Codable, Hashable {
    case forest         // Лес
    case swamp          // Болото
    case mountain       // Горы
    case settlement     // Поселение
    case water          // Водная зона
    case wasteland      // Пустошь
    case sacred         // Священное место

    public var displayName: String {
        switch self {
        case .forest: return L10n.regionTypeForest.localized
        case .swamp: return L10n.regionTypeSwamp.localized
        case .mountain: return L10n.regionTypeMountain.localized
        case .settlement: return L10n.regionTypeSettlement.localized
        case .water: return L10n.regionTypeWater.localized
        case .wasteland: return L10n.regionTypeWasteland.localized
        case .sacred: return L10n.regionTypeSacred.localized
        }
    }

    public var icon: String {
        switch self {
        case .forest: return "tree.fill"
        case .swamp: return "cloud.fog.fill"
        case .mountain: return "mountain.2.fill"
        case .settlement: return "house.fill"
        case .water: return "drop.fill"
        case .wasteland: return "wind"
        case .sacred: return "star.fill"
        }
    }
}

// MARK: - Anchor Type

public enum AnchorType: String, Codable {
    case shrine         // Капище
    case barrow         // Курган
    case sacredTree     // Священный дуб
    case stoneIdol      // Каменная баба
    case spring         // Родник
    case chapel         // Часовня
    case temple         // Храм
    case cross          // Обетный крест

    /// Initialize from JSON string (snake_case format)
    /// Used by data-driven content loading
    public init?(fromJSON string: String) {
        switch string {
        case "shrine": self = .shrine
        case "barrow": self = .barrow
        case "sacred_tree": self = .sacredTree
        case "stone_idol": self = .stoneIdol
        case "spring": self = .spring
        case "chapel": self = .chapel
        case "temple": self = .temple
        case "cross": self = .cross
        default: return nil
        }
    }

    public var displayName: String {
        switch self {
        case .shrine: return L10n.anchorTypeShrine.localized
        case .barrow: return L10n.anchorTypeBarrow.localized
        case .sacredTree: return L10n.anchorTypeSacredTree.localized
        case .stoneIdol: return L10n.anchorTypeStoneIdol.localized
        case .spring: return L10n.anchorTypeSpring.localized
        case .chapel: return L10n.anchorTypeChapel.localized
        case .temple: return L10n.anchorTypeTemple.localized
        case .cross: return L10n.anchorTypeCross.localized
        }
    }

    public var icon: String {
        switch self {
        case .shrine: return "flame.fill"
        case .barrow: return "mountain.2"
        case .sacredTree: return "leaf.fill"
        case .stoneIdol: return "figure.stand"
        case .spring: return "drop.circle.fill"
        case .chapel: return "building.columns.fill"
        case .temple: return "building.2.fill"
        case .cross: return "cross.fill"
        }
    }
}

// MARK: - Anchor

public struct Anchor: Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let type: AnchorType
    public var integrity: Int          // 0-100%
    public var influence: CardBalance  // .light, .neutral, .dark
    public let power: Int              // Сила влияния (1-10)

    public init(
        id: UUID = UUID(),
        name: String,
        type: AnchorType,
        integrity: Int = 100,
        influence: CardBalance = .light,
        power: Int = 5
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.integrity = max(0, min(100, integrity))
        self.influence = influence
        self.power = power
    }

    // Определяет состояние региона на основе целостности якоря
    public var determinedRegionState: RegionState {
        switch integrity {
        case 70...100:
            return .stable
        case 30..<70:
            return .borderland
        default:
            return .breach
        }
    }

    // Проверка, осквернен ли якорь
    public var isDefiled: Bool {
        return influence == .dark
    }
}

// MARK: - Region

/// Legacy Region model used for world state persistence and direct UI binding.
///
/// MIGRATION (Audit v1.1 Issue #9):
/// - For new code prefer using Engine models:
///   - `RegionDefinition` - static data (from ContentProvider)
///   - `RegionRuntimeState` - mutable state (Engine/Runtime/WorldRuntimeState.swift)
///   - `EngineRegionState` - combined state for UI (TwilightGameEngine.swift)
/// - This model is preserved for: save serialization, legacy UI, unit tests
/// - After full UI migration to Engine this model will become internal for persistence
public struct Region: Identifiable, Codable {
    public let id: UUID
    public let definitionId: String        // Content Pack ID (e.g., "village", "sacred_oak")
    public let name: String
    public let type: RegionType
    public var state: RegionState
    public var anchor: Anchor?
    public var availableEvents: [String]   // Event IDs
    public var activeQuests: [String]      // Active quest IDs
    public var reputation: Int             // -100 to 100
    public var visited: Bool               // Has player been here
    public var neighborIds: [UUID]         // Neighbor region IDs (travel = 1 day)

    public init(
        id: UUID = UUID(),
        definitionId: String = "",
        name: String,
        type: RegionType,
        state: RegionState = .stable,
        anchor: Anchor? = nil,
        availableEvents: [String] = [],
        activeQuests: [String] = [],
        reputation: Int = 0,
        visited: Bool = false,
        neighborIds: [UUID] = []
    ) {
        self.id = id
        self.definitionId = definitionId
        self.name = name
        self.type = type
        self.state = state
        self.anchor = anchor
        self.availableEvents = availableEvents
        self.activeQuests = activeQuests
        self.reputation = max(-100, min(100, reputation))
        self.visited = visited
        self.neighborIds = neighborIds
    }

    /// Check if region is neighbor
    public func isNeighbor(_ regionId: UUID) -> Bool {
        return neighborIds.contains(regionId)
    }

    // Update region state based on anchor
    public mutating func updateStateFromAnchor() {
        if let anchor = anchor {
            self.state = anchor.determinedRegionState
        } else {
            // Without anchor region is always in Breach
            self.state = .breach
        }
    }

    // Can trade in region
    public var canTrade: Bool {
        return state == .stable && type == .settlement && reputation >= 0
    }

    // Can rest in region
    public var canRest: Bool {
        return state == .stable && (type == .settlement || type == .sacred)
    }
}

// MARK: - Event Type

public enum EventType: String, Codable, Hashable {
    case combat         // Combat
    case ritual         // Ritual/Choice
    case narrative      // Narrative event
    case exploration    // Exploration
    case worldShift     // World shift

    public var displayName: String {
        switch self {
        case .combat: return L10n.eventTypeCombat.localized
        case .ritual: return L10n.eventTypeRitual.localized
        case .narrative: return L10n.eventTypeNarrative.localized
        case .exploration: return L10n.eventTypeExploration.localized
        case .worldShift: return L10n.eventTypeWorldShift.localized
        }
    }

    public var icon: String {
        switch self {
        case .combat: return "bolt.fill"
        case .ritual: return "sparkles"
        case .narrative: return "text.bubble.fill"
        case .exploration: return "magnifyingglass"
        case .worldShift: return "globe"
        }
    }
}

// MARK: - Event Choice

public struct EventChoice: Identifiable, Codable, Hashable {
    public let id: String
    public let text: String
    public let requirements: EventRequirements?
    public let consequences: EventConsequences

    public init(
        id: String = UUID().uuidString,
        text: String,
        requirements: EventRequirements? = nil,
        consequences: EventConsequences
    ) {
        self.id = id
        self.text = text
        self.requirements = requirements
        self.consequences = consequences
    }
}

// MARK: - Event Requirements

public struct EventRequirements: Codable, Hashable {
    public var minimumFaith: Int?
    public var minimumHealth: Int?
    public var requiredBalance: CardBalance?    // Required balance
    public var requiredFlags: [String]?         // Required world flags

    public init(
        minimumFaith: Int? = nil,
        minimumHealth: Int? = nil,
        requiredBalance: CardBalance? = nil,
        requiredFlags: [String]? = nil
    ) {
        self.minimumFaith = minimumFaith
        self.minimumHealth = minimumHealth
        self.requiredBalance = requiredBalance
        self.requiredFlags = requiredFlags
    }

    /// Check if requirements can be met using engine properties directly
    /// - Parameters:
    ///   - playerFaith: Current player faith value
    ///   - playerHealth: Current player health value
    ///   - playerBalance: Current player balance (0-100 scale)
    ///   - worldFlags: Current world flags dictionary
    /// - Returns: true if all requirements are met
    public func canMeet(
        playerFaith: Int,
        playerHealth: Int,
        playerBalance: Int,
        worldFlags: [String: Bool]
    ) -> Bool {
        if let minFaith = minimumFaith, playerFaith < minFaith {
            return false
        }
        if let minHealth = minimumHealth, playerHealth < minHealth {
            return false
        }
        if let reqBalance = requiredBalance {
            // Check player balance (0-100 scale)
            let playerBalanceEnum: CardBalance
            if playerBalance >= 70 {
                playerBalanceEnum = .light
            } else if playerBalance <= 30 {
                playerBalanceEnum = .dark
            } else {
                playerBalanceEnum = .neutral
            }

            if playerBalanceEnum != reqBalance {
                return false
            }
        }
        if let reqFlags = requiredFlags {
            for flag in reqFlags {
                if worldFlags[flag] != true {
                    return false
                }
            }
        }
        return true
    }
}

// MARK: - Event Consequences

public struct EventConsequences: Codable, Hashable {
    public var faithChange: Int?
    public var healthChange: Int?
    public var balanceChange: Int?         // Light/Dark change (delta: +N shift to Light, -N to Dark)
    public var tensionChange: Int?
    public var reputationChange: Int?
    public var addCards: [String]?         // Card IDs to add
    public var addCurse: String?           // Curse ID
    public var giveArtifact: String?       // Artifact ID
    public var setFlags: [String: Bool]?   // Set flags
    public var anchorIntegrityChange: Int? // Anchor integrity change
    public var message: String?            // Message to player

    public init(
        faithChange: Int? = nil,
        healthChange: Int? = nil,
        balanceChange: Int? = nil,
        tensionChange: Int? = nil,
        reputationChange: Int? = nil,
        addCards: [String]? = nil,
        addCurse: String? = nil,
        giveArtifact: String? = nil,
        setFlags: [String: Bool]? = nil,
        anchorIntegrityChange: Int? = nil,
        message: String? = nil
    ) {
        self.faithChange = faithChange
        self.healthChange = healthChange
        self.balanceChange = balanceChange
        self.tensionChange = tensionChange
        self.reputationChange = reputationChange
        self.addCards = addCards
        self.addCurse = addCurse
        self.giveArtifact = giveArtifact
        self.setFlags = setFlags
        self.anchorIntegrityChange = anchorIntegrityChange
        self.message = message
    }
}

// MARK: - Game Event

public struct GameEvent: Identifiable, Codable, Hashable {
    public let id: UUID
    public let definitionId: String            // Content Pack ID (e.g., "village_elder_request")
    public let eventType: EventType
    public let title: String
    public let description: String
    public let regionTypes: [RegionType]       // In which region types can occur
    public let regionStates: [RegionState]     // In which states can occur
    public let choices: [EventChoice]
    public let questLinks: [String]            // Quest links
    public var oneTime: Bool                   // Happens only once
    public var completed: Bool                 // Already occurred
    public let monsterCard: Card?              // Monster card for combat events

    // New fields per documentation
    public let instant: Bool                   // true = no time cost (short narrative events)
    public let weight: Int                     // Weight for weighted selection (default 1)
    public let minTension: Int?                // Minimum tension level (0-100)
    public let maxTension: Int?                // Maximum tension level (0-100)
    public let requiredFlags: [String]?        // Flags that must be set
    public let forbiddenFlags: [String]?       // Flags that must NOT be set

    public init(
        id: UUID = UUID(),
        definitionId: String = "",
        eventType: EventType,
        title: String,
        description: String,
        regionTypes: [RegionType] = [],
        regionStates: [RegionState] = [.stable, .borderland, .breach],
        choices: [EventChoice],
        questLinks: [String] = [],
        oneTime: Bool = false,
        completed: Bool = false,
        monsterCard: Card? = nil,
        instant: Bool = false,
        weight: Int = 1,
        minTension: Int? = nil,
        maxTension: Int? = nil,
        requiredFlags: [String]? = nil,
        forbiddenFlags: [String]? = nil
    ) {
        self.id = id
        self.definitionId = definitionId
        self.eventType = eventType
        self.title = title
        self.description = description
        self.regionTypes = regionTypes
        self.regionStates = regionStates
        self.choices = choices
        self.questLinks = questLinks
        self.oneTime = oneTime
        self.completed = completed
        self.monsterCard = monsterCard
        self.instant = instant
        self.weight = max(1, weight)  // Minimum 1
        self.minTension = minTension
        self.maxTension = maxTension
        self.requiredFlags = requiredFlags
        self.forbiddenFlags = forbiddenFlags
    }

    // Check if event can occur in region
    public func canOccur(in region: Region) -> Bool {
        if completed && oneTime {
            return false
        }

        if !regionTypes.isEmpty && !regionTypes.contains(region.type) {
            return false
        }

        if !regionStates.contains(region.state) {
            return false
        }

        return true
    }

    /// Check with tension and world flags
    public func canOccur(in region: Region, worldTension: Int, worldFlags: [String: Bool]) -> Bool {
        // Basic checks
        guard canOccur(in: region) else { return false }

        // Check tension
        if let min = minTension, worldTension < min {
            return false
        }
        if let max = maxTension, worldTension > max {
            return false
        }

        // Check required flags
        if let required = requiredFlags {
            for flag in required {
                if worldFlags[flag] != true {
                    return false
                }
            }
        }

        // Check forbidden flags
        if let forbidden = forbiddenFlags {
            for flag in forbidden {
                if worldFlags[flag] == true {
                    return false
                }
            }
        }

        return true
    }
}

// MARK: - Quest Type

public enum QuestType: String, Codable {
    case main       // Main quest
    case side       // Side quest
}

// MARK: - Quest Objective

public struct QuestObjective: Identifiable, Codable {
    public let id: UUID
    public let description: String
    public var completed: Bool
    public var requiredFlags: [String]?  // Flags required to complete objective

    public init(id: UUID = UUID(), description: String, completed: Bool = false, requiredFlags: [String]? = nil) {
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
    public let id: UUID
    public let definitionId: String            // Content Pack ID (REQUIRED - Audit A1)
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
        id: UUID = UUID(),
        definitionId: String,
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
        self.definitionId = definitionId
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

// MARK: - Side Quest Theme

/// Side quest theme (affects tone and consequences)
/// See EXPLORATION_CORE_DESIGN.md, section 30.2
public enum SideQuestTheme: String, Codable {
    case consequence    // Consequence - world already suffered
    case warning        // Warning - can prevent degradation
    case temptation     // Temptation - quick gains for long-term damage
}

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

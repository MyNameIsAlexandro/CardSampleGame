/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Models/ExplorationModels+Event.swift
/// Назначение: Содержит реализацию файла ExplorationModels+Event.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

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
        id: String,
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
    public let id: String
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
        id: String,
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

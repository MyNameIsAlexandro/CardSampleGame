import Foundation

// MARK: - Event Definition
// Reference: Docs/EVENT_MODULE_ARCHITECTURE.md
// Reference: Docs/ENGINE_ARCHITECTURE.md, Section 4.1

/// Immutable definition of a game event.
/// Events can be Inline (resolve in flow) or Mini-Game (external module).
/// Runtime state (completion, cooldowns) lives in EventRuntimeState.
public struct EventDefinition: GameDefinition {
    // MARK: - Identity

    /// Unique event identifier (e.g., "event_forest_whispers")
    public let id: String

    // MARK: - Localized Content

    /// Event title (supports inline LocalizedString or StringKey)
    public let title: LocalizableText

    /// Event body/narrative text (supports inline LocalizedString or StringKey)
    public let body: LocalizableText

    // MARK: - Type Classification

    /// Event kind: inline or mini-game
    public let eventKind: EventKind

    // MARK: - Availability

    /// Conditions for this event to appear
    public let availability: Availability

    /// Event pool IDs this event belongs to
    public let poolIds: [String]

    /// Weight for random selection (higher = more likely)
    public let weight: Int

    // MARK: - Behavior Flags

    /// If true, event can only occur once per playthrough
    public let isOneTime: Bool

    /// If true, event resolves instantly (0 time cost)
    public let isInstant: Bool

    /// Cooldown in turns before event can reoccur (0 = no cooldown)
    public let cooldown: Int

    // MARK: - Content

    /// Choices available in this event (for inline events)
    public let choices: [ChoiceDefinition]

    /// Mini-game challenge (for mini-game events)
    public let miniGameChallenge: MiniGameChallengeDefinition?

    // MARK: - Initialization

    public init(
        id: String,
        title: LocalizableText,
        body: LocalizableText,
        eventKind: EventKind = .inline,
        availability: Availability = .always,
        poolIds: [String] = [],
        weight: Int = 10,
        isOneTime: Bool = false,
        isInstant: Bool = false,
        cooldown: Int = 0,
        choices: [ChoiceDefinition] = [],
        miniGameChallenge: MiniGameChallengeDefinition? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.eventKind = eventKind
        self.availability = availability
        self.poolIds = poolIds
        self.weight = weight
        self.isOneTime = isOneTime
        self.isInstant = isInstant
        self.cooldown = cooldown
        self.choices = choices
        self.miniGameChallenge = miniGameChallenge
    }
}

// MARK: - Event Kind

/// Classification of event kinds (Engine-specific, distinct from legacy EventType)
/// Reference: Docs/EVENT_MODULE_ARCHITECTURE.md, Section 2
public enum EventKind: Codable, Hashable {
    /// Inline event - resolves within main game flow
    case inline

    /// Mini-game event - dispatches to external module
    case miniGame(MiniGameKind)

    /// All mini-game kinds
    public enum MiniGameKind: String, Codable, Hashable {
        case combat
        case ritual
        case exploration
        case dialogue
        case puzzle
    }

    // MARK: - Custom Codable

    /// Coding keys for JSON object format
    /// Note: When decoder uses convertFromSnakeCase, the JSON key "mini_game"
    /// is already converted to "miniGame", so we use that directly
    private enum CodingKeys: String, CodingKey {
        case miniGame
        // Alternative key for when convertFromSnakeCase is NOT used
        case miniGameSnake = "mini_game"
    }

    public init(from decoder: Decoder) throws {
        // Try decoding as a simple string first: "inline"
        if let container = try? decoder.singleValueContainer(),
           let stringValue = try? container.decode(String.self) {
            if stringValue == "inline" {
                self = .inline
            } else if let miniGameKind = MiniGameKind(rawValue: stringValue) {
                // Handle direct mini-game string: "combat", "ritual", etc.
                self = .miniGame(miniGameKind)
            } else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unknown event kind: \(stringValue)"
                )
            }
            return
        }

        // Try decoding as object: {"mini_game": "combat"}
        // Try both key formats to support convertFromSnakeCase and regular decoding
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let miniGameString: String
        if let value = try container.decodeIfPresent(String.self, forKey: .miniGame) {
            miniGameString = value
        } else if let value = try container.decodeIfPresent(String.self, forKey: .miniGameSnake) {
            miniGameString = value
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.miniGame,
                DecodingError.Context(codingPath: container.codingPath, debugDescription: "Neither 'miniGame' nor 'mini_game' found")
            )
        }

        if let miniGameKind = MiniGameKind(rawValue: miniGameString) {
            self = .miniGame(miniGameKind)
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .miniGame,
                in: container,
                debugDescription: "Unknown mini-game kind: \(miniGameString)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .inline:
            var container = encoder.singleValueContainer()
            try container.encode("inline")
        case .miniGame(let kind):
            // Always encode with snake_case for JSON compatibility
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(kind.rawValue, forKey: .miniGameSnake)
        }
    }
}

// MARK: - Choice Definition

/// Immutable definition of a choice within an event.
public struct ChoiceDefinition: Codable, Hashable, Identifiable {
    // MARK: - Identity

    /// Unique choice identifier within the event
    public let id: String

    // MARK: - Localized Content

    /// Choice button text (supports inline LocalizedString or StringKey)
    public let label: LocalizableText

    /// Optional choice tooltip/description (supports inline LocalizedString or StringKey)
    public let tooltip: LocalizableText?

    // MARK: - Requirements

    /// Conditions for this choice to be available
    public let requirements: ChoiceRequirements?

    // MARK: - Consequences

    /// Outcomes when this choice is selected
    public let consequences: ChoiceConsequences

    // MARK: - Initialization

    public init(
        id: String,
        label: LocalizableText,
        tooltip: LocalizableText? = nil,
        requirements: ChoiceRequirements? = nil,
        consequences: ChoiceConsequences
    ) {
        self.id = id
        self.label = label
        self.tooltip = tooltip
        self.requirements = requirements
        self.consequences = consequences
    }
}

// MARK: - Choice Requirements

/// Requirements that must be met to select a choice
public struct ChoiceRequirements: Codable, Hashable {
    /// Minimum resource values required
    public let minResources: [String: Int]

    /// Flags that must be set
    public let requiredFlags: [String]

    /// Flags that must NOT be set
    public let forbiddenFlags: [String]

    /// Minimum balance required (nil = no minimum)
    public let minBalance: Int?

    /// Maximum balance allowed (nil = no maximum)
    public let maxBalance: Int?

    public init(
        minResources: [String: Int] = [:],
        requiredFlags: [String] = [],
        forbiddenFlags: [String] = [],
        minBalance: Int? = nil,
        maxBalance: Int? = nil
    ) {
        self.minResources = minResources
        self.requiredFlags = requiredFlags
        self.forbiddenFlags = forbiddenFlags
        self.minBalance = minBalance
        self.maxBalance = maxBalance
    }

    /// Convenience initializer with balance range
    public init(
        minResources: [String: Int] = [:],
        requiredFlags: [String] = [],
        forbiddenFlags: [String] = [],
        balanceRange: ClosedRange<Int>?
    ) {
        self.minResources = minResources
        self.requiredFlags = requiredFlags
        self.forbiddenFlags = forbiddenFlags
        self.minBalance = balanceRange?.lowerBound
        self.maxBalance = balanceRange?.upperBound
    }

    /// Check if requirements can be met with given context
    /// - Note: Prefer using `Requirements.evaluator.canMeet(requirements:...)` instead
    ///   for cleaner separation of data and logic (see ENGINE_ARCHITECTURE.md)
    @available(*, deprecated, message: "Use Requirements.evaluator.canMeet() instead")
    public func canMeet(resources: [String: Int], flags: Set<String>, balance: Int) -> Bool {
        // Check resources
        for (resourceId, minValue) in minResources {
            if (resources[resourceId] ?? 0) < minValue {
                return false
            }
        }

        // Check required flags
        for flag in requiredFlags {
            if !flags.contains(flag) {
                return false
            }
        }

        // Check forbidden flags
        for flag in forbiddenFlags {
            if flags.contains(flag) {
                return false
            }
        }

        // Check balance range
        if let min = minBalance, balance < min {
            return false
        }
        if let max = maxBalance, balance > max {
            return false
        }

        return true
    }
}

// MARK: - Choice Consequences

/// Outcomes that occur when a choice is selected
public struct ChoiceConsequences: Codable, Hashable {
    /// Resource changes (costs and gains)
    public let resourceChanges: [String: Int]

    /// Flags to set
    public let setFlags: [String]

    /// Flags to clear
    public let clearFlags: [String]

    /// Balance change (-100 to +100)
    public let balanceDelta: Int

    /// Region state change (if any)
    public let regionStateChange: RegionStateChange?

    /// Quest progress trigger
    public let questProgress: QuestProgressTrigger?

    /// Follow-up event to trigger (if any)
    public let triggerEventId: String?

    /// Narrative result key (for UI display)
    public let resultKey: String?

    public init(
        resourceChanges: [String: Int] = [:],
        setFlags: [String] = [],
        clearFlags: [String] = [],
        balanceDelta: Int = 0,
        regionStateChange: RegionStateChange? = nil,
        questProgress: QuestProgressTrigger? = nil,
        triggerEventId: String? = nil,
        resultKey: String? = nil
    ) {
        self.resourceChanges = resourceChanges
        self.setFlags = setFlags
        self.clearFlags = clearFlags
        self.balanceDelta = balanceDelta
        self.regionStateChange = regionStateChange
        self.questProgress = questProgress
        self.triggerEventId = triggerEventId
        self.resultKey = resultKey
    }

    /// Empty consequences (no-op choice)
    public static let none = ChoiceConsequences()
}

// MARK: - Supporting Types

/// Region state change triggered by choice
public struct RegionStateChange: Codable, Hashable {
    /// Target region ID (nil = current region)
    public let regionId: String?

    /// New state to set
    public let newState: RegionStateType?

    /// State transition (degrade/restore)
    public let transition: StateTransition?

    public enum StateTransition: String, Codable, Hashable {
        case degrade
        case restore
    }
}

/// Quest progress trigger
public struct QuestProgressTrigger: Codable, Hashable {
    public let questId: String
    public let objectiveId: String?
    public let action: QuestAction

    public enum QuestAction: String, Codable, Hashable {
        case advance      // Move to next objective
        case complete     // Complete specific objective
        case fail         // Fail the quest
        case unlock       // Unlock the quest
    }
}

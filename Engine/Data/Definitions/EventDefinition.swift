import Foundation

// MARK: - Event Definition
// Reference: Docs/EVENT_MODULE_ARCHITECTURE.md
// Reference: Docs/ENGINE_ARCHITECTURE.md, Section 4.1

/// Immutable definition of a game event.
/// Events can be Inline (resolve in flow) or Mini-Game (external module).
/// Runtime state (completion, cooldowns) lives in EventRuntimeState.
struct EventDefinition: GameDefinition {
    // MARK: - Identity

    /// Unique event identifier (e.g., "event_forest_whispers")
    let id: String

    // MARK: - Localization Keys

    /// Localization key for event title
    let titleKey: String

    /// Localization key for event body/narrative text
    let bodyKey: String

    // MARK: - Type Classification

    /// Event type: inline or mini-game
    let eventType: EventType

    // MARK: - Availability

    /// Conditions for this event to appear
    let availability: Availability

    /// Event pool IDs this event belongs to
    let poolIds: [String]

    /// Weight for random selection (higher = more likely)
    let weight: Int

    // MARK: - Behavior Flags

    /// If true, event can only occur once per playthrough
    let isOneTime: Bool

    /// If true, event resolves instantly (0 time cost)
    let isInstant: Bool

    /// Cooldown in turns before event can reoccur (0 = no cooldown)
    let cooldown: Int

    // MARK: - Content

    /// Choices available in this event (for inline events)
    let choices: [ChoiceDefinition]

    /// Mini-game challenge (for mini-game events)
    let miniGameChallenge: MiniGameChallengeDefinition?

    // MARK: - Initialization

    init(
        id: String,
        titleKey: String,
        bodyKey: String,
        eventType: EventType = .inline,
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
        self.titleKey = titleKey
        self.bodyKey = bodyKey
        self.eventType = eventType
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

// MARK: - Event Type

/// Classification of event types
/// Reference: Docs/EVENT_MODULE_ARCHITECTURE.md, Section 2
enum EventType: Codable, Hashable {
    /// Inline event - resolves within main game flow
    case inline

    /// Mini-game event - dispatches to external module
    case miniGame(MiniGameType)

    /// All mini-game types
    enum MiniGameType: String, Codable, Hashable {
        case combat
        case ritual
        case exploration
        case dialogue
        case puzzle
    }
}

// MARK: - Choice Definition

/// Immutable definition of a choice within an event.
struct ChoiceDefinition: Codable, Hashable, Identifiable {
    // MARK: - Identity

    /// Unique choice identifier within the event
    let id: String

    // MARK: - Localization Keys

    /// Localization key for choice button text
    let labelKey: String

    /// Optional localization key for choice tooltip/description
    let tooltipKey: String?

    // MARK: - Requirements

    /// Conditions for this choice to be available
    let requirements: ChoiceRequirements?

    // MARK: - Consequences

    /// Outcomes when this choice is selected
    let consequences: ChoiceConsequences

    // MARK: - Initialization

    init(
        id: String,
        labelKey: String,
        tooltipKey: String? = nil,
        requirements: ChoiceRequirements? = nil,
        consequences: ChoiceConsequences
    ) {
        self.id = id
        self.labelKey = labelKey
        self.tooltipKey = tooltipKey
        self.requirements = requirements
        self.consequences = consequences
    }
}

// MARK: - Choice Requirements

/// Requirements that must be met to select a choice
struct ChoiceRequirements: Codable, Hashable {
    /// Minimum resource values required
    let minResources: [String: Int]

    /// Flags that must be set
    let requiredFlags: [String]

    /// Flags that must NOT be set
    let forbiddenFlags: [String]

    /// Balance range required
    let balanceRange: ClosedRange<Int>?

    init(
        minResources: [String: Int] = [:],
        requiredFlags: [String] = [],
        forbiddenFlags: [String] = [],
        balanceRange: ClosedRange<Int>? = nil
    ) {
        self.minResources = minResources
        self.requiredFlags = requiredFlags
        self.forbiddenFlags = forbiddenFlags
        self.balanceRange = balanceRange
    }

    /// Check if requirements can be met with given context
    func canMeet(resources: [String: Int], flags: Set<String>, balance: Int) -> Bool {
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

        // Check balance
        if let range = balanceRange, !range.contains(balance) {
            return false
        }

        return true
    }
}

// MARK: - Choice Consequences

/// Outcomes that occur when a choice is selected
struct ChoiceConsequences: Codable, Hashable {
    /// Resource changes (costs and gains)
    let resourceChanges: [String: Int]

    /// Flags to set
    let setFlags: [String]

    /// Flags to clear
    let clearFlags: [String]

    /// Balance change (-100 to +100)
    let balanceDelta: Int

    /// Region state change (if any)
    let regionStateChange: RegionStateChange?

    /// Quest progress trigger
    let questProgress: QuestProgressTrigger?

    /// Follow-up event to trigger (if any)
    let triggerEventId: String?

    /// Narrative result key (for UI display)
    let resultKey: String?

    init(
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
    static let none = ChoiceConsequences()
}

// MARK: - Supporting Types

/// Region state change triggered by choice
struct RegionStateChange: Codable, Hashable {
    /// Target region ID (nil = current region)
    let regionId: String?

    /// New state to set
    let newState: RegionStateType?

    /// State transition (degrade/restore)
    let transition: StateTransition?

    enum StateTransition: String, Codable, Hashable {
        case degrade
        case restore
    }
}

/// Quest progress trigger
struct QuestProgressTrigger: Codable, Hashable {
    let questId: String
    let objectiveId: String?
    let action: QuestAction

    enum QuestAction: String, Codable, Hashable {
        case advance      // Move to next objective
        case complete     // Complete specific objective
        case fail         // Fail the quest
        case unlock       // Unlock the quest
    }
}

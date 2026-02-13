/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Data/Definitions/EventDefinition+Choice.swift
/// Назначение: Содержит реализацию файла EventDefinition+Choice.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Choice Definition

/// Immutable definition of a choice within an event.
public struct ChoiceDefinition: Codable, Hashable, Identifiable {
    // MARK: - Identity

    /// Unique choice identifier within the event
    public var id: String

    // MARK: - Localized Content

    /// Choice button text (supports inline LocalizedString or StringKey)
    public var label: LocalizableText

    /// Optional choice tooltip/description (supports inline LocalizedString or StringKey)
    public var tooltip: LocalizableText?

    // MARK: - Requirements

    /// Conditions for this choice to be available
    public var requirements: ChoiceRequirements?

    // MARK: - Consequences

    /// Outcomes when this choice is selected
    public var consequences: ChoiceConsequences

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
    public var minResources: [String: Int]

    /// Flags that must be set
    public var requiredFlags: [String]

    /// Flags that must NOT be set
    public var forbiddenFlags: [String]

    /// Minimum balance required (nil = no minimum)
    public var minBalance: Int?

    /// Maximum balance allowed (nil = no maximum)
    public var maxBalance: Int?

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

}

// MARK: - Choice Consequences

/// Outcomes that occur when a choice is selected
public struct ChoiceConsequences: Codable, Hashable, Sendable {
    /// Resource changes (costs and gains)
    public var resourceChanges: [String: Int]

    /// Flags to set
    public var setFlags: [String]

    /// Flags to clear
    public var clearFlags: [String]

    /// Balance change (-100 to +100)
    public var balanceDelta: Int

    /// Region state change (if any)
    public var regionStateChange: RegionStateChange?

    /// Quest progress trigger
    public var questProgress: QuestProgressTrigger?

    /// Follow-up event to trigger (if any)
    public var triggerEventId: String?

    /// Narrative result key (for UI display)
    public var resultKey: String?

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

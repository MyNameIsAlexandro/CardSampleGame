/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Data/Definitions/EventDefinition.swift
/// Назначение: Содержит реализацию файла EventDefinition.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

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
    public var id: String

    // MARK: - Localized Content

    /// Event title (supports inline LocalizedString or StringKey)
    public var title: LocalizableText

    /// Event body/narrative text (supports inline LocalizedString or StringKey)
    public var body: LocalizableText

    // MARK: - Type Classification

    /// Event kind: inline or mini-game
    public var eventKind: EventKind

    // MARK: - Availability

    /// Conditions for this event to appear
    public var availability: Availability

    /// Event pool IDs this event belongs to
    public var poolIds: [String]

    /// Weight for random selection (higher = more likely)
    public var weight: Int

    // MARK: - Behavior Flags

    /// If true, event can only occur once per playthrough
    public var isOneTime: Bool

    /// If true, event resolves instantly (0 time cost)
    public var isInstant: Bool

    /// Cooldown in turns before event can reoccur (0 = no cooldown)
    public var cooldown: Int

    // MARK: - Content

    /// Choices available in this event (for inline events)
    public var choices: [ChoiceDefinition]

    /// Mini-game challenge (for mini-game events)
    public var miniGameChallenge: MiniGameChallengeDefinition?

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

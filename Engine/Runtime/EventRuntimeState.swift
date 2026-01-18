import Foundation

// MARK: - Event Runtime State
// Reference: Docs/EVENT_MODULE_ARCHITECTURE.md, Section 5
// Reference: Docs/MIGRATION_PLAN.md, Feature A2

/// Mutable runtime state for the event system.
/// Tracks which events have been completed, cooldowns, etc.
struct EventRuntimeState: Codable, Equatable {
    // MARK: - Completion Tracking

    /// Set of completed one-time event IDs
    var completedOneTimeEvents: Set<String>

    /// Count of times each event has occurred
    var eventOccurrenceCount: [String: Int]

    // MARK: - Cooldowns

    /// Cooldown remaining for each event (turns until available)
    var eventCooldowns: [String: Int]

    // MARK: - Current Event

    /// Currently active event ID (nil if no event active)
    var activeEventId: String?

    /// Currently active mini-game challenge (nil if no mini-game active)
    var activeMiniGameId: String?

    // MARK: - Selection State

    /// Last used random seed for deterministic replay
    var lastSelectionSeed: UInt64

    // MARK: - Initialization

    init(
        completedOneTimeEvents: Set<String> = [],
        eventOccurrenceCount: [String: Int] = [:],
        eventCooldowns: [String: Int] = [:],
        activeEventId: String? = nil,
        activeMiniGameId: String? = nil,
        lastSelectionSeed: UInt64 = 0
    ) {
        self.completedOneTimeEvents = completedOneTimeEvents
        self.eventOccurrenceCount = eventOccurrenceCount
        self.eventCooldowns = eventCooldowns
        self.activeEventId = activeEventId
        self.activeMiniGameId = activeMiniGameId
        self.lastSelectionSeed = lastSelectionSeed
    }

    // MARK: - Completion Operations

    /// Mark an event as completed
    mutating func markCompleted(_ eventId: String, isOneTime: Bool) {
        eventOccurrenceCount[eventId, default: 0] += 1
        if isOneTime {
            completedOneTimeEvents.insert(eventId)
        }
    }

    /// Check if a one-time event is completed
    func isOneTimeCompleted(_ eventId: String) -> Bool {
        return completedOneTimeEvents.contains(eventId)
    }

    /// Get occurrence count for an event
    func occurrenceCount(for eventId: String) -> Int {
        return eventOccurrenceCount[eventId] ?? 0
    }

    // MARK: - Cooldown Operations

    /// Set cooldown for an event
    mutating func setCooldown(_ eventId: String, turns: Int) {
        if turns > 0 {
            eventCooldowns[eventId] = turns
        }
    }

    /// Check if event is on cooldown
    func isOnCooldown(_ eventId: String) -> Bool {
        return (eventCooldowns[eventId] ?? 0) > 0
    }

    /// Tick all cooldowns (call each turn)
    mutating func tickCooldowns() {
        for (eventId, remaining) in eventCooldowns {
            if remaining > 1 {
                eventCooldowns[eventId] = remaining - 1
            } else {
                eventCooldowns.removeValue(forKey: eventId)
            }
        }
    }

    // MARK: - Active Event Operations

    /// Start an event
    mutating func startEvent(_ eventId: String) {
        activeEventId = eventId
    }

    /// End the current event
    mutating func endEvent() {
        activeEventId = nil
        activeMiniGameId = nil
    }

    /// Start a mini-game within current event
    mutating func startMiniGame(_ challengeId: String) {
        activeMiniGameId = challengeId
    }

    /// End the current mini-game
    mutating func endMiniGame() {
        activeMiniGameId = nil
    }
}

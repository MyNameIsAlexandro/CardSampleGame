/// Файл: Packages/TwilightEngine/Sources/TwilightEngineDevTools/Events/EventPipeline.swift
/// Назначение: Содержит реализацию файла EventPipeline.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation
import TwilightEngine

// MARK: - Event Pipeline
// Handles the complete flow: Selection → Resolution → Consequences

// MARK: - Choice Availability

/// Reason why an event choice is not currently available.
public enum EventChoiceUnavailableReason: Equatable, Sendable {
    case invalidChoiceIndex(index: Int, maxIndex: Int)
    case insufficientResource(resource: String, required: Int, available: Int)
    case missingFlag(String)
}

/// Main event processing pipeline
public final class EventPipeline {
    // MARK: - Dependencies

    private let selector: EventSelector
    private let resolver: EventResolver

    // MARK: - Initialization

    public init(
        selector: EventSelector = EventSelector(),
        resolver: EventResolver = EventResolver()
    ) {
        self.selector = selector
        self.resolver = resolver
    }

    // MARK: - Pipeline Methods

    /// Process a trigger and return available events
    public func getAvailableEvents(
        for context: EventContext,
        from events: [GameEvent]
    ) -> [GameEvent] {
        return selector.selectAvailableEvents(from: events, context: context)
    }

    /// Select a single event based on weights
    public func selectEvent(
        from events: [GameEvent],
        context: EventContext,
        rng: WorldRNG
    ) -> GameEvent? {
        let available = selector.selectAvailableEvents(from: events, context: context)
        return selector.weightedSelect(from: available, rng: rng)
    }

    /// Resolve an event choice and return state changes
    public func resolveChoice(
        event: GameEvent,
        choiceIndex: Int,
        context: EventResolutionContext
    ) -> EventResolutionResult {
        return resolver.resolve(event: event, choiceIndex: choiceIndex, context: context)
    }

    /// Check if a choice is available
    public func canChoose(
        event: GameEvent,
        choiceIndex: Int,
        context: EventContext
    ) -> (available: Bool, reason: EventChoiceUnavailableReason?) {
        guard choiceIndex < event.choices.count else {
            return (false, .invalidChoiceIndex(index: choiceIndex, maxIndex: max(0, event.choices.count - 1)))
        }

        let choice = event.choices[choiceIndex]

        // Check requirements if present
        guard let requirements = choice.requirements else {
            return (true, nil)  // No requirements = always available
        }

        // Check minimum faith
        if let minFaith = requirements.minimumFaith {
            let currentFaith = context.resources["faith"] ?? 0
            if currentFaith < minFaith {
                return (false, .insufficientResource(resource: "faith", required: minFaith, available: currentFaith))
            }
        }

        // Check minimum health
        if let minHealth = requirements.minimumHealth {
            let currentHealth = context.resources["health"] ?? 0
            if currentHealth < minHealth {
                return (false, .insufficientResource(resource: "health", required: minHealth, available: currentHealth))
            }
        }

        // Check required flags
        if let requiredFlags = requirements.requiredFlags {
            for flag in requiredFlags {
                if context.flags[flag] != true {
                    return (false, .missingFlag(flag))
                }
            }
        }

        return (true, nil)
    }
}

// MARK: - Event Selector

/// Handles event filtering and weighted selection
public final class EventSelector {
    public init() {}

    // MARK: - Selection

    /// Filter events by availability criteria
    public func selectAvailableEvents(
        from events: [GameEvent],
        context: EventContext
    ) -> [GameEvent] {
        return events.filter { event in
            isEventAvailable(event, context: context)
        }
    }

    /// Check if single event is available based on GameEvent's actual properties
    public func isEventAvailable(_ event: GameEvent, context: EventContext) -> Bool {
        // Check if already completed (for oneTime events)
        if event.oneTime && event.completed {
            return false
        }

        // Also check against context's completed set (uses stable definitionId, not UUID)
        if event.oneTime && context.completedEvents.contains(event.id) {
            return false
        }

        // Check region type requirements (empty = any region)
        if !event.regionTypes.isEmpty {
            guard let regionType = RegionType(rawValue: context.currentLocation) else {
                return false
            }
            if !event.regionTypes.contains(regionType) {
                return false
            }
        }

        // Check region state requirements (empty = any state)
        if !event.regionStates.isEmpty {
            guard let regionState = RegionState(rawValue: context.locationState) else {
                return false
            }
            if !event.regionStates.contains(regionState) {
                return false
            }
        }

        // Check event's required flags against context flags
        if let eventRequiredFlags = event.requiredFlags {
            for flag in eventRequiredFlags where context.flags[flag] != true {
                return false
            }
        }

        // Check event's forbidden flags
        if let forbiddenFlags = event.forbiddenFlags {
            for flag in forbiddenFlags where context.flags[flag] == true {
                return false
            }
        }

        return true
    }

    /// Select event using weighted random selection
    public func weightedSelect(from events: [GameEvent], rng: WorldRNG) -> GameEvent? {
        guard !events.isEmpty else { return nil }

        let totalWeight = events.reduce(0) { $0 + $1.weight }

        guard totalWeight > 0 else {
            // If all weights are 0, select randomly
            let index = rng.nextInt(in: 0...(events.count - 1))
            return events[index]
        }

        let roll = rng.nextInt(in: 0...(totalWeight - 1))
        var cumulative = 0

        for event in events {
            cumulative += event.weight
            if roll < cumulative {
                return event
            }
        }

        // Fallback (shouldn't reach here)
        return events.last
    }
}

// MARK: - Event Resolver

/// Handles event resolution and consequence calculation
public final class EventResolver {
    public init() {}

    // MARK: - Resolution

    /// Resolve an event choice
    public func resolve(
        event: GameEvent,
        choiceIndex: Int,
        context: EventResolutionContext
    ) -> EventResolutionResult {
        guard choiceIndex < event.choices.count else {
            return EventResolutionResult(
                success: false,
                error: "Invalid choice index",
                stateChanges: [],
                triggeredCombat: nil,
                triggeredMiniGame: nil,
                narrativeText: nil
            )
        }

        let choice = event.choices[choiceIndex]
        var stateChanges: [StateChange] = []

        // Apply consequences
        let consequences = choice.consequences

        // Health changes (optional Int?)
        if let healthDelta = consequences.healthChange, healthDelta != 0 {
            let newHealth = max(0, context.currentHealth + healthDelta)
            stateChanges.append(.healthChanged(
                delta: healthDelta,
                newValue: newHealth
            ))
        }

        // Faith changes (optional Int?)
        if let faithDelta = consequences.faithChange, faithDelta != 0 {
            let newFaith = max(0, context.currentFaith + faithDelta)
            stateChanges.append(.faithChanged(
                delta: faithDelta,
                newValue: newFaith
            ))
        }

        // Balance changes (optional Int?)
        if let balanceDelta = consequences.balanceChange, balanceDelta != 0 {
            let newBalance = max(0, min(100, context.currentBalance + balanceDelta))
            stateChanges.append(.balanceChanged(
                delta: balanceDelta,
                newValue: newBalance
            ))
        }

        // Tension changes (optional Int?)
        if let tensionDelta = consequences.tensionChange, tensionDelta != 0 {
            let newTension = max(0, min(100, context.currentTension + tensionDelta))
            stateChanges.append(.tensionChanged(
                delta: tensionDelta,
                newValue: newTension
            ))
        }

        // Set flags (optional dictionary)
        if let flagsToSet = consequences.setFlags {
            for (flag, value) in flagsToSet {
                stateChanges.append(.flagSet(key: flag, value: value))
            }
        }

        // Check for triggered combat (monster card in event)
        var triggeredCombat: String? = nil
        if event.monsterCard != nil {
            // Combat events have monsterCard, use event ID as combat trigger
            triggeredCombat = event.id
        }

        // Check for triggered mini-game (not directly in EventConsequences,
        // would be triggered through specific event types or flags)
        let triggeredMiniGame: String? = nil

        // Mark event as completed if oneTime
        if event.oneTime {
            stateChanges.append(.eventCompleted(eventId: event.id))
        }

        return EventResolutionResult(
            success: true,
            error: nil,
            stateChanges: stateChanges,
            triggeredCombat: triggeredCombat,
            triggeredMiniGame: triggeredMiniGame,
            narrativeText: consequences.message
        )
    }
}

// MARK: - Supporting Types
// Note: EventContext is defined in EngineProtocols.swift

/// Context for event resolution
public struct EventResolutionContext {
    public let currentHealth: Int
    public let currentFaith: Int
    public let currentBalance: Int
    public let currentTension: Int
    public let currentFlags: [String: Bool]

    public init(
        currentHealth: Int,
        currentFaith: Int,
        currentBalance: Int,
        currentTension: Int,
        currentFlags: [String: Bool]
    ) {
        self.currentHealth = currentHealth
        self.currentFaith = currentFaith
        self.currentBalance = currentBalance
        self.currentTension = currentTension
        self.currentFlags = currentFlags
    }
}

/// Result of event resolution
public struct EventResolutionResult {
    public let success: Bool
    public let error: String?
    public let stateChanges: [StateChange]
    public let triggeredCombat: String?
    public let triggeredMiniGame: String?
    public let narrativeText: String?
}

/// Event filter criteria for selection (different from EventRequirements in ExplorationModels)
public struct EventFilterCriteria: Sendable {
    public var location: String?
    public var locationState: String?
    public var pressureRange: ClosedRange<Int>?
    public var requiredFlags: [String] = []
    public var forbiddenFlags: [String] = []
    public var minResources: [String: Int] = [:]

    public static let none = EventFilterCriteria()
}

// MARK: - GameEvent Extension

extension GameEvent {
    /// Event filter criteria for engine filtering
    public var filterCriteria: EventFilterCriteria {
        // Build filter criteria from event data
        // Note: Full implementation would extract criteria from regionTypes/regionStates
        let criteria = EventFilterCriteria()
        return criteria
    }
}

// Note: EventConsequences doesn't have triggeredEncounter or triggeredMiniGame
// Combat is triggered through GameEvent.monsterCard != nil
// Mini-games are triggered through specific event types or game logic

import Foundation

// MARK: - Event Pipeline
// Handles the complete flow: Selection → Resolution → Consequences

/// Main event processing pipeline
final class EventPipeline {
    // MARK: - Dependencies

    private let selector: EventSelector
    private let resolver: EventResolver
    private let requirementsEvaluator: RequirementsEvaluator

    // MARK: - Initialization

    init(
        selector: EventSelector = EventSelector(),
        resolver: EventResolver = EventResolver(),
        requirementsEvaluator: RequirementsEvaluator = RequirementsEvaluator()
    ) {
        self.selector = selector
        self.resolver = resolver
        self.requirementsEvaluator = requirementsEvaluator
    }

    // MARK: - Pipeline Methods

    /// Process a trigger and return available events
    func getAvailableEvents(
        for context: EventContext,
        from events: [GameEvent]
    ) -> [GameEvent] {
        return selector.selectAvailableEvents(from: events, context: context)
    }

    /// Select a single event based on weights
    func selectEvent(
        from events: [GameEvent],
        context: EventContext
    ) -> GameEvent? {
        let available = selector.selectAvailableEvents(from: events, context: context)
        return selector.weightedSelect(from: available)
    }

    /// Resolve an event choice and return state changes
    func resolveChoice(
        event: GameEvent,
        choiceIndex: Int,
        context: EventResolutionContext
    ) -> EventResolutionResult {
        return resolver.resolve(event: event, choiceIndex: choiceIndex, context: context)
    }

    /// Check if a choice is available
    func canChoose(
        event: GameEvent,
        choiceIndex: Int,
        context: EventContext
    ) -> (available: Bool, reason: String?) {
        guard choiceIndex < event.choices.count else {
            return (false, "Invalid choice index")
        }

        let choice = event.choices[choiceIndex]

        // Check requirements
        let reqsMet = requirementsEvaluator.evaluate(
            requirements: choice.requirements,
            context: context
        )

        if !reqsMet.allSatisfied {
            return (false, reqsMet.failureReasons.first)
        }

        return (true, nil)
    }
}

// MARK: - Event Selector

/// Handles event filtering and weighted selection
final class EventSelector {
    // MARK: - Selection

    /// Filter events by availability criteria
    func selectAvailableEvents(
        from events: [GameEvent],
        context: EventContext
    ) -> [GameEvent] {
        return events.filter { event in
            isEventAvailable(event, context: context)
        }
    }

    /// Check if single event is available based on GameEvent's actual properties
    func isEventAvailable(_ event: GameEvent, context: EventContext) -> Bool {
        // Check if already completed (for oneTime events)
        if event.oneTime && event.completed {
            return false
        }

        // Also check against context's completed set
        if event.oneTime && context.completedEvents.contains(event.id.uuidString) {
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

        // Check required flags (from context)
        for flag in context.requiredFlags where context.flags[flag] != true {
            return false
        }

        return true
    }

    /// Select event using weighted random selection
    func weightedSelect(from events: [GameEvent]) -> GameEvent? {
        guard !events.isEmpty else { return nil }

        let totalWeight = events.reduce(0) { $0 + $1.weight }

        guard totalWeight > 0 else {
            // If all weights are 0, select randomly
            let index = WorldRNG.shared.nextInt(in: 0..<events.count)
            return events[index]
        }

        let roll = WorldRNG.shared.nextInt(in: 0..<totalWeight)
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
final class EventResolver {
    // MARK: - Resolution

    /// Resolve an event choice
    func resolve(
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
        var triggeredCombat: UUID? = nil
        if event.monsterCard != nil {
            // Combat events have monsterCard, use event ID as combat trigger
            triggeredCombat = event.id
        }

        // Check for triggered mini-game (not directly in EventConsequences,
        // would be triggered through specific event types or flags)
        let triggeredMiniGame: UUID? = nil

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
struct EventResolutionContext {
    let currentHealth: Int
    let currentFaith: Int
    let currentBalance: Int
    let currentTension: Int
    let currentFlags: [String: Bool]
}

/// Result of event resolution
struct EventResolutionResult {
    let success: Bool
    let error: String?
    let stateChanges: [StateChange]
    let triggeredCombat: UUID?
    let triggeredMiniGame: UUID?
    let narrativeText: String?
}

/// Event filter criteria for selection (different from EventRequirements in ExplorationModels)
struct EventFilterCriteria {
    var location: String?
    var locationState: String?
    var pressureRange: ClosedRange<Int>?
    var requiredFlags: [String] = []
    var forbiddenFlags: [String] = []
    var minResources: [String: Int] = [:]

    static let none = EventFilterCriteria()
}

// MARK: - GameEvent Extension

extension GameEvent {
    /// Event filter criteria for engine filtering
    var filterCriteria: EventFilterCriteria {
        // Build filter criteria from event data
        var criteria = EventFilterCriteria()

        // Extract from regionTypes if present
        if !regionTypes.isEmpty {
            // Location type requirement
        }

        // Extract from regionStates if present
        if !regionStates.isEmpty {
            // Location state requirement
        }

        return criteria
    }
}

// Note: EventConsequences doesn't have triggeredEncounter or triggeredMiniGame
// Combat is triggered through GameEvent.monsterCard != nil
// Mini-games are triggered through specific event types or game logic

import Foundation

// MARK: - Active Curse
// Tracking for curses applied to the player

/// Represents an active curse on the player
public struct ActiveCurse: Identifiable, Codable {
    public let id: UUID
    public let type: CurseType
    public var duration: Int  // turns remaining
    public let sourceCard: String?  // name of card that applied curse

    public init(id: UUID = UUID(), type: CurseType, duration: Int, sourceCard: String? = nil) {
        self.id = id
        self.type = type
        self.duration = duration
        self.sourceCard = sourceCard
    }
}

// MARK: - Event Log Entry

/// Record in the event log
public struct EventLogEntry: Identifiable, Codable {
    public let id: UUID
    public let dayNumber: Int
    public let timestamp: Date
    public let regionName: String
    public let eventTitle: String
    public let choiceMade: String
    public let outcome: String
    public let type: EventLogType

    public init(
        id: UUID = UUID(),
        dayNumber: Int,
        timestamp: Date = Date(),
        regionName: String,
        eventTitle: String,
        choiceMade: String,
        outcome: String,
        type: EventLogType
    ) {
        self.id = id
        self.dayNumber = dayNumber
        self.timestamp = timestamp
        self.regionName = regionName
        self.eventTitle = eventTitle
        self.choiceMade = choiceMade
        self.outcome = outcome
        self.type = type
    }
}

/// Type of event log entry
public enum EventLogType: String, Codable {
    case exploration    // Exploration
    case combat         // Combat
    case choice         // Choice
    case quest          // Quest
    case travel         // Travel
    case worldChange    // World change

    public var icon: String {
        switch self {
        case .exploration: return "magnifyingglass"
        case .combat: return "swords"
        case .choice: return "questionmark.circle"
        case .quest: return "scroll"
        case .travel: return "figure.walk"
        case .worldChange: return "globe"
        }
    }
}

// MARK: - Day Event

/// Event that occurred at the end of a day (for notifications)
public struct DayEvent: Identifiable {
    public let id = UUID()
    public let day: Int
    public let title: String
    public let description: String
    public let isNegative: Bool

    public init(day: Int, title: String, description: String, isNegative: Bool) {
        self.day = day
        self.title = title
        self.description = description
        self.isNegative = isNegative
    }

    public static func tensionIncrease(day: Int, newTension: Int) -> DayEvent {
        DayEvent(
            day: day,
            title: "Напряжение растёт",
            description: "Напряжение мира достигло \(newTension)%",
            isNegative: true
        )
    }

    public static func regionDegraded(day: Int, regionName: String, newState: RegionState) -> DayEvent {
        DayEvent(
            day: day,
            title: "Регион деградирует",
            description: "\(regionName) теперь в состоянии \(newState.displayName)",
            isNegative: true
        )
    }

    public static func worldImproving(day: Int) -> DayEvent {
        DayEvent(
            day: day,
            title: "Мир восстанавливается",
            description: "Силы Яви укрепляются",
            isNegative: false
        )
    }
}

// MARK: - Game End Result
// Note: GameEndResult is defined in Core/GameLoop.swift

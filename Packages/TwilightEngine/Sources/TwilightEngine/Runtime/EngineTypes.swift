/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Runtime/EngineTypes.swift
/// Назначение: Содержит реализацию файла EngineTypes.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Active Curse
// Tracking for curses applied to the player

/// Represents an active curse on the player
public struct ActiveCurse: Identifiable, Codable {
    public let id: String
    public let type: CurseType
    public var duration: Int  // turns remaining
    public let sourceCard: String?  // name of card that applied curse

    public init(id: String? = nil, type: CurseType, duration: Int, sourceCard: String? = nil) {
        self.id = id ?? "curse_\(type)_\(duration)"
        self.type = type
        self.duration = duration
        self.sourceCard = sourceCard
    }
}

// MARK: - Event Log Entry

/// Record in the event log
public struct EventLogEntry: Identifiable, Codable {
    public let id: String
    public let dayNumber: Int
    public let timestamp: Date
    public let regionName: String
    public let eventTitle: String
    public let choiceMade: String
    public let outcome: String
    public let type: EventLogType

    public init(
        id: String? = nil,
        dayNumber: Int,
        timestamp: Date = Date(),
        regionName: String,
        eventTitle: String,
        choiceMade: String,
        outcome: String,
        type: EventLogType
    ) {
        self.id = id ?? "log_day\(dayNumber)_\(eventTitle.prefix(10).lowercased().replacingOccurrences(of: " ", with: "_"))"
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
    public let id: String
    public let day: Int
    public let title: String
    public let description: String
    public let isNegative: Bool

    public init(day: Int, title: String, description: String, isNegative: Bool, id: String? = nil) {
        self.id = id ?? "day_\(day)_\(title.prefix(10).lowercased().replacingOccurrences(of: " ", with: "_"))"
        self.day = day
        self.title = title
        self.description = description
        self.isNegative = isNegative
    }

    public static func tensionIncrease(day: Int, newTension: Int) -> DayEvent {
        DayEvent(
            day: day,
            title: L10n.dayEventTensionIncreaseTitle.localized,
            description: L10n.dayEventTensionIncreaseDescription.localized(with: newTension),
            isNegative: true,
            id: "day_\(day)_tension_increase"
        )
    }

    public static func regionDegraded(day: Int, regionName: String, newState: RegionState) -> DayEvent {
        DayEvent(
            day: day,
            title: L10n.dayEventRegionDegradedTitle.localized,
            description: L10n.dayEventRegionDegradedDescription.localized(with: regionName, newState.displayName),
            isNegative: true,
            id: "day_\(day)_region_degraded_\(regionName.prefix(10).lowercased().replacingOccurrences(of: " ", with: "_"))"
        )
    }

    public static func worldImproving(day: Int) -> DayEvent {
        DayEvent(
            day: day,
            title: L10n.dayEventWorldImprovingTitle.localized,
            description: L10n.dayEventWorldImprovingDescription.localized,
            isNegative: false,
            id: "day_\(day)_world_improving"
        )
    }
}

// MARK: - Game End Result
// Note: GameEndResult is defined in Core/EngineProtocols.swift

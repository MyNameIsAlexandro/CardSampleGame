/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/EngineProtocols+EventDefinitions.swift
/// Назначение: Содержит реализацию файла EngineProtocols+EventDefinitions.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 3. Event System Definitions
// ═══════════════════════════════════════════════════════════════════════════════

/// Abstract event definition protocol (setting-agnostic)
/// Concrete implementation: Engine/Data/Definitions/EventDefinition.swift
public protocol EventDefinitionProtocol {
    associatedtype ChoiceType: ChoiceDefinitionProtocol

    var id: String { get }
    var title: String { get }
    var description: String { get }
    var choices: [ChoiceType] { get }

    /// Whether this event consumes time
    var isInstant: Bool { get }

    /// Whether this event can only occur once
    var isOneTime: Bool { get }

    /// Check if event can occur given current context
    func canOccur(in context: EventContext) -> Bool
}

/// Abstract choice definition protocol
/// Concrete implementation: Engine/Data/Definitions/EventDefinition.swift (ChoiceDefinition struct)
public protocol ChoiceDefinitionProtocol {
    associatedtype RequirementsType: RequirementsDefinitionProtocol
    associatedtype ConsequencesType: ConsequencesDefinitionProtocol

    var id: String { get }
    var text: String { get }
    var requirements: RequirementsType? { get }
    var consequences: ConsequencesType { get }
}

/// Abstract requirements protocol (gating conditions)
public protocol RequirementsDefinitionProtocol {
    func canMeet(with resources: ResourceProvider) -> Bool
}

/// Abstract consequences protocol (outcomes)
public protocol ConsequencesDefinitionProtocol {
    /// Resource changes (positive or negative)
    var resourceChanges: [String: Int] { get }

    /// Flags to set
    var flagsToSet: [String: Bool] { get }

    /// Custom effects
    var customEffects: [String] { get }
}

/// Context for event evaluation
public struct EventContext {
    public let currentLocation: String
    public let locationState: String
    public let pressure: Int
    public let flags: [String: Bool]
    public let resources: [String: Int]
    public let completedEvents: Set<String>

    public init(
        currentLocation: String,
        locationState: String,
        pressure: Int,
        flags: [String: Bool],
        resources: [String: Int],
        completedEvents: Set<String>
    ) {
        self.currentLocation = currentLocation
        self.locationState = locationState
        self.pressure = pressure
        self.flags = flags
        self.resources = resources
        self.completedEvents = completedEvents
    }
}

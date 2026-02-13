/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/EngineProtocols+WorldState.swift
/// Назначение: Содержит реализацию файла EngineProtocols+WorldState.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 8. World State System
// ═══════════════════════════════════════════════════════════════════════════════

/// Location state (abstract)
public protocol LocationStateProtocol {
    var id: String { get }
    var name: String { get }
    var currentState: String { get }

    /// Can player rest here?
    var canRest: Bool { get }

    /// Can player trade here?
    var canTrade: Bool { get }

    /// Neighbor location IDs
    var neighborIds: [String] { get }
}

/// World state manager protocol
public protocol WorldStateManagerProtocol {
    associatedtype Location: LocationStateProtocol

    var locations: [Location] { get }
    var currentLocationId: String? { get }
    var flags: [String: Bool] { get }

    /// Move to location
    func moveTo(locationId: String) -> Int // Returns time cost

    /// Set flag
    func setFlag(_ flag: String, value: Bool)

    /// Get flag
    func hasFlag(_ flag: String) -> Bool

    /// Degrade location
    func degradeLocation(_ locationId: String)

    /// Improve location
    func improveLocation(_ locationId: String)
}

/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Models/ExplorationModels+Region.swift
/// Назначение: Содержит реализацию файла ExplorationModels+Region.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Region

/// Legacy Region model used for world state persistence and direct UI binding.
///
/// MIGRATION (Audit v1.1 Issue #9):
/// - For new code prefer using Engine models:
///   - `RegionDefinition` - static data (from ContentProvider)
///   - `RegionRuntimeState` - mutable state (Engine/Runtime/WorldRuntimeState.swift)
///   - `EngineRegionState` - combined state for UI (TwilightGameEngine.swift)
/// - This model is preserved for: save serialization, legacy UI, unit tests
/// - After full UI migration to Engine this model will become internal for persistence
public struct Region: Identifiable, Codable {
    public let id: String
    public let name: String
    public let type: RegionType
    public var state: RegionState
    public var anchor: Anchor?
    public var availableEvents: [String]   // Event IDs
    public var activeQuests: [String]      // Active quest IDs
    public var reputation: Int             // -100 to 100
    public var visited: Bool               // Has player been here
    public var neighborIds: [String]       // Neighbor region IDs (travel = 1 day)

    public init(
        id: String,
        name: String,
        type: RegionType,
        state: RegionState = .stable,
        anchor: Anchor? = nil,
        availableEvents: [String] = [],
        activeQuests: [String] = [],
        reputation: Int = 0,
        visited: Bool = false,
        neighborIds: [String] = []
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.state = state
        self.anchor = anchor
        self.availableEvents = availableEvents
        self.activeQuests = activeQuests
        self.reputation = max(-100, min(100, reputation))
        self.visited = visited
        self.neighborIds = neighborIds
    }

    /// Check if region is neighbor
    public func isNeighbor(_ regionId: String) -> Bool {
        return neighborIds.contains(regionId)
    }

    // Update region state based on anchor
    public mutating func updateStateFromAnchor() {
        if let anchor = anchor {
            self.state = anchor.determinedRegionState
        } else {
            // Without anchor region is always in Breach
            self.state = .breach
        }
    }

    // Can trade in region
    public var canTrade: Bool {
        return state == .stable && type == .settlement && reputation >= 0
    }

    // Can rest in region
    public var canRest: Bool {
        return state == .stable && (type == .settlement || type == .sacred)
    }
}

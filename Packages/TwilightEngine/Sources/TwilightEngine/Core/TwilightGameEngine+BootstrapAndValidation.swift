/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/TwilightGameEngine+BootstrapAndValidation.swift
/// Назначение: Содержит реализацию файла TwilightGameEngine+BootstrapAndValidation.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

extension TwilightGameEngine {

    /// Map RegionState to content-registry region-state key.
    func mapRegionStateToString(_ state: RegionState) -> String {
        switch state {
        case .stable: return "stable"
        case .borderland: return "borderland"
        case .breach: return "breach"
        }
    }

    /// Create EngineAnchorState from AnchorDefinition.
    func createEngineAnchor(from def: AnchorDefinition?) -> EngineAnchorState? {
        guard let def else { return nil }
        return EngineAnchorState(
            id: def.id,
            name: def.title.resolve(using: services.localizationManager),
            integrity: def.initialIntegrity,
            alignment: def.initialInfluence
        )
    }

    /// Map region type string from ContentPack to RegionType enum.
    func mapRegionType(fromString typeString: String) -> RegionType {
        RegionType(rawValue: typeString.lowercased()) ?? .settlement
    }

    /// Map RegionStateType to RegionState.
    func mapRegionState(_ stateType: RegionStateType) -> RegionState {
        switch stateType {
        case .stable: return .stable
        case .borderland: return .borderland
        case .breach: return .breach
        }
    }

    /// Create initial events from ContentRegistry.
    func createInitialEvents() -> [GameEvent] {
        services.contentRegistry.getAllEvents().map {
            $0.toGameEvent(registry: services.contentRegistry, localizationManager: services.localizationManager)
        }
    }

    /// Create initial quests from ContentRegistry.
    func createInitialQuests() -> [Quest] {
        services.contentRegistry.getAllQuests().map { $0.toQuest() }
    }

    /// Validation helper for fate card draw.
    func validateDrawFateCard() -> ActionError? {
        guard fateDeckDrawCount > 0 || fateDeckDiscardCount > 0 else {
            return .invalidAction(reason: .fateDeckUnavailable)
        }
        return nil
    }

    /// Validation helper for event choice selection.
    func validateEventChoice(eventId: String, choiceIndex: Int) -> ActionError? {
        guard currentEventId == eventId else {
            return .eventNotFound(eventId: eventId)
        }

        // Additional choice validation would go here.
        _ = choiceIndex
        return nil
    }
}

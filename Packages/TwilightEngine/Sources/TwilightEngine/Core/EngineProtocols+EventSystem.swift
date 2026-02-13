/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/EngineProtocols+EventSystem.swift
/// Назначение: Содержит реализацию файла EngineProtocols+EventSystem.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 3. Event System
// ═══════════════════════════════════════════════════════════════════════════════

/// Provider for checking resources
public protocol ResourceProvider {
    func getValue(for resource: String) -> Int
    func hasFlag(_ flag: String) -> Bool
}

/// Event system protocol
public protocol EventSystemProtocol {
    associatedtype Event: EventDefinitionProtocol

    /// Get available events for current context
    func getAvailableEvents(in context: EventContext) -> [Event]

    /// Mark event as completed
    func markCompleted(eventId: String)

    /// Check if event was completed
    func isCompleted(eventId: String) -> Bool
}

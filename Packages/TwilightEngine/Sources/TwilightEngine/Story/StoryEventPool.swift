/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Story/StoryEventPool.swift
/// Назначение: Содержит реализацию файла StoryEventPool.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Event Pool

/// Pool of events for a specific context.
public struct EventPool {
    let id: String
    let events: [EventDefinition]
    let selectionStrategy: EventSelectionStrategy
}

public enum EventSelectionStrategy {
    case weighted      // Use event weights
    case sequential    // In order (for story events)
    case random        // Pure random
    case priority      // Highest priority first
}

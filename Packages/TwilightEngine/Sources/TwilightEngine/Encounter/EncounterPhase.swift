/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Encounter/EncounterPhase.swift
/// Назначение: Содержит реализацию файла EncounterPhase.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// Named phases of an encounter turn loop
/// Reference: ENCOUNTER_SYSTEM_DESIGN.md §2
public enum EncounterPhase: String, Codable, Equatable {
    case intent          // Enemy declares intent
    case playerAction    // Player chooses action
    case enemyResolution // Enemy executes declared intent
    case roundEnd        // Cleanup, victory check, advance round
}

/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/EngineProtocols+EndGame.swift
/// Назначение: Содержит реализацию файла EngineProtocols+EndGame.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 6. Victory/Defeat System
// ═══════════════════════════════════════════════════════════════════════════════

/// End condition types
public enum EndConditionType: String, Codable {
    case objectiveBased    // Complete specific goals
    case pressureBased     // Pressure reaches threshold
    case resourceBased     // Resource hits 0 or max
    case pathBased         // Player path determines ending
    case timeBased         // Time limit reached
}

/// End condition definition
public protocol EndConditionDefinition {
    var type: EndConditionType { get }
    var id: String { get }
    var isVictory: Bool { get }

    /// Check if condition is met
    func isMet(pressure: Int, resources: [String: Int], flags: [String: Bool], time: Int) -> Bool
}

/// Victory/Defeat checker protocol
public protocol EndGameCheckerProtocol {
    associatedtype Condition: EndConditionDefinition

    var conditions: [Condition] { get }

    /// Check all conditions, return first met (or nil)
    func checkConditions(
        pressure: Int,
        resources: [String: Int],
        flags: [String: Bool],
        time: Int
    ) -> Condition?
}

/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/EngineProtocols+Progression.swift
/// Назначение: Содержит реализацию файла EngineProtocols+Progression.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 5. Progression System
// ═══════════════════════════════════════════════════════════════════════════════

/// Player path/alignment tracking
public protocol ProgressionPathProtocol {
    associatedtype PathType

    var currentPath: PathType { get }
    var pathValue: Int { get }

    /// Shift path by delta
    func shift(by delta: Int)

    /// Get unlocked capabilities for current path
    func unlockedCapabilities() -> [String]

    /// Get locked options for current path
    func lockedOptions() -> [String]
}

/// Progression tracker
public protocol ProgressionTrackerProtocol {
    /// Track capability unlock
    func unlock(capability: String)

    /// Track capability lock (path trade-off)
    func lock(capability: String)

    /// Check if capability is available
    func isUnlocked(_ capability: String) -> Bool
}

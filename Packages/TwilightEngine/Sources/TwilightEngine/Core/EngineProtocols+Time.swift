/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/EngineProtocols+Time.swift
/// Назначение: Содержит реализацию файла EngineProtocols+Time.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 1. Time System
// ═══════════════════════════════════════════════════════════════════════════════

/// Delegate for time progression events
public protocol TimeSystemDelegate: AnyObject {
    /// Called when time advances by one tick
    func onTimeTick(currentTime: Int, delta: Int)

    /// Called when a time threshold is crossed (e.g., every 3 days)
    func onTimeThreshold(currentTime: Int, threshold: Int)
}

/// Contract for time-consuming actions
public protocol TimedAction {
    /// Cost in time units (0 = instant)
    var timeCost: Int { get }
}

/// Time engine protocol - manages game time progression
public protocol TimeEngineProtocol {
    var currentTime: Int { get }
    var delegate: TimeSystemDelegate? { get set }

    /// Advance time by a cost. Invariant: cost > 0 (except instant actions)
    func advance(cost: Int)

    /// Check if a threshold interval has been reached
    func checkThreshold(_ interval: Int) -> Bool
}

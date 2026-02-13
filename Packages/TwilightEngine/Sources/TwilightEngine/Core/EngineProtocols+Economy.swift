/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Core/EngineProtocols+Economy.swift
/// Назначение: Содержит реализацию файла EngineProtocols+Economy.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 7. Economy System
// ═══════════════════════════════════════════════════════════════════════════════

/// Transaction for resource changes
public struct Transaction {
    let costs: [String: Int]
    let gains: [String: Int]
    let description: String

    init(costs: [String: Int] = [:], gains: [String: Int] = [:], description: String = "") {
        self.costs = costs
        self.gains = gains
        self.description = description
    }
}

/// Economy manager protocol
public protocol EconomyManagerProtocol {
    /// Check if transaction is affordable
    func canAfford(_ transaction: Transaction, resources: [String: Int]) -> Bool

    /// Process transaction, returns new resource values
    func process(_ transaction: Transaction, resources: inout [String: Int]) -> Bool
}

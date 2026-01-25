import Foundation

// MARK: - Economy Manager Implementation
// Handles all resource transactions in a consistent way.

/// Default implementation of EconomyManagerProtocol
public final class EconomyManager: EconomyManagerProtocol {
    // MARK: - Properties

    /// Track transaction history for debugging/analytics
    private var transactionHistory: [TransactionRecord] = []

    /// Maximum history size
    private let maxHistorySize: Int

    // MARK: - Initialization

    public init(maxHistorySize: Int = 100) {
        self.maxHistorySize = maxHistorySize
    }

    // MARK: - EconomyManagerProtocol

    /// Check if a transaction can be afforded
    public func canAfford(_ transaction: Transaction, resources: [String: Int]) -> Bool {
        for (resource, cost) in transaction.costs {
            let available = resources[resource] ?? 0
            if available < cost {
                return false
            }
        }
        return true
    }

    /// Process a transaction, modifying resources
    /// Returns true if successful, false if cannot afford
    public func process(_ transaction: Transaction, resources: inout [String: Int]) -> Bool {
        // First check if affordable
        guard canAfford(transaction, resources: resources) else {
            return false
        }

        // Apply costs
        for (resource, cost) in transaction.costs {
            let current = resources[resource] ?? 0
            resources[resource] = current - cost
        }

        // Apply gains
        for (resource, gain) in transaction.gains {
            let current = resources[resource] ?? 0
            resources[resource] = current + gain
        }

        // Record transaction
        recordTransaction(transaction, success: true)

        return true
    }

    // MARK: - Extended Methods

    /// Process transaction with caps (e.g., max health)
    public func processWithCaps(
        _ transaction: Transaction,
        resources: inout [String: Int],
        caps: [String: Int]
    ) -> Bool {
        guard process(transaction, resources: &resources) else {
            return false
        }

        // Apply caps
        for (resource, maxValue) in caps {
            if let current = resources[resource], current > maxValue {
                resources[resource] = maxValue
            }
        }

        return true
    }

    /// Preview transaction result without applying
    public func preview(
        _ transaction: Transaction,
        resources: [String: Int]
    ) -> [String: Int]? {
        guard canAfford(transaction, resources: resources) else {
            return nil
        }

        var result = resources

        // Apply costs
        for (resource, cost) in transaction.costs {
            let current = result[resource] ?? 0
            result[resource] = current - cost
        }

        // Apply gains
        for (resource, gain) in transaction.gains {
            let current = result[resource] ?? 0
            result[resource] = current + gain
        }

        return result
    }

    /// Calculate net change from a transaction
    public func netChange(_ transaction: Transaction) -> [String: Int] {
        var net: [String: Int] = [:]

        for (resource, cost) in transaction.costs {
            net[resource] = (net[resource] ?? 0) - cost
        }

        for (resource, gain) in transaction.gains {
            net[resource] = (net[resource] ?? 0) + gain
        }

        return net
    }

    // MARK: - History

    private func recordTransaction(_ transaction: Transaction, success: Bool) {
        let record = TransactionRecord(
            transaction: transaction,
            timestamp: Date(),
            success: success
        )

        transactionHistory.append(record)

        // Trim history if needed
        if transactionHistory.count > maxHistorySize {
            transactionHistory.removeFirst(transactionHistory.count - maxHistorySize)
        }
    }

    /// Get recent transaction history
    public func getHistory(limit: Int = 10) -> [TransactionRecord] {
        return Array(transactionHistory.suffix(limit))
    }

    /// Clear history
    public func clearHistory() {
        transactionHistory.removeAll()
    }
}

// MARK: - Transaction Record

/// Record of a processed transaction
public struct TransactionRecord {
    public let transaction: Transaction
    public let timestamp: Date
    public let success: Bool
}

// MARK: - Transaction Extensions

extension Transaction {
    /// Create a simple cost-only transaction
    public static func cost(_ resource: String, amount: Int, description: String = "") -> Transaction {
        Transaction(costs: [resource: amount], description: description)
    }

    /// Create a simple gain-only transaction
    public static func gain(_ resource: String, amount: Int, description: String = "") -> Transaction {
        Transaction(gains: [resource: amount], description: description)
    }

    /// Create a trade transaction (exchange one resource for another)
    public static func trade(
        spend resource1: String,
        amount1: Int,
        gain resource2: String,
        amount2: Int,
        description: String = ""
    ) -> Transaction {
        Transaction(
            costs: [resource1: amount1],
            gains: [resource2: amount2],
            description: description
        )
    }

    /// Combine two transactions
    public func combined(with other: Transaction) -> Transaction {
        var newCosts = self.costs
        var newGains = self.gains

        for (resource, cost) in other.costs {
            newCosts[resource] = (newCosts[resource] ?? 0) + cost
        }

        for (resource, gain) in other.gains {
            newGains[resource] = (newGains[resource] ?? 0) + gain
        }

        return Transaction(
            costs: newCosts,
            gains: newGains,
            description: "\(self.description); \(other.description)"
        )
    }
}

// MARK: - Standard Resource Types

/// Common resource identifiers (games can define their own)
public enum StandardResource: String {
    case health
    case maxHealth
    case energy
    case faith
    case gold
    case experience
    case reputation

    public var id: String { rawValue }
}

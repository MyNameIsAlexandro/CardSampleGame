/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/EconomyManagerTests.swift
/// Назначение: Содержит реализацию файла EconomyManagerTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import TwilightEngine

/// Economy Manager Tests
/// Validates resource transaction handling, affordability checks,
/// caps enforcement, previews, history tracking, and convenience methods.
final class EconomyManagerTests: XCTestCase {

    var manager: EconomyManager!

    override func setUp() {
        super.setUp()
        manager = EconomyManager(maxHistorySize: 10)
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    // MARK: - Affordability Tests

    /// Test: canAfford returns true when all costs are met
    func testCanAffordWhenResourcesAreSufficient() {
        // Given: Sufficient resources
        let resources = ["gold": 100, "faith": 50]
        let transaction = Transaction(costs: ["gold": 50, "faith": 20])

        // When: Check affordability
        let canAfford = manager.canAfford(transaction, resources: resources)

        // Then: Should be affordable
        XCTAssertTrue(canAfford, "Transaction should be affordable with sufficient resources")
    }

    /// Test: canAfford returns false when any cost exceeds available resources
    func testCannotAffordWhenInsufficientResources() {
        // Given: Insufficient resources
        let resources = ["gold": 30, "faith": 10]
        let transaction = Transaction(costs: ["gold": 50, "faith": 5])

        // When: Check affordability
        let canAfford = manager.canAfford(transaction, resources: resources)

        // Then: Should not be affordable
        XCTAssertFalse(canAfford, "Transaction should not be affordable when gold is insufficient")
    }

    /// Test: canAfford handles missing resources (treats as 0)
    func testCannotAffordWhenResourceMissing() {
        // Given: Resources missing the required type
        let resources = ["gold": 100]
        let transaction = Transaction(costs: ["faith": 20])

        // When: Check affordability
        let canAfford = manager.canAfford(transaction, resources: resources)

        // Then: Should not be affordable (missing resource treated as 0)
        XCTAssertFalse(canAfford, "Transaction should not be affordable when required resource is missing")
    }

    // MARK: - Process Tests

    /// Test: process deducts costs and adds gains successfully
    func testProcessSuccessfullyModifiesResources() {
        // Given: Resources and affordable transaction
        var resources = ["gold": 100, "faith": 50, "health": 20]
        let transaction = Transaction(
            costs: ["gold": 30, "faith": 10],
            gains: ["health": 15],
            description: "Healing potion"
        )

        // When: Process transaction
        let success = manager.process(transaction, resources: &resources)

        // Then: Should succeed and modify resources correctly
        XCTAssertTrue(success, "Transaction should succeed")
        XCTAssertEqual(resources["gold"], 70, "Gold should be deducted")
        XCTAssertEqual(resources["faith"], 40, "Faith should be deducted")
        XCTAssertEqual(resources["health"], 35, "Health should be gained")
    }

    /// Test: process returns false when cannot afford and does not modify resources
    func testProcessFailsWhenCannotAfford() {
        // Given: Insufficient resources
        var resources = ["gold": 10, "faith": 5]
        let originalResources = resources
        let transaction = Transaction(costs: ["gold": 50])

        // When: Attempt to process
        let success = manager.process(transaction, resources: &resources)

        // Then: Should fail and not modify resources
        XCTAssertFalse(success, "Transaction should fail when unaffordable")
        XCTAssertEqual(resources, originalResources, "Resources should remain unchanged after failed transaction")
    }

    // MARK: - Caps Tests

    /// Test: processWithCaps clamps gains to cap values
    func testProcessWithCapsEnforcesCaps() {
        // Given: Resources, affordable transaction with gain, and caps
        var resources = ["health": 80, "gold": 100]
        let transaction = Transaction(
            costs: ["gold": 20],
            gains: ["health": 50]
        )
        let caps = ["health": 100]

        // When: Process with caps
        let success = manager.processWithCaps(transaction, resources: &resources, caps: caps)

        // Then: Should succeed and clamp health to max
        XCTAssertTrue(success, "Transaction should succeed")
        XCTAssertEqual(resources["health"], 100, "Health should be clamped to max (80 + 50 = 130 -> 100)")
        XCTAssertEqual(resources["gold"], 80, "Gold should be deducted normally")
    }

    /// Test: processWithCaps does not affect resources below cap
    func testProcessWithCapsDoesNotAffectResourcesBelowCap() {
        // Given: Transaction result stays below cap
        var resources = ["health": 30, "gold": 50]
        let transaction = Transaction(gains: ["health": 20])
        let caps = ["health": 100]

        // When: Process with caps
        let success = manager.processWithCaps(transaction, resources: &resources, caps: caps)

        // Then: Health should not be clamped
        XCTAssertTrue(success)
        XCTAssertEqual(resources["health"], 50, "Health should not be clamped when below max")
    }

    // MARK: - Preview Tests

    /// Test: preview returns result without mutating original resources
    func testPreviewReturnsResultWithoutMutation() {
        // Given: Resources and transaction
        let resources = ["gold": 100, "faith": 50]
        let transaction = Transaction(costs: ["gold": 30], gains: ["faith": 20])

        // When: Preview transaction
        let preview = manager.preview(transaction, resources: resources)

        // Then: Should return correct result and not mutate original
        XCTAssertNotNil(preview, "Preview should succeed for affordable transaction")
        XCTAssertEqual(preview?["gold"], 70, "Preview should show gold deducted")
        XCTAssertEqual(preview?["faith"], 70, "Preview should show faith gained")
        XCTAssertEqual(resources["gold"], 100, "Original resources should not be mutated")
        XCTAssertEqual(resources["faith"], 50, "Original resources should not be mutated")
    }

    /// Test: preview returns nil when cannot afford
    func testPreviewReturnsNilWhenCannotAfford() {
        // Given: Insufficient resources
        let resources = ["gold": 10]
        let transaction = Transaction(costs: ["gold": 50])

        // When: Preview transaction
        let preview = manager.preview(transaction, resources: resources)

        // Then: Should return nil
        XCTAssertNil(preview, "Preview should return nil when transaction is unaffordable")
    }

    // MARK: - Net Change Tests

    /// Test: netChange calculates correct delta per resource
    func testNetChangeCalculatesCorrectDelta() {
        // Given: Transaction with costs and gains
        let transaction = Transaction(
            costs: ["gold": 50, "faith": 20],
            gains: ["gold": 30, "health": 15]
        )

        // When: Calculate net change
        let net = manager.netChange(transaction)

        // Then: Should show correct delta
        XCTAssertEqual(net["gold"], -20, "Gold net should be -20 (30 gain - 50 cost)")
        XCTAssertEqual(net["faith"], -20, "Faith net should be -20 (only cost)")
        XCTAssertEqual(net["health"], 15, "Health net should be +15 (only gain)")
    }

    // MARK: - History Tests

    /// Test: history tracks successful transactions
    func testHistoryTracksSuccessfulTransactions() {
        // Given: Manager with empty history
        var resources = ["gold": 100]
        let transaction = Transaction(costs: ["gold": 20], description: "Test purchase")

        // When: Process transaction
        _ = manager.process(transaction, resources: &resources)

        // Then: History should contain the transaction
        let history = manager.getHistory(limit: 10)
        XCTAssertEqual(history.count, 1, "History should have 1 entry")
        XCTAssertEqual(history.first?.transaction.description, "Test purchase")
        XCTAssertTrue(history.first?.success ?? false, "Transaction should be marked as successful")
    }

    /// Test: getHistory respects limit parameter
    func testHistoryRespectsLimit() {
        // Given: Multiple transactions
        var resources = ["gold": 1000]
        for i in 1...5 {
            let transaction = Transaction(costs: ["gold": 10], description: "Transaction \(i)")
            _ = manager.process(transaction, resources: &resources)
        }

        // When: Request limited history
        let history = manager.getHistory(limit: 3)

        // Then: Should return only last 3 entries
        XCTAssertEqual(history.count, 3, "Should return only 3 most recent transactions")
        XCTAssertEqual(history.last?.transaction.description, "Transaction 5", "Should have most recent transaction")
    }

    /// Test: clearHistory removes all history entries
    func testClearHistoryRemovesAllEntries() {
        // Given: History with entries
        var resources = ["gold": 100]
        _ = manager.process(Transaction(costs: ["gold": 10]), resources: &resources)
        XCTAssertGreaterThan(manager.getHistory().count, 0, "Should have history before clearing")

        // When: Clear history
        manager.clearHistory()

        // Then: History should be empty
        XCTAssertEqual(manager.getHistory().count, 0, "History should be empty after clearing")
    }

    // MARK: - Transaction Convenience Methods

    /// Test: Transaction.cost creates cost-only transaction
    func testTransactionCostConvenience() {
        // When: Create cost transaction
        let transaction = Transaction.cost("gold", amount: 50, description: "Purchase")

        // Then: Should have only costs
        XCTAssertEqual(transaction.costs["gold"], 50)
        XCTAssertTrue(transaction.gains.isEmpty, "Gains should be empty")
        XCTAssertEqual(transaction.description, "Purchase")
    }

    /// Test: Transaction.gain creates gain-only transaction
    func testTransactionGainConvenience() {
        // When: Create gain transaction
        let transaction = Transaction.gain("health", amount: 20, description: "Healing")

        // Then: Should have only gains
        XCTAssertEqual(transaction.gains["health"], 20)
        XCTAssertTrue(transaction.costs.isEmpty, "Costs should be empty")
        XCTAssertEqual(transaction.description, "Healing")
    }

    /// Test: Transaction.trade creates exchange transaction
    func testTransactionTradeConvenience() {
        // When: Create trade transaction
        let transaction = Transaction.trade(
            spend: "gold",
            amount1: 100,
            gain: "health",
            amount2: 50,
            description: "Buy healing"
        )

        // Then: Should have both cost and gain
        XCTAssertEqual(transaction.costs["gold"], 100)
        XCTAssertEqual(transaction.gains["health"], 50)
        XCTAssertEqual(transaction.description, "Buy healing")
    }

    /// Test: Transaction.combined merges two transactions
    func testTransactionCombinedMergesTransactions() {
        // Given: Two transactions
        let t1 = Transaction(costs: ["gold": 30], gains: ["health": 10], description: "First")
        let t2 = Transaction(costs: ["faith": 20], gains: ["health": 5], description: "Second")

        // When: Combine them
        let combined = t1.combined(with: t2)

        // Then: Should merge costs and gains
        XCTAssertEqual(combined.costs["gold"], 30, "Gold cost should be from t1")
        XCTAssertEqual(combined.costs["faith"], 20, "Faith cost should be from t2")
        XCTAssertEqual(combined.gains["health"], 15, "Health gains should be summed (10 + 5)")
        XCTAssertTrue(combined.description.contains("First"), "Description should include t1")
        XCTAssertTrue(combined.description.contains("Second"), "Description should include t2")
    }
}

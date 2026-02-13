/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/PressureEngineTests.swift
/// Назначение: Содержит реализацию файла PressureEngineTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import TwilightEngine

/// Pressure Engine Tests
/// Validates pressure/tension system mechanics including escalation,
/// manual adjustments, threshold effects, bounds clamping, and adaptive rules.
final class PressureEngineTests: XCTestCase {

    var standardEngine: PressureEngine!
    var adaptiveEngine: PressureEngine!

    override func setUp() {
        super.setUp()

        // Standard rules: max 100, initial 30, escalate by 2 every 3 turns
        let standardRules = StandardPressureRules(
            maxPressure: 100,
            initialPressure: 30,
            escalationInterval: 3,
            escalationAmount: 2,
            thresholds: [
                50: [.globalEvent(eventId: "warning")],
                75: [.globalEvent(eventId: "critical")],
                100: [.phaseChange(newPhase: "endgame")]
            ]
        )
        standardEngine = PressureEngine(rules: standardRules)

        // Adaptive rules: escalation accelerates with pressure
        let adaptiveRules = AdaptivePressureRules(
            maxPressure: 100,
            initialPressure: 20,
            escalationInterval: 3,
            baseEscalationAmount: 2,
            accelerationFactor: 0.05,
            thresholds: [
                60: [.globalEvent(eventId: "adaptive_event")]
            ]
        )
        adaptiveEngine = PressureEngine(rules: adaptiveRules)
    }

    override func tearDown() {
        standardEngine = nil
        adaptiveEngine = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    /// Test: Engine initializes with rules' initial pressure
    func testInitialState() {
        // Then: Should start at initial pressure from rules
        XCTAssertEqual(standardEngine.currentPressure, 30, "Standard engine should start at initial pressure 30")
        XCTAssertEqual(adaptiveEngine.currentPressure, 20, "Adaptive engine should start at initial pressure 20")
    }

    // MARK: - Escalation Tests

    /// Test: escalate increases pressure by rule-calculated amount
    func testEscalateIncreasesPassure() {
        // Given: Engine at initial state
        let initialPressure = standardEngine.currentPressure

        // When: Escalate at time 3
        standardEngine.escalate(at: 3)

        // Then: Pressure should increase by escalationAmount (2)
        XCTAssertEqual(
            standardEngine.currentPressure,
            initialPressure + 2,
            "Pressure should increase by 2 after escalation"
        )
    }

    /// Test: multiple escalations accumulate pressure
    func testMultipleEscalationsAccumulate() {
        // Given: Initial pressure
        let initialPressure = standardEngine.currentPressure

        // When: Escalate multiple times
        standardEngine.escalate(at: 3)
        standardEngine.escalate(at: 6)
        standardEngine.escalate(at: 9)

        // Then: Pressure should increase by 3 * escalationAmount
        XCTAssertEqual(
            standardEngine.currentPressure,
            initialPressure + 6,
            "Pressure should increase by 6 (3 escalations * 2)"
        )
    }

    // MARK: - Manual Adjustment Tests

    /// Test: adjust increases pressure by positive delta
    func testAdjustByPositiveDelta() {
        // Given: Current pressure
        let initialPressure = standardEngine.currentPressure

        // When: Adjust by +10
        standardEngine.adjust(by: 10)

        // Then: Pressure should increase
        XCTAssertEqual(
            standardEngine.currentPressure,
            initialPressure + 10,
            "Pressure should increase by 10"
        )
    }

    /// Test: adjust decreases pressure by negative delta
    func testAdjustByNegativeDelta() {
        // Given: Current pressure
        let initialPressure = standardEngine.currentPressure

        // When: Adjust by -5
        standardEngine.adjust(by: -5)

        // Then: Pressure should decrease
        XCTAssertEqual(
            standardEngine.currentPressure,
            initialPressure - 5,
            "Pressure should decrease by 5"
        )
    }

    // MARK: - Clamping Tests

    /// Test: pressure cannot go below 0
    func testPressureClampedAtZero() {
        // Given: Engine at initial pressure
        // When: Adjust by large negative value
        standardEngine.adjust(by: -1000)

        // Then: Pressure should be clamped to 0
        XCTAssertEqual(standardEngine.currentPressure, 0, "Pressure should not go below 0")
    }

    /// Test: pressure cannot exceed maxPressure
    func testPressureClampedAtMaximum() {
        // Given: Engine at initial pressure
        // When: Adjust by large positive value
        standardEngine.adjust(by: 1000)

        // Then: Pressure should be clamped to maxPressure
        XCTAssertEqual(
            standardEngine.currentPressure,
            100,
            "Pressure should not exceed maxPressure (100)"
        )
    }

    /// Test: setPressure also clamps to bounds
    func testSetPressureClampsToBounds() {
        // When: Set to negative value
        standardEngine.setPressure(-50)
        XCTAssertEqual(standardEngine.currentPressure, 0, "setPressure should clamp to 0")

        // When: Set to value exceeding max
        standardEngine.setPressure(150)
        XCTAssertEqual(standardEngine.currentPressure, 100, "setPressure should clamp to maxPressure")

        // When: Set to valid value
        standardEngine.setPressure(60)
        XCTAssertEqual(standardEngine.currentPressure, 60, "setPressure should accept valid value")
    }

    // MARK: - Threshold Effects Tests

    /// Test: currentEffects returns effects for thresholds at/below current pressure
    func testCurrentEffectsReturnsActiveThresholds() {
        // Given: Pressure at 60 (above threshold 50, below 75)
        standardEngine.setPressure(60)

        // When: Get current effects
        let effects = standardEngine.currentEffects()

        // Then: Should include threshold 50 effect but not 75
        XCTAssertTrue(effects.contains(.globalEvent(eventId: "warning")), "Should include 50 threshold effect")
        XCTAssertFalse(effects.contains(.globalEvent(eventId: "critical")), "Should not include 75 threshold effect")
    }

    /// Test: currentEffects includes all thresholds at or below pressure
    func testCurrentEffectsIncludesMultipleThresholds() {
        // Given: Pressure at maximum
        standardEngine.setPressure(100)

        // When: Get current effects
        let effects = standardEngine.currentEffects()

        // Then: Should include all threshold effects
        XCTAssertEqual(effects.count, 3, "Should have all 3 threshold effects")
        XCTAssertTrue(effects.contains(.globalEvent(eventId: "warning")))
        XCTAssertTrue(effects.contains(.globalEvent(eventId: "critical")))
        XCTAssertTrue(effects.contains(.phaseChange(newPhase: "endgame")))
    }

    /// Test: currentEffects returns empty when no thresholds are met
    func testCurrentEffectsReturnsEmptyWhenNoThresholds() {
        // Given: Pressure below all thresholds
        standardEngine.setPressure(20)

        // When: Get current effects
        let effects = standardEngine.currentEffects()

        // Then: Should be empty
        XCTAssertTrue(effects.isEmpty, "Should have no effects when below all thresholds")
    }

    // MARK: - Reset Tests

    /// Test: reset restores initial pressure
    func testResetRestoresInitialPressure() {
        // Given: Modified pressure
        standardEngine.adjust(by: 40)
        XCTAssertNotEqual(standardEngine.currentPressure, 30, "Pressure should be modified")

        // When: Reset
        standardEngine.reset()

        // Then: Should return to initial pressure
        XCTAssertEqual(standardEngine.currentPressure, 30, "Pressure should be reset to initial value")
    }

    // MARK: - Utility Tests

    /// Test: pressurePercentage calculates correct ratio
    func testPressurePercentage() {
        // Given: Different pressure values
        standardEngine.setPressure(0)
        XCTAssertEqual(standardEngine.pressurePercentage, 0.0, accuracy: 0.01, "0% at pressure 0")

        standardEngine.setPressure(50)
        XCTAssertEqual(standardEngine.pressurePercentage, 0.5, accuracy: 0.01, "50% at pressure 50")

        standardEngine.setPressure(100)
        XCTAssertEqual(standardEngine.pressurePercentage, 1.0, accuracy: 0.01, "100% at max pressure")
    }

    /// Test: isAtMaximum is true when at or exceeding maxPressure
    func testIsAtMaximum() {
        // Given: Pressure below max
        standardEngine.setPressure(99)
        XCTAssertFalse(standardEngine.isAtMaximum, "Should not be at maximum when pressure is 99")

        // When: Set to max
        standardEngine.setPressure(100)
        XCTAssertTrue(standardEngine.isAtMaximum, "Should be at maximum when pressure is 100")

        // When: Attempt to exceed (will clamp)
        standardEngine.adjust(by: 50)
        XCTAssertTrue(standardEngine.isAtMaximum, "Should still be at maximum when clamped")
    }

    // MARK: - Adaptive Rules Tests

    /// Test: adaptive rules escalate more as pressure increases
    func testAdaptiveRulesAccelerateWithPressure() {
        // Given: Adaptive engine at low pressure
        adaptiveEngine.setPressure(20)
        let escalationAtLow = adaptiveEngine.rules.calculateEscalation(
            currentPressure: 20,
            currentTime: 3
        )

        // When: Pressure is higher
        adaptiveEngine.setPressure(60)
        let escalationAtHigh = adaptiveEngine.rules.calculateEscalation(
            currentPressure: 60,
            currentTime: 6
        )

        // Then: Escalation at high pressure should be greater
        // At 20: base (2) + (20 * 0.05) = 2 + 1 = 3
        // At 60: base (2) + (60 * 0.05) = 2 + 3 = 5
        XCTAssertEqual(escalationAtLow, 3, "Escalation at pressure 20 should be 3")
        XCTAssertEqual(escalationAtHigh, 5, "Escalation at pressure 60 should be 5")
        XCTAssertGreaterThan(
            escalationAtHigh,
            escalationAtLow,
            "Adaptive escalation should increase with pressure"
        )
    }

    /// Test: adaptive engine escalates correctly via escalate method
    func testAdaptiveEngineEscalateMethod() {
        // Given: Adaptive engine at 40 pressure
        adaptiveEngine.setPressure(40)
        let initialPressure = adaptiveEngine.currentPressure

        // Expected increase: base (2) + (40 * 0.05) = 2 + 2 = 4
        // When: Escalate
        adaptiveEngine.escalate(at: 3)

        // Then: Should increase by 4
        XCTAssertEqual(
            adaptiveEngine.currentPressure,
            initialPressure + 4,
            "Adaptive engine should escalate by 4 at pressure 40"
        )
    }
}

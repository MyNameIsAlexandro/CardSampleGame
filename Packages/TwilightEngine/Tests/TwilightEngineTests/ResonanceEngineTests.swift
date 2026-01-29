import XCTest
@testable import TwilightEngine

/// Tests for ResonanceEngine — world resonance state management
final class ResonanceEngineTests: XCTestCase {

    // MARK: - Initial State

    func testInitialValueIsZero() {
        let engine = ResonanceEngine()
        XCTAssertEqual(engine.value, 0.0)
        XCTAssertEqual(engine.getActiveZone(), .yav)
    }

    func testInitWithCustomValue() {
        let engine = ResonanceEngine(value: 42.0)
        XCTAssertEqual(engine.value, 42.0)
        XCTAssertEqual(engine.getActiveZone(), .prav)
    }

    // MARK: - Clamping

    func testResonanceClamping() {
        let engine = ResonanceEngine()

        // Shift far positive — should clamp at 100
        engine.shift(amount: 200, source: "test")
        XCTAssertEqual(engine.value, 100.0)

        // Shift far negative — should clamp at -100
        engine.shift(amount: -300, source: "test")
        XCTAssertEqual(engine.value, -100.0)
    }

    func testInitClamps() {
        let high = ResonanceEngine(value: 999)
        XCTAssertEqual(high.value, 100.0)

        let low = ResonanceEngine(value: -999)
        XCTAssertEqual(low.value, -100.0)
    }

    // MARK: - Zone Detection

    func testZoneDetection() {
        // deepNav: -100..-61
        XCTAssertEqual(ResonanceEngine.zone(for: -100), .deepNav)
        XCTAssertEqual(ResonanceEngine.zone(for: -61), .deepNav)

        // nav: -60..-21
        XCTAssertEqual(ResonanceEngine.zone(for: -60), .nav)
        XCTAssertEqual(ResonanceEngine.zone(for: -21), .nav)

        // yav: -20..20
        XCTAssertEqual(ResonanceEngine.zone(for: -20), .yav)
        XCTAssertEqual(ResonanceEngine.zone(for: 0), .yav)
        XCTAssertEqual(ResonanceEngine.zone(for: 20), .yav)

        // prav: 21..60
        XCTAssertEqual(ResonanceEngine.zone(for: 21), .prav)
        XCTAssertEqual(ResonanceEngine.zone(for: 60), .prav)

        // deepPrav: 61..100
        XCTAssertEqual(ResonanceEngine.zone(for: 61), .deepPrav)
        XCTAssertEqual(ResonanceEngine.zone(for: 100), .deepPrav)
    }

    // MARK: - Shift

    func testShiftReturnsRecord() {
        let engine = ResonanceEngine()

        let shift = engine.shift(amount: 15, source: "battle_won")

        XCTAssertEqual(shift.amount, 15)
        XCTAssertEqual(shift.source, "battle_won")
        XCTAssertEqual(shift.resultingValue, 15.0)
        XCTAssertEqual(engine.value, 15.0)
    }

    func testMultipleShifts() {
        let engine = ResonanceEngine()

        engine.shift(amount: 30, source: "a")
        let s2 = engine.shift(amount: -10, source: "b")

        XCTAssertEqual(s2.resultingValue, 20.0)
        XCTAssertEqual(engine.value, 20.0)
    }

    // MARK: - Save/Load

    func testSetValue() {
        let engine = ResonanceEngine()
        engine.setValue(75.0)
        XCTAssertEqual(engine.value, 75.0)

        // Clamps
        engine.setValue(200.0)
        XCTAssertEqual(engine.value, 100.0)
    }
}

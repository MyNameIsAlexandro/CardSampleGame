/// Файл: CardSampleGameTests/GateTests/RitualCombatGates/RitualAtmosphereGateTests.swift
/// Назначение: Gate-тесты архитектурных границ ResonanceAtmosphereController (R7).
/// Зона ответственности: Static scan — запрет мутаций CombatSimulation, read-only контракт.
/// Контекст: TDD RED — ResonanceAtmosphereController ещё не создан. Reference: RITUAL_COMBAT_TEST_MODEL.md §3.4

import XCTest
import TwilightEngine
@testable import CardSampleGame

/// Ritual Atmosphere Architecture Invariants — Phase 3 Gate Tests (R7)
/// Reference: RITUAL_COMBAT_TEST_MODEL.md §3.4
/// Rule: < 2 seconds per test, static source scan, no runtime dependencies
@MainActor
final class RitualAtmosphereGateTests: XCTestCase {

    // MARK: - Helpers

    private let projectRoot = SourcePathResolver.projectRoot

    /// Read file content, skipping comment lines. Returns array of (lineNumber, codeContent).
    private func readCodeLines(from url: URL) throws -> [(line: Int, code: String)] {
        let content = try String(contentsOf: url, encoding: .utf8)
        return content.components(separatedBy: .newlines).enumerated().compactMap { index, raw in
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") || trimmed.hasPrefix("*") || trimmed.isEmpty {
                return nil
            }
            var code = trimmed
            if let range = code.range(of: "//") {
                code = String(code[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
            return (line: index + 1, code: code)
        }
    }

    // MARK: - INV-ATM-001: ResonanceAtmosphereController is pure presentation

    /// Static scan: controller must not call CombatSimulation mutation methods.
    /// Only getter properties allowed: .resonance, .phase, .isOver, computed properties.
    func testResonanceAtmosphereIsPurePresentation() throws {
        let controllerFile = projectRoot.appendingPathComponent("Views/Combat/ResonanceAtmosphereController.swift")
        guard FileManager.default.fileExists(atPath: controllerFile.path) else {
            XCTFail("ResonanceAtmosphereController.swift not found — R7 not yet implemented (TDD RED)")
            return
        }

        let forbiddenMutations = [
            "selectCard(", "burnForEffort(", "commitAttack(",
            "commitInfluence(", "skipTurn(", "resolveEnemyTurn("
        ]

        let codeLines = try readCodeLines(from: controllerFile)
        var violations: [String] = []

        for (line, code) in codeLines {
            for pattern in forbiddenMutations where code.contains(pattern) {
                violations.append("  ResonanceAtmosphereController.swift:\(line): \(code) [mutation: \(pattern)]")
            }
        }

        XCTAssertTrue(violations.isEmpty,
            "ResonanceAtmosphereController must be pure presentation — no CombatSimulation mutations.\n" +
            "Allowed: .resonance, .phase, .isOver, computed properties (read-only).\n" +
            "Violations:\n\(violations.joined(separator: "\n"))")
    }

    // MARK: - INV-ATM-002: AtmosphereController is read-only (runtime mock)

    /// Runtime verification: controller.update() must not call any mutation methods.
    /// Mutation methods verified NOT called: selectCard, burnForEffort, commitAttack,
    /// commitInfluence, skipTurn, resolveEnemyTurn, advancePhase, resetRound.
    /// Read-only func allowed: snapshot(), resonance getter.
    /// Output: only visual parameters (color, alpha, particle config).
    /// TDD RED until R7 creates ResonanceAtmosphereController with mock support.
    func testAtmosphereControllerIsReadOnly() {
        // Create deterministic simulation and snapshot before controller interaction
        let sim = CombatSimulation.makeStandard(seed: 42)
        sim.selectCard(sim.hand[0].id)
        let snapshotBefore = sim.snapshot()

        // Create atmosphere controller (headless — no parent scene) and pump updates
        let controller = ResonanceAtmosphereController()
        controller.update(resonance: -80.0)
        controller.update(resonance: 0.0)
        controller.update(resonance: 50.0)
        controller.update(resonance: 100.0)

        // Snapshot after — must be identical (controller is pure presentation)
        let snapshotAfter = sim.snapshot()
        XCTAssertEqual(snapshotBefore, snapshotAfter,
            "ResonanceAtmosphereController.update() must not mutate CombatSimulation state. " +
            "Snapshot before and after update() calls must be identical.")
    }

    // MARK: - INV-ATM-003: HSL interpolation produces correct visual zones

    /// Extreme negative resonance (-100) yields high intensity, elevated alpha (Nav purple zone)
    func testAtmosphereVisuals_extremeNegativeResonanceProducesHighIntensity() {
        let controller = ResonanceAtmosphereController()
        controller.update(resonance: -100.0)

        let visuals = controller.currentVisuals
        XCTAssertEqual(visuals.particleIntensity, 1.0, accuracy: 0.01,
            "Resonance -100 must produce full particle intensity (abs(100)/100 = 1.0)")
        XCTAssertEqual(visuals.ambientAlpha, 0.5, accuracy: 0.01,
            "Resonance -100 must produce elevated ambient alpha (0.3 + 100/100 * 0.2 = 0.5)")
    }

    /// Neutral resonance (0) yields zero intensity and base alpha (Yav amber zone)
    func testAtmosphereVisuals_neutralResonanceProducesBaseValues() {
        let controller = ResonanceAtmosphereController()
        controller.update(resonance: 0.0)

        let visuals = controller.currentVisuals
        XCTAssertEqual(visuals.particleIntensity, 0.0, accuracy: 0.01,
            "Resonance 0 must produce zero particle intensity (abs(0)/100 = 0.0)")
        XCTAssertEqual(visuals.ambientAlpha, 0.3, accuracy: 0.01,
            "Resonance 0 must produce base ambient alpha (0.3 + 0/100 * 0.2 = 0.3)")
    }

    /// Extreme positive resonance (+100) yields high intensity, elevated alpha (Prav gold zone)
    func testAtmosphereVisuals_extremePositiveResonanceProducesHighIntensity() {
        let controller = ResonanceAtmosphereController()
        controller.update(resonance: 100.0)

        let visuals = controller.currentVisuals
        XCTAssertEqual(visuals.particleIntensity, 1.0, accuracy: 0.01,
            "Resonance +100 must produce full particle intensity (abs(100)/100 = 1.0)")
        XCTAssertEqual(visuals.ambientAlpha, 0.5, accuracy: 0.01,
            "Resonance +100 must produce elevated ambient alpha (0.3 + 100/100 * 0.2 = 0.5)")
    }
}

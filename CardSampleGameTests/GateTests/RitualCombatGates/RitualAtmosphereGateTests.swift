/// Файл: CardSampleGameTests/GateTests/RitualCombatGates/RitualAtmosphereGateTests.swift
/// Назначение: Gate-тесты архитектурных границ ResonanceAtmosphereController (R7).
/// Зона ответственности: Static scan — запрет мутаций CombatSimulation, read-only контракт.
/// Контекст: TDD RED — ResonanceAtmosphereController ещё не создан. Reference: RITUAL_COMBAT_TEST_MODEL.md §3.4

import XCTest
@testable import CardSampleGame

/// Ritual Atmosphere Architecture Invariants — Phase 3 Gate Tests (R7)
/// Reference: RITUAL_COMBAT_TEST_MODEL.md §3.4
/// Rule: < 2 seconds per test, static source scan, no runtime dependencies
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
        XCTFail("ResonanceAtmosphereController not yet implemented — R7 TDD RED")
    }
}

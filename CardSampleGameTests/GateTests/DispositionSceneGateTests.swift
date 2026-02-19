/// Файл: CardSampleGameTests/GateTests/DispositionSceneGateTests.swift
/// Назначение: Gate-тесты Scene архитектуры для Disposition Combat (Epic 24).
/// Зона ответственности: Проверяет инварианты сцены — drag→command routing, read-only controllers, animation contracts.
/// Контекст: Reference: RITUAL_COMBAT_TEST_MODEL.md §3.8

import XCTest
import TwilightEngine
@testable import CardSampleGame

/// Disposition Scene Architecture Invariants — Phase 3 Gate Tests (Epic 24)
/// Reference: RITUAL_COMBAT_TEST_MODEL.md §3.8
/// Rule: < 2 seconds per test, deterministic
final class DispositionSceneGateTests: XCTestCase {

    // MARK: - Helpers

    private let projectRoot = SourcePathResolver.projectRoot

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

    // MARK: - Test 1: Scene uses only CombatSimulation API

    /// RitualCombatScene must not access engine internal fields directly.
    /// All mutations go through CombatSimulation methods.
    func testRitualSceneUsesOnlyCombatSimulationAPI() throws {
        let sceneFiles = [
            "Views/Combat/RitualCombatScene.swift",
            "Views/Combat/RitualCombatScene+GameLoop.swift"
        ].map { projectRoot.appendingPathComponent($0) }

        let forbiddenPatterns = [
            ".pendingEncounterState",
            ".pendingExternalCombatSeed",
            ".currentEventId",
            "TwilightGameEngine("
        ]

        var violations: [String] = []

        for fileURL in sceneFiles {
            guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }
            let codeLines = try readCodeLines(from: fileURL)
            for (line, code) in codeLines {
                for pattern in forbiddenPatterns where code.contains(pattern) {
                    violations.append(
                        "  \(fileURL.lastPathComponent):\(line): \(code) [pattern: \(pattern)]"
                    )
                }
            }
        }

        XCTAssertTrue(violations.isEmpty, """
            RitualCombatScene must only use CombatSimulation API, no direct engine access.
            Violations:
            \(violations.joined(separator: "\n"))
        """)
    }

    // MARK: - Test 2: Drag-drop produces canonical commands

    /// ViewModel must route Strike/Influence/Sacrifice to DispositionCombatSimulation.
    /// Scene delegates through ViewModel — canonical command contract.
    func testDragDropProducesCanonicalCommands() {
        let sim = DispositionCombatSimulation.makeStandard(seed: 42)
        let vm = DispositionCombatViewModel(simulation: sim)

        // Strike route: delegates to simulation, shifts disposition negatively
        let preStrike = vm.disposition
        let strikeResult = vm.playStrike(cardId: "card_a", targetId: "enemy")
        XCTAssertTrue(strikeResult, "ViewModel must route strike to simulation")
        XCTAssertLessThan(vm.disposition, preStrike, "Strike must shift disposition negatively")

        // Influence route: delegates to simulation, shifts disposition positively
        let preInfluence = vm.disposition
        let influenceResult = vm.playInfluence(cardId: "card_b")
        XCTAssertTrue(influenceResult, "ViewModel must route influence to simulation")
        XCTAssertGreaterThan(vm.disposition, preInfluence, "Influence must shift disposition positively")

        // Sacrifice route: delegates to simulation, exhausts card
        let preHandCount = vm.hand.count
        let sacrificeResult = vm.playSacrifice(cardId: "card_c")
        XCTAssertTrue(sacrificeResult, "ViewModel must route sacrifice to simulation")
        XCTAssertLessThan(vm.hand.count, preHandCount, "Sacrifice must remove card from hand")
    }

    // MARK: - Test 3: ResonanceAtmosphereController is read-only

    /// ResonanceAtmosphereController must not call any CombatSimulation mutation methods.
    /// Only read-access to resonanceZone, disposition, enemyMode.
    func testResonanceAtmosphereIsReadOnly() throws {
        let controllerFile = projectRoot.appendingPathComponent(
            "Views/Combat/ResonanceAtmosphereController.swift"
        )
        guard FileManager.default.fileExists(atPath: controllerFile.path) else {
            XCTFail("ResonanceAtmosphereController.swift not found")
            return
        }

        let forbiddenPatterns = [
            ".playStrike(", ".playInfluence(", ".playCardAsSacrifice(",
            ".playEcho(", ".endPlayerTurn(", ".beginPlayerTurn(",
            ".applyEnemyAttack(", ".applyEnemyDefend(", ".applyEnemyProvoke(",
            ".applyDispositionShift("
        ]

        let codeLines = try readCodeLines(from: controllerFile)
        var violations: [String] = []

        for (line, code) in codeLines {
            for pattern in forbiddenPatterns where code.contains(pattern) {
                violations.append(
                    "  ResonanceAtmosphereController.swift:\(line): \(code) [pattern: \(pattern)]"
                )
            }
        }

        XCTAssertTrue(violations.isEmpty, """
            ResonanceAtmosphereController must be read-only — no CombatSimulation mutation calls.
            Violations:
            \(violations.joined(separator: "\n"))

            ResonanceAtmosphereController is a pure presentation controller that only reads
            resonance values and outputs visual parameters (§3.8, RITUAL_COMBAT_TEST_MODEL.md).
        """)
    }

    // MARK: - Test 4: Enemy mode transition animation ≥ 0.3s

    /// Enemy mode transition must have animation duration ≥ 0.3s and produce aura change.
    func testEnemyModeTransitionAnimated() throws {
        // Verify duration constant meets visual communication contract
        XCTAssertGreaterThanOrEqual(
            IdolNode.modeTransitionDuration, 0.3,
            "Mode transition animation must be ≥ 0.3s (Epic 24 visual communication contract)"
        )

        // Verify playModeTransition method exists and changes aura state (static scan)
        let idolFile = projectRoot.appendingPathComponent("Views/Combat/IdolNode.swift")
        let content = try String(contentsOf: idolFile, encoding: .utf8)

        XCTAssertTrue(
            content.contains("func playModeTransition(to mode: IdolModeAura"),
            "IdolNode must have playModeTransition(to:) method"
        )
        XCTAssertTrue(
            content.contains("strokeColor = auraColor"),
            "Mode transition must change idol aura via strokeColor"
        )

        // Runtime: verify currentModeAura updates on transition call
        let idol = IdolNode(enemyId: "test_enemy")
        XCTAssertEqual(idol.currentModeAura, .normal, "Initial mode aura must be .normal")

        idol.playModeTransition(to: .survival)
        XCTAssertEqual(idol.currentModeAura, .survival,
            "Mode transition must update currentModeAura to target mode")

        idol.playModeTransition(to: .desperation)
        XCTAssertEqual(idol.currentModeAura, .desperation,
            "Sequential transitions must update mode aura correctly")
    }
}

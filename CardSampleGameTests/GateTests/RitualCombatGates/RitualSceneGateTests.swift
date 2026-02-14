/// Файл: CardSampleGameTests/GateTests/RitualCombatGates/RitualSceneGateTests.swift
/// Назначение: Gate-тесты архитектурных границ RitualCombatScene и DragDropController (R2+R3).
/// Зона ответственности: Static scan — запрет прямого ECS доступа, engine refs, gesture priority.
/// Контекст: TDD RED — сканируемые файлы ещё не созданы. Reference: RITUAL_COMBAT_TEST_MODEL.md §3.3

import XCTest
@testable import CardSampleGame

/// Ritual Scene Architecture Invariants — Phase 3 Gate Tests (R2+R3)
/// Reference: RITUAL_COMBAT_TEST_MODEL.md §3.3
/// Rule: < 2 seconds per test, static source scan, no runtime dependencies
final class RitualSceneGateTests: XCTestCase {

    // MARK: - Helpers

    private let projectRoot = SourcePathResolver.projectRoot

    private func findSwiftFiles(in directory: URL) -> [URL] {
        var result: [URL] = []
        guard let enumerator = FileManager.default.enumerator(
            at: directory, includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return result }
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            result.append(fileURL)
        }
        return result
    }

    /// Read file content, skipping comment lines. Returns array of (lineNumber, codeContent).
    private func readCodeLines(from url: URL) throws -> [(line: Int, code: String)] {
        let content = try String(contentsOf: url, encoding: .utf8)
        return content.components(separatedBy: .newlines).enumerated().compactMap { index, raw in
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") || trimmed.hasPrefix("*") || trimmed.isEmpty {
                return nil
            }
            // Strip inline comments
            var code = trimmed
            if let range = code.range(of: "//") {
                code = String(code[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
            return (line: index + 1, code: code)
        }
    }

    // MARK: - INV-SCENE-001: RitualCombatScene uses only CombatSimulation API

    /// Scene must not access ECS components directly (neither mutation nor read)
    func testRitualSceneUsesOnlyCombatSimulationAPI() throws {
        let sceneFile = projectRoot.appendingPathComponent("Views/Combat/RitualCombatScene.swift")
        guard FileManager.default.fileExists(atPath: sceneFile.path) else {
            XCTFail("RitualCombatScene.swift not found — R2 not yet implemented (TDD RED)")
            return
        }

        let forbiddenPatterns = [
            // ECS types — direct access forbidden
            "Deck(", "DeckCard(", "CombatEntity(",
            // ECS mutations
            ".assign(", ".create(", ".destroy(",
            // ECS reads
            "component(for:", "getComponent("
        ]

        let codeLines = try readCodeLines(from: sceneFile)
        var violations: [String] = []

        for (line, code) in codeLines {
            for pattern in forbiddenPatterns where code.contains(pattern) {
                violations.append("  RitualCombatScene.swift:\(line): \(code) [pattern: \(pattern)]")
            }
        }

        XCTAssertTrue(violations.isEmpty,
            "RitualCombatScene must only use CombatSimulation API, no direct ECS access.\n" +
            "Violations:\n\(violations.joined(separator: "\n"))")
    }

    // MARK: - INV-SCENE-002: No strong engine/bridge references

    /// Scene must not store strong references to TwilightGameEngine or bridge types
    func testRitualSceneHasNoStrongEngineReference() throws {
        let sceneFiles = [
            projectRoot.appendingPathComponent("Views/Combat/RitualCombatScene.swift"),
            projectRoot.appendingPathComponent("Views/Combat/RitualCombatSceneView.swift")
        ]

        let forbiddenTypes = [
            "TwilightGameEngine", "EchoEncounterBridge", "EchoCombatBridge"
        ]

        var violations: [String] = []

        for fileURL in sceneFiles {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                XCTFail("\(fileURL.lastPathComponent) not found — R2 not yet implemented (TDD RED)")
                continue
            }
            let codeLines = try readCodeLines(from: fileURL)
            for (line, code) in codeLines {
                // Look for stored property declarations with forbidden types
                for typeName in forbiddenTypes {
                    if code.contains(typeName) && (code.contains("var ") || code.contains("let ")) {
                        violations.append("  \(fileURL.lastPathComponent):\(line): \(code) [type: \(typeName)]")
                    }
                }
            }
        }

        XCTAssertTrue(violations.isEmpty,
            "RitualCombatScene must not hold strong refs to Engine/Bridge.\n" +
            "Allowed: EchoCombatConfig (DTO), CombatSnapshot (DTO).\n" +
            "Violations:\n\(violations.joined(separator: "\n"))")
    }

    // MARK: - INV-INPUT-001: Drag produces canonical commands

    /// DragDropController must produce CombatSimulation commands, not raw mutations.
    /// This is a runtime behavior test — will be RED until R3 implementation.
    func testDragDropProducesCanonicalCommands() {
        // This test requires DragDropController + mock CombatSimulation to exist.
        // TDD RED: will fail until R3 creates these types.
        XCTFail("DragDropController not yet implemented — R3 TDD RED")
    }

    // MARK: - INV-INPUT-002: Drag does not mutate ECS directly

    /// Static scan: DragDropController must not contain ECS mutation calls
    func testDragDropDoesNotMutateECSDirectly() throws {
        let controllerFile = projectRoot.appendingPathComponent("Views/Combat/DragDropController.swift")
        guard FileManager.default.fileExists(atPath: controllerFile.path) else {
            XCTFail("DragDropController.swift not found — R3 not yet implemented (TDD RED)")
            return
        }

        let forbiddenPatterns = [
            ".assign(", ".create(", ".destroy(",
            "component(for:", "getComponent("
        ]

        let codeLines = try readCodeLines(from: controllerFile)
        var violations: [String] = []

        for (line, code) in codeLines {
            for pattern in forbiddenPatterns where code.contains(pattern) {
                violations.append("  DragDropController.swift:\(line): \(code) [pattern: \(pattern)]")
            }
        }

        XCTAssertTrue(violations.isEmpty,
            "DragDropController must not mutate ECS directly.\n" +
            "Violations:\n\(violations.joined(separator: "\n"))")
    }

    // MARK: - INV-INPUT-003: DragDropController has no engine imports

    /// Static scan: DragDropController must not import TwilightEngine/World types
    func testDragDropControllerHasNoEngineImports() throws {
        let controllerFile = projectRoot.appendingPathComponent("Views/Combat/DragDropController.swift")
        guard FileManager.default.fileExists(atPath: controllerFile.path) else {
            XCTFail("DragDropController.swift not found — R3 not yet implemented (TDD RED)")
            return
        }

        let forbiddenSymbols = [
            "import TwilightEngine",
            "TwilightGameEngine", "WorldState", "WorldRNG",
            "EchoEncounterBridge", "EchoCombatBridge"
        ]

        let codeLines = try readCodeLines(from: controllerFile)
        var violations: [String] = []

        for (line, code) in codeLines {
            for symbol in forbiddenSymbols where code.contains(symbol) {
                violations.append("  DragDropController.swift:\(line): \(code) [symbol: \(symbol)]")
            }
        }

        XCTAssertTrue(violations.isEmpty,
            "DragDropController must not import TwilightEngine or World types.\n" +
            "Allowed: EchoEngine for protocols/DTO.\n" +
            "Violations:\n\(violations.joined(separator: "\n"))")
    }

    // MARK: - INV-INPUT-004: Long-press does not fire after drag start

    /// Gesture priority: long-press must not activate after drag threshold crossed.
    /// Runtime behavior test — TDD RED until R3 implementation.
    func testLongPressDoesNotFireAfterDragStart() {
        // Requires DragDropController with gesture state machine.
        XCTFail("DragDropController gesture priority not yet implemented — R3 TDD RED")
    }
}

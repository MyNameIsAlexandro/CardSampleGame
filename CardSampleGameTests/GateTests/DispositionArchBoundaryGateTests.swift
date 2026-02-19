/// Файл: CardSampleGameTests/GateTests/DispositionArchBoundaryGateTests.swift
/// Назначение: Gate-тесты Architecture Boundary для Phase 3 Disposition Combat (Epics 26a/b).
/// Зона ответственности: Проверяет инварианты INV-DC-039..043.
/// Контекст: Reference: RITUAL_COMBAT_TEST_MODEL.md §3.6

import XCTest
import TwilightEngine
@testable import CardSampleGame

/// Architecture Boundary Invariants — Phase 3 Gate Tests (Epics 26a/b)
/// Reference: RITUAL_COMBAT_TEST_MODEL.md §3.6
/// Rule: < 2 seconds per test, deterministic
final class DispositionArchBoundaryGateTests: XCTestCase {

    // MARK: - Helpers

    private var projectRoot: URL {
        var url = URL(fileURLWithPath: #file)
        // GateTests → CardSampleGameTests → project root
        for _ in 0..<3 { url = url.deletingLastPathComponent() }
        return url
    }

    private func findSwiftFiles(in directory: URL) -> [URL] {
        var result: [URL] = []
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return result }

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            result.append(fileURL)
        }
        return result
    }

    private func isCommentLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") || trimmed.hasPrefix("*")
    }

    // MARK: - INV-DC-039: No direct disposition mutation from App/Views

    /// App/Views layer must not mutate disposition directly.
    /// All disposition changes must go through DispositionCombatSimulation action methods,
    /// routed via DispositionCombatViewModel.
    func testNoDirectDispositionMutationFromAppViews() throws {
        let root = projectRoot
        let dirsToScan = ["App", "Views", "ViewModels"].map {
            root.appendingPathComponent($0)
        }

        let forbiddenPatterns = [
            ".disposition =",
            ".disposition +=",
            ".disposition -="
        ]

        // ViewModel reads disposition through computed property (no mutation)
        let allowedFiles: Set<String> = [
            "DispositionCombatViewModel.swift"
        ]

        var violations: [String] = []

        for dir in dirsToScan where FileManager.default.fileExists(atPath: dir.path) {
            for fileURL in findSwiftFiles(in: dir) {
                let fileName = fileURL.lastPathComponent
                guard !allowedFiles.contains(fileName) else { continue }

                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)

                for (index, line) in lines.enumerated() {
                    guard !isCommentLine(line) else { continue }
                    for pattern in forbiddenPatterns where line.contains(pattern) {
                        let relPath = fileURL.path.replacingOccurrences(
                            of: root.path + "/", with: ""
                        )
                        violations.append(
                            "\(relPath):\(index + 1): \(line.trimmingCharacters(in: .whitespaces))"
                        )
                    }
                }
            }
        }

        XCTAssertTrue(violations.isEmpty, """
            Found direct disposition mutation in App/Views layer:
            \(violations.joined(separator: "\n"))

            Disposition must only be mutated through DispositionCombatSimulation action methods,
            routed via DispositionCombatViewModel (INV-DC-039).
        """)
    }

    // MARK: - INV-DC-040: No fate draw outside engine action path

    /// App/Views must not draw fate cards directly.
    /// Fate draws must occur only within the engine action pipeline.
    func testNoFateDrawOutsideEngineAction() throws {
        let root = projectRoot
        let dirsToScan = ["App", "Views", "ViewModels"].map {
            root.appendingPathComponent($0)
        }

        let forbiddenPatterns = [
            "DispositionFateDeck(",
            ".drawFate(",
            "fateDeck.draw("
        ]

        let allowedFiles: Set<String> = [
            "DispositionCombatViewModel.swift",
            "FateRevealDirector.swift"
        ]

        var violations: [String] = []

        for dir in dirsToScan where FileManager.default.fileExists(atPath: dir.path) {
            for fileURL in findSwiftFiles(in: dir) {
                let fileName = fileURL.lastPathComponent
                guard !allowedFiles.contains(fileName) else { continue }

                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)

                for (index, line) in lines.enumerated() {
                    guard !isCommentLine(line) else { continue }
                    for pattern in forbiddenPatterns where line.contains(pattern) {
                        let relPath = fileURL.path.replacingOccurrences(
                            of: root.path + "/", with: ""
                        )
                        violations.append(
                            "\(relPath):\(index + 1): \(line.trimmingCharacters(in: .whitespaces))"
                        )
                    }
                }
            }
        }

        XCTAssertTrue(violations.isEmpty, """
            Found fate draw usage outside engine action path:
            \(violations.joined(separator: "\n"))

            Fate draws must occur only within the engine action pipeline,
            not directly from App/Views (INV-DC-040).
        """)
    }

    // MARK: - INV-DC-041: Save/restore disposition state roundtrip

    /// DispositionCombatSnapshot must correctly encode, decode, and restore simulation state.
    func testSaveRestoreRoundtrip() throws {
        var sim = DispositionCombatSimulation.makeStandard(seed: 42)
        sim.playStrike(cardId: "card_a", targetId: "enemy")
        sim.playInfluence(cardId: "card_b")

        let snapshot = DispositionCombatSnapshot.capture(from: sim)

        // Encode and decode (simulates actual save/load)
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(DispositionCombatSnapshot.self, from: data)
        let restored = decoded.restore()

        XCTAssertEqual(restored.disposition, sim.disposition,
            "Restored disposition must match original")
        XCTAssertEqual(restored.heroHP, sim.heroHP,
            "Restored heroHP must match original")
        XCTAssertEqual(restored.energy, sim.energy,
            "Restored energy must match original")
        XCTAssertEqual(restored.hand.count, sim.hand.count,
            "Restored hand count must match original")
        XCTAssertEqual(restored.streakType, sim.streakType,
            "Restored streakType must match original")
        XCTAssertEqual(restored.streakCount, sim.streakCount,
            "Restored streakCount must match original")
        XCTAssertEqual(restored.outcome, sim.outcome,
            "Restored outcome must match original")
    }

    // MARK: - INV-DC-042: Arena isolation — no bridge call from arena paths

    /// Arena (sandbox) must not commit disposition combat results to world engine state.
    /// Scans arena-related files for DispositionCombatBridge usage.
    func testArenaIsolation_noBridgeCallFromArena() throws {
        let root = projectRoot

        let arenaDirs = ["Views/Arena", "Views/QuickBattle"].map {
            root.appendingPathComponent($0)
        }

        let forbiddenPattern = "DispositionCombatBridge.applyCombatResult("
        var violations: [String] = []

        for dir in arenaDirs where FileManager.default.fileExists(atPath: dir.path) {
            for fileURL in findSwiftFiles(in: dir) {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)

                for (index, line) in lines.enumerated() {
                    guard !isCommentLine(line) else { continue }
                    if line.contains(forbiddenPattern) {
                        let relPath = fileURL.path.replacingOccurrences(
                            of: root.path + "/", with: ""
                        )
                        violations.append(
                            "\(relPath):\(index + 1): \(line.trimmingCharacters(in: .whitespaces))"
                        )
                    }
                }
            }
        }

        XCTAssertTrue(violations.isEmpty, """
            Found DispositionCombatBridge usage in Arena/QuickBattle paths:
            \(violations.joined(separator: "\n"))

            Arena is a sandbox — disposition combat results must NOT be committed
            to world engine state (§1.5, INV-DC-042).
        """)
    }

    // MARK: - INV-DC-043: Defeat produces correct engine outcome mapping

    /// DispositionCombatResult must correctly map disposition outcomes to engine outcomes.
    /// Defeat (destroyed) → .defeat, Victory (subjugated) → .victory.
    func testDefeatAndVictory_produceCorrectEngineOutcomes() {
        let defeatResult = DispositionCombatResult(
            outcome: .destroyed,
            finalDisposition: -100,
            hpDelta: -30,
            faithDelta: -1,
            resonanceDelta: -0.1,
            lootCardIds: [],
            updatedFateDeckState: nil,
            turnsPlayed: 5,
            cardsPlayed: 10
        )

        XCTAssertEqual(defeatResult.engineOutcome, .defeat,
            "Destroyed outcome must map to .defeat")
        XCTAssertLessThan(defeatResult.hpDelta, 0,
            "Defeat must carry negative hpDelta for world state update")

        let victoryResult = DispositionCombatResult(
            outcome: .subjugated,
            finalDisposition: 100,
            hpDelta: -10,
            faithDelta: 2,
            resonanceDelta: 0.2,
            lootCardIds: ["reward_1"],
            updatedFateDeckState: nil,
            turnsPlayed: 8,
            cardsPlayed: 15
        )

        XCTAssertEqual(victoryResult.engineOutcome, .victory,
            "Subjugated outcome must map to .victory")
        XCTAssertFalse(victoryResult.lootCardIds.isEmpty,
            "Victory must allow loot card distribution")
    }
}

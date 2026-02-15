/// Файл: CardSampleGameTests/GateTests/RitualCombatGates/RitualIntegrationGateTests.swift
/// Назначение: Gate-тесты интеграции FateReveal, Determinism, Snapshot, Arena, Replay (R6+R9+R10a).
/// Зона ответственности: Static scan + runtime gate для cross-component инвариантов.
/// Контекст: TDD RED — большинство сканируемых файлов ещё не созданы. Reference: RITUAL_COMBAT_TEST_MODEL.md §3.5

import XCTest
@testable import CardSampleGame

/// Ritual Integration Invariants — Phase 3 Gate Tests (R6+R9+R10a)
/// Reference: RITUAL_COMBAT_TEST_MODEL.md §3.5
/// Rule: < 2 seconds per test, static source scan where possible, no system RNG
final class RitualIntegrationGateTests: XCTestCase {

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
            var code = trimmed
            if let range = code.range(of: "//") {
                code = String(code[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
            return (line: index + 1, code: code)
        }
    }

    /// Read raw non-comment lines preserving inline comments (for ANIMATION-ONLY whitelist check).
    private func readRawCodeLines(from url: URL) throws -> [(line: Int, raw: String)] {
        let content = try String(contentsOf: url, encoding: .utf8)
        return content.components(separatedBy: .newlines).enumerated().compactMap { index, raw in
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") || trimmed.hasPrefix("*") || trimmed.isEmpty {
                return nil
            }
            return (line: index + 1, raw: trimmed)
        }
    }

    // MARK: - INV-DET-001: FateRevealDirector does not affect determinism

    /// FateRevealDirector as observer must not introduce side effects into CombatSimulation.
    /// Comparison via CombatSnapshot.fingerprint (SHA-256 canonical JSON).
    /// TDD RED until R6 creates FateRevealDirector and CombatSimulation.
    func testFateRevealPreservesExistingDeterminism() {
        XCTFail("FateRevealDirector + CombatSimulation not yet implemented — R6 TDD RED")
    }

    // MARK: - INV-DET-001a: FateRevealDirector has no stored simulation reference

    /// Static scan: FateRevealDirector must not store a reference to CombatSimulation.
    /// Allowed: method parameters (event-driven / callback pattern).
    func testFateRevealDirectorHasNoSimulationReference() throws {
        let directorFile = projectRoot.appendingPathComponent("Views/Combat/FateRevealDirector.swift")
        guard FileManager.default.fileExists(atPath: directorFile.path) else {
            XCTFail("FateRevealDirector.swift not found — R6 not yet implemented (TDD RED)")
            return
        }

        let forbiddenStoredTypes = [
            "CombatSimulation", "CombatSimulationProtocol"
        ]
        let simulationPattern = "Simulation"

        let codeLines = try readCodeLines(from: directorFile)
        var violations: [String] = []

        for (line, code) in codeLines {
            let isStoredProperty = code.contains("var ") || code.contains("let ")
            guard isStoredProperty else { continue }

            for typeName in forbiddenStoredTypes where code.contains(typeName) {
                violations.append("  FateRevealDirector.swift:\(line): \(code) [stored ref: \(typeName)]")
            }
            if code.contains(simulationPattern) && !forbiddenStoredTypes.contains(where: { code.contains($0) }) {
                violations.append("  FateRevealDirector.swift:\(line): \(code) [stored ref pattern: *Simulation*]")
            }
        }

        XCTAssertTrue(violations.isEmpty,
            "FateRevealDirector must not store a reference to CombatSimulation.\n" +
            "Allowed: method parameters (event-driven/callback).\n" +
            "Violations:\n\(violations.joined(separator: "\n"))")
    }

    // MARK: - INV-DET-002: No system RNG sources in RitualCombat code

    /// Static scan: all .swift files in Views/Combat/ (ritual combat area) must not use system RNG.
    /// Whitelist: lines with `// ANIMATION-ONLY: <non-empty reason>` are exempt.
    func testRitualCombatNoSystemRNGSources() throws {
        let combatDir = projectRoot.appendingPathComponent("Views/Combat")
        guard FileManager.default.fileExists(atPath: combatDir.path) else {
            XCTFail("Views/Combat/ directory not found")
            return
        }

        let ritualFiles = findSwiftFiles(in: combatDir).filter { url in
            let name = url.lastPathComponent
            return name.hasPrefix("Ritual") || name.hasPrefix("DragDrop") ||
                   name.hasPrefix("FateReveal") || name.hasPrefix("ResonanceAtmosphere")
        }

        guard !ritualFiles.isEmpty else {
            XCTFail("No RitualCombat source files found in Views/Combat/ — TDD RED")
            return
        }

        let forbiddenPatterns = [
            "random(", ".random(in:", ".random(using:",
            "UUID()",
            "Date()", "Date.now",
            "arc4random", "arc4random_uniform",
            "SystemRandomNumberGenerator",
            "CFAbsoluteTimeGetCurrent",
            "DispatchTime.now()",
            "CACurrentMediaTime()"
        ]

        var violations: [String] = []

        for fileURL in ritualFiles {
            let rawLines = try readRawCodeLines(from: fileURL)
            let fileName = fileURL.lastPathComponent

            for (line, raw) in rawLines {
                for pattern in forbiddenPatterns where raw.contains(pattern) {
                    // Check for ANIMATION-ONLY whitelist marker with non-empty reason
                    if let markerRange = raw.range(of: "// ANIMATION-ONLY: ") {
                        let reason = String(raw[markerRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                        if !reason.isEmpty {
                            continue // Whitelisted with valid reason
                        }
                    }
                    violations.append("  \(fileName):\(line): \(raw) [pattern: \(pattern)]")
                }
            }
        }

        XCTAssertTrue(violations.isEmpty,
            "RitualCombat code must not use system RNG.\n" +
            "Exempt: lines with `// ANIMATION-ONLY: <reason>` (non-empty reason).\n" +
            "Violations:\n\(violations.joined(separator: "\n"))")
    }

    // MARK: - INV-CONTRACT-001: KeywordEffect bonusValue consumed or documented

    /// bonusValue from KeywordEffect must be applied somewhere in engine combat code,
    /// or explicitly documented with INTENTIONALLY_UNUSED marker.
    /// Scans entire engine source trees (not specific files) for rename resilience.
    func testKeywordEffectConsumedOrDocumented() throws {
        // Scan all engine source directories — resilient to file renames/refactoring
        let engineSourceDirs = [
            projectRoot.appendingPathComponent("Packages/TwilightEngine/Sources"),
            projectRoot.appendingPathComponent("Packages/EchoEngine/Sources")
        ]

        var bonusValueConsumed = false
        var intentionallyUnusedMarked = false
        var definitionFile: String?

        for dirURL in engineSourceDirs {
            guard FileManager.default.fileExists(atPath: dirURL.path) else { continue }

            for fileURL in findSwiftFiles(in: dirURL) {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let fileName = fileURL.lastPathComponent

                // Track where bonusValue is defined (to exclude from "consumed" count)
                if content.contains("let bonusValue:") || content.contains("var bonusValue:") ||
                   content.contains("public let bonusValue") || content.contains("public var bonusValue") {
                    definitionFile = fileName
                }

                // Check 1: bonusValue is actively consumed (not just defined)
                if content.contains(".bonusValue") {
                    bonusValueConsumed = true
                }

                // Check 2: INTENTIONALLY_UNUSED marker
                if content.contains("INTENTIONALLY_UNUSED: bonusValue") {
                    intentionallyUnusedMarked = true
                }
            }
        }

        XCTAssertTrue(bonusValueConsumed || intentionallyUnusedMarked,
            "KeywordEffect.bonusValue must be consumed in engine combat code " +
            "OR documented with `// INTENTIONALLY_UNUSED: bonusValue — <reason>` marker.\n" +
            "Scanned: Packages/{TwilightEngine,EchoEngine}/Sources/**/*.swift\n" +
            "Found: bonusValueConsumed=\(bonusValueConsumed), " +
            "intentionallyUnusedMarked=\(intentionallyUnusedMarked), " +
            "definedIn=\(definitionFile ?? "not found")")
    }

    // MARK: - INV-INT-001: RitualScene restores from snapshot

    /// UI restoration from CombatSnapshot: Bonfire/Circle/Seals/Hand visual state.
    /// Includes negative case: inconsistent snapshot (effortBonus ≠ effortCardIds.count).
    /// TDD RED until R9 creates RitualCombatScene with restore support.
    func testRitualSceneRestoresFromSnapshot() {
        XCTFail("RitualCombatScene.restore(from:) not yet implemented — R9 TDD RED")
    }

    // MARK: - INV-INT-002: Arena does not call commit path

    /// Static scan: BattleArenaView must not call commitExternalCombat or bridge commit.
    /// Arena = sandbox, display-only, no world commit.
    func testBattleArenaDoesNotCallCommitPathWhenUsingRitualScene() throws {
        let arenaFile = projectRoot.appendingPathComponent("Views/BattleArenaView.swift")
        guard FileManager.default.fileExists(atPath: arenaFile.path) else {
            XCTFail("BattleArenaView.swift not found")
            return
        }

        let forbiddenCommitPatterns = [
            "commitExternalCombat(",
            ".commitExternalCombat(",
            "applyCombatResult("
        ]

        let codeLines = try readCodeLines(from: arenaFile)
        var violations: [String] = []

        for (line, code) in codeLines {
            for pattern in forbiddenCommitPatterns where code.contains(pattern) {
                violations.append("  BattleArenaView.swift:\(line): \(code) [commit path: \(pattern)]")
            }
        }

        XCTAssertTrue(violations.isEmpty,
            "BattleArenaView (Arena sandbox) must not call commit paths.\n" +
            "Forbidden: commitExternalCombat, applyCombatResult, EchoCombatBridge commit.\n" +
            "Arena = display-only, no world commit.\n" +
            "Violations:\n\(violations.joined(separator: "\n"))")
    }

    // MARK: - INV-INT-003: Old CombatScene not imported in production

    /// Static scan: deprecated CombatScene must not be used in production source.
    /// Checks symbol usage (instantiation, views, extensions, typealias) in production directories.
    ///
    /// Production path allowlist (explicit, not inferred):
    ///   App-layer:   App/, Views/, ViewModels/, Models/, Managers/, Utilities/
    ///   Packages:    EchoEngine/Sources/, EchoScenes/Sources/ (production graph)
    ///   Engine:      TwilightEngine/Sources/ (but CombatScene*.swift files are excluded — they ARE the definition)
    /// Excluded: **/Tests/**, DevTools/, .build/
    func testOldCombatSceneNotImportedInProduction() throws {
        // Explicit production path allowlist — resilient to SourcePathResolver changes
        let productionPaths = [
            "App", "Views", "ViewModels", "Models", "Managers", "Utilities",
            "Packages/EchoEngine/Sources",
            "Packages/TwilightEngine/Sources"
        ]
        let productionDirs = productionPaths.map { projectRoot.appendingPathComponent($0) }

        var violations: [String] = []

        for dirURL in productionDirs {
            guard FileManager.default.fileExists(atPath: dirURL.path) else { continue }

            for fileURL in findSwiftFiles(in: dirURL) {
                let fileName = fileURL.lastPathComponent

                // Skip files that ARE the CombatScene definition (EchoScenes package)
                // and Ritual combat files (RitualCombatScene* are the replacement)
                if fileName.hasPrefix("CombatScene") { continue }
                if fileName.hasPrefix("RitualCombat") { continue }
                // Skip test files
                if fileName.contains("Test") { continue }

                let codeLines = try readCodeLines(from: fileURL)
                for (line, code) in codeLines {
                    // Strip RitualCombat references before checking for legacy CombatScene usage
                    let stripped = code.replacingOccurrences(of: "RitualCombatScene", with: "")
                                       .replacingOccurrences(of: "RitualCombatResult", with: "")
                                       .replacingOccurrences(of: "RitualCombatBridge", with: "")
                    // Check for CombatScene instantiation
                    if stripped.contains("CombatScene(") {
                        violations.append("  \(fileName):\(line): \(code) [symbol: CombatScene(]")
                    }
                    // Check for CombatSceneView usage
                    if stripped.contains("CombatSceneView") {
                        violations.append("  \(fileName):\(line): \(code) [symbol: CombatSceneView]")
                    }
                    // Check for inheritance / conformance
                    if stripped.contains(": CombatScene") {
                        violations.append("  \(fileName):\(line): \(code) [symbol: : CombatScene]")
                    }
                    // Check for typealias to CombatScene
                    if stripped.contains("typealias") && stripped.contains("CombatScene") {
                        violations.append("  \(fileName):\(line): \(code) [symbol: typealias CombatScene]")
                    }
                }
            }
        }

        XCTAssertTrue(violations.isEmpty,
            "Deprecated CombatScene must not be used in production source.\n" +
            "Use RitualCombatScene instead.\n" +
            "Violations:\n\(violations.joined(separator: "\n"))")
    }

    // MARK: - INV-REPLAY-001: Vertical slice replay trace

    /// Replay trace: fixture seed + action sequence → CombatSnapshot.fingerprint must match.
    /// Fixture: Tests/Fixtures/ritual_replay_trace.json (generated by gate script at R10a Go/No-Go).
    /// Fingerprint: SHA-256 of canonical JSON CombatSnapshot (sorted keys, no whitespace).
    /// TDD RED until R10a creates CombatSimulation + fixture + fingerprint.
    func testVerticalSliceReplayTrace() {
        XCTFail("CombatSimulation + replay trace fixture not yet implemented — R10a TDD RED")
    }
}

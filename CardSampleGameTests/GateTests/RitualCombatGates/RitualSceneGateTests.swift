/// Файл: CardSampleGameTests/GateTests/RitualCombatGates/RitualSceneGateTests.swift
/// Назначение: Gate-тесты архитектурных границ RitualCombatScene и DragDropController (R2+R3).
/// Зона ответственности: Static scan — запрет прямого ECS доступа, engine refs, gesture priority.
/// Контекст: TDD RED — сканируемые файлы ещё не созданы. Reference: RITUAL_COMBAT_TEST_MODEL.md §3.3

import XCTest
import TwilightEngine
@testable import CardSampleGame

/// Ritual Scene Architecture Invariants — Phase 3 Gate Tests (R2+R3)
/// Reference: RITUAL_COMBAT_TEST_MODEL.md §3.3
/// Rule: < 2 seconds per test, static source scan, no runtime dependencies
@MainActor
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

    private func fileContent(_ relativePath: String) throws -> String {
        let fileURL = projectRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: fileURL, encoding: .utf8)
    }

    private func assertPattern(
        _ pattern: String,
        in content: String,
        failureMessage: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let range = NSRange(location: 0, length: content.utf16.count)
        let hasMatch = regex?.firstMatch(in: content, options: [], range: range) != nil
        XCTAssertTrue(hasMatch, failureMessage, file: file, line: line)
    }

    private func matchCount(_ pattern: String, in content: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return 0
        }
        let range = NSRange(location: 0, length: content.utf16.count)
        return regex.matches(in: content, options: [], range: range).count
    }

    private func parseRevealBaseDurations(from content: String) -> [Double] {
        guard let regex = try? NSRegularExpression(
            pattern: #"private let base[A-Za-z]+: TimeInterval = ([0-9]+(?:\.[0-9]+)?)"#,
            options: []
        ) else { return [] }

        let ns = content as NSString
        let range = NSRange(location: 0, length: ns.length)
        return regex.matches(in: content, options: [], range: range).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            return Double(ns.substring(with: match.range(at: 1)))
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
    func testDragDropProducesCanonicalCommands() {
        let controller = DragDropController()
        var receivedCommands: [DragCommand] = []
        controller.onCommand = { receivedCommands.append($0) }

        // Tap (no drag) → selectCard
        controller.beginTouch(cardId: "card_a")
        controller.endTouch()
        XCTAssertEqual(receivedCommands.last, .selectCard(cardId: "card_a"))

        // Drag beyond threshold → burnForEffort
        controller.beginTouch(cardId: "card_b")
        controller.updateDrag(offset: CGSize(width: 6, height: 0))
        controller.endTouch()
        XCTAssertEqual(receivedCommands.last, .burnForEffort(cardId: "card_b"))

        // Cancel → cancelDrag
        controller.beginTouch(cardId: "card_c")
        controller.cancel()
        XCTAssertEqual(receivedCommands.last, .cancelDrag)

        XCTAssertEqual(receivedCommands.count, 3)
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
    func testLongPressDoesNotFireAfterDragStart() {
        let controller = DragDropController()

        controller.beginTouch(cardId: "card_a")
        XCTAssertFalse(controller.isLongPressBlocked,
            "Long-press should be allowed during initial press")

        // Move 6px (> 5px threshold) — drag starts
        controller.updateDrag(offset: CGSize(width: 6, height: 0))

        XCTAssertTrue(controller.isLongPressBlocked,
            "Long-press must be blocked after drag threshold crossed")

        if case .dragging = controller.state {
            // Expected
        } else {
            XCTFail("Expected .dragging state after 6px move, got \(controller.state)")
        }
    }

    // MARK: - INV-INPUT-005: Seal strike drag maps to commitAttack

    /// Static contract: in `endSealDrag`, `.strike` must map to `performCommitAttack()`.
    func testSealDragOnEnemyCommitsAttack() throws {
        let content = try fileContent("Views/Combat/RitualCombatScene+GameLoop.swift")
        assertPattern(
            #"switch\s+sealType\s*\{[\s\S]*case\s+\.strike:\s*performCommitAttack\(\)"#,
            in: content,
            failureMessage:
                "Seal strike drag must commit attack via performCommitAttack() in endSealDrag."
        )
    }

    // MARK: - INV-INPUT-006: Seal wait drag maps to skipTurn path

    /// Static contract: in `endSealDrag`, `.wait` must map to `performSkipTurn()`.
    func testSealDragOnAltarCommitsSkip() throws {
        let content = try fileContent("Views/Combat/RitualCombatScene+GameLoop.swift")
        assertPattern(
            #"switch\s+sealType\s*\{[\s\S]*case\s+\.wait:\s*performSkipTurn\(\)"#,
            in: content,
            failureMessage:
                "Wait seal drag must execute skip path via performSkipTurn() in endSealDrag."
        )
    }

    // MARK: - INV-INPUT-007: Wait seal always visible

    /// Wait seal must stay active even when no card is in ritual circle.
    func testWaitSealAlwaysVisible() {
        let simulation = CombatSimulation.makeStandard(seed: 42)
        let scene = RitualCombatScene(size: RitualCombatScene.sceneSize)
        scene.configure(with: simulation)

        scene.updateSealVisibility()

        let waitSeal = scene.sealNodes.first(where: { $0.sealType == .wait })
        let strikeSeal = scene.sealNodes.first(where: { $0.sealType == .strike })
        let speakSeal = scene.sealNodes.first(where: { $0.sealType == .speak })

        XCTAssertNotNil(waitSeal, "Wait seal must exist in layout")
        XCTAssertTrue(waitSeal?.isActive == true, "Wait seal must be visible without selected card")
        XCTAssertTrue(strikeSeal?.isActive == false, "Strike seal must be hidden without selected card")
        XCTAssertTrue(speakSeal?.isActive == false, "Speak seal must be hidden without selected card")

        simulation.selectCard(simulation.hand[0].id)
        scene.updateSealVisibility()

        XCTAssertTrue(waitSeal?.isActive == true, "Wait seal must remain visible with selected card")
        XCTAssertTrue(strikeSeal?.isActive == true, "Strike seal must become visible when card selected")
        XCTAssertTrue(speakSeal?.isActive == true, "Speak seal must become visible when card selected")
    }

    // MARK: - INV-FATE-001: Major reveal uses full timeline

    /// Major reveal must keep full sequence chain with default major tempo.
    func testMajorFateUsesFullTimeline() throws {
        XCTAssertEqual(RevealTempo.major.scale, 1.0, accuracy: 0.0001, "Major tempo scale must remain full")

        let content = try fileContent("Views/Combat/FateRevealDirector.swift")
        assertPattern(
            #"func beginReveal\([\s\S]*tempo: RevealTempo = \.major"#,
            in: content,
            failureMessage: "beginReveal default tempo must be .major for full drama path."
        )
        assertPattern(
            #"runAnticipation\([\s\S]*\{\s*\[weak self\]\s*in\s*self\?\.runFlip\(data: data\)"#,
            in: content,
            failureMessage: "Major timeline must transition anticipation → flip."
        )
        assertPattern(
            #"runFlip\([\s\S]*\{\s*\[weak self\]\s*in[\s\S]*self\?\.runValuePunch\(data: data\)"#,
            in: content,
            failureMessage: "Major timeline must transition flip → value punch."
        )
        assertPattern(
            #"if data\.isSuitMatch \{[\s\S]*runSuitMatch\(data: data\)[\s\S]*else if data\.keyword != nil \{[\s\S]*runKeywordEffect\(data: data\)[\s\S]*else \{[\s\S]*runDamageFlyOrHold\(data: data\)"#,
            in: content,
            failureMessage: "Major timeline must include suit/keyword branches before damage/hold."
        )
    }

    // MARK: - INV-FATE-002: Minor reveal is compact

    /// Minor tempo must stay strictly shorter than major across all reveal phases.
    func testMinorFateUsesShortTimeline() throws {
        XCTAssertEqual(RevealTempo.minor.scale, 0.6, accuracy: 0.0001, "Minor tempo scale must remain compact")
        XCTAssertLessThan(RevealTempo.minor.scale, RevealTempo.major.scale, "Minor tempo must be shorter than major")

        let content = try fileContent("Views/Combat/FateRevealDirector.swift")
        let baseDurations = parseRevealBaseDurations(from: content)
        XCTAssertGreaterThanOrEqual(baseDurations.count, 6, "Reveal director must keep explicit base phase timings")

        let majorTotal = baseDurations.reduce(0, +) * RevealTempo.major.scale
        let minorTotal = baseDurations.reduce(0, +) * RevealTempo.minor.scale
        XCTAssertLessThan(minorTotal, majorTotal, "Minor timeline must be shorter than major timeline")
    }

    // MARK: - INV-FATE-003: Wait path skips reveal

    /// Wait action must suppress defense reveal and jump directly to resolution.
    func testWaitSkipsFateReveal() throws {
        let content = try fileContent("Views/Combat/RitualCombatScene+GameLoop.swift")
        assertPattern(
            #"private func performSkipTurn\(\)\s*\{[\s\S]*suppressDefenseRevealForCurrentResolution = true[\s\S]*transitionToResolution\(\)"#,
            in: content,
            failureMessage: "Skip path must mark defense reveal as suppressed and transition to resolution."
        )
        assertPattern(
            #"let shouldShowDefenseReveal = !suppressDefenseRevealForCurrentResolution && !attacks\.isEmpty"#,
            in: content,
            failureMessage: "Resolution must gate reveal by suppressDefenseRevealForCurrentResolution flag."
        )
    }

    // MARK: - INV-FATE-004: Defense reveal uses compact tempo

    /// Defense reveal, when shown, must use compact minor tempo.
    func testDefenseFateUsesCompactReveal() throws {
        let candidatePaths = [
            "Views/Combat/RitualCombatScene+GameLoop.swift",
            "Views/Combat/RitualCombatScene.swift"
        ]
        let content = try candidatePaths
            .compactMap { relativePath -> String? in
                let fileURL = projectRoot.appendingPathComponent(relativePath)
                guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
                return try String(contentsOf: fileURL, encoding: .utf8)
            }
            .joined(separator: "\n")
        XCTAssertFalse(content.isEmpty, "Ritual scene source files for defense reveal were not found.")
        assertPattern(
            #"beginReveal\([\s\S]*tempo:\s*\.minor"#,
            in: content,
            failureMessage: "Defense reveal must call FateRevealDirector.beginReveal with tempo: .minor."
        )
    }

    // MARK: - INV-FATE-005: Keyword visual maps from resolved keyword

    /// Keyword effect label must render resolved keyword value, not hardcoded token.
    func testKeywordVisualMatchesResolution() throws {
        let content = try fileContent("Views/Combat/FateRevealDirector.swift")
        assertPattern(
            #"private func runKeywordEffect\(data: RevealData\)"#,
            in: content,
            failureMessage: "FateRevealDirector must implement dedicated keyword visual phase."
        )
        assertPattern(
            #"let keyword = data\.keyword"#,
            in: content,
            failureMessage: "Keyword visual must read keyword from resolved reveal data."
        )
        assertPattern(
            #"label\.text = keyword"#,
            in: content,
            failureMessage: "Keyword visual label must display resolved keyword text."
        )
    }

    // MARK: - INV-FATE-006: Suit match glow is present

    /// Suit match branch must produce glow flash effect.
    func testSuitMatchShowsGlowEffect() throws {
        let content = try fileContent("Views/Combat/FateRevealDirector.swift")
        assertPattern(
            #"if data\.isSuitMatch \{[\s\S]*runSuitMatch\(data: data\)"#,
            in: content,
            failureMessage: "Suit match branch must invoke runSuitMatch."
        )
        assertPattern(
            #"flash\.glowWidth = 6"#,
            in: content,
            failureMessage: "Suit match visual must keep glow flash."
        )
        assertPattern(
            #"flash\.strokeColor = SKColor\(red: 0\.90, green: 0\.75, blue: 0\.30, alpha: 1\)"#,
            in: content,
            failureMessage: "Suit match glow must use highlighted stroke color."
        )
    }

    // MARK: - INV-FATE-007: Suit mismatch does not trigger glow

    /// Non-match branch must bypass runSuitMatch and proceed to keyword/damage path.
    func testSuitMismatchShowsNoGlow() throws {
        let content = try fileContent("Views/Combat/FateRevealDirector.swift")
        assertPattern(
            #"if data\.isSuitMatch \{[\s\S]*runSuitMatch\(data: data\)[\s\S]*\} else if data\.keyword != nil \{[\s\S]*runKeywordEffect\(data: data\)[\s\S]*\} else \{[\s\S]*runDamageFlyOrHold\(data: data\)"#,
            in: content,
            failureMessage: "Non-match branch must skip glow and route to keyword/damage logic."
        )
        XCTAssertEqual(
            matchCount(#"runSuitMatch\(data: data\)"#, in: content),
            1,
            "runSuitMatch(data:) call site count must remain exactly one guarded branch."
        )
    }
}

/// Файл: CardSampleGameTests/GateTests/AuditArchitectureBoundaryGateTests+ExternalCombatAndMutations.swift
/// Назначение: Содержит реализацию файла AuditArchitectureBoundaryGateTests+ExternalCombatAndMutations.swift.
/// Зона ответственности: Фиксирует проверяемый контракт и не содержит production-логики.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import CardSampleGame

extension AuditArchitectureBoundaryGateTests {
    // MARK: - Epic 20: External Combat Lifecycle Integrity Gates

    /// Gate test: App/UI code must not mutate external combat persistence fields directly.
    /// Only engine action pipeline may update `pendingEncounterState` / `pendingExternalCombatSeed`.
    func testAppLayersDoNotMutatePendingEncounterStateDirectly() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let dirsToScan = ["App", "Views", "ViewModels", "Models", "Utilities"]
        let patterns = ["pendingEncounterState =", "pendingExternalCombatSeed ="]

        var violations: [String] = []

        for dir in dirsToScan {
            let dirURL = projectRoot.appendingPathComponent(dir)
            guard FileManager.default.fileExists(atPath: dirURL.path) else { continue }

            for fileURL in findSwiftFiles(in: dirURL) {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)

                for (index, line) in lines.enumerated() {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") || trimmed.hasPrefix("*") {
                        continue
                    }

                    if patterns.contains(where: { line.contains($0) }) {
                        violations.append("\(fileURL.lastPathComponent):\(index + 1): \(trimmed)")
                    }
                }
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            """
            Found direct external-combat state mutation in app layers:
            \(violations.joined(separator: "\n"))

            Use `performAction(.combatStoreEncounterState(...))` via bridge helpers.
            """
        )
    }

    /// Gate test: direct mutation points in Engine/Core remain narrowly scoped.
    func testEngineCorePendingEncounterMutationPointsAreExplicit() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let coreDir = projectRoot.appendingPathComponent(SourcePathResolver.engineBase + "/Core")
        guard FileManager.default.fileExists(atPath: coreDir.path) else {
            XCTFail("GATE TEST FAILURE: Engine/Core directory not found")
            return
        }

        let allowedFiles: Set<String> = [
            "TwilightGameEngine+Initialization.swift",
            "TwilightGameEngine+Actions.swift",
            "TwilightGameEngine+SaveLoad.swift",
            "TwilightGameEngine.swift"
        ]
        let patterns = ["pendingEncounterState =", "pendingExternalCombatSeed ="]
        var violations: [String] = []

        for fileURL in findSwiftFiles(in: coreDir) {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            guard patterns.contains(where: { content.contains($0) }) else { continue }

            if !allowedFiles.contains(fileURL.lastPathComponent) {
                violations.append(fileURL.lastPathComponent)
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            """
            External-combat persistence fields are mutated outside approved Engine/Core files:
            \(violations.joined(separator: ", "))

            Keep mutation points centralized in initialization, actions, save/load and combat-finalize paths.
            """
        )
    }

    // MARK: - Epic 29: Engine Mutation Boundary Hardening

    /// Gate test: app/UI layers must not mutate critical engine state fields directly.
    /// These fields must be changed only inside engine action/save-load paths.
    func testAppLayersDoNotMutateCriticalEngineStateDirectly() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let dirsToScan = ["App", "Views", "ViewModels", "Models", "Utilities"]
        let criticalFields = [
            "pendingEncounterState",
            "pendingExternalCombatSeed",
            "currentEventId",
            "isInCombat",
            "publishedActiveQuests",
            "publishedWorldFlags",
            "publishedEventLog"
        ]

        var violations: [String] = []

        for dir in dirsToScan {
            let dirURL = projectRoot.appendingPathComponent(dir)
            guard FileManager.default.fileExists(atPath: dirURL.path) else { continue }

            for fileURL in findSwiftFiles(in: dirURL) {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)
                let relPath = fileURL.path.replacingOccurrences(of: projectRoot.path + "/", with: "")

                for (index, rawLine) in lines.enumerated() {
                    let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
                    if isCommentLine(trimmed) { continue }

                    let code = stripInlineComment(from: rawLine)
                    guard !code.isEmpty else { continue }

                    for field in criticalFields where lineContainsAssignment(code, field: field) {
                        violations.append("\(relPath):\(index + 1): [\(field)] \(trimmed)")
                    }
                }
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            """
            Found direct app-layer mutation of critical engine fields:
            \(violations.joined(separator: "\n"))

            App/UI must commit through `performAction(...)` only.
            """
        )
    }

    /// Gate test: app/UI layers must not access deterministic RNG primitives directly.
    /// RNG ownership belongs to Engine/Core to preserve reproducibility and save/load invariants.
    func testAppLayersDoNotAccessEngineServicesRngDirectly() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let dirsToScan = ["App", "Views", "ViewModels", "Models", "Utilities"]
        let forbiddenPatterns = [
            "engine.services.rng",
            "vm.engine.services.rng",
            "WorldRNG.shared.nextSeed("
        ]

        var violations: [String] = []

        for dir in dirsToScan {
            let dirURL = projectRoot.appendingPathComponent(dir)
            guard FileManager.default.fileExists(atPath: dirURL.path) else { continue }

            for fileURL in findSwiftFiles(in: dirURL) {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)
                let relPath = fileURL.path.replacingOccurrences(of: projectRoot.path + "/", with: "")

                for (index, rawLine) in lines.enumerated() {
                    let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
                    if isCommentLine(trimmed) { continue }

                    let code = stripInlineComment(from: rawLine)
                    guard !code.isEmpty else { continue }

                    if forbiddenPatterns.contains(where: { code.contains($0) }) {
                        violations.append("\(relPath):\(index + 1): \(trimmed)")
                    }
                }
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            """
            Found direct app-layer access to deterministic RNG primitives:
            \(violations.joined(separator: "\n"))

            Keep RNG usage inside Engine/Core action paths only.
            """
        )
    }

    /// Gate test: app/UI layers must not request deterministic seeds via engine facade.
    /// External combat seed lifecycle is controlled by action pipeline (`.startCombat`).
    func testAppLayersDoNotCallEngineNextSeedFacade() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let dirsToScan = ["App", "Views", "ViewModels", "Models", "Utilities"]
        let forbiddenPatterns = [
            "engine.nextSeed(",
            "vm.engine.nextSeed("
        ]

        var violations: [String] = []

        for dir in dirsToScan {
            let dirURL = projectRoot.appendingPathComponent(dir)
            guard FileManager.default.fileExists(atPath: dirURL.path) else { continue }

            for fileURL in findSwiftFiles(in: dirURL) {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)
                let relPath = fileURL.path.replacingOccurrences(of: projectRoot.path + "/", with: "")

                for (index, rawLine) in lines.enumerated() {
                    let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
                    if isCommentLine(trimmed) { continue }

                    let code = stripInlineComment(from: rawLine)
                    guard !code.isEmpty else { continue }

                    if forbiddenPatterns.contains(where: { code.contains($0) }) {
                        violations.append("\(relPath):\(index + 1): \(trimmed)")
                    }
                }
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            """
            Found direct app-layer calls to engine `nextSeed` facade:
            \(violations.joined(separator: "\n"))

            Deterministic external-combat seed allocation must stay inside `.startCombat`.
            """
        )
    }

    /// Gate test: TwilightGameEngine facade must not expose public `nextSeed`.
    func testTwilightGameEngineFacadeDoesNotExposePublicNextSeed() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let coreDir = projectRoot.appendingPathComponent(SourcePathResolver.engineBase + "/Core")
        guard FileManager.default.fileExists(atPath: coreDir.path) else {
            XCTFail("GATE TEST FAILURE: Engine/Core directory not found")
            return
        }

        var violations: [String] = []
        for fileURL in findSwiftFiles(in: coreDir) {
            let relPath = fileURL.path.replacingOccurrences(of: projectRoot.path + "/", with: "")
            let fileViolations = try checkForbiddenPatternsInFile(
                fileURL,
                patterns: ["public func nextSeed("]
            )
            violations.append(contentsOf: fileViolations.map { "\(relPath) -> \($0)" })
        }

        XCTAssertTrue(
            violations.isEmpty,
            """
            Engine/Core must not expose public `nextSeed`:
            \(violations.joined(separator: "\n"))

            Use action-driven seed capability (`.startCombat` + `pendingExternalCombatSeed`) instead.
            """
        )
    }

    /// Gate test: pending encounter snapshot must be read-only outside engine internals.
    func testPendingEncounterStateIsReadOnlyOutsideEngine() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let engineFile = projectRoot.appendingPathComponent(
            SourcePathResolver.engineBase + "/Core/TwilightGameEngine.swift"
        )
        guard FileManager.default.fileExists(atPath: engineFile.path) else {
            XCTFail("GATE TEST FAILURE: TwilightGameEngine.swift not found")
            return
        }

        let content = try String(contentsOf: engineFile, encoding: .utf8)
        XCTAssertTrue(
            content.contains("public private(set) var pendingEncounterState: EncounterSaveState?"),
            """
            `pendingEncounterState` must be `public private(set)` to prevent app-layer direct mutation.
            Write access must stay inside engine action/save-load paths.
            """
        )
    }

    /// Gate test: engine invalid-action contract must use typed reason codes, not raw user-facing strings.
    func testEngineInvalidActionUsesTypedReasonCodes() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let actionFile = projectRoot.appendingPathComponent(
            SourcePathResolver.engineBase + "/Core/TwilightGameActionResult.swift"
        )
        guard FileManager.default.fileExists(atPath: actionFile.path) else {
            XCTFail("GATE TEST FAILURE: TwilightGameActionResult.swift not found")
            return
        }

        let actionContent = try String(contentsOf: actionFile, encoding: .utf8)
        XCTAssertTrue(
            actionContent.contains("case invalidAction(reason: InvalidActionReason)"),
            """
            ActionError.invalidAction must use typed InvalidActionReason payload.
            """
        )
        XCTAssertFalse(
            actionContent.contains("case invalidAction(reason: String)"),
            """
            ActionError.invalidAction(reason: String) is forbidden.
            Keep invalid-action payload as typed reason-codes to prevent raw text drift in engine.
            """
        )

        let coreDir = projectRoot.appendingPathComponent(SourcePathResolver.engineBase + "/Core")
        guard FileManager.default.fileExists(atPath: coreDir.path) else {
            XCTFail("GATE TEST FAILURE: Engine/Core directory not found")
            return
        }

        var violations: [String] = []
        for fileURL in findSwiftFiles(in: coreDir) {
            let relPath = fileURL.path.replacingOccurrences(of: projectRoot.path + "/", with: "")
            let fileViolations = try checkForbiddenPatternsInFile(
                fileURL,
                patterns: [".invalidAction(reason: \""]
            )
            violations.append(contentsOf: fileViolations.map { "\(relPath) -> \($0)" })
        }

        XCTAssertTrue(
            violations.isEmpty,
            """
            Found raw string invalid-action reasons in Engine/Core:
            \(violations.joined(separator: "\n"))

            Use typed `InvalidActionReason` cases instead.
            """
        )
    }

    /// Gate test: Quick Battle / Arena stays sandboxed and cannot commit result into world-engine state.
    func testBattleArenaRemainsSandboxedFromWorldEngineCommitPath() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let arenaFile = projectRoot.appendingPathComponent("Views/BattleArenaView.swift")
        guard FileManager.default.fileExists(atPath: arenaFile.path) else {
            XCTFail("GATE TEST FAILURE: BattleArenaView.swift not found")
            return
        }

        let forbiddenPatterns = [
            ".applyEchoCombatResult(",
            "EchoCombatBridge.applyCombatResult(",
            "GameEngineObservable",
            "TwilightGameEngine",
            "vm.engine",
            "engine.services.rng",
            "UInt64.random(",
            ".performAction(",
            ".startCombat(",
            ".combatFinish(",
            ".combatStoreEncounterState(",
            ".commitExternalCombat("
        ]

        let violations = try checkForbiddenPatternsInFile(arenaFile, patterns: forbiddenPatterns)

        XCTAssertTrue(
            violations.isEmpty,
            """
            BattleArenaView must remain sandboxed from world-engine mutation/RNG paths:
            \(violations.joined(separator: "\n"))

            Quick Battle should not commit results to main engine state.
            """
        )
    }

    /// Gate test: Echo bridge must use engine-owned external combat snapshot seed.
    func testEchoEncounterBridgeUsesEngineExternalCombatSnapshotSeed() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let bridgeFile = projectRoot.appendingPathComponent("Views/Combat/EchoEncounterBridge.swift")
        guard FileManager.default.fileExists(atPath: bridgeFile.path) else {
            XCTFail("GATE TEST FAILURE: EchoEncounterBridge.swift not found")
            return
        }

        let content = try String(contentsOf: bridgeFile, encoding: .utf8)
        XCTAssertTrue(
            content.contains("makeExternalCombatSnapshot(difficulty:"),
            """
            EchoEncounterBridge must build combat config from engine external-combat snapshot.
            """
        )
        XCTAssertFalse(
            content.contains("WorldRNG.shared.nextSeed("),
            """
            EchoEncounterBridge must not allocate combat seed from app-layer/global RNG.
            Use engine-owned snapshot seed only.
            """
        )
    }

    /// Gate test: direct mutation points for critical state fields in Engine/Core remain explicitly centralized.
    func testEngineCoreCriticalStateMutationPointsAreExplicit() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let coreDir = projectRoot.appendingPathComponent(SourcePathResolver.engineBase + "/Core")
        guard FileManager.default.fileExists(atPath: coreDir.path) else {
            XCTFail("GATE TEST FAILURE: Engine/Core directory not found")
            return
        }

        let mutationAllowlist: [(field: String, allowedFiles: Set<String>)] = [
            (
                "currentEventId",
                [
                    "TwilightGameEngine+Initialization.swift",
                    "TwilightGameEngine+Actions.swift",
                    "TwilightGameEngine+SaveLoad.swift",
                    "TwilightGameEngine.swift"
                ]
            ),
            (
                "isInCombat",
                [
                    "TwilightGameEngine+Initialization.swift",
                    "TwilightGameEngine+SaveLoad.swift",
                    "EngineCombatManager.swift",
                    "TwilightGameEngine.swift"
                ]
            ),
            (
                "pendingEncounterState",
                [
                    "TwilightGameEngine+Initialization.swift",
                    "TwilightGameEngine+Actions.swift",
                    "TwilightGameEngine+SaveLoad.swift",
                    "TwilightGameEngine.swift"
                ]
            ),
            (
                "pendingExternalCombatSeed",
                [
                    "TwilightGameEngine+Initialization.swift",
                    "TwilightGameEngine+Actions.swift",
                    "TwilightGameEngine+SaveLoad.swift",
                    "TwilightGameEngine.swift"
                ]
            ),
            (
                "publishedActiveQuests",
                [
                    "TwilightGameEngine+SaveLoad.swift",
                    "TwilightGameEngine+PersistenceRestore.swift",
                    "TwilightGameEngine+WorldSetupAndPublishedState.swift",
                    "TwilightGameEngine.swift"
                ]
            ),
            (
                "publishedWorldFlags",
                [
                    "TwilightGameEngine+SaveLoad.swift",
                    "TwilightGameEngine+WorldSetupAndPublishedState.swift",
                    "TwilightGameEngine.swift"
                ]
            ),
            (
                "publishedEventLog",
                [
                    "TwilightGameEngine+Journal.swift",
                    "TwilightGameEngine+WorldSetupAndPublishedState.swift",
                    "TwilightGameEngine.swift"
                ]
            )
        ]

        var violations: [String] = []

        for fileURL in findSwiftFiles(in: coreDir) {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            let relPath = fileURL.path.replacingOccurrences(of: projectRoot.path + "/", with: "")

            for (index, rawLine) in lines.enumerated() {
                let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
                if isCommentLine(trimmed) { continue }

                let code = stripInlineComment(from: rawLine)
                guard !code.isEmpty else { continue }

                for rule in mutationAllowlist where lineContainsAssignment(code, field: rule.field) {
                    if !rule.allowedFiles.contains(fileURL.lastPathComponent) {
                        violations.append("\(relPath):\(index + 1): [\(rule.field)] \(trimmed)")
                    }
                }
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            """
            Critical Engine/Core state mutation detected outside approved files:
            \(violations.joined(separator: "\n"))

            Keep mutation points centralized in engine initialization, actions, save/load and combat manager paths.
            """
        )
    }
}

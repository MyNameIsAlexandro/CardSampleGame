/// Файл: CardSampleGameTests/GateTests/AuditArchitectureBoundaryGateTests+BridgeCallsiteGates.swift
/// Назначение: Содержит реализацию файла AuditArchitectureBoundaryGateTests+BridgeCallsiteGates.swift.
/// Зона ответственности: Фиксирует проверяемый контракт и не содержит production-логики.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import CardSampleGame

extension AuditArchitectureBoundaryGateTests {
    /// Gate test: app-layer `EchoCombatBridge.applyCombatResult(...)` call-sites must be explicit and reviewed.
    /// This prevents accidental world-state mutation from non-canonical UI flows.
    func testEchoCombatBridgeApplyCallSitesAreExplicit() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let dirsToScan = ["App", "Views", "ViewModels", "Models", "Utilities"]
        let allowedFiles: Set<String> = [
            "ContentView.swift", // resume external combat
            "EventView.swift"    // canonical event-driven external combat flow
        ]
        let pattern = "EchoCombatBridge.applyCombatResult("

        var violations: [String] = []

        for dir in dirsToScan {
            let dirURL = projectRoot.appendingPathComponent(dir)
            guard FileManager.default.fileExists(atPath: dirURL.path) else { continue }

            for fileURL in findSwiftFiles(in: dirURL) {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                guard content.contains(pattern) else { continue }
                guard !allowedFiles.contains(fileURL.lastPathComponent) else { continue }

                let relPath = fileURL.path.replacingOccurrences(of: projectRoot.path + "/", with: "")
                let lines = content.components(separatedBy: .newlines)
                for (index, line) in lines.enumerated() where line.contains(pattern) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") || trimmed.hasPrefix("*") {
                        continue
                    }
                    violations.append("\(relPath):\(index + 1): \(trimmed)")
                }
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            """
            Found unexpected `EchoCombatBridge.applyCombatResult(...)` call-sites outside approved entry points:
            \(violations.joined(separator: "\n"))

            External combat results must be committed only by the canonical bridge flow.
            """
        )
    }

    /// Gate test: app-layer `.startCombat(...)` call-sites must be explicit and reviewed.
    func testStartCombatCallSitesAreExplicit() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let dirsToScan = ["App", "Views", "ViewModels", "Models", "Utilities"]
        let allowedFiles: Set<String> = [
            "EventView.swift" // canonical event-driven external combat entry
        ]
        let pattern = ".startCombat("

        var violations: [String] = []

        for dir in dirsToScan {
            let dirURL = projectRoot.appendingPathComponent(dir)
            guard FileManager.default.fileExists(atPath: dirURL.path) else { continue }

            for fileURL in findSwiftFiles(in: dirURL) {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                guard content.contains(pattern) else { continue }
                guard !allowedFiles.contains(fileURL.lastPathComponent) else { continue }

                let relPath = fileURL.path.replacingOccurrences(of: projectRoot.path + "/", with: "")
                let lines = content.components(separatedBy: .newlines)
                for (index, line) in lines.enumerated() where line.contains(pattern) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") || trimmed.hasPrefix("*") {
                        continue
                    }
                    violations.append("\(relPath):\(index + 1): \(trimmed)")
                }
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            """
            Found unexpected `.startCombat(...)` call-sites outside approved entry points:
            \(violations.joined(separator: "\n"))

            External combat start must stay centralized in canonical event flow.
            """
        )
    }

    /// Gate test: app/UI layers must not setup combat enemy directly.
    /// Enemy setup belongs to engine action path (`.startCombat`).
    func testDirectCombatEnemySetupCallSitesAreForbidden() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let dirsToScan = ["App", "Views", "ViewModels", "Models", "Utilities"]
        let forbiddenPatterns = [
            "combat.setupCombatEnemy(",
            "engine.combat.setupCombatEnemy("
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
            Found direct app-layer `combat.setupCombatEnemy(...)` call-sites:
            \(violations.joined(separator: "\n"))

            Use `performAction(.startCombat(...))` as the canonical entrypoint.
            """
        )
    }

    /// Gate test: app/UI layers must not call `.combatFinish(...)` directly.
    /// Commit must go through canonical `commitExternalCombat(...)` facade.
    func testCombatFinishCallSitesAreExplicit() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let dirsToScan = ["App", "Views", "ViewModels", "Models", "Utilities"]
        let pattern = ".combatFinish("

        var violations: [String] = []

        for dir in dirsToScan {
            let dirURL = projectRoot.appendingPathComponent(dir)
            guard FileManager.default.fileExists(atPath: dirURL.path) else { continue }

            for fileURL in findSwiftFiles(in: dirURL) {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                guard content.contains(pattern) else { continue }

                let relPath = fileURL.path.replacingOccurrences(of: projectRoot.path + "/", with: "")
                let lines = content.components(separatedBy: .newlines)
                for (index, line) in lines.enumerated() where line.contains(pattern) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") || trimmed.hasPrefix("*") {
                        continue
                    }
                    violations.append("\(relPath):\(index + 1): \(trimmed)")
                }
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            """
            Found direct `.combatFinish(...)` app-layer call-sites:
            \(violations.joined(separator: "\n"))

            Use `commitExternalCombat(...)` facade instead of direct action invocation.
            """
        )
    }

    /// Gate test: app-layer `commitExternalCombat(...)` call-sites must be explicit and reviewed.
    func testCommitExternalCombatCallSitesAreExplicit() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let dirsToScan = ["App", "Views", "ViewModels", "Models", "Utilities"]
        let allowedFiles: Set<String> = [
            "EventView.swift",
            "EchoCombatBridge.swift",
            "RitualCombatBridge.swift"
        ]
        let pattern = "commitExternalCombat("

        var violations: [String] = []

        for dir in dirsToScan {
            let dirURL = projectRoot.appendingPathComponent(dir)
            guard FileManager.default.fileExists(atPath: dirURL.path) else { continue }

            for fileURL in findSwiftFiles(in: dirURL) {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                guard content.contains(pattern) else { continue }
                guard !allowedFiles.contains(fileURL.lastPathComponent) else { continue }

                let relPath = fileURL.path.replacingOccurrences(of: projectRoot.path + "/", with: "")
                let lines = content.components(separatedBy: .newlines)
                for (index, line) in lines.enumerated() where line.contains(pattern) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") || trimmed.hasPrefix("*") {
                        continue
                    }
                    violations.append("\(relPath):\(index + 1): \(trimmed)")
                }
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            """
            Found unexpected `.commitExternalCombat(...)` call-sites outside approved entry points:
            \(violations.joined(separator: "\n"))

            External combat commit should stay centralized in canonical bridge/event flows.
            """
        )
    }

    /// Gate test: combat bridge files in app layer must stay adapter-only and must not extend TwilightGameEngine.
    func testCombatBridgeFilesDoNotReintroduceEngineExtensions() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let bridgePaths = [
            "Views/Combat/EchoCombatBridge.swift",
            "Views/Combat/EchoEncounterBridge.swift"
        ]

        let forbiddenPatterns = [
            "extension TwilightGameEngine",
            "struct ExternalCombatSnapshot",
            "struct ExternalCombatEnemySnapshot"
        ]

        var violations: [String] = []

        for bridgePath in bridgePaths {
            let bridgeFile = projectRoot.appendingPathComponent(bridgePath)
            guard FileManager.default.fileExists(atPath: bridgeFile.path) else {
                XCTFail("GATE TEST FAILURE: \(bridgePath) not found")
                return
            }
            violations.append(contentsOf: try checkForbiddenPatternsInFile(bridgeFile, patterns: forbiddenPatterns))
        }

        XCTAssertTrue(
            violations.isEmpty,
            """
            Combat bridge files must remain adapter-only. Found forbidden engine logic:
            \(violations.joined(separator: "\n"))

            Keep external combat snapshot/context construction inside TwilightEngine package.
            """
        )
    }
}

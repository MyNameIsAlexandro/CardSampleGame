/// Файл: CardSampleGameTests/GateTests/AuditArchitectureBoundaryGateTests+DependenciesAndHygiene.swift
/// Назначение: Содержит реализацию файла AuditArchitectureBoundaryGateTests+DependenciesAndHygiene.swift.
/// Зона ответственности: Фиксирует проверяемый контракт и не содержит production-логики.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import CardSampleGame

extension AuditArchitectureBoundaryGateTests {
    // MARK: - Epic 36: Architecture Dependency Gates

    /// Gate test: ViewModels stay framework-agnostic and do not depend on UI/render modules.
    func testViewModelsDoNotImportUIOrRenderModules() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let viewModelsDir = projectRoot.appendingPathComponent("ViewModels")
        guard FileManager.default.fileExists(atPath: viewModelsDir.path) else {
            XCTFail("GATE TEST FAILURE: ViewModels directory not found")
            return
        }

        let forbiddenModules: Set<String> = [
            "SwiftUI",
            "UIKit",
            "AppKit",
            "SpriteKit",
            "SceneKit",
            "EchoEngine",
            "EchoScenes"
        ]

        let violations = try collectImportViolations(
            in: [viewModelsDir],
            forbiddenModules: forbiddenModules
        )

        XCTAssertTrue(
            violations.isEmpty,
            """
            Found forbidden ViewModel imports from UI/render modules:
            \(violations.joined(separator: "\n"))

            Keep ViewModels independent from view/runtime rendering frameworks.
            """
        )
    }

    /// Gate test: pure model layer must remain UI-framework free.
    func testModelsDoNotImportUIOrRenderModules() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let modelsDir = projectRoot.appendingPathComponent("Models")
        guard FileManager.default.fileExists(atPath: modelsDir.path) else {
            XCTFail("GATE TEST FAILURE: Models directory not found")
            return
        }

        let forbiddenModules: Set<String> = [
            "SwiftUI",
            "UIKit",
            "AppKit",
            "SpriteKit",
            "SceneKit",
            "EchoEngine",
            "EchoScenes"
        ]

        let violations = try collectImportViolations(
            in: [modelsDir],
            forbiddenModules: forbiddenModules
        )

        XCTAssertTrue(
            violations.isEmpty,
            """
            Found forbidden model-layer imports from UI/render modules:
            \(violations.joined(separator: "\n"))

            Keep model layer independent from presentation frameworks.
            """
        )
    }

    /// Gate test: ViewModels must not depend on concrete View types.
    func testViewModelsDoNotReferenceViewTypes() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let viewModelsDir = projectRoot.appendingPathComponent("ViewModels")
        guard FileManager.default.fileExists(atPath: viewModelsDir.path) else {
            XCTFail("GATE TEST FAILURE: ViewModels directory not found")
            return
        }

        let viewDirectories = [
            projectRoot.appendingPathComponent("Views"),
            projectRoot.appendingPathComponent("App/Screens")
        ]
        let viewTypeNames = try collectSwiftUIViewTypeNames(in: viewDirectories)

        XCTAssertFalse(viewTypeNames.isEmpty, "Expected to discover SwiftUI View types for dependency gate checks")

        let violations = try collectTypeReferenceViolations(
            in: [viewModelsDir],
            forbiddenTypes: viewTypeNames
        )

        XCTAssertTrue(
            violations.isEmpty,
            """
            Found ViewModel references to concrete View types:
            \(violations.joined(separator: "\n"))

            Keep ViewModels decoupled from View-layer concrete types.
            """
        )
    }

    // MARK: - Epic 21: Module Hygiene Gates

    /// Gate test: production code must not import legacy devtools pipelines.
    func testProductionCodeDoesNotImportTwilightEngineDevTools() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let dirsToScan = [
            "App",
            "Views",
            "ViewModels",
            "Models",
            "Managers",
            "Utilities",
            "Packages/TwilightEngine/Sources/TwilightEngine",
            "Packages/EchoEngine/Sources",
            "Packages/EchoScenes/Sources"
        ]

        var violations: [String] = []

        for dir in dirsToScan {
            let dirURL = projectRoot.appendingPathComponent(dir)
            guard FileManager.default.fileExists(atPath: dirURL.path) else { continue }

            for fileURL in findSwiftFiles(in: dirURL) {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)
                for (index, line) in lines.enumerated() where line.contains("import TwilightEngineDevTools") {
                    violations.append("\(fileURL.lastPathComponent):\(index + 1)")
                }
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            """
            Found forbidden `import TwilightEngineDevTools` in production code:
            \(violations.joined(separator: "\n"))

            Keep EventPipeline/MiniGameDispatcher isolated in the devtools target.
            """
        )
    }

    /// Gate test: legacy event pipeline files must not live in the core engine target.
    func testLegacyPipelinesAreIsolatedFromTwilightEngineTarget() {
        let projectRoot = SourcePathResolver.projectRoot
        let legacyDir = projectRoot.appendingPathComponent(SourcePathResolver.engineBase + "/Events")
        let devToolsDir = projectRoot.appendingPathComponent("Packages/TwilightEngine/Sources/TwilightEngineDevTools/Events")

        let legacyEventPipeline = legacyDir.appendingPathComponent("EventPipeline.swift")
        let legacyMiniGameDispatcher = legacyDir.appendingPathComponent("MiniGameDispatcher.swift")
        let devToolsEventPipeline = devToolsDir.appendingPathComponent("EventPipeline.swift")
        let devToolsMiniGameDispatcher = devToolsDir.appendingPathComponent("MiniGameDispatcher.swift")

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: legacyEventPipeline.path),
            "EventPipeline.swift must not exist inside TwilightEngine target"
        )
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: legacyMiniGameDispatcher.path),
            "MiniGameDispatcher.swift must not exist inside TwilightEngine target"
        )

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: devToolsEventPipeline.path),
            "EventPipeline.swift must exist in TwilightEngineDevTools target"
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: devToolsMiniGameDispatcher.path),
            "MiniGameDispatcher.swift must exist in TwilightEngineDevTools target"
        )
    }

    /// Gate test: ContentRegistry test helpers must stay in SPI-only surface.
    func testContentRegistryTestingHelpersAreSpiOnly() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let contentPacksDir = projectRoot.appendingPathComponent(
            "Packages/TwilightEngine/Sources/TwilightEngine/ContentPacks"
        )
        guard FileManager.default.fileExists(atPath: contentPacksDir.path) else {
            XCTFail("GATE TEST FAILURE: ContentPacks directory not found")
            return
        }

        let methods = [
            "resetForTesting(",
            "registerMockContent(",
            "loadMockPack(",
            "checkIdCollisions("
        ]
        let registryFiles = findSwiftFiles(in: contentPacksDir).filter {
            $0.lastPathComponent.hasPrefix("ContentRegistry")
        }
        guard !registryFiles.isEmpty else {
            XCTFail("GATE TEST FAILURE: ContentRegistry source files not found")
            return
        }

        var fileLines: [String: [String]] = [:]
        for file in registryFiles {
            let content = try String(contentsOf: file, encoding: .utf8)
            fileLines[file.path] = content.components(separatedBy: .newlines)
        }

        var violations: [String] = []

        for method in methods {
            var declarations: [(fileName: String, lineNumber: Int, lines: [String])] = []

            for file in registryFiles {
                guard let lines = fileLines[file.path] else { continue }
                for (index, line) in lines.enumerated() where line.contains("func \(method)") {
                    declarations.append((file.lastPathComponent, index + 1, lines))
                }
            }

            guard !declarations.isEmpty else {
                violations.append("Missing method: \(method)")
                continue
            }

            for declaration in declarations {
                let lineIndex = declaration.lineNumber - 1
                let declarationLine = declaration.lines[lineIndex].trimmingCharacters(in: .whitespaces)
                var hasSPI = declarationLine.contains("@_spi(Testing)")

                if !hasSPI {
                    var previousIndex = lineIndex - 1
                    while previousIndex >= 0 {
                        let previousLine = declaration.lines[previousIndex].trimmingCharacters(in: .whitespaces)
                        if previousLine.isEmpty {
                            previousIndex -= 1
                            continue
                        }
                        if previousLine.hasPrefix("@") {
                            if previousLine.contains("@_spi(Testing)") {
                                hasSPI = true
                            }
                            previousIndex -= 1
                            continue
                        }
                        break
                    }
                }

                if !hasSPI {
                    violations.append("Method without SPI guard: \(declaration.fileName):\(declaration.lineNumber) \(declarationLine)")
                }
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            """
            ContentRegistry testing helpers must be SPI-only:
            \(violations.joined(separator: "\n"))

            Keep test-only helpers behind `@_spi(Testing)` and out of regular production API.
            """
        )
    }

    /// Gate test: known monolith hotspots must stay under the global hard cap.
    /// This mirrors CodeHygiene line-limit policy (`<= 600` LOC).
    func testMonolithHotspotsDoNotGrow() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let hotspotBudgets: [(path: String, maxLines: Int)] = [
            ("Packages/TwilightEngine/Sources/TwilightEngine/Core/TwilightGameEngine.swift", 600),
            ("Packages/TwilightEngine/Sources/TwilightEngine/ContentPacks/ContentRegistry.swift", 600),
            ("Views/WorldMap/EngineRegionDetailView.swift", 600),
            ("CardSampleGameTests/GateTests/AuditGateTests+LegacyAndDeterminism.swift", 600)
        ]

        var violations: [String] = []

        for budget in hotspotBudgets {
            let fileURL = projectRoot.appendingPathComponent(budget.path)
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                violations.append("\(budget.path): file missing")
                continue
            }

            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let lineCount = content.components(separatedBy: .newlines).count

            if lineCount > budget.maxLines {
                violations.append("\(budget.path): \(lineCount) > \(budget.maxLines)")
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            """
            Monolith hotspot budget exceeded:
            \(violations.joined(separator: "\n"))

            Keep files within budget or split by feature/module before adding new logic.
            """
        )
    }

    /// Gate test: audit gate suites must not duplicate test names.
    /// Prevents stale copy-paste checks drifting between AuditGate and ArchitectureBoundary suites.
    func testAuditGateSuitesDoNotDuplicateTestNames() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let auditGateFile = projectRoot.appendingPathComponent("CardSampleGameTests/GateTests/AuditGateTests.swift")
        let architectureGateFile = projectRoot.appendingPathComponent(
            "CardSampleGameTests/GateTests/AuditArchitectureBoundaryGateTests.swift"
        )

        guard FileManager.default.fileExists(atPath: auditGateFile.path) else {
            XCTFail("GATE TEST FAILURE: AuditGateTests.swift not found")
            return
        }
        guard FileManager.default.fileExists(atPath: architectureGateFile.path) else {
            XCTFail("GATE TEST FAILURE: AuditArchitectureBoundaryGateTests.swift not found")
            return
        }

        let auditGateTests = try collectXCTestMethodNames(in: auditGateFile)
        let architectureGateTests = try collectXCTestMethodNames(in: architectureGateFile)
        let duplicates = auditGateTests.intersection(architectureGateTests).sorted()

        XCTAssertTrue(
            duplicates.isEmpty,
            """
            Found duplicated gate test names across audit suites:
            \(duplicates.joined(separator: "\n"))

            Keep each gate in one canonical suite to avoid maintenance drift.
            """
        )
    }

    /// Gate test: production code must not accumulate stale TODO/FIXME markers.
    func testProductionCodeHasNoTodoFixmeMarkers() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let dirsToScan = [
            "App",
            "ViewModels",
            "Views",
            "Packages/TwilightEngine/Sources/TwilightEngine/Core",
            "Packages/TwilightEngine/Sources/TwilightEngine/ContentPacks"
        ]

        var violations: [String] = []

        for dir in dirsToScan {
            let dirURL = projectRoot.appendingPathComponent(dir)
            guard FileManager.default.fileExists(atPath: dirURL.path) else { continue }

            for fileURL in findSwiftFiles(in: dirURL) {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)
                let relPath = fileURL.path.replacingOccurrences(of: projectRoot.path + "/", with: "")

                for (index, line) in lines.enumerated() where line.contains("TODO") || line.contains("FIXME") {
                    violations.append("\(relPath):\(index + 1): \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            """
            Found TODO/FIXME markers in production code:
            \(violations.joined(separator: "\n"))

            Convert temporary notes into tracked backlog items and remove in-code TODO/FIXME markers.
            """
        )
    }

    /// Gate test: key combat adapters must have active call-sites (not dead wrappers).
    func testCombatAdaptersAreNotOrphaned() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let dirsToScan = [
            "App",
            "Views",
            "ViewModels",
            "CardSampleGameTests"
        ]
        let adapterTokens = [
            "EchoCombatBridge.",
            "EchoEncounterBridge.",
            "EncounterBridge."
        ]

        var tokenCounts = Dictionary(uniqueKeysWithValues: adapterTokens.map { ($0, 0) })

        for dir in dirsToScan {
            let dirURL = projectRoot.appendingPathComponent(dir)
            guard FileManager.default.fileExists(atPath: dirURL.path) else { continue }

            for fileURL in findSwiftFiles(in: dirURL) {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                for token in adapterTokens {
                    tokenCounts[token, default: 0] += content.components(separatedBy: token).count - 1
                }
            }
        }

        let orphaned = tokenCounts
            .filter { $0.value < 2 } // definition only == dead adapter
            .map { "\($0.key) usages: \($0.value)" }
            .sorted()

        XCTAssertTrue(
            orphaned.isEmpty,
            """
            Found potentially orphaned adapter wrappers:
            \(orphaned.joined(separator: "\n"))

            Ensure adapters have real call-sites or remove dead bridge wrappers.
            """
        )
    }

    /// Gate test: hero/ability icons must be rendered as symbols, not raw token strings.
    func testHeroAndAbilityIconsAreNotRenderedAsRawTokens() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let scanDirectories: [String] = [
            "App",
            "Views"
        ]
        let iconTextRegex = try NSRegularExpression(pattern: #"Text\s*\([^)]*\.icon[^)]*\)"#)

        var violations: [String] = []

        for relativeDirectory in scanDirectories {
            let directoryURL = projectRoot.appendingPathComponent(relativeDirectory)
            guard FileManager.default.fileExists(atPath: directoryURL.path) else {
                continue
            }

            for fileURL in findSwiftFiles(in: directoryURL) {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)
                let relativePath = fileURL.path.replacingOccurrences(of: projectRoot.path + "/", with: "")

                for (index, rawLine) in lines.enumerated() {
                    let trimmed = stripInlineComment(from: rawLine)
                    if isCommentLine(trimmed) || trimmed.isEmpty { continue }

                    let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
                    if iconTextRegex.firstMatch(in: trimmed, options: [], range: range) != nil {
                        violations.append("\(relativePath):\(index + 1): \(trimmed)")
                    }
                }
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            """
            Found raw icon token rendering in UI:
            \(violations.joined(separator: "\n"))

            Render icon tokens via `Image(systemName:)` (or a dedicated icon adapter), not with `Text(...)`.
            """
        )
    }

}

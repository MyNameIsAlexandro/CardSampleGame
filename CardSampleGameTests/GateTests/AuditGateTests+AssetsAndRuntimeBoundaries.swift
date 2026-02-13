/// Файл: CardSampleGameTests/GateTests/AuditGateTests+AssetsAndRuntimeBoundaries.swift
/// Назначение: Содержит реализацию файла AuditGateTests+AssetsAndRuntimeBoundaries.swift.
/// Зона ответственности: Фиксирует проверяемый контракт и не содержит production-логики.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
import TwilightEngine
import PackAuthoring

@testable import CardSampleGame

extension AuditGateTests {

    // MARK: - F2: AssetRegistry Safety (No Direct UIImage)

    /// Gate test: Views and ViewModels must not use UIImage(named:) directly (Audit F2)
    /// Requirement: "Запрещены прямые UIImage(named:) в UI и VM — только через AssetRegistry"
    ///
    /// Direct UIImage(named:) bypasses the fallback system and can show:
    /// - Pink squares (missing image)
    /// - Empty images
    /// - Nil crashes
    ///
    /// All image loading must go through AssetRegistry which provides SF Symbol fallback.
    /// Audit 2.2 alias: exact name from acceptance criteria
    func testNoDirectImageNamedInViews() throws {
        try testNoDirectUIImageNamedInViewsAndViewModels()
    }

    func testNoDirectUIImageNamedInViewsAndViewModels() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()  // Engine
            .deletingLastPathComponent()  // CardSampleGameTests
            .deletingLastPathComponent()  // Project root

        // Directories to scan
        let dirsToScan = ["Views", "ViewModels"]

        // Forbidden patterns (direct UIImage/NSImage/SwiftUI Image loading)
        let forbiddenPatterns = [
            "UIImage(named:",
            "NSImage(named:",
            "Image(uiImage: UIImage(named:",
            "Image(nsImage: NSImage(named:"
        ]

        // Forbidden SwiftUI pattern: Image("...") but NOT Image(systemName:
        let swiftUIImagePattern = "Image(\""

        // Allowed files (AssetRegistry itself needs to use UIImage)
        let allowedFiles = [
            "AssetRegistry.swift",
            "AssetValidator.swift"
        ]

        var violations: [(file: String, line: Int, content: String)] = []
        var dirsFound = 0

        for dirName in dirsToScan {
            let dirURL = projectRoot.appendingPathComponent(dirName)

            guard FileManager.default.fileExists(atPath: dirURL.path) else {
                continue
            }
            dirsFound += 1

            let swiftFiles = findSwiftFiles(in: dirURL)

            for fileURL in swiftFiles {
                let fileName = fileURL.lastPathComponent

                // Skip allowed files
                if allowedFiles.contains(fileName) {
                    continue
                }

                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)

                for (index, line) in lines.enumerated() {
                    let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                    let lineNumber = index + 1

                    // Skip comments
                    if trimmedLine.hasPrefix("//") || trimmedLine.hasPrefix("/*") || trimmedLine.hasPrefix("*") {
                        continue
                    }

                    // Check for forbidden patterns
                    for pattern in forbiddenPatterns {
                        if line.contains(pattern) {
                            violations.append((
                                file: fileName,
                                line: lineNumber,
                                content: trimmedLine
                            ))
                        }
                    }

                    // Check for SwiftUI Image("...") — but not Image(systemName:
                    if line.contains(swiftUIImagePattern) && !line.contains("Image(systemName:") {
                        violations.append((
                            file: fileName,
                            line: lineNumber,
                            content: trimmedLine
                        ))
                    }
                }
            }
        }

        XCTAssertGreaterThan(dirsFound, 0, "No view directories found — repo structure may have changed")

        if !violations.isEmpty {
            let message = violations.map { "\($0.file):\($0.line): \($0.content)" }
                .joined(separator: "\n")
            XCTFail("""
                GATE TEST FAILURE: Direct Image(named:)/UIImage(named:) found in Views/ViewModels (Audit 2.2)

                Use AssetRegistry instead for automatic fallback support:
                - AssetRegistry.image(for: .region("forest"))
                - AssetRegistry.heroPortrait("warrior")
                - AssetRegistry.cardArt("fireball")

                Violations:
                \(message)
                """)
        }
    }

    // MARK: - B1.2: Static Scan — No Game-Specific IDs in Engine Source

    /// Gate test: Engine source must not contain hardcoded game-specific region/entity IDs (Audit 1.2)
    /// Requirement: "Engine не должен содержать game-specific IDs/словари конкретной игры"
    func testEngineSourceContainsNoGameSpecificIds() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()  // GateTests
            .deletingLastPathComponent()  // CardSampleGameTests
            .deletingLastPathComponent()  // Project root

        let engineBase = projectRoot.appendingPathComponent(SourcePathResolver.engineBase)

        // Build forbidden literals dynamically from loaded content packs.
        // Any content-defined ID (region, event, quest, hero, enemy) should NOT
        // appear as a string literal in Engine source code.
        let registry = try TestContentLoader.makeStandardRegistry()
        var contentIds: Set<String> = []
        for pack in registry.loadedPacks.values {
            contentIds.formUnion(pack.regions.keys)
            contentIds.formUnion(pack.events.keys)
            contentIds.formUnion(pack.quests.keys)
            contentIds.formUnion(pack.heroes.keys)
            contentIds.formUnion(pack.enemies.keys)
        }

        // Exclude engine-level enum rawValues that coincide with content IDs
        // (e.g., "breach" is both a region ID and a RegionState enum value)
        var engineTerms: Set<String> = []
        // RegionState rawValues
        for state in RegionState.allCases { engineTerms.insert(state.rawValue) }
        // RegionStateType rawValues
        for state in RegionStateType.allCases { engineTerms.insert(state.rawValue) }
        // Generic terms used by engine code (defaults, error messages)
        engineTerms.insert("unknown")
        engineTerms.insert("test")
        engineTerms.insert("rest")
        contentIds.subtract(engineTerms)

        // Format as quoted string literals for source scanning
        let forbiddenLiterals = contentIds.map { "\"\($0)\"" }

        // Allowed contexts: files that define type enums with rawValue strings
        let allowedFiles = [
            "ExplorationModels.swift"  // RegionType enum rawValues
        ]

        var violations: [String] = []

        // Scan all Swift files recursively under engine source (no hardcoded subdirectory list)
        let swiftFiles = findSwiftFiles(in: engineBase)

        for fileURL in swiftFiles {
            let fileName = fileURL.lastPathComponent
            if allowedFiles.contains(fileName) { continue }

            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)

            for (index, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                // Skip comments
                if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") || trimmed.hasPrefix("*") {
                    continue
                }

                for literal in forbiddenLiterals {
                    if line.contains(literal) {
                        violations.append("  \(fileName):\(index + 1): \(trimmed) [literal: \(literal)]")
                    }
                }
            }
        }

        if !violations.isEmpty {
            XCTFail("""
                GATE TEST FAILURE: Game-specific IDs found in Engine source (Audit 1.2)

                Engine must not contain hardcoded game-specific strings.
                All IDs must come from pack manifests/definitions.

                Violations:
                \(violations.joined(separator: "\n"))
                """)
        }
    }

    // MARK: - Runtime must not use PackLoader (JSON is authoring-only)

    /// Gate test: ContentRegistry and ContentManager must NOT reference PackLoader.
    /// Runtime loads only binary .pack files via BinaryPackReader.
    func testRuntimeDoesNotUsePackLoader() throws {
        let projectRoot = SourcePathResolver.projectRoot
        let runtimeFiles = [
            "ContentPacks/ContentRegistry.swift",
            "ContentPacks/ContentManager.swift"
        ]

        var filesFound = 0
        for file in runtimeFiles {
            let filePath = projectRoot.appendingPathComponent(SourcePathResolver.engineBase + "/" + file)
            guard FileManager.default.fileExists(atPath: filePath.path) else { continue }
            filesFound += 1
            let content = try String(contentsOf: filePath, encoding: .utf8)
            XCTAssertFalse(
                content.contains("PackLoader"),
                "\(file) must not use PackLoader — runtime uses BinaryPackReader only"
            )
        }
        XCTAssertGreaterThan(filesFound, 0, "No runtime files found — repo structure may have changed")
    }

    // MARK: - C1: No XCTSkip in ANY Tests

    /// Gate test: ALL tests must not use XCTSkip (Audit C1 / v2.1)
    /// Requirement: "Gate tests должны падать, а не скипаться"
    /// Scope expanded to ALL test directories (v2.1 audit requirement)
    ///
    /// If a test can't verify something, it must XCTFail, not XCTSkip.
    /// XCTSkip creates "false green" - CI passes but nothing was verified.
    func testNoXCTSkipInAnyTests() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()  // GateTests
            .deletingLastPathComponent()  // CardSampleGameTests
            .deletingLastPathComponent()  // Project root

        // Scan ALL test directories (v2.1: expanded from GateTests only)
        let testDirs = [
            projectRoot.appendingPathComponent("CardSampleGameTests"),
            projectRoot.appendingPathComponent("Packages/TwilightEngine/Tests/TwilightEngineTests") // Test dir, not engine source
        ]

        var violations: [(file: String, line: Int, content: String)] = []
        var dirsFound = 0

        for testDir in testDirs {
            guard FileManager.default.fileExists(atPath: testDir.path) else { continue }
            dirsFound += 1

            let fileManager = FileManager.default
            guard let enumerator = fileManager.enumerator(
                at: testDir,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "swift" else { continue }

                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)

                for (index, line) in lines.enumerated() {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)

                    // Skip comments
                    if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") || trimmed.hasPrefix("*") {
                        continue
                    }

                    // Skip string literals containing "XCTSkip" (e.g. in this very test's detection logic)
                    if trimmed.contains("\"XCTSkip") || trimmed.contains("XCTSkip\"") {
                        continue
                    }

                    // Match actual XCTSkip/XCTSkipIf calls
                    if line.contains("XCTSkip(") || line.contains("XCTSkipIf(") || line.contains("XCTSkipUnless(") {
                        let fileName = fileURL.lastPathComponent
                        violations.append((file: fileName, line: index + 1, content: trimmed))
                    }
                }
            }
        }

        XCTAssertGreaterThan(dirsFound, 0, "No test directories found — repo structure may have changed")

        if !violations.isEmpty {
            let message = violations.map { "\($0.file):\($0.line): \($0.content)" }.joined(separator: "\n")
            XCTFail("""
                GATE TEST FAILURE: XCTSkip found in tests (Audit C1 v2.1)

                ALL tests must use XCTFail, not XCTSkip. XCTSkip creates "false green" CI results.

                Violations:
                \(message)

                Fix: Replace XCTSkip/XCTSkipIf with XCTFail and return.
                """)
        }
    }

    // MARK: - F1: No Legacy Initialization in Views

    /// Gate test: Views must not contain legacy initialization patterns (Audit F1).
    func testNoLegacyInitializationInViews() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let viewsDir = projectRoot.appendingPathComponent("Views")
        guard FileManager.default.fileExists(atPath: viewsDir.path) else {
            XCTFail("GATE TEST FAILURE: Views directory not found")
            return
        }

        let forbiddenPatterns = [
            "legacy init",
            "legacy initialization",
            "shared between legacy",
            "LegacyAdapter",
            "legacyInit",
            "connectToLegacy"
        ]
        let allowedPatterns = [
            "no legacy sync needed",
            "no legacy needed",
            "legacy removed"
        ]

        var violations: [(file: String, line: Int, content: String, pattern: String)] = []
        let swiftFiles = findSwiftFiles(in: viewsDir)

        for fileURL in swiftFiles {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            let fileName = fileURL.lastPathComponent

            for (index, line) in lines.enumerated() {
                let lowerLine = line.lowercased()
                let lineNumber = index + 1

                for pattern in forbiddenPatterns where lowerLine.contains(pattern.lowercased()) {
                    let hasAllowedPattern = allowedPatterns.contains { allowed in
                        lowerLine.contains(allowed.lowercased())
                    }
                    if !hasAllowedPattern {
                        violations.append((
                            file: fileName,
                            line: lineNumber,
                            content: line.trimmingCharacters(in: .whitespaces),
                            pattern: pattern
                        ))
                    }
                }
            }
        }

        if !violations.isEmpty {
            let message = violations.map { "\($0.file):\($0.line): \($0.content) [pattern: \($0.pattern)]" }
                .joined(separator: "\n")
            XCTFail("""
                GATE TEST FAILURE: Legacy initialization patterns found in Views/ (Audit F1)

                Views should use Engine-First architecture only.
                Remove legacy initialization, adapters, and related comments.

                Violations:
                \(message)
                """)
        }
    }

    /// Audit 2.1 alias: exact name from acceptance criteria.
    func testNoLegacyInitializationCommentsInWorldMapView() throws {
        try testNoLegacyInitializationInViews()
    }

}

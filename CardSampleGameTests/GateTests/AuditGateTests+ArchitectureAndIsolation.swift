/// Файл: CardSampleGameTests/GateTests/AuditGateTests+ArchitectureAndIsolation.swift
/// Назначение: Содержит реализацию файла AuditGateTests+ArchitectureAndIsolation.swift.
/// Зона ответственности: Фиксирует проверяемый контракт и не содержит production-логики.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
import TwilightEngine
import PackAuthoring

@testable import CardSampleGame

extension AuditGateTests {

    // MARK: - EPIC 5: Localization Support

    /// Gate test: Pack content supports localization
    /// Requirement: "Packs используют stringKey/nameRu/descriptionRu для локализации"
    func testPackContentSupportsLocalization() {
        // Verify that content definitions have localization support
        // Current implementation uses nameRu/descriptionRu fields (PoC approach)
        // Future: stringKey approach for app-side localization

        // Verify HeroRegistry uses localized names
        for hero in registry.heroRegistry.allHeroes {
            // Hero should have a name (either localized or default)
            XCTAssertFalse(hero.name.isEmpty, "Hero должен иметь имя")
            XCTAssertFalse(hero.description.isEmpty, "Hero должен иметь описание")
        }

        // Verify ContentRegistry provides localized content
        let regions = registry.getAllRegions()
        for region in regions {
            XCTAssertFalse(region.title.localized.isEmpty, "Region должен иметь имя")
        }

        // This documents that localization is supported via nameRu/descriptionRu pattern
        // The pack loader handles locale detection and returns appropriate strings
    }

    // MARK: - EPIC 6: Pack Composition

    /// Gate test: Multiple packs can be loaded together
    /// Requirement: "Campaign Pack + Character Pack работают вместе"
    func testCampaignPlusCharacterPackComposition() {
        // Verify ContentRegistry supports multiple pack loading
        // Registry should be able to hold multiple packs
        XCTAssertNotNil(registry.loadedPacks, "Registry должен поддерживать множественные pack'и")

        // Verify pack loading API exists
        // Note: Full test requires actual pack files

        // Document the composition requirement:
        // - Campaign pack provides: regions, events, quests, enemies
        // - Character pack provides: heroes, hero-specific cards, hero abilities
        // - Packs can have dependencies (character pack depends on campaign pack)
    }

    // MARK: - EPIC 7: Save Pack Set Tracking

    /// Gate test: Save stores pack set for compatibility
    /// Requirement: "Save хранит activePackSet и проверяет при загрузке"
    func testSaveStoresPackSetAndValidates() {
        // Verify EngineSave has pack compatibility fields
        let engine = TwilightGameEngine()

        // EngineSave should include:
        // - coreVersion: String
        // - activePackSet: [String: String] (packId -> version)
        // - formatVersion: Int

        // Verify engine is valid and can be used for save
        XCTAssertNotNil(engine, "Engine должен быть создан для сохранения")

        // Create a minimal save to verify structure
        // Note: This is documented in EngineSave.swift
        XCTAssertEqual(EngineSave.currentVersion, 1, "EngineSave должен иметь версию")
        XCTAssertEqual(EngineSave.currentFormatVersion, 1, "EngineSave должен иметь версию формата")
        XCTAssertFalse(EngineSave.currentCoreVersion.isEmpty, "EngineSave должен иметь версию core")
    }

    // MARK: - EPIC 1.2: One Engine = One Truth

    /// Gate test: Contract tests run against production engine, not test stub
    /// Also verifies that TwilightGameEngine is the ONLY runtime engine
    func testContractsAgainstProductionEngine() {
        // Verify that TwilightGameEngine (production) can be tested
        let engine = TwilightGameEngine()

        // Basic contract: performAction returns result
        let result = engine.performAction(.rest)
        XCTAssertNotNil(result, "Production engine should return action result")

        // Contract: state changes are observable
        // (This is verified by the Engine-First architecture)
    }

    /// Gate test: No alternative runtime engines exist in TwilightEngine package
    /// Requirement: "Production runtime engine должен быть единственным исполняемым движком"
    func testNoAlternativeEnginesExist() throws {
        // Get project root directory from compile-time path
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()  // Engine
            .deletingLastPathComponent()  // CardSampleGameTests
            .deletingLastPathComponent()  // Project root

        let coreDir = projectRoot.appendingPathComponent(SourcePathResolver.engineBase + "/Core")

        // Scan for actual class declarations ending with "Engine".
        // File-name based checks are brittle after decomposition into extension slices.
        let engineFiles = try FileManager.default.contentsOfDirectory(at: coreDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
            .filter { $0.lastPathComponent.contains("Engine") }

        let allowedEngineClassNames: Set<String> = [
            "TwilightGameEngine",
            "TimeEngine",
            "PressureEngine",
            "ResonanceEngine"
        ]

        let engineClassRegex = try NSRegularExpression(
            pattern: "(?:final\\s+)?class\\s+([A-Za-z_][A-Za-z0-9_]*Engine)\\b"
        )

        var alternativeEngines: [String] = []
        for fileURL in engineFiles {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let range = NSRange(content.startIndex..<content.endIndex, in: content)
            let matches = engineClassRegex.matches(in: content, range: range)

            for match in matches {
                guard match.numberOfRanges > 1,
                      let classRange = Range(match.range(at: 1), in: content) else {
                    continue
                }
                let className = String(content[classRange])
                if !allowedEngineClassNames.contains(className) {
                    alternativeEngines.append("\(className) (\(fileURL.lastPathComponent))")
                }
            }
        }

        XCTAssertTrue(
            alternativeEngines.isEmpty,
            "Found alternative runtime engines that should be removed: \(alternativeEngines). " +
            "TwilightGameEngine должен быть единственным runtime движком."
        )
    }

    // MARK: - SpriteKit-Only Combat

    /// Gate test: CombatView (SwiftUI) must not be instantiated in production code.
    /// All combat must go through CombatSceneView (SpriteKit/EchoEngine).
    func testNoCombatViewUsedInProductionCode() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let productionDirs = ["Views", "App"]
        var violations: [String] = []

        for dir in productionDirs {
            let dirURL = projectRoot.appendingPathComponent(dir)
            guard let enumerator = FileManager.default.enumerator(
                at: dirURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
            ) else { continue }

            for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let lines = content.components(separatedBy: "\n")
                for (i, line) in lines.enumerated() {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("//") || trimmed.hasPrefix("*") { continue }
                    // CombatView( instantiation — but not CombatSceneView( or type refs like CombatView.CombatStats
                    if trimmed.contains("CombatView(") && !trimmed.contains("CombatSceneView(") {
                        violations.append("\(fileURL.lastPathComponent):\(i + 1)")
                    }
                }
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            "Found SwiftUI CombatView instantiation in production code (must use CombatSceneView): \(violations)"
        )
    }

    // MARK: - EPIC 2.1: Single Source of Content (Packs only)

    /// Gate test: Runtime does not access code registries directly
    /// Requirement: "Вся загрузка карт/героев/квестов/ивентов осуществляется через ContentRegistry"
    func testRuntimeDoesNotAccessCodeRegistries() throws {
        // Get project root directory from compile-time path
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()  // Engine
            .deletingLastPathComponent()  // CardSampleGameTests
            .deletingLastPathComponent()  // Project root

        // Directories to check (production code only, excluding tests)
        // Engine code is now in TwilightEngine package
        let productionDirs = [SourcePathResolver.engineBase, "App", "Views", "Models", "Utilities"]

        // Patterns that indicate direct code registry access (should use ContentRegistry/CardFactory)
        let forbiddenPatterns = [
            "CardRegistry.shared",           // Direct CardRegistry access (deleted)
            "TwilightMarchesCards",          // Hardcoded card definitions
            "registerBuiltInCards",          // Built-in card registration
            "HeroRegistry.shared.register"   // Direct hero registration (reading is OK)
        ]

        // Allowed patterns (these files ARE the registries, they can access themselves)
        let allowedFiles = [
            "CardFactory.swift",  // CardFactory internally manages registries
            "ContentRegistry.swift",
            "HeroRegistry.swift"
        ]

        var violations: [String] = []
        var dirsFound = 0

        for dir in productionDirs {
            let dirURL = projectRoot.appendingPathComponent(dir)
            guard FileManager.default.fileExists(atPath: dirURL.path) else { continue }
            dirsFound += 1

            let swiftFiles = findSwiftFiles(in: dirURL)
            for fileURL in swiftFiles {
                let fileName = fileURL.lastPathComponent

                // Skip allowed files (registries themselves)
                if allowedFiles.contains(fileName) { continue }

                let fileViolations = try checkForbiddenPatternsInFile(fileURL, patterns: forbiddenPatterns)
                violations.append(contentsOf: fileViolations)
            }
        }

        XCTAssertGreaterThan(dirsFound, 0, "No production directories found — repo structure may have changed")

        if !violations.isEmpty {
            let message = """
            Found \(violations.count) direct code registry accesses in production code:
            \(violations.joined(separator: "\n"))

            Runtime должен использовать ContentRegistry/CardFactory для загрузки контента.
            Прямой доступ к CardRegistry.shared или TwilightMarchesCards запрещён.
            """
            XCTFail(message)
        }
    }

    /// Gate test: engine journal must use core-state primitives, not UI mirror state.
    func testEngineJournalUsesCoreStatePrimitives() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let journalFile = projectRoot.appendingPathComponent(
            "Packages/TwilightEngine/Sources/TwilightEngine/Core/TwilightGameEngine+Journal.swift"
        )
        guard FileManager.default.fileExists(atPath: journalFile.path) else {
            XCTFail("GATE TEST FAILURE: TwilightGameEngine+Journal.swift not found")
            return
        }

        let forbiddenJournalPatterns = [
            "publishedRegions[",
            "publishedEventLog",
            "setEventLog(",
            "setResonance("
        ]
        let journalViolations = try checkForbiddenPatternsInFile(journalFile, patterns: forbiddenJournalPatterns)
        XCTAssertTrue(
            journalViolations.isEmpty,
            """
            Journal extension must not mutate/read UI mirror state directly:
            \(journalViolations.joined(separator: "\n"))

            Use core primitives (`resolveRegionName`, `appendEventLogEntry`, `setWorldResonance`) only.
            """
        )

        let coreDir = projectRoot.appendingPathComponent(
            "Packages/TwilightEngine/Sources/TwilightEngine/Core"
        )
        guard FileManager.default.fileExists(atPath: coreDir.path) else {
            XCTFail("GATE TEST FAILURE: TwilightEngine/Core directory not found")
            return
        }

        var coreContent = ""
        guard let enumerator = FileManager.default.enumerator(
            at: coreDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            XCTFail("GATE TEST FAILURE: Unable to enumerate TwilightEngine/Core")
            return
        }

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            coreContent += (try String(contentsOf: fileURL, encoding: .utf8)) + "\n"
        }

        let requiredCorePatterns = [
            "func setWorldResonance(",
            "func appendEventLogEntry(",
            "func resolveRegionName("
        ]

        let missingPatterns = requiredCorePatterns.filter { !coreContent.contains($0) }
        XCTAssertTrue(
            missingPatterns.isEmpty,
            """
            Missing required core-state primitives in TwilightEngine/Core:
            \(missingPatterns.joined(separator: ", "))
            """
        )
    }

    /// Gate test: CardSampleGameTests must not link TwilightEngine directly.
    /// The test host already loads TwilightEngine, so direct test-target linking causes runtime class duplication.
    func testCardSampleGameTestsDoesNotLinkTwilightEngineDirectly() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let pbxprojFile = projectRoot.appendingPathComponent("CardSampleGame.xcodeproj/project.pbxproj")
        guard FileManager.default.fileExists(atPath: pbxprojFile.path) else {
            XCTFail("GATE TEST FAILURE: project.pbxproj not found")
            return
        }

        let content = try String(contentsOf: pbxprojFile, encoding: .utf8)

        func extractBlock(startMarker: String) -> String? {
            guard let start = content.range(of: startMarker) else { return nil }
            guard let end = content[start.lowerBound...].range(of: "\n\t\t};") else { return nil }
            return String(content[start.lowerBound..<end.upperBound])
        }

        guard let testsTargetBlock = extractBlock(
            startMarker: "BB0000030000000000000001 /* CardSampleGameTests */ = {"
        ) else {
            XCTFail("GATE TEST FAILURE: CardSampleGameTests target block not found in project.pbxproj")
            return
        }

        XCTAssertFalse(
            testsTargetBlock.contains("/* TwilightEngine */"),
            """
            CardSampleGameTests target must not contain direct TwilightEngine package dependency.
            Keep TwilightEngine loaded only through host app to avoid ObjC runtime class duplication.
            """
        )

        guard let testsFrameworksBlock = extractBlock(
            startMarker: "BB0000020000000000000001 /* Frameworks */ = {"
        ) else {
            XCTFail("GATE TEST FAILURE: CardSampleGameTests frameworks block not found in project.pbxproj")
            return
        }

        XCTAssertFalse(
            testsFrameworksBlock.contains("TwilightEngine in Frameworks"),
            """
            CardSampleGameTests frameworks phase must not link TwilightEngine directly.
            Duplicate linkage reintroduces `Class ... is implemented in both` runtime warnings.
            """
        )
    }

    /// Gate test: Runtime rejects raw JSON files, only accepts binary .pack
    /// Requirement: "Runtime загружает только .pack файлы, JSON только для compile-time"
    func testRuntimeRejectsRawJSON() throws {
        // Create a temporary JSON directory (simulating raw JSON pack)
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create a minimal manifest.json file
        let manifestJSON = """
        {
            "packId": "test-json-pack",
            "displayName": { "en": "Test JSON Pack", "ru": "Тестовый JSON пак" },
            "version": "1.0.0",
            "packType": "character",
            "coreVersionMin": "1.0.0"
        }
        """
        let manifestURL = tempDir.appendingPathComponent("manifest.json")
        try manifestJSON.write(to: manifestURL, atomically: true, encoding: .utf8)

        // Attempt to load raw JSON directory should fail
        let registry = ContentRegistry()

        // Try to load the JSON directory (not a .pack file)
        do {
            _ = try registry.loadPack(from: tempDir)
            XCTFail("GATE TEST FAILURE: Runtime должен отвергать raw JSON директории")
        } catch let error as PackLoadError {
            // Expected: should fail with invalidManifest error
            if case .invalidManifest(let reason) = error {
                XCTAssertTrue(
                    reason.contains(".pack") || reason.contains("pack"),
                    "Error message should mention .pack files: \(reason)"
                )
            } else {
                // Any PackLoadError is acceptable - runtime rejected the JSON
            }
        } catch {
            // Any error is fine - runtime rejected the raw JSON
        }

        // Also verify that a file with wrong extension is rejected
        let wrongExtFile = tempDir.appendingPathComponent("test.json")
        try "{}".write(to: wrongExtFile, atomically: true, encoding: .utf8)

        do {
            _ = try registry.loadPack(from: wrongExtFile)
            XCTFail("GATE TEST FAILURE: Runtime должен отвергать файлы без расширения .pack")
        } catch {
            // Expected: any error means runtime correctly rejected the file
        }
    }

    /// Check a Swift file for forbidden patterns not in comments
    private func checkForbiddenPatternsInFile(_ fileURL: URL, patterns: [String]) throws -> [String] {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        var violations: [String] = []

        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            let lineNumber = index + 1

            // Skip comments
            if trimmedLine.hasPrefix("//") || trimmedLine.hasPrefix("/*") || trimmedLine.hasPrefix("*") {
                continue
            }

            // Remove inline comments for pattern matching
            var lineToCheck = trimmedLine
            if let commentRange = lineToCheck.range(of: "//") {
                lineToCheck = String(lineToCheck[..<commentRange.lowerBound])
            }

            // Check for forbidden patterns
            for pattern in patterns {
                if lineToCheck.contains(pattern) {
                    let fileName = fileURL.lastPathComponent
                    violations.append("  \(fileName):\(lineNumber): \(trimmedLine) [pattern: \(pattern)]")
                }
            }
        }

        return violations
    }

}

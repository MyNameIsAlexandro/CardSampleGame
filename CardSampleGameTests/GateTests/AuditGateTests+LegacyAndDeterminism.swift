/// Файл: CardSampleGameTests/GateTests/AuditGateTests+LegacyAndDeterminism.swift
/// Назначение: Содержит реализацию файла AuditGateTests+LegacyAndDeterminism.swift.
/// Зона ответственности: Фиксирует проверяемый контракт и не содержит production-логики.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
import TwilightEngine
import PackAuthoring

@testable import CardSampleGame

extension AuditGateTests {

    // MARK: - EPIC 1.1: One Truth Runtime (No Legacy Models in Views)

    /// Gate test: Views should not use legacy WorldState, GameState, or direct state mutations
    /// Requirement: "Views/ не импортируют и не используют legacy модели"
    func testNoLegacyWorldStateUsageInViews() throws {
        // Get project root directory from compile-time path
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()  // Engine
            .deletingLastPathComponent()  // CardSampleGameTests
            .deletingLastPathComponent()  // Project root

        let viewsDir = projectRoot.appendingPathComponent("Views")

        // Skip if Views directory doesn't exist
        guard FileManager.default.fileExists(atPath: viewsDir.path) else {
            XCTFail("GATE TEST FAILURE: Views directory not found at \(viewsDir.path)")
            return
        }

        // Legacy patterns that should NOT appear in Views (outside of comments/previews)
        let legacyPatterns = [
            "WorldState",           // Legacy world state model
            "GameState",            // Legacy game state model
            "legacyPlayer",         // Legacy player reference
            "legacyWorldState",     // Legacy world state reference
            "connectToLegacy"       // Legacy connection method
        ]

        var violations: [String] = []
        let swiftFiles = findSwiftFiles(in: viewsDir)

        for fileURL in swiftFiles {
            let fileViolations = try checkLegacyPatternsInFile(fileURL, patterns: legacyPatterns)
            violations.append(contentsOf: fileViolations)
        }

        // Report all violations
        if !violations.isEmpty {
            let message = """
            Found \(violations.count) legacy model usages in Views/:
            \(violations.joined(separator: "\n"))

            Views should only use TwilightGameEngine as the single source of truth.
            Remove legacy WorldState/GameState references and use engine properties instead.
            """
            XCTFail(message)
        }
    }

    /// Check a Swift file for legacy patterns not in comments or preview blocks
    private func checkLegacyPatternsInFile(_ fileURL: URL, patterns: [String]) throws -> [String] {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        var violations: [String] = []

        // Track if we're inside a preview block or multiline comment
        var inPreviewBlock = false
        var previewBraceDepth = 0
        var inMultilineComment = false

        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            let lineNumber = index + 1

            // Track multiline comments
            if trimmedLine.contains("/*") {
                inMultilineComment = true
            }
            if trimmedLine.contains("*/") {
                inMultilineComment = false
                continue
            }
            if inMultilineComment {
                continue
            }

            // Track #Preview blocks
            if trimmedLine.hasPrefix("#Preview") || trimmedLine.contains("PreviewProvider") {
                inPreviewBlock = true
                previewBraceDepth = 0
            }

            // Track braces in preview block
            if inPreviewBlock {
                previewBraceDepth += trimmedLine.filter { $0 == "{" }.count
                previewBraceDepth -= trimmedLine.filter { $0 == "}" }.count
                if previewBraceDepth <= 0 && trimmedLine.contains("}") {
                    inPreviewBlock = false
                }
                continue  // Skip preview content
            }

            // Skip single-line comments
            if trimmedLine.hasPrefix("//") {
                continue
            }

            // Remove inline comments for pattern matching
            var lineToCheck = trimmedLine
            if let commentRange = lineToCheck.range(of: "//") {
                lineToCheck = String(lineToCheck[..<commentRange.lowerBound])
            }

            // Check for legacy patterns
            for pattern in patterns {
                if lineToCheck.contains(pattern) {
                    let fileName = fileURL.lastPathComponent
                    violations.append("  \(fileName):\(lineNumber): \(trimmedLine) [pattern: \(pattern)]")
                }
            }
        }

        return violations
    }

    // MARK: - EPIC 3.1: Stable IDs Everywhere

    /// Gate test: Save/Load uses stable definition IDs, not UUIDs
    /// Requirement: "Запрет UUID для контентных сущностей в Save/Load"
    func testSaveLoadUsesStableDefinitionIdsOnly() throws {
        // Get project root directory from compile-time path
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()  // Engine
            .deletingLastPathComponent()  // CardSampleGameTests
            .deletingLastPathComponent()  // Project root

        let engineFile = projectRoot
            .appendingPathComponent(SourcePathResolver.engineBase + "/Core/TwilightGameEngine.swift")

        guard FileManager.default.fileExists(atPath: engineFile.path) else {
            XCTFail("GATE TEST FAILURE: TwilightGameEngine.swift not found at \(engineFile.path)")
            return
        }

        let content = try String(contentsOf: engineFile, encoding: .utf8)

        // Patterns that indicate UUID usage for content entity IDs (should use String definition IDs)
        let forbiddenPatterns = [
            "completedEventIds: Set<UUID>",      // Should be Set<String>
            "completedEventIds.map { $0.uuidString }",  // Should not need conversion
            "compactMap { UUID(uuidString:",    // Should not convert strings to UUIDs
            "eventDefinitionIdToUUID"           // Helper should be removed
        ]

        var violations: [String] = []
        let lines = content.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            let lineNumber = index + 1

            // Skip comments
            if trimmedLine.hasPrefix("//") || trimmedLine.hasPrefix("/*") || trimmedLine.hasPrefix("*") {
                continue
            }

            for pattern in forbiddenPatterns {
                if line.contains(pattern) {
                    violations.append("  TwilightGameEngine.swift:\(lineNumber): \(trimmedLine) [pattern: \(pattern)]")
                }
            }
        }

        if !violations.isEmpty {
            let message = """
            Found \(violations.count) UUID usages for content entity IDs:
            \(violations.joined(separator: "\n"))

            Content entity IDs (events, quests, cards, heroes) should use stable String definition IDs,
            not generated UUIDs. This ensures save compatibility across sessions.
            """
            XCTFail(message)
        }

        // Additional verification: completedEventIds should be declared as Set<String>
        XCTAssertTrue(
            content.contains("completedEventIds: Set<String>"),
            "completedEventIds should be declared as Set<String>, not Set<UUID>"
        )

        // Verify EngineSave uses String IDs
        let saveFile = projectRoot.appendingPathComponent(SourcePathResolver.engineBase + "/Core/EngineSave.swift")
        if FileManager.default.fileExists(atPath: saveFile.path) {
            let saveContent = try String(contentsOf: saveFile, encoding: .utf8)
            XCTAssertTrue(
                saveContent.contains("completedEventIds: [String]"),
                "EngineSave.completedEventIds should be [String], not [UUID]"
            )
        }
    }

    // MARK: - A1: definitionId Non-Optional Gate Tests

    /// Gate test: definitionId must be non-optional in pack-driven entities (Audit A1)
    /// Requirement: "definitionId должен быть обязательным для всех pack-driven сущностей"
    func testDefinitionIdIsNonOptional() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()  // Engine
            .deletingLastPathComponent()  // CardSampleGameTests
            .deletingLastPathComponent()  // Project root

        // Check EngineRegionState in canonical world-state models file
        let worldStateFile = projectRoot.appendingPathComponent(SourcePathResolver.engineBase + "/Core/EngineWorldStateModels.swift")
        guard FileManager.default.fileExists(atPath: worldStateFile.path) else {
            XCTFail("GATE TEST FAILURE: EngineWorldStateModels.swift not found")
            return
        }

        let worldStateContent = try String(contentsOf: worldStateFile, encoding: .utf8)

        // EngineRegionState.id must be String (id IS the definitionId after UUID->String migration)
        XCTAssertTrue(
            worldStateContent.contains("public struct EngineRegionState"),
            "EngineRegionState must remain declared in EngineWorldStateModels.swift"
        )
        XCTAssertTrue(
            worldStateContent.contains("public let id: String"),
            "EngineRegionState.id must be non-optional String (id IS definitionId)"
        )

        // Check Quest
        let modelsFile = projectRoot.appendingPathComponent(SourcePathResolver.engineBase + "/Models/ExplorationModels.swift")
        guard FileManager.default.fileExists(atPath: modelsFile.path) else {
            XCTFail("GATE TEST FAILURE: ExplorationModels.swift not found")
            return
        }

        let modelsContent = try String(contentsOf: modelsFile, encoding: .utf8)

        // Quest.id must be String (id IS the definitionId after UUID->String migration)
        XCTAssertTrue(
            modelsContent.contains("public let id: String"),
            "Quest.id must be non-optional String (id IS definitionId)"
        )
    }

    /// Gate test: All pack-driven entities have non-empty definitionId at runtime (Audit 1.4)
    func testDefinitionIdNeverNilForPackEntities() throws {
        XCTAssertFalse(registry.loadedPacks.isEmpty, "Content packs must be loaded")

        // Regions
        for (id, region) in registry.loadedPacks.values.flatMap({ $0.regions }) {
            XCTAssertFalse(id.isEmpty, "Region definitionId must not be empty")
            XCTAssertEqual(id, region.id, "Region key must match id")
        }

        // Events
        for (id, event) in registry.loadedPacks.values.flatMap({ $0.events }) {
            XCTAssertFalse(id.isEmpty, "Event definitionId must not be empty")
            XCTAssertEqual(id, event.id, "Event key must match id")
            for choice in event.choices {
                XCTAssertFalse(choice.id.isEmpty, "EventChoice.id must not be empty (event: \(id))")
            }
        }

        // Quests
        for (id, quest) in registry.loadedPacks.values.flatMap({ $0.quests }) {
            XCTAssertFalse(id.isEmpty, "Quest definitionId must not be empty")
            XCTAssertEqual(id, quest.id, "Quest key must match id")
        }

        // Heroes
        for (id, hero) in registry.loadedPacks.values.flatMap({ $0.heroes }) {
            XCTAssertFalse(id.isEmpty, "Hero definitionId must not be empty")
            XCTAssertEqual(id, hero.id, "Hero key must match id")
        }

        // Enemies
        for (id, enemy) in registry.loadedPacks.values.flatMap({ $0.enemies }) {
            XCTAssertFalse(id.isEmpty, "Enemy definitionId must not be empty")
            XCTAssertEqual(id, enemy.id, "Enemy key must match id")
        }

        // Cards
        for card in registry.getAllCards() {
            XCTAssertFalse(card.id.isEmpty, "Card definitionId must not be empty")
        }
    }

    /// Gate test: No UUID fallback in save serialization (Audit A1)
    /// Requirement: "Полностью удалить fallback uuidString из сейвов"
    func testNoUuidFallbackInSave() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let saveFile = projectRoot.appendingPathComponent(SourcePathResolver.engineBase + "/Core/EngineSave.swift")
        guard FileManager.default.fileExists(atPath: saveFile.path) else {
            XCTFail("GATE TEST FAILURE: EngineSave.swift not found")
            return
        }

        let content = try String(contentsOf: saveFile, encoding: .utf8)

        // No UUID fallback patterns allowed
        let forbiddenPatterns = [
            "?? region.id.uuidString",
            "?? anchor.id.uuidString",
            "?? quest.id.uuidString",
            ".uuidString // fallback"
        ]

        var violations: [String] = []
        let lines = content.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            for pattern in forbiddenPatterns {
                if line.contains(pattern) {
                    violations.append("Line \(index + 1): \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }

        if !violations.isEmpty {
            XCTFail("""
                Found UUID fallback patterns in EngineSave.swift (Audit A1 violation):
                \(violations.joined(separator: "\n"))

                definitionId must be required, no UUID fallback allowed.
                """)
        }
    }

    // MARK: - A2: RNG State Persistence Gate Tests

    /// Gate test: RNG state is saved and restored (Audit A2)
    /// Requirement: "Сейв обязан хранить RNG state для детерминизма после загрузки"
    func testSaveLoadRestoresRngState() throws {
        // Set a known RNG state
        let testSeed: UInt64 = 12345
        rng.setSeed(testSeed)

        // Advance RNG a few times
        _ = rng.next()
        _ = rng.next()
        _ = rng.next()

        let stateBeforeSave = rng.currentState()

        // Generate some random values to verify
        let value1 = rng.next()
        let value2 = rng.next()

        // Restore state to before we generated values
        rng.restoreState(stateBeforeSave)

        // Verify same values are generated
        let restored1 = rng.next()
        let restored2 = rng.next()

        XCTAssertEqual(value1, restored1, "RNG should produce same value after state restore")
        XCTAssertEqual(value2, restored2, "RNG should produce same sequence after state restore")
    }

    /// Gate test: EngineSave includes rngState field (Audit A2)
    func testEngineSaveHasRngStateField() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let saveFile = projectRoot.appendingPathComponent(SourcePathResolver.engineBase + "/Core/EngineSave.swift")
        guard FileManager.default.fileExists(atPath: saveFile.path) else {
            XCTFail("GATE TEST FAILURE: EngineSave.swift not found")
            return
        }

        let content = try String(contentsOf: saveFile, encoding: .utf8)

        // EngineSave must have rngState field
        XCTAssertTrue(
            content.contains("public let rngState: UInt64"),
            "EngineSave must have rngState field for deterministic save/load (Audit 1.5)"
        )
    }

    /// Gate test: createSave saves RNG state (Audit A2)
    func testCreateSaveSavesRngState() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let snapshotFile = projectRoot.appendingPathComponent(
            SourcePathResolver.engineBase + "/Core/TwilightGameEngine+PersistenceSnapshot.swift"
        )
        guard FileManager.default.fileExists(atPath: snapshotFile.path) else {
            XCTFail("GATE TEST FAILURE: TwilightGameEngine+PersistenceSnapshot.swift not found")
            return
        }

        let content = try String(contentsOf: snapshotFile, encoding: .utf8)

        // createSave must include RNG state
        XCTAssertTrue(
            content.contains("rngState: services.rng.currentState()"),
            "createSave must save RNG state via services.rng.currentState() (Audit A2)"
        )

        // Must not have "rngSeed: nil" pattern anymore
        XCTAssertFalse(
            content.contains("rngSeed: nil"),
            "createSave must not set rngSeed to nil (Audit A2)"
        )
    }

    // MARK: - Audit 4.2: Pack Compiler Round-Trip

    /// Gate test: .pack load → re-write → re-load round-trip (Audit 4.2)
    func testPackCompilerRoundTrip() throws {
        // Load the compiled .pack via registry (already loaded)
        XCTAssertFalse(registry.loadedPacks.isEmpty, "Packs must be loaded")

        guard let pack = registry.loadedPacks.values.first else {
            XCTFail("GATE TEST FAILURE: No loaded packs available")
            return
        }

        let originalRegionCount = pack.regions.count
        let originalEventCount = pack.events.count
        let packId = pack.manifest.packId

        // Write to temp .pack file
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pack_roundtrip_\(ProcessInfo.processInfo.globallyUniqueString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let packFile = tempDir.appendingPathComponent("roundtrip.pack")
        try BinaryPackWriter.compile(pack, to: packFile)

        // Verify .pack file exists and is non-empty
        let attrs = try FileManager.default.attributesOfItem(atPath: packFile.path)
        let fileSize = attrs[.size] as? Int64 ?? 0
        XCTAssertGreaterThan(fileSize, 0, ".pack file must not be empty")

        // Re-load .pack
        let reloaded = try BinaryPackReader.loadContent(from: packFile)

        // Validate round-trip: content is intact
        XCTAssertEqual(reloaded.manifest.packId, packId, "Pack ID must survive round-trip")
        XCTAssertEqual(reloaded.regions.count, originalRegionCount, "Region count must survive round-trip")
        XCTAssertEqual(reloaded.events.count, originalEventCount, "Event count must survive round-trip")
    }

    // MARK: - Determinism Helpers

    struct DeterministicResults {
        var randomValues: [Double] = []
        var selectedIndices: [Int] = []
    }

    func simulateDeterministicActions() -> DeterministicResults {
        var results = DeterministicResults()

        for _ in 0..<10 {
            results.randomValues.append(rng.nextDouble())
        }

        let testArray = ["a", "b", "c", "d", "e"]
        for _ in 0..<5 {
            if let selected = rng.randomElement(from: testArray),
               let index = testArray.firstIndex(of: selected) {
                results.selectedIndices.append(index)
            }
        }

        return results
    }

    /// Find all Swift files recursively in a directory.
    func findSwiftFiles(in directory: URL) -> [URL] {
        var result: [URL] = []
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return result
        }

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            result.append(fileURL)
        }

        return result
    }

}

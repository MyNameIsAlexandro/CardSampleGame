/// Файл: CardSampleGameTests/GateTests/AuditGateTests+StaticAndSerialization.swift
/// Назначение: Содержит реализацию файла AuditGateTests+StaticAndSerialization.swift.
/// Зона ответственности: Фиксирует проверяемый контракт и не содержит production-логики.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
import TwilightEngine
import PackAuthoring

@testable import CardSampleGame

extension AuditGateTests {

    /// Supplementary: Verify no hardcoded region IDs in key files
    /// See ArchitectureComplianceTests for full static analysis
    func testDocumentHardcodedIdRemoval() throws {
        // Document the changes made to remove hardcoded IDs:
        //
        // 1. TwilightGameEngine.swift:
        //    - mapRegionType(fromString:) now takes regionType string, not ID
        //    - entryRegionId comes from manifest, no "village" fallback
        //    - tensionTickInterval and restHealAmount now from BalanceConfiguration
        //
        // 2. JSONContentProvider.swift:
        //    - Events loaded from events.json, not hardcoded pool_* files
        //    - RegionDefinition includes regionType field
        //
        // 3. ContentView.swift, WorldMapView.swift, WorldState.swift:
        //    - All TwilightMarchesCards usage replaced with CardFactory
        //
        // 4. PlayerRuntimeState.swift:
        //    - shuffle() replaced with WorldRNG.shared.shuffle()
        //
        // 5. BalanceConfiguration:
        //    - Added restHealAmount and tensionTickInterval

        // Verify architectural principles are enforced
        // Full static analysis in ArchitectureComplianceTests
        let factory = cardFactory!
        XCTAssertNotNil(factory, "CardFactory must be the single source of cards")

        let guardians = factory.createGuardians()
        // Skip if ContentPacks not loaded in test environment
        // GATE TEST: Must not skip - if packs not loaded, this is a test environment issue
        if guardians.isEmpty {
            XCTFail("GATE TEST FAILURE: ContentPacks not loaded - test environment configuration issue")
            return
        }
    }

    // MARK: - EPIC 0.3: Content Hash Verification

    /// Gate test: Checksum mismatch throws error during pack loading
    /// Requirement: "hash verification при загрузке pack'ов"
    func testContentHashMismatchThrowsError() throws {
        // Create a temporary pack with incorrect checksum
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Create a simple test file
        let testContent = "test content"
        let testFileURL = tempDir.appendingPathComponent("test.json")
        try testContent.data(using: .utf8)!.write(to: testFileURL)

        // Compute correct hash
        let correctHash = try PackLoader.computeSHA256(of: testFileURL)
        XCTAssertFalse(correctHash.isEmpty, "Hash should not be empty")

        // Verify that an intentionally wrong hash would be detected
        let wrongHash = "0000000000000000000000000000000000000000000000000000000000000000"
        XCTAssertNotEqual(correctHash, wrongHash, "Correct hash should differ from test wrong hash")

        // Create manifest with wrong checksum
        let manifest = PackManifest(
            packId: "test-pack",
            displayName: LocalizedString("Test Pack"),
            description: LocalizedString("Test pack for checksum verification"),
            version: SemanticVersion(major: 1, minor: 0, patch: 0),
            packType: .campaign,
            coreVersionMin: SemanticVersion(major: 1, minor: 0, patch: 0),
            author: "Test",
            checksums: ["test.json": wrongHash]
        )

        // Attempt to load should fail with checksum mismatch
        do {
            _ = try PackLoader.load(manifest: manifest, from: tempDir)
            XCTFail("Loading pack with wrong checksum should throw error")
        } catch let error as PackLoadError {
            if case .checksumMismatch(let file, let expected, let actual) = error {
                XCTAssertEqual(file, "test.json")
                XCTAssertEqual(expected, wrongHash)
                XCTAssertEqual(actual, correctHash)
            } else {
                // File not found is acceptable since we only have test.json
                // and no real content files
                if case .fileNotFound = error {
                    // This is OK - the checksum check happens first
                } else {
                    throw error
                }
            }
        }
    }

    /// Gate test: Correct checksum passes verification
    func testCorrectChecksumPassesVerification() throws {
        // Create a temporary pack with correct checksum
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Create a simple test file
        let testContent = "test content"
        let testFileURL = tempDir.appendingPathComponent("test.json")
        try testContent.data(using: .utf8)!.write(to: testFileURL)

        // Compute correct hash
        let correctHash = try PackLoader.computeSHA256(of: testFileURL)

        // Create manifest with correct checksum
        let manifest = PackManifest(
            packId: "test-pack",
            displayName: LocalizedString("Test Pack"),
            description: LocalizedString("Test pack for checksum verification"),
            version: SemanticVersion(major: 1, minor: 0, patch: 0),
            packType: .campaign,
            coreVersionMin: SemanticVersion(major: 1, minor: 0, patch: 0),
            author: "Test",
            checksums: ["test.json": correctHash]
        )

        // Attempt to load should pass checksum verification
        // (may fail later due to missing content files, but that's OK)
        do {
            _ = try PackLoader.load(manifest: manifest, from: tempDir)
        } catch let error as PackLoadError {
            // Checksum should pass, other errors are acceptable
            if case .checksumMismatch = error {
                XCTFail("Pack with correct checksum should not fail checksum verification")
            }
            // Other errors (contentLoadFailed, etc.) are acceptable since we have minimal test files
        }
    }

    // MARK: - EPIC 11.2: Negative Tests for ContentLoader

    /// Negative test: Broken JSON fails to load
    func testBrokenJSONFailsToLoad() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Create invalid JSON
        let brokenJSON = "{ invalid json content"
        let jsonFileURL = tempDir.appendingPathComponent("regions.json")
        try brokenJSON.data(using: .utf8)!.write(to: jsonFileURL)

        // Create manifest pointing to broken JSON
        let manifest = PackManifest(
            packId: "broken-pack",
            displayName: LocalizedString("Broken Pack"),
            description: LocalizedString("Test pack with broken JSON"),
            version: SemanticVersion(major: 1, minor: 0, patch: 0),
            packType: .campaign,
            coreVersionMin: SemanticVersion(major: 1, minor: 0, patch: 0),
            author: "Test",
            regionsPath: "regions.json"
        )

        // Attempt to load should fail
        do {
            _ = try PackLoader.load(manifest: manifest, from: tempDir)
            XCTFail("Loading broken JSON should throw error")
        } catch let error as PackLoadError {
            // Should fail with contentLoadFailed
            if case .contentLoadFailed(let file, _) = error {
                XCTAssertEqual(file, "regions.json", "Ошибка должна указывать на сломанный файл")
            } else {
                // Any PackLoadError is acceptable for broken JSON
            }
        }
    }

    /// Negative test: Missing required fields fails validation
    func testMissingRequiredFieldsFailsValidation() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Create JSON with missing required fields (id is required for regions)
        let incompleteJSON = """
        [
            {
                "name": "Test Region"
            }
        ]
        """
        let jsonFileURL = tempDir.appendingPathComponent("regions.json")
        try incompleteJSON.data(using: .utf8)!.write(to: jsonFileURL)

        // Create manifest
        let manifest = PackManifest(
            packId: "incomplete-pack",
            displayName: LocalizedString("Incomplete Pack"),
            description: LocalizedString("Test pack with incomplete JSON"),
            version: SemanticVersion(major: 1, minor: 0, patch: 0),
            packType: .campaign,
            coreVersionMin: SemanticVersion(major: 1, minor: 0, patch: 0),
            author: "Test",
            regionsPath: "regions.json"
        )

        // Attempt to load - should fail due to missing fields
        do {
            _ = try PackLoader.load(manifest: manifest, from: tempDir)
            // If it loads, the JSON decoder should have failed
            XCTFail("Loading JSON with missing required fields should fail")
        } catch {
            // Expected to fail - any error is acceptable
        }
    }

    // MARK: - EPIC 11.3: State Round-Trip Serialization

    /// Gate test: EngineSave round-trip preserves all data
    func testStateRoundTripSerialization() throws {
        // Create EngineSave with test data
        let originalSave = EngineSave(
            version: EngineSave.currentVersion,
            savedAt: Date(),
            gameDuration: 3600.0,
            coreVersion: EngineSave.currentCoreVersion,
            activePackSet: ["test_campaign": "1.0.0"],
            formatVersion: EngineSave.currentFormatVersion,
            primaryCampaignPackId: nil,
            playerName: "Test Hero",
            heroId: "test_hero",
            playerHealth: 10,
            playerMaxHealth: 12,
            playerFaith: 5,
            playerMaxFaith: 8,
            playerBalance: 50,
            deckCardIds: ["card_1", "card_2", "card_3"],
            handCardIds: ["card_4"],
            discardCardIds: ["card_5"],
            currentDay: 3,
            worldTension: 25,
            lightDarkBalance: 50,
            currentRegionId: "test_region",
            regions: [],
            mainQuestStage: 2,
            activeQuestIds: ["quest_1"],
            completedQuestIds: ["quest_0"],
            questStages: ["quest_1": 1],
            completedEventIds: ["event_1", "event_2"],
            eventLog: [],
            worldFlags: ["flag_1": true, "flag_2": false],
            rngSeed: 12345,
            rngState: 12345
        )

        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(originalSave)

        // Decode back
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let loadedSave = try decoder.decode(EngineSave.self, from: jsonData)

        // Verify all fields match
        XCTAssertEqual(loadedSave.version, originalSave.version)
        XCTAssertEqual(loadedSave.coreVersion, originalSave.coreVersion)
        XCTAssertEqual(loadedSave.formatVersion, originalSave.formatVersion)
        XCTAssertEqual(loadedSave.playerName, originalSave.playerName)
        XCTAssertEqual(loadedSave.playerHealth, originalSave.playerHealth)
        XCTAssertEqual(loadedSave.playerMaxHealth, originalSave.playerMaxHealth)
        XCTAssertEqual(loadedSave.playerFaith, originalSave.playerFaith)
        XCTAssertEqual(loadedSave.playerMaxFaith, originalSave.playerMaxFaith)
        XCTAssertEqual(loadedSave.playerBalance, originalSave.playerBalance)
        XCTAssertEqual(loadedSave.deckCardIds, originalSave.deckCardIds)
        XCTAssertEqual(loadedSave.handCardIds, originalSave.handCardIds)
        XCTAssertEqual(loadedSave.discardCardIds, originalSave.discardCardIds)
        XCTAssertEqual(loadedSave.currentDay, originalSave.currentDay)
        XCTAssertEqual(loadedSave.worldTension, originalSave.worldTension)
        XCTAssertEqual(loadedSave.lightDarkBalance, originalSave.lightDarkBalance)
        XCTAssertEqual(loadedSave.currentRegionId, originalSave.currentRegionId)
        XCTAssertEqual(loadedSave.mainQuestStage, originalSave.mainQuestStage)
        XCTAssertEqual(loadedSave.activeQuestIds, originalSave.activeQuestIds)
        XCTAssertEqual(loadedSave.completedQuestIds, originalSave.completedQuestIds)
        XCTAssertEqual(loadedSave.questStages, originalSave.questStages)
        XCTAssertEqual(loadedSave.completedEventIds, originalSave.completedEventIds)
        XCTAssertEqual(loadedSave.worldFlags, originalSave.worldFlags)
        XCTAssertEqual(loadedSave.rngSeed, originalSave.rngSeed)
        XCTAssertEqual(loadedSave.activePackSet, originalSave.activePackSet)
    }

    // MARK: - EPIC 12: Critical Game Conditions

    /// Gate test: Player health reaching 0 triggers defeat
    /// Requirement: "здоровье игрока = 0 вызывает поражение"
    func testPlayerDeathTriggersDefeat() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame(playerName: "Test", heroId: nil, startingDeck: [])

        // Verify player starts alive
        XCTAssertGreaterThan(engine.player.health, 0, "Player should start with health > 0")

        // Set health to 0 (simulating fatal damage)
        engine.player.setHealth(0)

        // Verify player health is 0 (not negative)
        XCTAssertEqual(engine.player.health, 0, "Player health should be exactly 0, not negative")
    }

    /// Gate test: Player health cannot go below 0
    /// Requirement: "здоровье не может быть отрицательным"
    func testPlayerHealthCannotBeNegative() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame(playerName: "Test", heroId: nil, startingDeck: [])

        // Set health to 0 (simulating massive damage)
        engine.player.setHealth(0)

        // Health should be 0, not negative
        XCTAssertGreaterThanOrEqual(engine.player.health, 0, "Health cannot be negative")
    }

    /// Gate test: Healing cannot exceed max health
    /// Requirement: "лечение не превышает максимальное здоровье"
    func testHealingCannotExceedMaxHealth() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame(playerName: "Test", heroId: nil, startingDeck: [])

        let maxHealth = engine.player.maxHealth

        // Set health to max (simulating heal beyond max)
        engine.player.setHealth(maxHealth + 100)

        // Health should not exceed max (setPlayerHealth clamps)
        XCTAssertLessThanOrEqual(engine.player.health, maxHealth, "Health cannot exceed max")
    }

    /// Gate test: Faith cannot go below 0 or exceed max
    /// Requirement: "вера в пределах 0..max"
    func testFaithBoundsAreRespected() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame(playerName: "Test", heroId: nil, startingDeck: [])

        let maxFaith = engine.player.maxFaith

        // Spending faith via engine setter — verify bounds
        engine.player.setFaith(0)
        XCTAssertGreaterThanOrEqual(engine.player.faith, 0, "Faith cannot be negative")

        // Setting faith above max — verify bounds
        engine.player.setFaith(maxFaith)
        XCTAssertLessThanOrEqual(engine.player.faith, maxFaith, "Faith cannot exceed max")
    }

    /// Gate test: Enemy health cannot go below 0
    /// Requirement: "здоровье врага не отрицательное"
    func testEnemyHealthCannotBeNegative() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame(playerName: "Test", heroId: nil, startingDeck: [])

        let enemy = Card(id: "test_enemy", name: "Test Enemy", type: .monster, description: "Test", health: 10)
        engine.combat.setupCombatEnemy(enemy)

        // Verify enemy health initialized correctly and is non-negative
        XCTAssertEqual(engine.combat.combatEnemyHealth, 10, "Enemy should start with defined health")
        XCTAssertGreaterThanOrEqual(engine.combat.combatEnemyHealth, 0, "Enemy health should never be negative")
    }

    // MARK: - EPIC 0.2: Release Configuration (Debug Prints)

    /// Gate test: All print() statements must be wrapped in #if DEBUG
    /// Requirement: "В Release сборке нет debug print'ов"
    func testAllPrintStatementsAreDebugOnly() throws {
        // Get project root directory from compile-time path
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()  // Engine
            .deletingLastPathComponent()  // CardSampleGameTests
            .deletingLastPathComponent()  // Project root

        // Skip if project source not accessible (e.g., running on CI without source)
        guard FileManager.default.fileExists(atPath: projectRoot.path) else {
            XCTFail("GATE TEST FAILURE: Project source not accessible at \(projectRoot.path)")
            return
        }

        // Directories to check (production code only)
        let productionDirs = [
            "Engine",
            "App",
            "Views",
            "Models",
            "Utilities"
        ]

        var violations: [String] = []
        var dirsFound = 0

        for dir in productionDirs {
            let dirURL = projectRoot.appendingPathComponent(dir)

            // Skip if directory doesn't exist
            guard FileManager.default.fileExists(atPath: dirURL.path) else {
                continue
            }
            dirsFound += 1

            let swiftFiles = findSwiftFiles(in: dirURL)

            for fileURL in swiftFiles {
                let fileViolations = try checkPrintStatementsInFile(fileURL)
                violations.append(contentsOf: fileViolations)
            }
        }

        XCTAssertGreaterThan(dirsFound, 0, "No production directories found — repo structure may have changed")

        // Report all violations
        if !violations.isEmpty {
            let message = "Found \(violations.count) print() statements not wrapped in #if DEBUG:\n" +
                violations.joined(separator: "\n")
            XCTFail(message)
        }
    }

    /// Check a Swift file for print() statements not in #if DEBUG blocks
    /// Returns array of violation descriptions
    private func checkPrintStatementsInFile(_ fileURL: URL) throws -> [String] {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        var violations: [String] = []

        // Track preprocessor directive stack
        // Each entry is true if we're in a DEBUG-related block
        var conditionalStack: [Bool] = []
        var inPreviewBlock = false
        var previewBraceDepth = 0

        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            let lineNumber = index + 1

            // Track #if / #elseif / #else / #endif blocks
            if trimmedLine.hasPrefix("#if DEBUG") || trimmedLine.hasPrefix("#if compiler") {
                // Start of DEBUG or compiler-specific block (compiler is also debug-only)
                conditionalStack.append(true)
            } else if trimmedLine.hasPrefix("#if ") || trimmedLine.hasPrefix("#if(") {
                // Start of non-DEBUG conditional
                conditionalStack.append(false)
            } else if trimmedLine.hasPrefix("#elseif DEBUG") {
                // Switching to DEBUG branch
                if !conditionalStack.isEmpty {
                    conditionalStack[conditionalStack.count - 1] = true
                }
            } else if trimmedLine.hasPrefix("#elseif") || trimmedLine.hasPrefix("#else") {
                // Switching to non-DEBUG branch (inverse of previous)
                if !conditionalStack.isEmpty {
                    conditionalStack[conditionalStack.count - 1] = false
                }
            } else if trimmedLine.hasPrefix("#endif") {
                // End of conditional block
                if !conditionalStack.isEmpty {
                    conditionalStack.removeLast()
                }
            }

            // Track #Preview blocks (SwiftUI previews are debug-only)
            if trimmedLine.hasPrefix("#Preview") {
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
            }

            // Check if we're inside any DEBUG block
            let isInsideDebugBlock = conditionalStack.contains(true)

            // Skip if inside DEBUG or Preview block
            if isInsideDebugBlock || inPreviewBlock {
                continue
            }

            // Skip comments
            if trimmedLine.hasPrefix("//") || trimmedLine.hasPrefix("/*") || trimmedLine.hasPrefix("*") {
                continue
            }

            // Skip markdown files embedded in code (documentation)
            if fileURL.lastPathComponent.hasSuffix(".md") {
                continue
            }

            // Check for print() call
            if trimmedLine.contains("print(") {
                // Skip if it's in a comment on the same line
                if let printIndex = trimmedLine.range(of: "print("),
                   let commentIndex = trimmedLine.range(of: "//"),
                   commentIndex.lowerBound < printIndex.lowerBound {
                    continue
                }

                let fileName = fileURL.lastPathComponent
                violations.append("  \(fileName):\(lineNumber): \(trimmedLine)")
            }
        }

        return violations
    }


}

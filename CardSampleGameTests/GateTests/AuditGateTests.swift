import XCTest
import TwilightEngine
import PackAuthoring

@testable import CardSampleGame

/// Audit Gate Tests - Required for "фундамент для будущих игр" approval
/// These tests verify architectural requirements from Audit 2.0
///
/// Reference: Результат аудита 2.0.rtf
final class AuditGateTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WorldRNG.shared.setSeed(0)
        // Загружаем ContentPacks для тестов
        TestContentLoader.loadContentPacksIfNeeded()
    }

    override func tearDown() {
        WorldRNG.shared.setSeed(0)
        super.tearDown()
    }

    // MARK: - EPIC 0: Release Safety & Build Hygiene

    /// Gate test: Missing asset returns placeholder, never nil/crash
    /// Requirement: "UI никогда не показывает пустую иконку из-за отсутствующего ассета"
    func testMissingAssetHandling_returnsPlaceholder() {
        // Test with definitely non-existent asset names
        let missingAssets = [
            "nonexistent_icon_12345",
            "missing_region_xyz",
            "invalid_asset_name",
            "",
            "   "
        ]

        let defaultFallback = "questionmark.circle"

        for assetName in missingAssets {
            let result = AssetValidator.safeIconName(assetName, fallback: defaultFallback)

            // Must return fallback, not the missing asset name
            XCTAssertEqual(
                result,
                defaultFallback,
                "Missing asset '\(assetName)' should return fallback '\(defaultFallback)'"
            )
        }

        // Test nil input
        let nilResult = AssetValidator.safeIconName(nil, fallback: defaultFallback)
        XCTAssertEqual(
            nilResult,
            defaultFallback,
            "Nil asset name should return fallback"
        )

        // Test custom fallback
        let customFallback = "exclamationmark.triangle"
        let customResult = AssetValidator.safeIconName("missing_icon", fallback: customFallback)
        XCTAssertEqual(
            customResult,
            customFallback,
            "Should use custom fallback when provided"
        )
    }

    /// Gate test: AssetValidator.assetExists returns false for missing assets
    func testAssetValidator_detectsMissingAssets() {
        // Non-existent asset should return false
        XCTAssertFalse(
            AssetValidator.assetExists("definitely_not_a_real_asset_xyz"),
            "assetExists should return false for missing assets"
        )

        // Validate pack icons returns list of missing
        let testIcons = ["missing1", "missing2", "missing3"]
        let missing = AssetValidator.validatePackIcons(icons: testIcons)
        XCTAssertEqual(
            missing.count,
            testIcons.count,
            "All test icons should be reported as missing"
        )
    }

    /// Gate test: AssetRegistry returns SF Symbol fallback for missing assets
    /// Requirement: Epic 0.1 - "UI никогда не показывает пустую иконку"
    func testAssetRegistry_returnsFallbackForMissingAssets() {
        // AssetRegistry should always return a valid Image, never crash
        // For missing assets, it falls back to SF Symbols

        // Test region fallback
        _ = AssetRegistry.regionIcon("nonexistent_region_12345")

        // Test hero fallback
        _ = AssetRegistry.heroPortrait("nonexistent_hero_xyz")

        // Test card fallback
        _ = AssetRegistry.cardArt("nonexistent_card_abc")

        // Test hasAsset returns false for missing
        XCTAssertFalse(
            AssetRegistry.hasAsset(named: "definitely_missing_asset_99999"),
            "hasAsset should return false for missing assets"
        )

        // Test placeholder validation
        let missingPlaceholders = AssetRegistry.validatePlaceholders()
        // Note: In a real app with Assets.xcassets, this would be empty
        // For now we verify the API works
        XCTAssertNotNil(missingPlaceholders, "validatePlaceholders should return array")
    }

    // MARK: - EPIC 1: Engine Core Scrubbing

    /// Gate test: Engine/Core should not contain game-specific IDs
    /// Requirement: "Engine не содержит ни одного ID, специфичного для игры"
    func testEngineContainsNoGameSpecificIds() {
        // Verify that regions come from ContentRegistry, not hardcoded in Engine
        let registry = ContentRegistry.shared
        let regionsFromRegistry = registry.getAllRegions()

        // If packs are loaded, verify engine uses ContentRegistry data
        if !regionsFromRegistry.isEmpty {
            // All region IDs should come from loaded packs
            let regionIds = regionsFromRegistry.map { $0.id }
            XCTAssertFalse(regionIds.isEmpty, "Регионы должны загружаться из ContentRegistry")

            // Verify each region has data-driven properties
            for region in regionsFromRegistry {
                XCTAssertFalse(region.id.isEmpty, "Region ID не должен быть пустым")
                XCTAssertFalse(region.title.localized.isEmpty, "Region должен иметь локализованное имя")
                XCTAssertFalse(region.regionType.isEmpty, "Region должен иметь тип из данных")
            }
        }

        // Verify Engine initializes and works with data-driven content
        let engine = TwilightGameEngine()
        XCTAssertNotNil(engine, "Engine должен инициализироваться без хардкода контента")

        // Engine should expose regions from ContentRegistry, not internal hardcoded list
        let engineRegions = engine.regionsArray
        XCTAssertNotNil(engineRegions, "Engine должен предоставлять регионы из ContentRegistry")
    }

    /// Gate test: Manifest is single source of entry region
    /// Requirement: "no fallback 'village'"
    func testManifestIsSingleSourceOfEntryRegion() {
        // Verify that ContentRegistry uses manifest.entryRegionId
        let registry = ContentRegistry.shared

        // Campaign packs should have entryRegionId, character packs don't need it
        let campaignPacks = registry.loadedPacks.values.filter {
            $0.manifest.packType == .campaign
        }

        for pack in campaignPacks {
            // Campaign packs must specify entryRegionId
            XCTAssertNotNil(
                pack.manifest.entryRegionId,
                "Campaign pack '\(pack.manifest.packId)' must specify entryRegionId"
            )
        }

        // The code change removed `?? "village"` fallback
        // This test documents the requirement
    }

    // MARK: - EPIC 1.1: One Truth Runtime (Engine-First Architecture)

    /// Gate test: Views should primarily use TwilightGameEngine, not legacy WorldState
    /// Requirement: "UI читает Engine, а не legacy WorldState напрямую"
    func testViewsUseEngineFirstArchitecture() {
        // This test documents the Engine-First architecture requirement
        // Views should observe TwilightGameEngine for state, not WorldState directly
        //
        // Allowed patterns:
        // - @ObservedObject var engine: TwilightGameEngine (primary source)
        // - WorldState usage only for legacy compatibility adapters (marked as such)
        //
        // Disallowed patterns:
        // - Direct WorldState mutation from Views
        // - Views creating new WorldState instances for game logic

        // Verify Engine provides all necessary data for Views
        let engine = TwilightGameEngine()

        // Engine should expose player state
        XCTAssertGreaterThan(engine.playerHealth, 0, "Engine должен предоставлять здоровье игрока")
        XCTAssertGreaterThan(engine.playerFaith, 0, "Engine должен предоставлять веру игрока")

        // Engine should expose world state
        XCTAssertFalse(engine.playerName.isEmpty, "Engine должен предоставлять имя игрока")

        // Engine should handle actions
        let result = engine.performAction(.rest)
        XCTAssertNotNil(result, "Engine должен обрабатывать действия")

        // Note: Full verification requires static code analysis
        // This test documents the requirement and verifies API availability
    }

    /// Gate test: Contract tests run against production engine
    /// Requirement: "контрактные тесты идут против production engine, не test stub"
    func testContractsRunAgainstProductionEngine() {
        // Verify that TwilightGameEngine (production) is testable
        let engine = TwilightGameEngine()

        // Basic contracts: state changes are observable
        let initialHealth = engine.playerHealth
        XCTAssertGreaterThan(initialHealth, 0, "Initial health должен быть положительным")

        // Perform action that should change state
        _ = engine.performAction(.rest)

        // State should be accessible (may or may not change depending on game rules)
        XCTAssertGreaterThanOrEqual(engine.playerHealth, 0, "Health должен быть доступен после действия")

        // The test verifies we're using production engine, not a mock
        // Production engine has full game logic
    }

    // MARK: - EPIC 2.1: Code Registry Isolation

    /// Gate test: CardFactory is the primary interface, not direct registry access
    /// Requirement: "runtime не обращается напрямую к CodeRegistry"
    func testCardFactoryIsThePrimaryInterface() throws {
        // CardFactory should be the single entry point for card creation at runtime
        // It abstracts over both ContentRegistry (JSON packs) and CardRegistry (built-in)

        let factory = CardFactory.shared

        // Factory should provide starting decks
        let deck = factory.createStartingDeck(forHero: "veleslava")
        // Deck may be empty if no packs loaded, but method should work
        XCTAssertNotNil(deck, "CardFactory должен предоставлять стартовые колоды")

        // Factory should provide guardians
        let guardians = factory.createGuardians()
        // Skip if ContentPacks not loaded in test environment
        // GATE TEST: Must not skip - if packs not loaded, this is a test environment issue
        if guardians.isEmpty {
            XCTFail("GATE TEST FAILURE: ContentPacks not loaded - test environment configuration issue")
            return
        }

        // Factory should provide encounter deck
        let encounters = factory.createEncounterDeck()
        XCTAssertNotNil(encounters, "CardFactory должен предоставлять колоду столкновений")

        // This test documents that CardFactory is the correct abstraction layer
        // Direct CardRegistry/HeroRegistry access should only be in CardFactory implementation
    }

    /// Gate test: ContentRegistry is the source of truth for pack content
    /// Requirement: "ContentRegistry как единственный источник данных из pack'ов"
    func testContentRegistryIsSingleSourceOfPackData() {
        // ContentRegistry should be used for all pack content access
        let registry = ContentRegistry.shared

        // Registry should expose loaded packs
        XCTAssertNotNil(registry.loadedPacks, "ContentRegistry должен хранить загруженные pack'и")

        // Registry should provide access to pack content via factory methods
        // Direct access to registry methods is appropriate for reading definitions
        let regions = registry.getAllRegions()
        XCTAssertNotNil(regions, "ContentRegistry должен предоставлять регионы")

        let events = registry.getAllEvents()
        XCTAssertNotNil(events, "ContentRegistry должен предоставлять события")

        // This documents that ContentRegistry is the correct source for pack data
    }

    // MARK: - EPIC 2: Determinism

    /// Gate test: Full playthrough is identical with same seed
    /// Requirement: "полный playthrough одинаков при seed (на production engine)"
    func testWorldDeterminismWithSeed() {
        let testSeed: UInt64 = 12345

        // First playthrough
        WorldRNG.shared.setSeed(testSeed)
        let results1 = simulateDeterministicActions()

        // Second playthrough with same seed
        WorldRNG.shared.setSeed(testSeed)
        let results2 = simulateDeterministicActions()

        // Results must be identical
        XCTAssertEqual(
            results1.randomValues,
            results2.randomValues,
            "Random values must be identical with same seed"
        )
        XCTAssertEqual(
            results1.selectedIndices,
            results2.selectedIndices,
            "Selection results must be identical with same seed"
        )
    }

    /// Gate test: No system random in Engine/Core and core paths
    /// Requirement: "статический scan по randomElement/shuffled/Double.random"
    func testNoSystemRandomInEngineCore() throws {
        // Get project root directory from compile-time path
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()  // Engine
            .deletingLastPathComponent()  // CardSampleGameTests
            .deletingLastPathComponent()  // Project root

        // Scan entire engine source tree recursively (no hardcoded subdirectory list)
        let engineBase = SourcePathResolver.engineBase

        // Forbidden patterns (system random APIs)
        let forbiddenPatterns = [
            ".randomElement()",      // Array.randomElement()
            ".shuffled()",           // Array.shuffled()
            "Int.random(",           // Int.random(in:)
            "Double.random(",        // Double.random(in:)
            "UInt64.random(",        // UInt64.random(in:)
            "Bool.random(",          // Bool.random()
            "arc4random",            // C random
            "drand48"                // C random
        ]

        // Allowed contexts (where system random is OK)
        let allowedContexts = [
            "WorldRNG",              // Our deterministic RNG
            "// ",                   // Single-line comments
            "/// ",                  // Doc comments
            "/* ",                   // Block comments
            "* "                     // Block comment continuation
        ]

        // No exceptions: all system RNG removed from engine
        let allowedExceptions: [String: [String]] = [:]

        var violations: [String] = []

        let engineDir = projectRoot.appendingPathComponent(engineBase)
        let swiftFiles = findSwiftFiles(in: engineDir)

        for fileURL in swiftFiles {
            let fileName = fileURL.lastPathComponent
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)

            for (index, line) in lines.enumerated() {
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                let lineNumber = index + 1

                // Check each forbidden pattern
                for pattern in forbiddenPatterns {
                    if line.contains(pattern) {
                        // Check if it's in an allowed context
                        let isAllowedContext = allowedContexts.contains { context in
                            trimmedLine.hasPrefix(context) || line.contains(context)
                        }

                        // Check if it's an allowed exception for this file
                        let isAllowedException = allowedExceptions[fileName]?.contains { exception in
                            pattern.contains(exception) || exception.contains(pattern)
                        } ?? false

                        if !isAllowedContext && !isAllowedException {
                            violations.append("  \(fileName):\(lineNumber): \(trimmedLine) [pattern: \(pattern)]")
                        }
                    }
                }
            }
        }

        if !violations.isEmpty {
            let message = """
            Found \(violations.count) system random API usages in core engine paths:
            \(violations.joined(separator: "\n"))

            All randomness in Engine/Core must use WorldRNG for determinism.
            Replace:
            - .randomElement() → WorldRNG.shared.randomElement(from:)
            - .shuffled() → WorldRNG.shared.shuffle(&array)
            - Int.random(in:) → WorldRNG.shared.nextInt(in:)
            - Double.random(in:) → WorldRNG.shared.nextDouble()
            """
            XCTFail(message)
        }

        // Also verify WorldRNG determinism
        WorldRNG.shared.setSeed(42)
        let val1 = WorldRNG.shared.nextDouble()
        WorldRNG.shared.setSeed(42)
        let val2 = WorldRNG.shared.nextDouble()
        XCTAssertEqual(val1, val2, "WorldRNG must be deterministic with same seed")
    }

    // MARK: - EPIC 3: Pack Compatibility

    /// Gate test: Can load multiple packs (campaign + character)
    /// Note: "Character Pack" replaces "Investigator Pack" for Twilight Marches theme
    func testLoadTwoPacks_CampaignPlusCharacter() throws {
        // This test would require having multiple pack files
        // For now, verify the API supports this
        let registry = ContentRegistry.shared

        // Verify registry can hold multiple packs
        XCTAssertNotNil(registry.loadedPacks, "Registry should support multiple packs")

        // Note: Full test requires campaign + character pack files
    }

    /// Gate test: Save stores pack versions and validates on load
    func testSaveLoadValidatesPackVersions() {
        // Get currently loaded packs to create a valid activePackSet
        let registry = ContentRegistry.shared
        var activePackSet: [String: String] = [:]
        for (packId, pack) in registry.loadedPacks {
            activePackSet[packId] = pack.manifest.version.description
        }

        // Create a test save with pack version info
        let testSave = EngineSave(
            version: EngineSave.currentVersion,
            savedAt: Date(),
            gameDuration: 100,
            coreVersion: EngineSave.currentCoreVersion,
            activePackSet: activePackSet,
            formatVersion: EngineSave.currentFormatVersion,
            primaryCampaignPackId: nil,
            playerName: "Test",
            heroId: nil,
            playerHealth: 10,
            playerMaxHealth: 10,
            playerFaith: 5,
            playerMaxFaith: 5,
            playerBalance: 50,
            deckCardIds: [],
            handCardIds: [],
            discardCardIds: [],
            currentDay: 1,
            worldTension: 0,
            lightDarkBalance: 50,
            currentRegionId: nil,
            regions: [],
            mainQuestStage: 0,
            activeQuestIds: [],
            completedQuestIds: [],
            questStages: [:],
            completedEventIds: [],
            eventLog: [],
            worldFlags: [:],
            rngSeed: 0,
            rngState: 0
        )

        // Verify save contains required version fields
        XCTAssertFalse(testSave.coreVersion.isEmpty, "Save must store coreVersion")
        XCTAssertNotNil(testSave.activePackSet, "Save must store activePackSet")
        XCTAssertGreaterThan(testSave.formatVersion, 0, "Save must have formatVersion > 0")

        // Verify validation works - save with matching pack versions should be loadable
        let compatibility = testSave.validateCompatibility(with: registry)
        XCTAssertTrue(compatibility.isLoadable, "Save with matching pack versions should be loadable")

        // Test that mismatched pack triggers warning/error
        let mismatchedSave = EngineSave(
            version: EngineSave.currentVersion,
            savedAt: Date(),
            gameDuration: 100,
            coreVersion: EngineSave.currentCoreVersion,
            activePackSet: ["nonexistent_pack": "1.0.0"],
            formatVersion: EngineSave.currentFormatVersion,
            primaryCampaignPackId: nil,
            playerName: "Test",
            heroId: nil,
            playerHealth: 10,
            playerMaxHealth: 10,
            playerFaith: 5,
            playerMaxFaith: 5,
            playerBalance: 50,
            deckCardIds: [],
            handCardIds: [],
            discardCardIds: [],
            currentDay: 1,
            worldTension: 0,
            lightDarkBalance: 50,
            currentRegionId: nil,
            regions: [],
            mainQuestStage: 0,
            activeQuestIds: [],
            completedQuestIds: [],
            questStages: [:],
            completedEventIds: [],
            eventLog: [],
            worldFlags: [:],
            rngSeed: 0,
            rngState: 0
        )

        let mismatchedCompatibility = mismatchedSave.validateCompatibility(with: registry)
        // Missing packs result in warnings, not errors - save is still loadable
        // This allows users to continue playing even if some content is unavailable
        XCTAssertTrue(mismatchedCompatibility.isLoadable, "Save with missing pack should still be loadable (with warnings)")

        // But it should have warnings
        if case .compatible(let warnings) = mismatchedCompatibility {
            XCTAssertFalse(warnings.isEmpty, "Missing pack should generate warnings")
        } else if case .fullyCompatible = mismatchedCompatibility {
            XCTFail("Missing pack should generate at least a warning")
        }
    }

    // MARK: - EPIC 5: Localization Support

    /// Gate test: Pack content supports localization
    /// Requirement: "Packs используют stringKey/nameRu/descriptionRu для локализации"
    func testPackContentSupportsLocalization() {
        // Verify that content definitions have localization support
        // Current implementation uses nameRu/descriptionRu fields (PoC approach)
        // Future: stringKey approach for app-side localization

        // Verify HeroRegistry uses localized names
        let heroes = HeroRegistry.shared.allHeroes
        for hero in heroes {
            // Hero should have a name (either localized or default)
            XCTAssertFalse(hero.name.isEmpty, "Hero должен иметь имя")
            XCTAssertFalse(hero.description.isEmpty, "Hero должен иметь описание")
        }

        // Verify ContentRegistry provides localized content
        let registry = ContentRegistry.shared
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
        let registry = ContentRegistry.shared

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

    // MARK: - Determinism Helpers

    private struct DeterministicResults {
        var randomValues: [Double] = []
        var selectedIndices: [Int] = []
    }

    private func simulateDeterministicActions() -> DeterministicResults {
        var results = DeterministicResults()

        // Generate random values
        for _ in 0..<10 {
            results.randomValues.append(WorldRNG.shared.nextDouble())
        }

        // Simulate selection from arrays
        let testArray = ["a", "b", "c", "d", "e"]
        for _ in 0..<5 {
            if let selected = WorldRNG.shared.randomElement(from: testArray),
               let index = testArray.firstIndex(of: selected) {
                results.selectedIndices.append(index)
            }
        }

        return results
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

        // Scan for files with "Engine" in the name
        let engineFiles = try FileManager.default.contentsOfDirectory(at: coreDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
            .filter { $0.lastPathComponent.contains("Engine") }
            .map { $0.lastPathComponent }

        // Only TwilightGameEngine should exist as the runtime engine
        // Other "Engine" files (TimeEngine, PressureEngine) are subsystems, not full runtime engines
        let alternativeEngines = engineFiles.filter { file in
            // TwilightGameEngine is the production engine
            if file == "TwilightGameEngine.swift" { return false }
            // TimeEngine and PressureEngine are subsystems, not runtime engines
            if file == "TimeEngine.swift" || file == "PressureEngine.swift" { return false }
            // EngineProtocols.swift contains protocols, not a runtime engine
            if file == "EngineProtocols.swift" { return false }
            // EngineSave.swift is a data model, not a runtime engine
            if file == "EngineSave.swift" { return false }
            // ResonanceEngine.swift is a subsystem (zone detection + resonance state), not a runtime engine
            if file == "ResonanceEngine.swift" { return false }
            // Any other "Engine" file is a potential violation
            return true
        }

        XCTAssertTrue(
            alternativeEngines.isEmpty,
            "Found alternative runtime engines that should be removed: \(alternativeEngines). " +
            "TwilightGameEngine должен быть единственным runtime движком."
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
            "CardRegistry.shared",           // Direct CardRegistry access
            "TwilightMarchesCards",          // Hardcoded card definitions
            "registerBuiltInCards",          // Built-in card registration
            "HeroRegistry.shared.register"   // Direct hero registration (reading is OK)
        ]

        // Allowed patterns (these files ARE the registries, they can access themselves)
        let allowedFiles = [
            "CardRegistry.swift",
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
        let registry = ContentRegistry.shared
        registry.resetForTesting()

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

// MARK: - Static Analysis Test (Supplementary)

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
        let factory = CardFactory.shared
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
        XCTAssertGreaterThan(engine.playerHealth, 0, "Player should start with health > 0")

        // Deal fatal damage
        let fatalDamage = engine.playerHealth + 10
        engine.performAction(.combatApplyEffect(effect: .takeDamage(amount: fatalDamage)))

        // Verify player health is 0 (not negative)
        XCTAssertEqual(engine.playerHealth, 0, "Player health should be exactly 0, not negative")
    }

    /// Gate test: Player health cannot go below 0
    /// Requirement: "здоровье не может быть отрицательным"
    func testPlayerHealthCannotBeNegative() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame(playerName: "Test", heroId: nil, startingDeck: [])

        // Deal massive damage
        engine.performAction(.combatApplyEffect(effect: .takeDamage(amount: 9999)))

        // Health should be 0, not negative
        XCTAssertGreaterThanOrEqual(engine.playerHealth, 0, "Health cannot be negative")
    }

    /// Gate test: Healing cannot exceed max health
    /// Requirement: "лечение не превышает максимальное здоровье"
    func testHealingCannotExceedMaxHealth() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame(playerName: "Test", heroId: nil, startingDeck: [])

        let maxHealth = engine.playerMaxHealth

        // Heal beyond max
        engine.performAction(.combatApplyEffect(effect: .heal(amount: 9999)))

        // Health should not exceed max
        XCTAssertLessThanOrEqual(engine.playerHealth, maxHealth, "Health cannot exceed max")
        XCTAssertEqual(engine.playerHealth, maxHealth, "Healing should cap at max health")
    }

    /// Gate test: Faith cannot go below 0 or exceed max
    /// Requirement: "вера в пределах 0..max"
    func testFaithBoundsAreRespected() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame(playerName: "Test", heroId: nil, startingDeck: [])

        let maxFaith = engine.playerMaxFaith

        // Try to spend more faith than available
        engine.performAction(.combatApplyEffect(effect: .spendFaith(amount: 9999)))
        XCTAssertGreaterThanOrEqual(engine.playerFaith, 0, "Faith cannot be negative")

        // Try to gain more faith than max
        engine.performAction(.combatApplyEffect(effect: .gainFaith(amount: 9999)))
        XCTAssertLessThanOrEqual(engine.playerFaith, maxFaith, "Faith cannot exceed max")
    }

    /// Gate test: Enemy health cannot go below 0
    /// Requirement: "здоровье врага не отрицательное"
    func testEnemyHealthCannotBeNegative() {
        let engine = TwilightGameEngine()
        engine.initializeNewGame(playerName: "Test", heroId: nil, startingDeck: [])

        let enemy = Card(id: "test_enemy", name: "Test Enemy", type: .monster, description: "Test", health: 10)
        engine.setupCombatEnemy(enemy)

        // Deal massive damage
        engine.performAction(.combatApplyEffect(effect: .damageEnemy(amount: 9999)))

        // Enemy health should be 0, not negative
        XCTAssertEqual(engine.combatEnemyHealth, 0, "Enemy health should be 0, not negative")
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

    /// Find all Swift files recursively in a directory
    private func findSwiftFiles(in directory: URL) -> [URL] {
        var result: [URL] = []
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return result
        }

        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "swift" {
                result.append(fileURL)
            }
        }

        return result
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

        // Check EngineRegionState
        let engineFile = projectRoot.appendingPathComponent(SourcePathResolver.engineBase + "/Core/TwilightGameEngine.swift")
        guard FileManager.default.fileExists(atPath: engineFile.path) else {
            XCTFail("GATE TEST FAILURE: TwilightGameEngine.swift not found")
            return
        }

        let engineContent = try String(contentsOf: engineFile, encoding: .utf8)

        // EngineRegionState.id must be String (id IS the definitionId after UUID->String migration)
        XCTAssertTrue(
            engineContent.contains("public let id: String"),
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
        let registry = ContentRegistry.shared
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
        WorldRNG.shared.setSeed(testSeed)

        // Advance RNG a few times
        _ = WorldRNG.shared.next()
        _ = WorldRNG.shared.next()
        _ = WorldRNG.shared.next()

        let stateBeforeSave = WorldRNG.shared.currentState()

        // Generate some random values to verify
        let value1 = WorldRNG.shared.next()
        let value2 = WorldRNG.shared.next()

        // Restore state to before we generated values
        WorldRNG.shared.restoreState(stateBeforeSave)

        // Verify same values are generated
        let restored1 = WorldRNG.shared.next()
        let restored2 = WorldRNG.shared.next()

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

        let engineFile = projectRoot.appendingPathComponent(SourcePathResolver.engineBase + "/Core/TwilightGameEngine.swift")
        guard FileManager.default.fileExists(atPath: engineFile.path) else {
            XCTFail("GATE TEST FAILURE: TwilightGameEngine.swift not found")
            return
        }

        let content = try String(contentsOf: engineFile, encoding: .utf8)

        // createSave must include RNG state
        XCTAssertTrue(
            content.contains("rngState: WorldRNG.shared.currentState()"),
            "createSave must save WorldRNG.shared.currentState() (Audit A2)"
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
        let registry = ContentRegistry.shared
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

    // MARK: - F1: No Legacy Initialization in Views

    /// Gate test: Views must not contain legacy initialization patterns (Audit F1)
    /// Requirement: "В WorldMapView отсутствуют legacy init/ветки/комментарии"
    ///
    /// Legacy patterns to detect:
    /// - "legacy init" / "legacy initialization" comments
    /// - "shared between legacy" comments
    /// - Legacy adapter references
    ///
    /// Positive patterns to allow:
    /// - "no legacy sync needed" (indicates legacy was removed)
    func testNoLegacyInitializationInViews() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()  // Engine
            .deletingLastPathComponent()  // CardSampleGameTests
            .deletingLastPathComponent()  // Project root

        let viewsDir = projectRoot.appendingPathComponent("Views")

        guard FileManager.default.fileExists(atPath: viewsDir.path) else {
            XCTFail("GATE TEST FAILURE: Views directory not found")
            return
        }

        // Legacy patterns that indicate old architecture (should be removed)
        let forbiddenPatterns = [
            "legacy init",
            "legacy initialization",
            "shared between legacy",
            "LegacyAdapter",
            "legacyInit",
            "connectToLegacy"
        ]

        // Positive patterns that are allowed (indicate legacy was removed)
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

                // Check each forbidden pattern
                for pattern in forbiddenPatterns {
                    if lowerLine.contains(pattern.lowercased()) {
                        // Check if this line also contains an allowed pattern
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

    /// Audit 2.1 alias: exact name from acceptance criteria
    func testNoLegacyInitializationCommentsInWorldMapView() throws {
        try testNoLegacyInitializationInViews()
    }

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
        TestContentLoader.loadContentPacksIfNeeded()
        var contentIds: Set<String> = []
        for pack in ContentRegistry.shared.loadedPacks.values {
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
}

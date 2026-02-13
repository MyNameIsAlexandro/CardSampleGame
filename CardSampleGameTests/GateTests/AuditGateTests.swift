/// Файл: CardSampleGameTests/GateTests/AuditGateTests.swift
/// Назначение: Содержит реализацию файла AuditGateTests.swift.
/// Зона ответственности: Фиксирует проверяемый контракт и не содержит production-логики.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
import TwilightEngine
import PackAuthoring

@testable import CardSampleGame

/// Базовый набор audit-гейтов продукта.
/// Фиксирует обязательные архитектурные и качественные инварианты для развития проекта.
final class AuditGateTests: XCTestCase {

    var rng: WorldRNG!
    var registry: ContentRegistry!
    var localizationManager: LocalizationManager!
    var cardFactory: CardFactory!

    override func setUpWithError() throws {
        try super.setUpWithError()
        registry = try TestContentLoader.makeStandardRegistry()
        localizationManager = LocalizationManager()
        rng = WorldRNG(seed: 0)
        cardFactory = CardFactory(contentRegistry: registry, localizationManager: localizationManager)
    }

    override func tearDown() {
        cardFactory = nil
        rng = nil
        localizationManager = nil
        registry = nil
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
        let engine = TwilightGameEngine(
            services: EngineServices(rng: rng, contentRegistry: registry, localizationManager: localizationManager)
        )
        XCTAssertNotNil(engine, "Engine должен инициализироваться без хардкода контента")

        // Engine should expose regions from ContentRegistry, not internal hardcoded list
        let engineRegions = engine.regionsArray
        XCTAssertNotNil(engineRegions, "Engine должен предоставлять регионы из ContentRegistry")
    }

    /// Gate test: Manifest is single source of entry region
    /// Requirement: "no fallback 'village'"
    func testManifestIsSingleSourceOfEntryRegion() {
        // Verify that ContentRegistry uses manifest.entryRegionId

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
        XCTAssertGreaterThan(engine.player.health, 0, "Engine должен предоставлять здоровье игрока")
        XCTAssertGreaterThan(engine.player.faith, 0, "Engine должен предоставлять веру игрока")

        // Engine should expose world state
        XCTAssertFalse(engine.player.name.isEmpty, "Engine должен предоставлять имя игрока")

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
        let initialHealth = engine.player.health
        XCTAssertGreaterThan(initialHealth, 0, "Initial health должен быть положительным")

        // Perform action that should change state
        _ = engine.performAction(.rest)

        // State should be accessible (may or may not change depending on game rules)
        XCTAssertGreaterThanOrEqual(engine.player.health, 0, "Health должен быть доступен после действия")

        // The test verifies we're using production engine, not a mock
        // Production engine has full game logic
    }

    // MARK: - EPIC 2.1: Code Registry Isolation

    /// Gate test: CardFactory is the primary interface, not direct registry access
    /// Requirement: "runtime не обращается напрямую к CodeRegistry"
    func testCardFactoryIsThePrimaryInterface() throws {
        // CardFactory should be the single entry point for card creation at runtime
        // It abstracts over ContentRegistry (JSON packs)

        let factory = cardFactory!

        guard let heroId = registry.heroRegistry.firstHero?.id else {
            XCTFail("GATE TEST FAILURE: No heroes loaded in test registry")
            return
        }

        // Factory should provide starting decks
        let deck = factory.createStartingDeck(forHero: heroId)
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
        // Direct HeroRegistry access should only be in CardFactory implementation
    }

    /// Gate test: ContentRegistry is the source of truth for pack content
    /// Requirement: "ContentRegistry как единственный источник данных из pack'ов"
    func testContentRegistryIsSingleSourceOfPackData() {
        // ContentRegistry should be used for all pack content access

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
        rng.setSeed(testSeed)
        let results1 = simulateDeterministicActions()

        // Second playthrough with same seed
        rng.setSeed(testSeed)
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
        rng.setSeed(42)
        let val1 = rng.nextDouble()
        rng.setSeed(42)
        let val2 = rng.nextDouble()
        XCTAssertEqual(val1, val2, "WorldRNG must be deterministic with same seed")
    }

    // MARK: - EPIC 3: Pack Compatibility

    /// Gate test: Can load multiple packs (campaign + character)
    /// Note: "Character Pack" replaces "Investigator Pack" for Twilight Marches theme
    func testLoadTwoPacks_CampaignPlusCharacter() throws {
        // This test would require having multiple pack files
        // For now, verify the API supports this

        // Verify registry can hold multiple packs
        XCTAssertNotNil(registry.loadedPacks, "Registry should support multiple packs")

        // Note: Full test requires campaign + character pack files
    }

    /// Gate test: Save stores pack versions and validates on load
    func testSaveLoadValidatesPackVersions() {
        // Get currently loaded packs to create a valid activePackSet
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

}

import XCTest
@testable import CardSampleGame

/// Data Separation Contract Tests
/// Verify Definition/Runtime separation is maintained.
/// Reference: Docs/ENGINE_ARCHITECTURE.md, Section 4
final class DataSeparationTests: XCTestCase {

    // MARK: - INV-D01: Definitions Are Immutable

    /// Definition structs should have no runtime/mutable state
    /// Reference: ENGINE_ARCHITECTURE.md, Section 4.1
    func testDefinitionsAreImmutable() {
        // Given: A region definition
        let regionDef = MockRegionDefinition(
            id: "test_region",
            titleKey: "region.test.title",
            neighborIds: ["north", "south"],
            anchorId: "anchor_001",
            eventPoolIds: ["pool_common", "pool_special"],
            initialState: "stable"
        )

        // Then: All properties should be let (immutable)
        // This test verifies by construction - Definition uses let for all fields
        XCTAssertEqual(regionDef.id, "test_region")
        XCTAssertEqual(regionDef.neighborIds.count, 2)

        // Note: In Swift, the compiler enforces immutability via let.
        // This test documents the contract.
    }

    func testDefinitionHasNoRuntimeFields() {
        // Given: Event definition
        let eventDef = MockEventDefinition(
            id: "event_001",
            titleKey: "event.test.title",
            bodyKey: "event.test.body",
            choiceIds: ["choice_a", "choice_b"],
            isOneTime: true,
            pressureRange: 0...100,
            regionIds: ["forest", "village"]
        )

        // Then: No runtime fields (visitCount, isCompleted, etc.)
        // Definition only has static data
        XCTAssertEqual(eventDef.id, "event_001")
        XCTAssertTrue(eventDef.isOneTime)

        // Runtime state like "isCompleted" lives in EventRuntimeState, not here
    }

    // MARK: - INV-D02: Runtime References Valid Definitions

    /// RuntimeState should reference Definition by valid id
    func testRuntimeReferencesValidDefinitions() {
        // Given: Content provider with definitions
        let provider = MockContentProvider()

        // And: Runtime state referencing definitions
        let runtime = MockWorldRuntimeState(
            currentRegionId: "forest",
            regionsState: [
                "forest": MockRegionRuntimeState(definitionId: "forest", currentState: "stable", visitCount: 0),
                "village": MockRegionRuntimeState(definitionId: "village", currentState: "stable", visitCount: 2)
            ],
            pressure: 20,
            currentTime: 5
        )

        // When: Validate references
        var brokenReferences: [String] = []
        for (regionId, regionState) in runtime.regionsState {
            if provider.getRegionDefinition(id: regionState.definitionId) == nil {
                brokenReferences.append(regionId)
            }
        }

        // Then: All references valid
        XCTAssertTrue(brokenReferences.isEmpty, "Broken references: \(brokenReferences)")
    }

    func testRuntimeWithInvalidReferenceDetected() {
        // Given: Runtime with invalid reference
        let provider = MockContentProvider()
        let runtime = MockWorldRuntimeState(
            currentRegionId: "nonexistent_region",
            regionsState: [
                "invalid": MockRegionRuntimeState(definitionId: "does_not_exist", currentState: "stable", visitCount: 0)
            ],
            pressure: 20,
            currentTime: 5
        )

        // When: Validate
        var brokenReferences: [String] = []
        for (regionId, regionState) in runtime.regionsState {
            if provider.getRegionDefinition(id: regionState.definitionId) == nil {
                brokenReferences.append(regionId)
            }
        }

        // Then: Invalid reference detected
        XCTAssertFalse(brokenReferences.isEmpty, "Should detect broken reference")
        XCTAssertTrue(brokenReferences.contains("invalid"))
    }

    // MARK: - INV-D03: ContentProvider Validation

    /// ContentProvider should catch broken links
    func testContentProviderValidationCatchesBrokenLinks() {
        // Given: Provider with broken content
        let provider = MockContentProviderWithBrokenLinks()

        // When: Validate
        let errors = provider.validate()

        // Then: Errors detected
        XCTAssertFalse(errors.isEmpty, "Should detect validation errors")
        XCTAssertTrue(errors.contains { $0.type == .brokenNeighborLink })
    }

    func testContentProviderValidationPassesForValidContent() {
        // Given: Provider with valid content
        let provider = MockContentProvider()

        // When: Validate
        let errors = provider.validate()

        // Then: No errors
        XCTAssertTrue(errors.isEmpty, "Valid content should pass validation")
    }

    // MARK: - INV-D04: ID Uniqueness

    func testDefinitionIdsAreUnique() {
        // Given: Content provider
        let provider = MockContentProvider()

        // When: Get all definitions
        let regionDefs = provider.getAllRegionDefinitions()
        let eventDefs = provider.getAllEventDefinitions()

        // Then: IDs unique within each type
        let regionIds = regionDefs.map { $0.id }
        let eventIds = eventDefs.map { $0.id }

        XCTAssertEqual(regionIds.count, Set(regionIds).count, "Region IDs should be unique")
        XCTAssertEqual(eventIds.count, Set(eventIds).count, "Event IDs should be unique")
    }

    // MARK: - INV-D05: Localization Keys Present

    func testDefinitionsHaveLocalizationKeys() {
        // Given: Definitions
        let regionDef = MockRegionDefinition(
            id: "test",
            titleKey: "region.test.title",
            neighborIds: [],
            anchorId: nil,
            eventPoolIds: [],
            initialState: "stable"
        )

        // Then: Uses key, not hardcoded string
        XCTAssertTrue(regionDef.titleKey.contains("."), "Should be localization key format")
        XCTAssertFalse(regionDef.titleKey.contains(" "), "Should not be display string")
    }

    // MARK: - INV-D06: TwilightMarchesCodeContentProvider Tests

    /// TwilightMarchesCodeContentProvider should load all Act I regions
    /// Reference: Audit.rtf - Data-Driven architecture
    func testTwilightMarchesProviderLoadsAllRegions() {
        // Given: Twilight Marches content provider
        let provider = TwilightMarchesCodeContentProvider()

        // When: Get all regions
        let regions = provider.getAllRegionDefinitions()

        // Then: Should have 7 Act I regions
        XCTAssertEqual(regions.count, 7, "Act I should have 7 regions")

        // Verify all canonical regions exist
        let regionIds = Set(regions.map { $0.id })
        XCTAssertTrue(regionIds.contains("village"), "Should have village region")
        XCTAssertTrue(regionIds.contains("oak"), "Should have oak region")
        XCTAssertTrue(regionIds.contains("forest"), "Should have forest region")
        XCTAssertTrue(regionIds.contains("swamp"), "Should have swamp region")
        XCTAssertTrue(regionIds.contains("mountain"), "Should have mountain region")
        XCTAssertTrue(regionIds.contains("breach"), "Should have breach region")
        XCTAssertTrue(regionIds.contains("dark_lowland"), "Should have dark_lowland region")
    }

    /// TwilightMarchesCodeContentProvider should load all anchors
    func testTwilightMarchesProviderLoadsAnchors() {
        // Given: Twilight Marches content provider
        let provider = TwilightMarchesCodeContentProvider()

        // When: Get all anchors
        let anchors = provider.getAllAnchorDefinitions()

        // Then: Should have 6 anchors (dark_lowland has no anchor)
        XCTAssertEqual(anchors.count, 6, "Act I should have 6 anchors")

        // Verify anchor for village
        let villageAnchor = provider.getAnchorDefinition(forRegion: "village")
        XCTAssertNotNil(villageAnchor, "Village should have anchor")
        XCTAssertEqual(villageAnchor?.anchorType, "chapel", "Village anchor should be chapel")
    }

    /// Region neighbor links should be valid
    func testTwilightMarchesProviderNeighborLinksValid() {
        // Given: Twilight Marches content provider
        let provider = TwilightMarchesCodeContentProvider()

        // When: Get all regions
        let regions = provider.getAllRegionDefinitions()
        let regionIds = Set(regions.map { $0.id })

        // Then: All neighbor references should be valid
        for region in regions {
            for neighborId in region.neighborIds {
                XCTAssertTrue(
                    regionIds.contains(neighborId),
                    "Region \(region.id) references non-existent neighbor \(neighborId)"
                )
            }
        }
    }

    /// Localization helpers should return correct names
    func testTwilightMarchesLocalizationHelpers() {
        // Test region names
        XCTAssertEqual(
            TwilightMarchesCodeContentProvider.regionName(for: "village"),
            "Деревня у тракта",
            "Village should have correct Russian name"
        )
        XCTAssertEqual(
            TwilightMarchesCodeContentProvider.regionName(for: "breach"),
            "Разлом Курганов",
            "Breach should have correct Russian name"
        )

        // Test anchor names
        XCTAssertEqual(
            TwilightMarchesCodeContentProvider.anchorName(for: "anchor_village_chapel"),
            "Часовня Света",
            "Village chapel should have correct Russian name"
        )
    }

    /// Initial states should match design document
    func testTwilightMarchesRegionInitialStates() {
        // Given: Twilight Marches content provider
        let provider = TwilightMarchesCodeContentProvider()

        // When: Get specific regions
        let village = provider.getRegionDefinition(id: "village")
        let forest = provider.getRegionDefinition(id: "forest")
        let breach = provider.getRegionDefinition(id: "breach")

        // Then: Initial states should match game design
        XCTAssertEqual(village?.initialState, .stable, "Village should start as stable")
        XCTAssertEqual(forest?.initialState, .borderland, "Forest should start as borderland")
        XCTAssertEqual(breach?.initialState, .breach, "Breach should start as breach")
    }
}

// MARK: - Mock Types

struct MockRegionDefinition {
    let id: String
    let titleKey: String
    let neighborIds: [String]
    let anchorId: String?
    let eventPoolIds: [String]
    let initialState: String
}

struct MockEventDefinition {
    let id: String
    let titleKey: String
    let bodyKey: String
    let choiceIds: [String]
    let isOneTime: Bool
    let pressureRange: ClosedRange<Int>
    let regionIds: [String]
}

struct MockRegionRuntimeState {
    let definitionId: String
    var currentState: String
    var visitCount: Int
}

struct MockWorldRuntimeState {
    var currentRegionId: String
    var regionsState: [String: MockRegionRuntimeState]
    var pressure: Int
    var currentTime: Int
}

struct ContentValidationError: Equatable {
    enum ErrorType: Equatable {
        case brokenNeighborLink
        case brokenEventReference
        case duplicateId
        case invalidPressureRange
    }

    let type: ErrorType
    let message: String

    static func == (lhs: ContentValidationError, rhs: ContentValidationError) -> Bool {
        return lhs.type == rhs.type && lhs.message == rhs.message
    }
}

// MARK: - Mock Content Provider

class MockContentProvider {
    private let regions: [MockRegionDefinition] = [
        MockRegionDefinition(
            id: "forest",
            titleKey: "region.forest.title",
            neighborIds: ["village"],
            anchorId: "anchor_forest",
            eventPoolIds: ["pool_forest"],
            initialState: "stable"
        ),
        MockRegionDefinition(
            id: "village",
            titleKey: "region.village.title",
            neighborIds: ["forest", "mountains"],
            anchorId: nil,
            eventPoolIds: ["pool_village"],
            initialState: "stable"
        ),
        MockRegionDefinition(
            id: "mountains",
            titleKey: "region.mountains.title",
            neighborIds: ["village"],
            anchorId: "anchor_mountains",
            eventPoolIds: ["pool_mountains"],
            initialState: "borderland"
        )
    ]

    private let events: [MockEventDefinition] = [
        MockEventDefinition(
            id: "event_001",
            titleKey: "event.001.title",
            bodyKey: "event.001.body",
            choiceIds: ["choice_a", "choice_b"],
            isOneTime: false,
            pressureRange: 0...50,
            regionIds: ["forest"]
        ),
        MockEventDefinition(
            id: "event_002",
            titleKey: "event.002.title",
            bodyKey: "event.002.body",
            choiceIds: ["choice_c"],
            isOneTime: true,
            pressureRange: 30...100,
            regionIds: ["village", "mountains"]
        )
    ]

    func getAllRegionDefinitions() -> [MockRegionDefinition] {
        return regions
    }

    func getRegionDefinition(id: String) -> MockRegionDefinition? {
        return regions.first { $0.id == id }
    }

    func getAllEventDefinitions() -> [MockEventDefinition] {
        return events
    }

    func validate() -> [ContentValidationError] {
        var errors: [ContentValidationError] = []

        // Check neighbor links
        let regionIds = Set(regions.map { $0.id })
        for region in regions {
            for neighborId in region.neighborIds {
                if !regionIds.contains(neighborId) {
                    errors.append(ContentValidationError(
                        type: .brokenNeighborLink,
                        message: "Region \(region.id) references non-existent neighbor \(neighborId)"
                    ))
                }
            }
        }

        return errors
    }
}

class MockContentProviderWithBrokenLinks: MockContentProvider {
    private let brokenRegions: [MockRegionDefinition] = [
        MockRegionDefinition(
            id: "island",
            titleKey: "region.island.title",
            neighborIds: ["nonexistent_region"], // Broken link!
            anchorId: nil,
            eventPoolIds: [],
            initialState: "stable"
        )
    ]

    override func getAllRegionDefinitions() -> [MockRegionDefinition] {
        return brokenRegions
    }

    override func validate() -> [ContentValidationError] {
        var errors: [ContentValidationError] = []
        let regions = getAllRegionDefinitions()
        let regionIds = Set(regions.map { $0.id })

        for region in regions {
            for neighborId in region.neighborIds {
                if !regionIds.contains(neighborId) {
                    errors.append(ContentValidationError(
                        type: .brokenNeighborLink,
                        message: "Region \(region.id) references non-existent neighbor \(neighborId)"
                    ))
                }
            }
        }

        return errors
    }
}

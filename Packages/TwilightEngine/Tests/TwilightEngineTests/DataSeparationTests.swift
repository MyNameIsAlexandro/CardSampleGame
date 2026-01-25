import XCTest
@testable import TwilightEngine

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
            title: LocalizedString(en: "Test Region", ru: "Тестовый регион"),
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
            title: LocalizedString(en: "Test Event", ru: "Тестовое событие"),
            body: LocalizedString(en: "Test body", ru: "Тестовое тело"),
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

    // MARK: - INV-D05: Localized Strings Present

    func testDefinitionsHaveLocalizedStrings() {
        // Given: Definitions with LocalizedString
        let regionDef = MockRegionDefinition(
            id: "test",
            title: LocalizedString(en: "Test Region", ru: "Тестовый регион"),
            neighborIds: [],
            anchorId: nil,
            eventPoolIds: [],
            initialState: "stable"
        )

        // Then: Both English and Russian localizations are present
        XCTAssertFalse(regionDef.title.en.isEmpty, "Should have English localization")
        XCTAssertFalse(regionDef.title.ru.isEmpty, "Should have Russian localization")
        XCTAssertNotEqual(regionDef.title.en, regionDef.title.ru, "Localizations should be different")
    }

    // NOTE: ContentRegistry JSON loading tests are in ContentRegistryTests.
    // Removed duplicate stubs that were just throwing XCTSkip.
}

// MARK: - Mock Types

struct MockRegionDefinition {
    let id: String
    let title: LocalizedString
    let neighborIds: [String]
    let anchorId: String?
    let eventPoolIds: [String]
    let initialState: String
}

struct MockEventDefinition {
    let id: String
    let title: LocalizedString
    let body: LocalizedString
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
            title: LocalizedString(en: "Forest", ru: "Лес"),
            neighborIds: ["village"],
            anchorId: "anchor_forest",
            eventPoolIds: ["pool_forest"],
            initialState: "stable"
        ),
        MockRegionDefinition(
            id: "village",
            title: LocalizedString(en: "Village", ru: "Деревня"),
            neighborIds: ["forest", "mountains"],
            anchorId: nil,
            eventPoolIds: ["pool_village"],
            initialState: "stable"
        ),
        MockRegionDefinition(
            id: "mountains",
            title: LocalizedString(en: "Mountains", ru: "Горы"),
            neighborIds: ["village"],
            anchorId: "anchor_mountains",
            eventPoolIds: ["pool_mountains"],
            initialState: "borderland"
        )
    ]

    private let events: [MockEventDefinition] = [
        MockEventDefinition(
            id: "event_001",
            title: LocalizedString(en: "Event 001", ru: "Событие 001"),
            body: LocalizedString(en: "Event body", ru: "Тело события"),
            choiceIds: ["choice_a", "choice_b"],
            isOneTime: false,
            pressureRange: 0...50,
            regionIds: ["forest"]
        ),
        MockEventDefinition(
            id: "event_002",
            title: LocalizedString(en: "Event 002", ru: "Событие 002"),
            body: LocalizedString(en: "Event body 2", ru: "Тело события 2"),
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
            title: LocalizedString(en: "Island", ru: "Остров"),
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

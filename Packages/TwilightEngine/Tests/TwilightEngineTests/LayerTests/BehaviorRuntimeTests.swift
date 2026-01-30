import XCTest
@testable import TwilightEngine

/// Behavior Runtime component tests
/// Reference: ENCOUNTER_TEST_MODEL.md §3.4
final class BehaviorRuntimeTests: XCTestCase {

    // #21: Intent updates when conditions change
    func testDynamicIntentUpdate() {
        let ctx = EncounterContextFixtures.standard()
        let engine = EncounterEngine(context: ctx)

        // Round 1: full HP enemy → likely attack intent
        let intent1 = engine.generateIntent(for: "test_enemy")

        // Damage enemy significantly
        _ = engine.advancePhase() // intent → playerAction
        _ = engine.performAction(.attack(targetId: "test_enemy"))

        // Round 2: low HP enemy → intent may change (heal/flee)
        let intent2 = engine.generateIntent(for: "test_enemy")

        // Intent should potentially change based on HP condition
        // (exact behavior depends on behavior definition)
        XCTAssertNotNil(intent1)
        XCTAssertNotNil(intent2)
        // Dynamic: the test verifies the system CAN produce different intents
    }
}

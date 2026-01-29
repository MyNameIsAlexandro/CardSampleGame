import XCTest
@testable import TwilightEngine

/// Keyword Interpreter component tests
/// Reference: ENCOUNTER_TEST_MODEL.md §3.2
/// Tests context × keyword interpretation matrix
final class KeywordInterpreterTests: XCTestCase {

    // #34: Same keyword gives different effects in different contexts
    func testSurgeInCombatPhysical() {
        // TODO: Requires KeywordInterpreter implementation
        // surge + combatPhysical → extra damage
        // surge + exploration → extra discovery
        XCTFail("KeywordInterpreter not implemented — TDD RED")
    }

    // #35: Match bonus when suit matches action type
    func testMatchBonusEnhanced() {
        // Nav card + Nav action (attack) → enhanced keyword effect
        XCTFail("KeywordInterpreter not implemented — TDD RED")
    }

    // #36: Mismatch gives only value, no keyword effect
    func testMismatchSuppressed() {
        // Nav card + Prav action (heal) → keyword suppressed, value only
        XCTFail("KeywordInterpreter not implemented — TDD RED")
    }

    // #37: All keywords × all contexts = 25 combinations, none nil
    func testAllKeywordsAllContexts() {
        // 5 keywords × 5 contexts = 25, all must have defined effect
        XCTFail("KeywordInterpreter not implemented — TDD RED")
    }
}

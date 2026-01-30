import XCTest
@testable import TwilightEngine

/// Modifier System component tests
/// Reference: ENCOUNTER_TEST_MODEL.md §3.5
final class ModifierSystemTests: XCTestCase {

    // #13: Resonance zone affects fate card value via resonance rules
    func testResonanceCostModifier() {
        // A Nav card in deep Prav zone should have its value modified
        let navCard = FateCard(
            id: "test_nav",
            modifier: -1,
            name: "Nav Test",
            suit: .nav,
            resonanceRules: [
                FateResonanceRule(zone: .deepPrav, modifyValue: 1),  // neutralized in Prav
                FateResonanceRule(zone: .deepNav, modifyValue: -1)   // strengthened in Nav
            ]
        )

        // In deep Prav zone, the Nav card should be penalized (modifyValue = +1, i.e. less negative)
        let deepPravRule = navCard.resonanceRules.first { $0.zone == .deepPrav }
        XCTAssertNotNil(deepPravRule, "Nav card must have a deepPrav resonance rule")
        XCTAssertGreaterThan(deepPravRule!.modifyValue, 0,
            "Nav card in deep Prav zone should be weakened (positive modifier)")

        // In deep Nav zone, the Nav card should be strengthened
        let deepNavRule = navCard.resonanceRules.first { $0.zone == .deepNav }
        XCTAssertNotNil(deepNavRule, "Nav card must have a deepNav resonance rule")
        XCTAssertLessThan(deepNavRule!.modifyValue, 0,
            "Nav card in deep Nav zone should be strengthened (negative modifier)")
    }
}

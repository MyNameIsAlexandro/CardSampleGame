import XCTest
@testable import TwilightEngine

final class RequirementsEvaluatorTests: XCTestCase {

    var evaluator: RequirementsEvaluator!

    override func setUp() {
        super.setUp()
        evaluator = RequirementsEvaluator()
    }

    override func tearDown() {
        evaluator = nil
        super.tearDown()
    }

    // MARK: - canMeet Tests

    func testCanMeet_AllConditionsMet() {
        // Given
        let requirements = ChoiceRequirements(
            minResources: ["faith": 10, "health": 5],
            requiredFlags: ["met_elder", "visited_shrine"],
            forbiddenFlags: ["cursed"],
            minBalance: 30,
            maxBalance: 70
        )
        let resources = ["faith": 15, "health": 10]
        let flags: Set<String> = ["met_elder", "visited_shrine", "other_flag"]
        let balance = 50

        // When
        let result = evaluator.canMeet(
            requirements: requirements,
            resources: resources,
            flags: flags,
            balance: balance
        )

        // Then
        XCTAssertTrue(result, "Should meet all requirements")
    }

    func testCanMeet_InsufficientResources() {
        // Given
        let requirements = ChoiceRequirements(
            minResources: ["faith": 10, "health": 5],
            requiredFlags: [],
            forbiddenFlags: []
        )
        let resources = ["faith": 5, "health": 10] // faith too low
        let flags: Set<String> = []
        let balance = 50

        // When
        let result = evaluator.canMeet(
            requirements: requirements,
            resources: resources,
            flags: flags,
            balance: balance
        )

        // Then
        XCTAssertFalse(result, "Should fail due to insufficient faith")
    }

    func testCanMeet_MissingResource() {
        // Given
        let requirements = ChoiceRequirements(
            minResources: ["faith": 10],
            requiredFlags: [],
            forbiddenFlags: []
        )
        let resources: [String: Int] = [:] // no faith resource
        let flags: Set<String> = []
        let balance = 50

        // When
        let result = evaluator.canMeet(
            requirements: requirements,
            resources: resources,
            flags: flags,
            balance: balance
        )

        // Then
        XCTAssertFalse(result, "Should fail when resource is missing")
    }

    func testCanMeet_MissingRequiredFlag() {
        // Given
        let requirements = ChoiceRequirements(
            minResources: [:],
            requiredFlags: ["met_elder", "visited_shrine"],
            forbiddenFlags: []
        )
        let resources: [String: Int] = [:]
        let flags: Set<String> = ["met_elder"] // missing visited_shrine
        let balance = 50

        // When
        let result = evaluator.canMeet(
            requirements: requirements,
            resources: resources,
            flags: flags,
            balance: balance
        )

        // Then
        XCTAssertFalse(result, "Should fail when required flag is missing")
    }

    func testCanMeet_ForbiddenFlagPresent() {
        // Given
        let requirements = ChoiceRequirements(
            minResources: [:],
            requiredFlags: [],
            forbiddenFlags: ["cursed", "corrupted"]
        )
        let resources: [String: Int] = [:]
        let flags: Set<String> = ["blessed", "cursed"] // cursed is forbidden
        let balance = 50

        // When
        let result = evaluator.canMeet(
            requirements: requirements,
            resources: resources,
            flags: flags,
            balance: balance
        )

        // Then
        XCTAssertFalse(result, "Should fail when forbidden flag is present")
    }

    func testCanMeet_BalanceTooLow() {
        // Given
        let requirements = ChoiceRequirements(
            minResources: [:],
            requiredFlags: [],
            forbiddenFlags: [],
            minBalance: 40
        )
        let resources: [String: Int] = [:]
        let flags: Set<String> = []
        let balance = 30 // below minimum

        // When
        let result = evaluator.canMeet(
            requirements: requirements,
            resources: resources,
            flags: flags,
            balance: balance
        )

        // Then
        XCTAssertFalse(result, "Should fail when balance is below minimum")
    }

    func testCanMeet_BalanceTooHigh() {
        // Given
        let requirements = ChoiceRequirements(
            minResources: [:],
            requiredFlags: [],
            forbiddenFlags: [],
            maxBalance: 60
        )
        let resources: [String: Int] = [:]
        let flags: Set<String> = []
        let balance = 80 // above maximum

        // When
        let result = evaluator.canMeet(
            requirements: requirements,
            resources: resources,
            flags: flags,
            balance: balance
        )

        // Then
        XCTAssertFalse(result, "Should fail when balance is above maximum")
    }

    func testCanMeet_BalanceInRange() {
        // Given
        let requirements = ChoiceRequirements(
            minResources: [:],
            requiredFlags: [],
            forbiddenFlags: [],
            minBalance: 40,
            maxBalance: 60
        )
        let resources: [String: Int] = [:]
        let flags: Set<String> = []
        let balance = 50 // in range

        // When
        let result = evaluator.canMeet(
            requirements: requirements,
            resources: resources,
            flags: flags,
            balance: balance
        )

        // Then
        XCTAssertTrue(result, "Should pass when balance is in range")
    }

    func testCanMeet_CombinedConditions() {
        // Given
        let requirements = ChoiceRequirements(
            minResources: ["faith": 10, "health": 5],
            requiredFlags: ["met_elder"],
            forbiddenFlags: ["cursed"],
            minBalance: 30,
            maxBalance: 70
        )
        let resources = ["faith": 12, "health": 6]
        let flags: Set<String> = ["met_elder", "blessed"]
        let balance = 45

        // When
        let result = evaluator.canMeet(
            requirements: requirements,
            resources: resources,
            flags: flags,
            balance: balance
        )

        // Then
        XCTAssertTrue(result, "Should meet all combined conditions")
    }

    func testCanMeet_EmptyRequirements() {
        // Given
        let requirements = ChoiceRequirements()
        let resources: [String: Int] = [:]
        let flags: Set<String> = []
        let balance = 0

        // When
        let result = evaluator.canMeet(
            requirements: requirements,
            resources: resources,
            flags: flags,
            balance: balance
        )

        // Then
        XCTAssertTrue(result, "Empty requirements should always be met")
    }

    // MARK: - isChoiceAvailable Tests

    func testIsChoiceAvailable_NoRequirements() {
        // Given
        let choice = ChoiceDefinition(
            id: "choice_1",
            label: .inline("Accept"),
            requirements: nil,
            consequences: ChoiceConsequences()
        )
        let resources: [String: Int] = [:]
        let flags: Set<String> = []
        let balance = 50

        // When
        let result = evaluator.isChoiceAvailable(
            choice: choice,
            resources: resources,
            flags: flags,
            balance: balance
        )

        // Then
        XCTAssertTrue(result, "Choice with no requirements should always be available")
    }

    func testIsChoiceAvailable_RequirementsMet() {
        // Given
        let requirements = ChoiceRequirements(
            minResources: ["faith": 5],
            requiredFlags: ["met_elder"],
            forbiddenFlags: []
        )
        let choice = ChoiceDefinition(
            id: "choice_1",
            label: .inline("Pray"),
            requirements: requirements,
            consequences: ChoiceConsequences()
        )
        let resources = ["faith": 10]
        let flags: Set<String> = ["met_elder"]
        let balance = 50

        // When
        let result = evaluator.isChoiceAvailable(
            choice: choice,
            resources: resources,
            flags: flags,
            balance: balance
        )

        // Then
        XCTAssertTrue(result, "Choice should be available when requirements are met")
    }

    func testIsChoiceAvailable_RequirementsNotMet() {
        // Given
        let requirements = ChoiceRequirements(
            minResources: ["faith": 20],
            requiredFlags: [],
            forbiddenFlags: []
        )
        let choice = ChoiceDefinition(
            id: "choice_1",
            label: .inline("Perform ritual"),
            requirements: requirements,
            consequences: ChoiceConsequences()
        )
        let resources = ["faith": 5] // insufficient
        let flags: Set<String> = []
        let balance = 50

        // When
        let result = evaluator.isChoiceAvailable(
            choice: choice,
            resources: resources,
            flags: flags,
            balance: balance
        )

        // Then
        XCTAssertFalse(result, "Choice should not be available when requirements are not met")
    }
}

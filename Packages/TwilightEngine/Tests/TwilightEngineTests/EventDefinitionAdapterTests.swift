import XCTest
@testable import TwilightEngine

final class EventDefinitionAdapterTests: XCTestCase {

    // MARK: - Helpers

    private func makeEvent(
        id: String = "e1",
        title: String = "Title",
        body: String = "Body",
        eventKind: EventKind = .inline,
        availability: Availability = .always,
        weight: Int = 10,
        isOneTime: Bool = false,
        isInstant: Bool = false,
        choices: [ChoiceDefinition] = [],
        miniGameChallenge: MiniGameChallengeDefinition? = nil
    ) -> EventDefinition {
        EventDefinition(
            id: id,
            title: .text(title),
            body: .text(body),
            eventKind: eventKind,
            availability: availability,
            weight: weight,
            isOneTime: isOneTime,
            isInstant: isInstant,
            choices: choices,
            miniGameChallenge: miniGameChallenge
        )
    }

    // MARK: - Event Kind Mapping

    func testInlineKindMapsToNarrative() {
        let event = makeEvent(eventKind: .inline)
        let result = event.toGameEvent()
        XCTAssertEqual(result.eventType, .narrative)
    }

    func testMiniGameCombatMapsToCombat() {
        let event = makeEvent(eventKind: .miniGame(.combat))
        let result = event.toGameEvent()
        XCTAssertEqual(result.eventType, .combat)
    }

    func testMiniGameRitualMapsToRitual() {
        let event = makeEvent(eventKind: .miniGame(.ritual))
        let result = event.toGameEvent()
        XCTAssertEqual(result.eventType, .ritual)
    }

    func testMiniGameExplorationMapsToExploration() {
        let event = makeEvent(eventKind: .miniGame(.exploration))
        let result = event.toGameEvent()
        XCTAssertEqual(result.eventType, .exploration)
    }

    func testMiniGameDialogueMapsToNarrative() {
        let event = makeEvent(eventKind: .miniGame(.dialogue))
        let result = event.toGameEvent()
        XCTAssertEqual(result.eventType, .narrative)
    }

    func testMiniGamePuzzleMapsToRitual() {
        let event = makeEvent(eventKind: .miniGame(.puzzle))
        let result = event.toGameEvent()
        XCTAssertEqual(result.eventType, .ritual)
    }

    // MARK: - Basic Field Mapping

    func testBasicFieldsPassThrough() {
        let event = makeEvent(
            id: "test_event",
            title: "My Title",
            body: "My Body",
            weight: 25,
            isOneTime: true,
            isInstant: true
        )
        let result = event.toGameEvent()

        XCTAssertEqual(result.id, "test_event")
        XCTAssertEqual(result.title, "My Title")
        XCTAssertEqual(result.description, "My Body")
        XCTAssertEqual(result.weight, 25)
        XCTAssertTrue(result.oneTime)
        XCTAssertTrue(result.instant)
    }

    func testPressureMapsToTension() {
        let availability = Availability(minPressure: 10, maxPressure: 50)
        let event = makeEvent(availability: availability)
        let result = event.toGameEvent()

        XCTAssertEqual(result.minTension, 10)
        XCTAssertEqual(result.maxTension, 50)
    }

    func testEmptyFlagsMappedToNil() {
        let availability = Availability(requiredFlags: [], forbiddenFlags: [])
        let event = makeEvent(availability: availability)
        let result = event.toGameEvent()

        XCTAssertNil(result.requiredFlags)
        XCTAssertNil(result.forbiddenFlags)
    }

    func testNonEmptyFlagsPassThrough() {
        let availability = Availability(requiredFlags: ["flag1"], forbiddenFlags: ["flag2"])
        let event = makeEvent(availability: availability)
        let result = event.toGameEvent()

        XCTAssertEqual(result.requiredFlags, ["flag1"])
        XCTAssertEqual(result.forbiddenFlags, ["flag2"])
    }

    // MARK: - Region State Mapping

    func testNilRegionStatesReturnsAllStates() {
        let availability = Availability(regionStates: nil)
        let event = makeEvent(availability: availability)
        let result = event.toGameEvent()

        XCTAssertTrue(result.regionStates.contains(.stable))
        XCTAssertTrue(result.regionStates.contains(.borderland))
        XCTAssertTrue(result.regionStates.contains(.breach))
        XCTAssertEqual(result.regionStates.count, 3)
    }

    func testSpecificRegionStateMapped() {
        let availability = Availability(regionStates: ["stable"])
        let event = makeEvent(availability: availability)
        let result = event.toGameEvent()

        XCTAssertEqual(result.regionStates, [.stable])
    }

    func testUnknownRegionStateFilteredOut() {
        let availability = Availability(regionStates: ["stable", "unknown_state"])
        let event = makeEvent(availability: availability)
        let result = event.toGameEvent()

        XCTAssertEqual(result.regionStates, [.stable])
    }

    // MARK: - Choice Conversion

    func testChoiceBasicFields() {
        let choice = ChoiceDefinition(
            id: "c1",
            label: .text("Pick me"),
            consequences: .none
        )
        let result = choice.toEventChoice()

        XCTAssertEqual(result.id, "c1")
        XCTAssertEqual(result.text, "Pick me")
    }

    func testChoiceNilRequirementsMapsToNil() {
        let choice = ChoiceDefinition(
            id: "c1",
            label: .text("Go"),
            requirements: nil,
            consequences: .none
        )
        let result = choice.toEventChoice()
        XCTAssertNil(result.requirements)
    }

    // MARK: - Choice Requirements Conversion

    func testRequirementsFaithAndHealth() {
        let reqs = ChoiceRequirements(minResources: ["faith": 3, "health": 5])
        let result = reqs.toEventRequirements()

        XCTAssertEqual(result.minimumFaith, 3)
        XCTAssertEqual(result.minimumHealth, 5)
    }

    func testRequirementsLightBalance() {
        let reqs = ChoiceRequirements(minBalance: 70)
        let result = reqs.toEventRequirements()
        XCTAssertEqual(result.requiredBalance, .light)
    }

    func testRequirementsDarkBalance() {
        let reqs = ChoiceRequirements(minBalance: 0, maxBalance: 30)
        let result = reqs.toEventRequirements()
        XCTAssertEqual(result.requiredBalance, .dark)
    }

    func testRequirementsFlags() {
        let reqs = ChoiceRequirements(requiredFlags: ["has_item", "talked_to_npc"])
        let result = reqs.toEventRequirements()
        XCTAssertEqual(result.requiredFlags, ["has_item", "talked_to_npc"])
    }

    // MARK: - Choice Consequences Conversion

    func testConsequencesResourceChanges() {
        let cons = ChoiceConsequences(resourceChanges: ["faith": 2, "health": -1])
        let result = cons.toEventConsequences()

        XCTAssertEqual(result.faithChange, 2)
        XCTAssertEqual(result.healthChange, -1)
    }

    func testConsequencesBalanceChange() {
        let cons = ChoiceConsequences(balanceDelta: 10)
        let result = cons.toEventConsequences()
        XCTAssertEqual(result.balanceChange, 10)
    }

    func testConsequencesSetAndClearFlags() {
        let cons = ChoiceConsequences(setFlags: ["won"], clearFlags: ["lost"])
        let result = cons.toEventConsequences()

        XCTAssertEqual(result.setFlags?["won"], true)
        XCTAssertEqual(result.setFlags?["lost"], false)
    }

    func testConsequencesRestoreTransition() {
        let stateChange = RegionStateChange(regionId: nil, newState: nil, transition: .restore)
        let cons = ChoiceConsequences(regionStateChange: stateChange)
        let result = cons.toEventConsequences()

        XCTAssertEqual(result.anchorIntegrityChange, 20)
    }

    func testConsequencesDegradeTransition() {
        let stateChange = RegionStateChange(regionId: nil, newState: nil, transition: .degrade)
        let cons = ChoiceConsequences(regionStateChange: stateChange)
        let result = cons.toEventConsequences()

        XCTAssertEqual(result.anchorIntegrityChange, -20)
    }

    func testConsequencesResultKeyToMessage() {
        let cons = ChoiceConsequences(resultKey: "success_message")
        let result = cons.toEventConsequences()

        XCTAssertEqual(result.message, "Success Message")
    }

    // MARK: - Quest Links Extraction

    func testQuestLinksExtracted() {
        let quest = QuestProgressTrigger(questId: "q1", objectiveId: "o1", action: .advance)
        let choice = ChoiceDefinition(
            id: "c1",
            label: .text("Go"),
            consequences: ChoiceConsequences(questProgress: quest)
        )
        let event = makeEvent(choices: [choice])
        let result = event.toGameEvent()

        XCTAssertEqual(result.questLinks, ["q1"])
    }

    // MARK: - Difficulty to Rarity Mapping

    private func makeChallenge(difficulty: Int, enemyId: String) -> MiniGameChallengeDefinition {
        MiniGameChallengeDefinition(
            id: "ch_\(enemyId)",
            challengeKind: .combat,
            difficulty: difficulty,
            enemyId: enemyId
        )
    }

    func testDifficultyToRarityMapping() {
        // Difficulty 1 → common
        let r1 = makeEvent(miniGameChallenge: makeChallenge(difficulty: 1, enemyId: "goblin")).toGameEvent()
        XCTAssertEqual(r1.monsterCard?.rarity, .common)

        // Difficulty 2 → uncommon
        let r2 = makeEvent(miniGameChallenge: makeChallenge(difficulty: 2, enemyId: "orc")).toGameEvent()
        XCTAssertEqual(r2.monsterCard?.rarity, .uncommon)

        // Difficulty 3 → rare
        let r3 = makeEvent(miniGameChallenge: makeChallenge(difficulty: 3, enemyId: "troll")).toGameEvent()
        XCTAssertEqual(r3.monsterCard?.rarity, .rare)

        // Difficulty 4 → epic
        let r4 = makeEvent(miniGameChallenge: makeChallenge(difficulty: 4, enemyId: "dragon")).toGameEvent()
        XCTAssertEqual(r4.monsterCard?.rarity, .epic)

        // Difficulty 6 → legendary
        let r6 = makeEvent(miniGameChallenge: makeChallenge(difficulty: 6, enemyId: "god")).toGameEvent()
        XCTAssertEqual(r6.monsterCard?.rarity, .legendary)
    }
}

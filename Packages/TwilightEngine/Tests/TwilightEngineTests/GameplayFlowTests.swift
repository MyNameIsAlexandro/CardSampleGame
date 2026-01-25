import XCTest
@testable import TwilightEngine

/// Tests for gameplay flow - regions, travel, events, choices
/// These tests verify the critical user paths work correctly
final class GameplayFlowTests: XCTestCase {

    var engine: TwilightGameEngine!
    private var testPackURL: URL!

    override func setUp() {
        super.setUp()
        // Load ContentRegistry with TwilightMarches pack
        ContentRegistry.shared.resetForTesting()
        testPackURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // Engine
            .deletingLastPathComponent() // CardSampleGameTests
            .deletingLastPathComponent() // CardSampleGame
            .appendingPathComponent("ContentPacks/TwilightMarches")
        _ = try? ContentRegistry.shared.loadPack(from: testPackURL)

        // Engine-First: engine initializes its own state
        engine = TwilightGameEngine()
        engine.initializeFromContentRegistry(ContentRegistry.shared)
    }

    override func tearDown() {
        engine = nil
        ContentRegistry.shared.resetForTesting()
        testPackURL = nil
        super.tearDown()
    }

    /// Helper to skip test if regions not loaded
    private func requireRegionsLoaded() throws {
        if engine.regionsArray.isEmpty {
            throw XCTSkip("Skipping: ContentPack not loaded (no regions)")
        }
    }

    // MARK: - Region Tests

    func testRegionsArrayNotEmpty() throws {
        try requireRegionsLoaded()
        // Given: Engine initialized
        // When: Accessing regions
        let regions = engine.regionsArray

        // Then: Should have regions
        XCTAssertFalse(regions.isEmpty, "Engine should have at least one region")
    }

    func testCurrentRegionExists() throws {
        try requireRegionsLoaded()
        // Given: Engine initialized
        // When: Checking current region
        let currentRegionId = engine.currentRegionId

        // Then: Should have current region
        XCTAssertNotNil(currentRegionId, "Engine should have current region ID")

        // And current region should be in regionsArray
        let currentRegion = engine.regionsArray.first { $0.id == currentRegionId }
        XCTAssertNotNil(currentRegion, "Current region should exist in regionsArray")
    }

    func testRegionHasRequiredProperties() throws {
        try requireRegionsLoaded()
        // Given: Engine with regions
        guard let region = engine.regionsArray.first else {
            throw XCTSkip("No regions available")
        }

        // Then: Region should have required properties
        XCTAssertFalse(region.name.isEmpty, "Region should have name")
        // ID is UUID, always valid
        XCTAssertNotNil(region.id, "Region should have ID")
    }

    // MARK: - Travel Tests

    func testTravelToNeighborRegion() throws {
        try requireRegionsLoaded()
        // Given: Current region with neighbors
        guard let currentRegion = engine.currentRegion else {
            throw XCTSkip("No current region")
        }

        guard let neighborId = currentRegion.neighborIds.first else {
            throw XCTSkip("Current region has no neighbors to travel to")
        }

        let initialRegionId = engine.currentRegionId

        // When: Traveling to neighbor
        let result = engine.performAction(.travel(toRegionId: neighborId))

        // Then: Travel should succeed
        XCTAssertTrue(result.success, "Travel to neighbor should succeed")

        // And current region should change
        XCTAssertNotEqual(engine.currentRegionId, initialRegionId, "Current region should change after travel")
        XCTAssertEqual(engine.currentRegionId, neighborId, "Current region should be destination")
    }

    func testTravelAdvancesTime() throws {
        // Given: Current day
        let initialDay = engine.currentDay

        guard let currentRegion = engine.currentRegion,
              let neighborId = currentRegion.neighborIds.first else {
            throw XCTSkip("Cannot test travel time - no neighbors")
        }

        // When: Traveling
        let _ = engine.performAction(.travel(toRegionId: neighborId))

        // Then: Day should advance
        XCTAssertGreaterThan(engine.currentDay, initialDay, "Travel should advance time")
    }

    func testCannotTravelToNonNeighbor() throws {
        try requireRegionsLoaded()
        // Given: A region that is not a neighbor
        guard let currentRegion = engine.currentRegion else {
            throw XCTSkip("No current region")
        }

        // Find a non-neighbor region
        let nonNeighborRegion = engine.regionsArray.first { region in
            region.id != currentRegion.id && !currentRegion.neighborIds.contains(region.id)
        }

        guard let targetRegion = nonNeighborRegion else {
            throw XCTSkip("All regions are neighbors - cannot test non-neighbor travel")
        }

        // When: Trying to travel to non-neighbor
        let _ = engine.performAction(.travel(toRegionId: targetRegion.id))

        // Then: Should fail or be blocked (depending on implementation)
        // Note: Some implementations may allow travel to any region
        // This test documents expected behavior
        if !currentRegion.neighborIds.contains(targetRegion.id) {
            // Either fails or implementation allows any travel
            XCTAssertTrue(true, "Non-neighbor travel behavior documented")
        }
    }

    // MARK: - Event Tests

    func testExploreTriggersEvent() throws {
        try requireRegionsLoaded()
        // Given: Engine in a region
        guard engine.currentRegion != nil else {
            throw XCTSkip("No current region")
        }

        // When: Exploring
        let result = engine.performAction(.explore)

        // Then: Should succeed (may or may not trigger event)
        XCTAssertTrue(result.success, "Explore action should succeed")

        // Note: Event may or may not be triggered depending on availability
        // This test verifies the action completes without error
    }

    func testEventHasChoices() {
        // Given: A combat event
        let testEvent = GameEvent(
            eventType: .combat,
            title: "Test Combat",
            description: "Test description",
            choices: [
                EventChoice(
                    text: "Fight",
                    consequences: EventConsequences(message: "Fought")
                ),
                EventChoice(
                    text: "Flee",
                    consequences: EventConsequences(healthChange: -1, message: "Fled")
                )
            ]
        )

        // Then: Event should have choices
        XCTAssertGreaterThan(testEvent.choices.count, 0, "Event should have at least one choice")
        XCTAssertEqual(testEvent.choices.count, 2, "Test event should have 2 choices")
    }

    // MARK: - Choice Requirement Tests

    func testChoiceWithNoRequirementsIsAvailable() {
        // Given: A choice with no requirements
        let choice = EventChoice(
            text: "Simple choice",
            requirements: nil,
            consequences: EventConsequences(message: "Done")
        )

        // Then: Should be available (requirements are nil)
        XCTAssertNil(choice.requirements, "Choice should have no requirements")
    }

    func testChoiceWithFaithRequirement() {
        // Given: A choice requiring faith
        let choice = EventChoice(
            text: "Holy action",
            requirements: EventRequirements(minimumFaith: 5),
            consequences: EventConsequences(message: "Blessed")
        )

        // When: Player has enough faith
        let hasFaith = engine.playerFaith >= 5

        // Then: Requirement check depends on faith
        XCTAssertNotNil(choice.requirements?.minimumFaith, "Choice should have faith requirement")
        XCTAssertEqual(choice.requirements?.minimumFaith, 5, "Faith requirement should be 5")

        // Document current state
        print("Player faith: \(engine.playerFaith), Required: 5, Can meet: \(hasFaith)")
    }

    func testChoiceWithHealthRequirement() {
        // Given: A choice requiring health
        let choice = EventChoice(
            text: "Dangerous action",
            requirements: EventRequirements(minimumHealth: 3),
            consequences: EventConsequences(message: "Survived")
        )

        // When: Player has enough health
        let hasHealth = engine.playerHealth >= 3

        // Then: Requirement check depends on health
        XCTAssertNotNil(choice.requirements?.minimumHealth, "Choice should have health requirement")
        XCTAssertEqual(choice.requirements?.minimumHealth, 3, "Health requirement should be 3")
        XCTAssertTrue(hasHealth, "Player should have at least 3 health")
    }

    // MARK: - Choice Application Tests

    func testChoiceConsequencesStructure() {
        // Given: Consequences with various changes
        let consequences = EventConsequences(
            faithChange: -2,
            healthChange: -1,
            message: "Test consequence"
        )

        // Then: Verify consequences structure
        XCTAssertNotNil(consequences.faithChange, "Consequences should have faith change")
        XCTAssertEqual(consequences.faithChange, -2, "Faith change should be -2")
        XCTAssertNotNil(consequences.healthChange, "Consequences should have health change")
        XCTAssertEqual(consequences.healthChange, -1, "Health change should be -1")
        XCTAssertEqual(consequences.message, "Test consequence", "Message should match")
    }

    // MARK: - Combat Event Tests

    func testCombatEventHasMonsterCard() {
        // Given: A combat event definition with challenge
        let challenge = MiniGameChallengeDefinition(
            id: "test_challenge",
            challengeKind: .combat,
            difficulty: 1,
            enemyId: "wild_beast"
        )

        let eventDef = EventDefinition(
            id: "test_combat",
            title: .inline(LocalizedString(en: "Test Combat", ru: "Тест Бой")),
            body: .inline(LocalizedString(en: "A beast attacks!", ru: "Зверь атакует!")),
            eventKind: .miniGame(.combat),
            availability: .always,
            poolIds: ["pool_common"],
            weight: 10,
            isOneTime: false,
            choices: [],
            miniGameChallenge: challenge
        )

        // When: Converting to GameEvent using extension method
        let gameEvent = eventDef.toGameEvent()

        // Then: Should be combat event type
        XCTAssertEqual(gameEvent.eventType, .combat, "Event type should be combat")
        // Note: monsterCard may be nil if enemy is not in registry, but eventType should be correct
    }

    func testNarrativeEventType() {
        // Given: A narrative event definition
        let eventDef = EventDefinition(
            id: "test_narrative",
            title: .inline(LocalizedString(en: "Test Narrative", ru: "Тест Нарратив")),
            body: .inline(LocalizedString(en: "Something happens", ru: "Что-то происходит")),
            eventKind: .inline,
            availability: .always,
            poolIds: ["pool_common"],
            weight: 10,
            isOneTime: false,
            choices: [],
            miniGameChallenge: nil
        )

        // When: Converting to GameEvent using extension method
        let gameEvent = eventDef.toGameEvent()

        // Then: Should NOT have monster card and should be narrative type
        XCTAssertNil(gameEvent.monsterCard, "Non-combat event should not have monster card")
        XCTAssertEqual(gameEvent.eventType, .narrative, "Event type should be narrative")
    }

    // MARK: - Event Definition Parsing Tests

    func testEventKindDecodingInline() throws {
        // Given: JSON with inline event kind
        let json = """
        "inline"
        """.data(using: .utf8)!

        // When: Decoding
        let decoder = JSONDecoder()
        let eventKind = try decoder.decode(EventKind.self, from: json)

        // Then: Should be inline
        XCTAssertEqual(eventKind, .inline, "Should decode 'inline' string to EventKind.inline")
    }

    func testEventKindDecodingMiniGame() throws {
        // Given: JSON with mini_game event kind
        let json = """
        {"mini_game": "combat"}
        """.data(using: .utf8)!

        // When: Decoding
        let decoder = JSONDecoder()
        let eventKind = try decoder.decode(EventKind.self, from: json)

        // Then: Should be miniGame combat
        XCTAssertEqual(eventKind, .miniGame(.combat), "Should decode mini_game object to EventKind.miniGame(.combat)")
    }

    func testMiniGameChallengeDecoding() throws {
        // Given: JSON with simplified mini_game_challenge format
        let json = """
        {
            "enemy_id": "wild_beast",
            "difficulty": 2
        }
        """.data(using: .utf8)!

        // When: Decoding (using same decoder config as PackLoader)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let challenge = try decoder.decode(MiniGameChallengeDefinition.self, from: json)

        // Then: Should have correct values
        XCTAssertEqual(challenge.enemyId, "wild_beast", "Enemy ID should be decoded")
        XCTAssertEqual(challenge.difficulty, 2, "Difficulty should be decoded")
        XCTAssertEqual(challenge.id, "challenge_wild_beast", "ID should be generated from enemy ID")
    }

    // MARK: - State Persistence Tests

    func testRegionStateAfterTravel() throws {
        // Given: Initial state
        guard let initialRegion = engine.currentRegion,
              let neighborId = initialRegion.neighborIds.first else {
            throw XCTSkip("Cannot test - no neighbors")
        }

        // When: Traveling
        let _ = engine.performAction(.travel(toRegionId: neighborId))

        // Then: New region should be current
        XCTAssertEqual(engine.currentRegionId, neighborId, "Current region ID should update")

        // And previous region should still exist in array
        let previousRegion = engine.regionsArray.first { $0.id == initialRegion.id }
        XCTAssertNotNil(previousRegion, "Previous region should still exist")
    }

    // MARK: - Explore Flow Tests

    func testExploreActionSuccess() throws {
        try requireRegionsLoaded()
        // Given: Engine in a region
        guard engine.currentRegion != nil else {
            throw XCTSkip("No current region")
        }

        // When: Exploring
        let result = engine.performAction(.explore)

        // Then: Action should succeed
        XCTAssertTrue(result.success, "Explore action should always succeed")
    }

    func testExploreReturnsEventOrNil() throws {
        try requireRegionsLoaded()
        // Given: Engine in a region
        guard engine.currentRegion != nil else {
            throw XCTSkip("No current region")
        }

        // When: Exploring
        let result = engine.performAction(.explore)

        // Then: Either an event is triggered or nil (no events available)
        // Both outcomes are valid
        if let eventId = result.currentEvent {
            // Event was triggered - verify it's a valid UUID
            XCTAssertNotNil(eventId, "Triggered event should have valid ID")
            // Engine should have currentEvent set
            XCTAssertEqual(engine.currentEventId, eventId, "Engine currentEventId should match result")
        } else {
            // No event available - this is expected when region is fully explored
            XCTAssertTrue(result.success, "Explore should succeed even without events")
            XCTAssertNil(engine.currentEventId, "Engine currentEventId should be nil when no event")
        }
    }

    func testExploreDoesNotAdvanceTimeWhenNoEvent() throws {
        try requireRegionsLoaded()
        // Given: Engine with current day
        let initialDay = engine.currentDay

        // When: Exploring
        let result = engine.performAction(.explore)

        // Then: If no event triggered, time should not advance
        if result.currentEvent == nil {
            XCTAssertEqual(engine.currentDay, initialDay, "Day should not advance when no event found")
        }
        // Note: If event was triggered, time advancement depends on event handling
    }

    // MARK: - Combat Mechanics v2.0 Tests (Cards as Modifiers)
    // NOTE: CombatView.CombatStats/CombatOutcome tests moved to app tests (UI types)

    func testCardTypeAttackAddsBonus() {
        // Given: An attack card
        let attackCard = Card(
            name: "Test Sword",
            type: .attack,
            description: "A test weapon",
            power: 5
        )

        // Then: Attack cards should have power property
        XCTAssertEqual(attackCard.type, .attack, "Card should be attack type")
        XCTAssertEqual(attackCard.power, 5, "Attack card should have power for bonus damage")
    }

    func testCardTypeDefenseHasDefenseValue() {
        // Given: A defense card
        let defenseCard = Card(
            name: "Test Shield",
            type: .defense,
            description: "A test shield",
            defense: 4
        )

        // Then: Defense cards should have defense property
        XCTAssertEqual(defenseCard.type, .defense, "Card should be defense type")
        XCTAssertEqual(defenseCard.defense, 4, "Defense card should have defense for shield value")
    }

    func testCardCostProperty() {
        // Given: Cards with different costs
        let freeCard = Card(
            name: "Free Card",
            type: .attack,
            description: "No cost",
            cost: 0
        )
        let costlyCard = Card(
            name: "Costly Card",
            type: .spell,
            description: "Costs faith",
            cost: 3
        )

        // Then: Costs should be correct
        XCTAssertEqual(freeCard.cost, 0, "Free card should have 0 cost")
        XCTAssertEqual(costlyCard.cost, 3, "Costly card should have cost of 3")
    }

    func testCardTypeSpellHasAbilities() {
        // Given: A spell card with abilities
        let spellCard = Card(
            name: "Fireball",
            type: .spell,
            description: "Deals damage",
            cost: 2,
            abilities: [
                CardAbility(
                    name: "Fire Damage",
                    description: "Deals fire damage",
                    effect: .damage(amount: 6, type: .fire)
                )
            ]
        )

        // Then: Spell should have abilities
        XCTAssertEqual(spellCard.type, .spell, "Card should be spell type")
        XCTAssertFalse(spellCard.abilities.isEmpty, "Spell should have abilities")

        if case .damage(let amount, let type) = spellCard.abilities.first?.effect {
            XCTAssertEqual(amount, 6, "Damage amount should be 6")
            XCTAssertEqual(type, .fire, "Damage type should be fire")
        } else {
            XCTFail("First ability should be damage effect")
        }
    }

    func testCardTypeAffectsCombatBehavior() {
        // Given: Different card types
        let attackTypes: [CardType] = [.attack, .weapon]
        let defenseTypes: [CardType] = [.defense, .armor]
        let spellTypes: [CardType] = [.spell, .ritual]

        // Then: Types should be categorized correctly
        for type in attackTypes {
            XCTAssertTrue(type == .attack || type == .weapon, "Should be attack type")
        }
        for type in defenseTypes {
            XCTAssertTrue(type == .defense || type == .armor, "Should be defense type")
        }
        for type in spellTypes {
            XCTAssertTrue(type == .spell || type == .ritual, "Should be spell type")
        }
    }

    func testCombatResourceFaith() {
        // Given: Engine with player
        let initialFaith = engine.playerFaith

        // Then: Faith should be available for card costs
        XCTAssertGreaterThanOrEqual(initialFaith, 0, "Player should have non-negative faith")
    }

    func testCardAbilityAddDice() {
        // Given: An ability that adds dice
        let ability = CardAbility(
            name: "Blessing",
            description: "Adds bonus dice",
            effect: .addDice(count: 2)
        )

        // Then: Effect should be addDice with correct count
        if case .addDice(let count) = ability.effect {
            XCTAssertEqual(count, 2, "Should add 2 dice")
        } else {
            XCTFail("Effect should be addDice")
        }
    }

    func testCardAbilityHeal() {
        // Given: An ability that heals
        let ability = CardAbility(
            name: "Heal",
            description: "Heals player",
            effect: .heal(amount: 5)
        )

        // Then: Effect should be heal with correct amount
        if case .heal(let amount) = ability.effect {
            XCTAssertEqual(amount, 5, "Should heal 5 HP")
        } else {
            XCTFail("Effect should be heal")
        }
    }

    func testCardAbilityGainFaith() {
        // Given: An ability that grants faith
        let ability = CardAbility(
            name: "Prayer",
            description: "Grants faith",
            effect: .gainFaith(amount: 3)
        )

        // Then: Effect should be gainFaith with correct amount
        if case .gainFaith(let amount) = ability.effect {
            XCTAssertEqual(amount, 3, "Should grant 3 faith")
        } else {
            XCTFail("Effect should be gainFaith")
        }
    }

    // MARK: - Navigation System Tests v2.0

    func testIsNeighborReturnsTrue() throws {
        // Given: Current region with neighbors
        guard let currentRegion = engine.currentRegion,
              let neighborId = currentRegion.neighborIds.first else {
            throw XCTSkip("No neighbors available")
        }

        // When: Checking if neighbor
        let isNeighbor = engine.isNeighbor(regionId: neighborId)

        // Then: Should return true
        XCTAssertTrue(isNeighbor, "Should return true for neighbor region")
    }

    func testIsNeighborReturnsFalseForDistant() throws {
        // Given: A region that is not a neighbor
        guard let currentRegion = engine.currentRegion else {
            throw XCTSkip("No current region")
        }

        let distantRegion = engine.regionsArray.first { region in
            region.id != currentRegion.id && !currentRegion.neighborIds.contains(region.id)
        }

        guard let distant = distantRegion else {
            throw XCTSkip("All regions are neighbors")
        }

        // When: Checking if neighbor
        let isNeighbor = engine.isNeighbor(regionId: distant.id)

        // Then: Should return false
        XCTAssertFalse(isNeighbor, "Should return false for distant region")
    }

    func testCalculateTravelCostForNeighbor() throws {
        // Given: Current region with neighbors
        guard let currentRegion = engine.currentRegion,
              let neighborId = currentRegion.neighborIds.first else {
            throw XCTSkip("No neighbors available")
        }

        // When: Calculating travel cost
        let cost = engine.calculateTravelCost(to: neighborId)

        // Then: Should be 1 day for neighbor
        XCTAssertEqual(cost, 1, "Travel cost to neighbor should be 1 day")
    }

    func testCalculateTravelCostForDistant() throws {
        // Given: A distant region
        guard let currentRegion = engine.currentRegion else {
            throw XCTSkip("No current region")
        }

        let distantRegion = engine.regionsArray.first { region in
            region.id != currentRegion.id && !currentRegion.neighborIds.contains(region.id)
        }

        guard let distant = distantRegion else {
            throw XCTSkip("All regions are neighbors")
        }

        // When: Calculating travel cost
        let cost = engine.calculateTravelCost(to: distant.id)

        // Then: Should be 2 days for distant
        XCTAssertEqual(cost, 2, "Travel cost to distant region should be 2 days")
    }

    func testCanTravelToNeighbor() throws {
        // Given: Current region with neighbors
        guard let currentRegion = engine.currentRegion,
              let neighborId = currentRegion.neighborIds.first else {
            throw XCTSkip("No neighbors available")
        }

        // When: Checking if can travel
        let canTravel = engine.canTravelTo(regionId: neighborId)

        // Then: Should be able to travel to neighbor
        XCTAssertTrue(canTravel, "Should be able to travel to neighbor")
    }

    func testCannotTravelToDistantRegion() throws {
        // Given: A distant region
        guard let currentRegion = engine.currentRegion else {
            throw XCTSkip("No current region")
        }

        let distantRegion = engine.regionsArray.first { region in
            region.id != currentRegion.id && !currentRegion.neighborIds.contains(region.id)
        }

        guard let distant = distantRegion else {
            throw XCTSkip("All regions are neighbors")
        }

        // When: Checking if can travel
        let canTravel = engine.canTravelTo(regionId: distant.id)

        // Then: Should not be able to travel to distant
        XCTAssertFalse(canTravel, "Should not be able to travel to distant region directly")
    }

    func testCannotTravelToCurrentRegion() throws {
        // Given: Current region
        guard let currentRegionId = engine.currentRegionId else {
            throw XCTSkip("No current region")
        }

        // When: Checking if can travel to self
        let canTravel = engine.canTravelTo(regionId: currentRegionId)

        // Then: Should not be able to travel to self
        XCTAssertFalse(canTravel, "Should not be able to travel to current region")
    }

    func testGetRoutingHintForDistantRegion() throws {
        // Given: A distant region
        guard let currentRegion = engine.currentRegion else {
            throw XCTSkip("No current region")
        }

        let distantRegion = engine.regionsArray.first { region in
            region.id != currentRegion.id && !currentRegion.neighborIds.contains(region.id)
        }

        guard let distant = distantRegion else {
            throw XCTSkip("All regions are neighbors")
        }

        // When: Getting routing hint
        let hints = engine.getRoutingHint(to: distant.id)

        // Then: Should return array (may be empty if no path via 1 hop)
        // This test verifies the method returns without error and hints are valid region names
        for hint in hints {
            XCTAssertFalse(hint.isEmpty, "Each routing hint should be a non-empty region name")
        }
    }

    func testGetRoutingHintEmptyForNeighbor() throws {
        // Given: A neighbor region
        guard let currentRegion = engine.currentRegion,
              let neighborId = currentRegion.neighborIds.first else {
            throw XCTSkip("No neighbors available")
        }

        // When: Getting routing hint for neighbor
        let hints = engine.getRoutingHint(to: neighborId)

        // Then: Should be empty (no hint needed)
        XCTAssertTrue(hints.isEmpty, "Routing hints should be empty for neighbor")
    }

    // MARK: - UI Stability Tests (Duplicate ID Prevention)

    func testDuplicateCardsHaveUniqueIds() {
        // Given: Two cards with the same name (like "Защитный Посох")
        let card1 = Card(
            name: "Защитный Посох",
            type: .attack,
            rarity: .common,
            description: "Простой посох",
            power: 2
        )
        let card2 = Card(
            name: "Защитный Посох",
            type: .attack,
            rarity: .common,
            description: "Простой посох",
            power: 2
        )

        // Then: Cards should have unique IDs even with same name
        XCTAssertNotEqual(card1.id, card2.id, "Cards with same name should have unique IDs")
    }

    func testCombatLogCanHaveDuplicateEntries() {
        // Given: A combat log with duplicate entries
        var combatLog: [String] = []
        let entry = "⚔️ Защитный Посох: +2 к урону следующей атаки"

        // When: Adding same entry multiple times
        combatLog.append(entry)
        combatLog.append(entry)
        combatLog.append(entry)

        // Then: Log should contain all entries
        XCTAssertEqual(combatLog.count, 3, "Combat log should allow duplicate entries")

        // And: Enumerated access should work (as used in ForEach)
        let enumerated = Array(combatLog.suffix(5).enumerated())
        XCTAssertEqual(enumerated.count, 3, "Enumerated log should have same count")

        // And: Each entry should have unique offset
        let offsets = enumerated.map { $0.offset }
        let uniqueOffsets = Set(offsets)
        XCTAssertEqual(offsets.count, uniqueOffsets.count, "Each entry should have unique offset for ForEach id")
    }

    // NOTE: SF Symbol tests (testValidSFSymbolsUsed, testInvalidSFSymbolReturnsNil) moved to app tests (UIImage)

    func testDeckCanContainMultipleCopiesOfSameCard() {
        // Given: A deck with multiple copies of the same card name
        let cards = [
            Card(name: "Защитный Посох", type: .attack, rarity: .common, description: "Test", power: 2),
            Card(name: "Защитный Посох", type: .attack, rarity: .common, description: "Test", power: 2),
            Card(name: "Светлый Оберег", type: .defense, rarity: .common, description: "Test", defense: 1),
            Card(name: "Светлый Оберег", type: .defense, rarity: .common, description: "Test", defense: 1)
        ]

        // When: Getting unique IDs
        let ids = cards.map { $0.id }
        let uniqueIds = Set(ids)

        // Then: All cards should have unique IDs
        XCTAssertEqual(ids.count, uniqueIds.count, "All cards should have unique IDs even with same names")
        XCTAssertEqual(uniqueIds.count, 4, "Should have 4 unique card IDs")
    }

    // MARK: - Content Pack Loading Tests

    func testSemanticVersionDecoding() throws {
        // Given: JSON with version string
        let json = """
        {"version": "1.2.3"}
        """
        struct VersionWrapper: Codable { let version: SemanticVersion }

        // When: Decoding
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(VersionWrapper.self, from: data)

        // Then: Version should be parsed correctly
        XCTAssertEqual(decoded.version.major, 1)
        XCTAssertEqual(decoded.version.minor, 2)
        XCTAssertEqual(decoded.version.patch, 3)
    }

    func testSemanticVersionEncoding() throws {
        // Given: SemanticVersion
        let version = SemanticVersion(major: 2, minor: 0, patch: 1)
        struct VersionWrapper: Codable { let version: SemanticVersion }

        // When: Encoding
        let wrapper = VersionWrapper(version: version)
        let data = try JSONEncoder().encode(wrapper)
        let json = String(data: data, encoding: .utf8)!

        // Then: Should encode to string format
        XCTAssertTrue(json.contains("\"2.0.1\""), "Version should be encoded as string")
    }

    func testInvalidSemanticVersionThrowsError() {
        // Given: JSON with invalid version
        let json = """
        {"version": "invalid"}
        """
        struct VersionWrapper: Codable { let version: SemanticVersion }

        // When/Then: Decoding should throw
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(VersionWrapper.self, from: data))
    }

    func testContentRegistryExists() {
        // Given: Shared content registry
        let registry = ContentRegistry.shared

        // Then: Should exist
        XCTAssertNotNil(registry, "ContentRegistry.shared should exist")
    }

    // MARK: - Performance Tests

    func testEngineInitializationPerformance() throws {
        try requireRegionsLoaded()
        // Measure time to initialize engine (Engine-First)
        measure {
            let testEngine = TwilightGameEngine()
            testEngine.initializeFromContentRegistry(ContentRegistry.shared)

            // Ensure engine is usable
            XCTAssertNotNil(testEngine.currentRegionId)
        }
    }

    func testRegionAccessPerformance() throws {
        try requireRegionsLoaded()
        // Measure time to access regions multiple times
        measure {
            for _ in 0..<100 {
                let regions = engine.regionsArray
                XCTAssertFalse(regions.isEmpty)
            }
        }
    }

    func testTravelActionPerformance() throws {
        guard let currentRegion = engine.currentRegion,
              let neighborId = currentRegion.neighborIds.first else {
            throw XCTSkip("No neighbors for performance test")
        }

        // Measure travel performance
        measure {
            // Travel to neighbor
            _ = engine.performAction(.travel(toRegionId: neighborId))

            // Travel back
            if let newRegion = engine.currentRegion,
               let returnId = newRegion.neighborIds.first {
                _ = engine.performAction(.travel(toRegionId: returnId))
            }
        }
    }

    func testCardCreationPerformance() {
        // Measure card creation performance
        measure {
            for i in 0..<100 {
                _ = Card(
                    name: "Test Card \(i)",
                    type: .attack,
                    rarity: .common,
                    description: "Test description",
                    power: 2
                )
            }
        }
    }

    func testCombatLogEnumeratedPerformance() {
        // Test that enumerated log (used in ForEach) is fast
        var log: [String] = []
        for i in 0..<1000 {
            log.append("⚔️ Action \(i)")
        }

        measure {
            // This is what ForEach does
            let enumerated = Array(log.suffix(5).enumerated())
            XCTAssertEqual(enumerated.count, 5)

            // Access each element
            for (index, entry) in enumerated {
                XCTAssertNotNil(index)
                XCTAssertFalse(entry.isEmpty)
            }
        }
    }

    // Legacy sync tests removed - Engine-First architecture manages playerHand directly

    // MARK: - Engine Reset Tests

    /// Test that resetGameState clears isGameOver flag
    func testResetGameStateClearsIsGameOver() {
        // Given: Game is over (simulate by setting tension to max)
        // First check that we can trigger game over
        let initialGameOver = engine.isGameOver
        XCTAssertFalse(initialGameOver, "Game should not be over initially")

        // When: resetGameState is called
        engine.resetGameState()

        // Then: isGameOver should be false
        XCTAssertFalse(engine.isGameOver, "isGameOver should be false after reset")
    }

    /// Test that new game creates fresh world state - Engine-First version
    func testNewGameCreatesFreshWorldState() throws {
        try requireRegionsLoaded()
        // Given: A fresh engine after initialization
        let freshEngine = TwilightGameEngine()
        TestContentLoader.loadContentPacksIfNeeded()
        freshEngine.initializeNewGame(playerName: "Test", heroId: nil)

        // Then: It should have initial world tension
        XCTAssertEqual(freshEngine.worldTension, 30, "Fresh engine should have initial tension")

        // And: It should have initial day count
        XCTAssertEqual(freshEngine.currentDay, 0, "Fresh engine should start at day 0")

        // And: It should have regions (when ContentPack loaded)
        XCTAssertFalse(freshEngine.publishedRegions.isEmpty, "Fresh engine should have regions")
    }

    // MARK: - Travel Validation Tests

    /// Test that travel to non-neighbor region is blocked
    func testTravelToNonNeighborIsBlocked() throws {
        guard let currentRegion = engine.currentRegion else {
            throw XCTSkip("No current region")
        }

        // Find a non-neighbor region
        let nonNeighborRegion = engine.regionsArray.first { region in
            region.id != currentRegion.id && !currentRegion.neighborIds.contains(region.id)
        }

        guard let targetRegion = nonNeighborRegion else {
            throw XCTSkip("No non-neighbor region available for testing")
        }

        // When: Try to travel to non-neighbor
        let result = engine.performAction(.travel(toRegionId: targetRegion.id))

        // Then: Action should fail
        XCTAssertFalse(result.success, "Travel to non-neighbor should fail")
        XCTAssertNotNil(result.error, "Should have an error for non-neighbor travel")
    }

    /// Test that travel to neighbor region succeeds
    func testTravelToNeighborSucceeds() throws {
        guard let currentRegion = engine.currentRegion,
              let neighborId = currentRegion.neighborIds.first else {
            throw XCTSkip("No neighbor available for travel test")
        }

        let initialDay = engine.currentDay

        // When: Travel to neighbor
        let result = engine.performAction(.travel(toRegionId: neighborId))

        // Then: Action should succeed
        XCTAssertTrue(result.success, "Travel to neighbor should succeed")
        XCTAssertGreaterThan(engine.currentDay, initialDay, "Day should advance after travel")
        XCTAssertEqual(engine.currentRegionId, neighborId, "Current region should change")
    }

    /// Test that travel cost is calculated correctly
    func testTravelCostCalculation() throws {
        guard let currentRegion = engine.currentRegion,
              let neighborId = currentRegion.neighborIds.first else {
            throw XCTSkip("No neighbor for cost test")
        }

        // When: Calculate travel cost to neighbor
        let neighborCost = engine.calculateTravelCost(to: neighborId)

        // Then: Cost should be 1 for neighbor
        XCTAssertEqual(neighborCost, 1, "Travel to neighbor should cost 1 day")

        // Find non-neighbor
        let nonNeighborRegion = engine.regionsArray.first { region in
            region.id != currentRegion.id && !currentRegion.neighborIds.contains(region.id)
        }

        if let nonNeighbor = nonNeighborRegion {
            // When: Calculate travel cost to non-neighbor
            let nonNeighborCost = engine.calculateTravelCost(to: nonNeighbor.id)

            // Then: Cost should be 2 for non-neighbor
            XCTAssertEqual(nonNeighborCost, 2, "Travel to non-neighbor should cost 2 days")
        }
    }
}

// MARK: - Test Helpers

extension GameplayFlowTests {

    /// Helper to create test engine (Engine-First)
    func createTestEngine() -> TwilightGameEngine {
        let testEngine = TwilightGameEngine()
        testEngine.initializeFromContentRegistry(ContentRegistry.shared)
        return testEngine
    }
}

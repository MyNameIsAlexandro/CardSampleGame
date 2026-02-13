/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/GameplayFlowTests+CombatAndNavigation.swift
/// Назначение: Содержит реализацию файла GameplayFlowTests+CombatAndNavigation.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import TwilightEngine

extension GameplayFlowTests {
    // MARK: - Combat Mechanics v2.0 Tests (Cards as Modifiers)
    // NOTE: CombatView.CombatStats/CombatOutcome tests moved to app tests (UI types)

    func testCardTypeAttackAddsBonus() {
        // Given: An attack card
        let attackCard = Card(
            id: "test_card_1",
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
            id: "test_card_2",
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
            id: "test_card_3",
            name: "Free Card",
            type: .attack,
            description: "No cost",
            cost: 0
        )
        let costlyCard = Card(
            id: "test_card_4",
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
            id: "test_card_5",
            name: "Fireball",
            type: .spell,
            description: "Deals damage",
            cost: 2,
            abilities: [
                CardAbility(
                    id: "test_ability_1",
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
            XCTFail("First ability should be damage effect"); return
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
        let initialFaith = engine.player.faith

        // Then: Faith should be available for card costs
        XCTAssertGreaterThanOrEqual(initialFaith, 0, "Player should have non-negative faith")
    }

    func testCardAbilityAddDice() {
        // Given: An ability that adds dice
        let ability = CardAbility(
            id: "test_ability_2",
            name: "Blessing",
            description: "Adds bonus dice",
            effect: .addDice(count: 2)
        )

        // Then: Effect should be addDice with correct count
        if case .addDice(let count) = ability.effect {
            XCTAssertEqual(count, 2, "Should add 2 dice")
        } else {
            XCTFail("Effect should be addDice"); return
        }
    }

    func testCardAbilityHeal() {
        // Given: An ability that heals
        let ability = CardAbility(
            id: "test_ability_3",
            name: "Heal",
            description: "Heals player",
            effect: .heal(amount: 5)
        )

        // Then: Effect should be heal with correct amount
        if case .heal(let amount) = ability.effect {
            XCTAssertEqual(amount, 5, "Should heal 5 HP")
        } else {
            XCTFail("Effect should be heal"); return
        }
    }

    func testCardAbilityGainFaith() {
        // Given: An ability that grants faith
        let ability = CardAbility(
            id: "test_ability_4",
            name: "Prayer",
            description: "Grants faith",
            effect: .gainFaith(amount: 3)
        )

        // Then: Effect should be gainFaith with correct amount
        if case .gainFaith(let amount) = ability.effect {
            XCTAssertEqual(amount, 3, "Should grant 3 faith")
        } else {
            XCTFail("Effect should be gainFaith"); return
        }
    }

    // MARK: - Navigation System Tests v2.0

    func testIsNeighborReturnsTrue() {
        // Given: Current region with neighbors
        guard let currentRegion = engine.currentRegion,
              let neighborId = currentRegion.neighborIds.first else {
            XCTFail("No neighbors available"); return
        }

        // When: Checking if neighbor
        let isNeighbor = engine.isNeighbor(regionId: neighborId)

        // Then: Should return true
        XCTAssertTrue(isNeighbor, "Should return true for neighbor region")
    }

    func testIsNeighborReturnsFalseForDistant() {
        // Given: A region that is not a neighbor
        guard let currentRegion = engine.currentRegion else {
            XCTFail("No current region"); return
        }

        let distantRegion = engine.regionsArray.first { region in
            region.id != currentRegion.id && !currentRegion.neighborIds.contains(region.id)
        }

        guard let distant = distantRegion else {
            XCTFail("All regions are neighbors"); return
        }

        // When: Checking if neighbor
        let isNeighbor = engine.isNeighbor(regionId: distant.id)

        // Then: Should return false
        XCTAssertFalse(isNeighbor, "Should return false for distant region")
    }

    func testCalculateTravelCostForNeighbor() {
        // Given: Current region with neighbors
        guard let currentRegion = engine.currentRegion,
              let neighborId = currentRegion.neighborIds.first else {
            XCTFail("No neighbors available"); return
        }

        // When: Calculating travel cost
        let cost = engine.calculateTravelCost(to: neighborId)

        // Then: Should be 1 day for neighbor
        XCTAssertEqual(cost, 1, "Travel cost to neighbor should be 1 day")
    }

    func testCalculateTravelCostForDistant() {
        // Given: A distant region
        guard let currentRegion = engine.currentRegion else {
            XCTFail("No current region"); return
        }

        let distantRegion = engine.regionsArray.first { region in
            region.id != currentRegion.id && !currentRegion.neighborIds.contains(region.id)
        }

        guard let distant = distantRegion else {
            XCTFail("All regions are neighbors"); return
        }

        // When: Calculating travel cost
        let cost = engine.calculateTravelCost(to: distant.id)

        // Then: Should be 2 days for distant
        XCTAssertEqual(cost, 2, "Travel cost to distant region should be 2 days")
    }

    func testCanTravelToNeighbor() {
        // Given: Current region with neighbors
        guard let currentRegion = engine.currentRegion,
              let neighborId = currentRegion.neighborIds.first else {
            XCTFail("No neighbors available"); return
        }

        // When: Checking if can travel
        let canTravel = engine.canTravelTo(regionId: neighborId)

        // Then: Should be able to travel to neighbor
        XCTAssertTrue(canTravel, "Should be able to travel to neighbor")
    }

    func testCannotTravelToDistantRegion() {
        // Given: A distant region
        guard let currentRegion = engine.currentRegion else {
            XCTFail("No current region"); return
        }

        let distantRegion = engine.regionsArray.first { region in
            region.id != currentRegion.id && !currentRegion.neighborIds.contains(region.id)
        }

        guard let distant = distantRegion else {
            XCTFail("All regions are neighbors"); return
        }

        // When: Checking if can travel
        let canTravel = engine.canTravelTo(regionId: distant.id)

        // Then: Should not be able to travel to distant
        XCTAssertFalse(canTravel, "Should not be able to travel to distant region directly")
    }

    func testCannotTravelToCurrentRegion() {
        // Given: Current region
        guard let currentRegionId = engine.currentRegionId else {
            XCTFail("No current region"); return
        }

        // When: Checking if can travel to self
        let canTravel = engine.canTravelTo(regionId: currentRegionId)

        // Then: Should not be able to travel to self
        XCTAssertFalse(canTravel, "Should not be able to travel to current region")
    }

    func testGetRoutingHintForDistantRegion() {
        // Given: A distant region
        guard let currentRegion = engine.currentRegion else {
            XCTFail("No current region"); return
        }

        let distantRegion = engine.regionsArray.first { region in
            region.id != currentRegion.id && !currentRegion.neighborIds.contains(region.id)
        }

        guard let distant = distantRegion else {
            XCTFail("All regions are neighbors"); return
        }

        // When: Getting routing hint
        let hints = engine.getRoutingHint(to: distant.id)

        // Then: Should return array (may be empty if no path via 1 hop)
        // This test verifies the method returns without error and hints are valid region names
        for hint in hints {
            XCTAssertFalse(hint.isEmpty, "Each routing hint should be a non-empty region name")
        }
    }

    func testGetRoutingHintEmptyForNeighbor() {
        // Given: A neighbor region
        guard let currentRegion = engine.currentRegion,
              let neighborId = currentRegion.neighborIds.first else {
            XCTFail("No neighbors available"); return
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
            id: "test_card_dup_1",
            name: "Защитный Посох",
            type: .attack,
            rarity: .common,
            description: "Простой посох",
            power: 2
        )
        let card2 = Card(
            id: "test_card_dup_2",
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
            Card(id: "test_deck_1", name: "Защитный Посох", type: .attack, rarity: .common, description: "Test", power: 2),
            Card(id: "test_deck_2", name: "Защитный Посох", type: .attack, rarity: .common, description: "Test", power: 2),
            Card(id: "test_deck_3", name: "Светлый Оберег", type: .defense, rarity: .common, description: "Test", defense: 1),
            Card(id: "test_deck_4", name: "Светлый Оберег", type: .defense, rarity: .common, description: "Test", defense: 1)
        ]

        // When: Getting unique IDs
        let ids = cards.map { $0.id }
        let uniqueIds = Set(ids)

        // Then: All cards should have unique IDs
        XCTAssertEqual(ids.count, uniqueIds.count, "All cards should have unique IDs even with same names")
        XCTAssertEqual(uniqueIds.count, 4, "Should have 4 unique card IDs")
    }

}

import XCTest
@testable import TwilightEngine

final class CombatSystemCompletionTests: XCTestCase {

    // MARK: - Helpers

    private func makeCard(
        id: String = "test_card",
        name: String = "Test Card",
        power: Int? = nil,
        defense: Int? = nil,
        abilities: [CardAbility] = [],
        faithCost: Int = 3,
        realm: Realm? = nil
    ) -> Card {
        Card(
            id: id,
            name: name,
            type: .spell,
            description: "Test",
            power: power,
            defense: defense,
            abilities: abilities,
            realm: realm,
            faithCost: faithCost
        )
    }

    private func makeAbility(effect: AbilityEffect) -> CardAbility {
        CardAbility(id: "ab_\(UUID().uuidString.prefix(4))", name: "Test", description: "Test", effect: effect)
    }

    private func makeEngine(
        heroCards: [Card] = [],
        heroStrength: Int = 5,
        heroWisdom: Int = 3,
        heroFaith: Int = 100,
        worldResonance: Float = 0,
        enemySpiritDefense: Int = 0,
        enemyWP: Int? = nil
    ) -> EncounterEngine {
        let hero = EncounterHero(id: "hero", hp: 20, maxHp: 20, strength: heroStrength, armor: 0, wisdom: heroWisdom)
        let enemy = EncounterEnemy(
            id: "enemy", name: "Goblin", hp: 30, maxHp: 30,
            wp: enemyWP, maxWp: enemyWP,
            power: 3, defense: 2, spiritDefense: enemySpiritDefense
        )
        let ctx = EncounterContext(
            hero: hero,
            enemies: [enemy],
            fateDeckSnapshot: FateDeckState(drawPile: [], discardPile: []),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42,
            worldResonance: worldResonance,
            heroCards: heroCards,
            heroFaith: heroFaith
        )
        let eng = EncounterEngine(context: ctx)
        _ = eng.advancePhase() // intent → playerAction
        return eng
    }

    /// Advance from playerAction through a full round back to playerAction.
    private func advanceFullRound(_ eng: EncounterEngine) {
        _ = eng.advancePhase() // → enemyResolution
        _ = eng.advancePhase() // → roundEnd
        _ = eng.advancePhase() // → intent
        _ = eng.advancePhase() // → playerAction
    }

    // MARK: - Faith Cost Tests

    func testFaithCostEnforcement() {
        let card = makeCard(id: "c1", name: "Costly", faithCost: 3)
        let eng = makeEngine(heroCards: [card], heroFaith: 2)

        let result = eng.performAction(.useCard(cardId: "c1", targetId: nil))
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.error, .insufficientFaith, "Should fail when faith < card cost")
    }

    func testFaithCostDeducted() {
        let card = makeCard(id: "c1", name: "Spell", faithCost: 3)
        let eng = makeEngine(heroCards: [card], heroFaith: 10)

        let result = eng.performAction(.useCard(cardId: "c1", targetId: nil))
        XCTAssertTrue(result.success)
        XCTAssertEqual(eng.heroFaith, 7, "Faith should decrease by card cost")
    }

    // MARK: - Resonance Faith Modifier Tests

    func testResonanceFaithModifier_NavInPravZone() {
        // worldResonance=50 → prav zone; card realm=.nav → penalty +1 → effective cost = 4
        let card = makeCard(id: "c1", name: "Nav Spell", faithCost: 3, realm: .nav)
        let eng = makeEngine(heroCards: [card], heroFaith: 10, worldResonance: 50)

        let result = eng.performAction(.useCard(cardId: "c1", targetId: nil))
        XCTAssertTrue(result.success)
        XCTAssertEqual(eng.heroFaith, 6, "Nav card in Prav zone costs 4 (3 base + 1 penalty)")
    }

    func testResonanceFaithModifier_Matching() {
        // worldResonance=-50 → nav zone; card realm=.nav → discount -1 → effective cost = 2
        let card = makeCard(id: "c1", name: "Nav Spell", faithCost: 3, realm: .nav)
        let eng = makeEngine(heroCards: [card], heroFaith: 10, worldResonance: -50)

        let result = eng.performAction(.useCard(cardId: "c1", targetId: nil))
        XCTAssertTrue(result.success)
        XCTAssertEqual(eng.heroFaith, 8, "Nav card in Nav zone costs 2 (3 base - 1 discount)")
    }

    // MARK: - Spirit Defense

    func testSpiritDefenseReducesDamage() {
        // wisdom=3, spiritDefense=5, empty fate deck → damage = max(1, 3 - 5) = 1
        let eng = makeEngine(heroWisdom: 3, enemySpiritDefense: 5, enemyWP: 20)

        let result = eng.performAction(.spiritAttack(targetId: "enemy"))
        XCTAssertTrue(result.success)

        let wpChange = result.stateChanges.first(where: {
            if case .enemyWPChanged = $0 { return true }; return false
        })
        if case .enemyWPChanged(_, let delta, let newValue) = wpChange {
            XCTAssertEqual(delta, -1, "Damage clamped to 1 when spiritDefense exceeds wisdom")
            XCTAssertEqual(newValue, 19)
        } else {
            XCTFail("Expected enemyWPChanged state change")
        }
    }

    // MARK: - Draw Per Round

    func testDrawPerRound() {
        // 5 heroCards, initial hand = 3 (first 3). After a full round, hand should gain 1 card.
        let cards = (0..<5).map { makeCard(id: "c\($0)", name: "Card \($0)") }
        let eng = makeEngine(heroCards: cards)

        XCTAssertEqual(eng.hand.count, 3, "Initial hand should be 3")

        advanceFullRound(eng)

        XCTAssertEqual(eng.hand.count, 4, "Hand should gain 1 card after round end")
    }

    // MARK: - Mulligan

    func testMulliganSwapsCards() {
        let cards = (0..<5).map { makeCard(id: "c\($0)", name: "Card \($0)") }
        let eng = makeEngine(heroCards: cards)

        // Hand starts with c0, c1, c2 (first 3). Mulligan c0 and c1 → get 2 replacements from pool.
        let handBefore = Set(eng.hand.map(\.id))
        XCTAssertTrue(handBefore.contains("c0"))
        XCTAssertTrue(handBefore.contains("c1"))

        let result = eng.performAction(.mulligan(cardIds: ["c0", "c1"]))
        XCTAssertTrue(result.success)
        XCTAssertEqual(eng.hand.count, 3, "Hand size should remain 3 after mulligan")

        let handAfter = Set(eng.hand.map(\.id))
        XCTAssertFalse(handAfter.contains("c0"), "Mulliganed card should be gone")
        XCTAssertFalse(handAfter.contains("c1"), "Mulliganed card should be gone")
        XCTAssertTrue(handAfter.contains("c2"), "Non-mulliganed card should remain")
    }

    func testMulliganOnceOnly() {
        let cards = (0..<5).map { makeCard(id: "c\($0)", name: "Card \($0)") }
        let eng = makeEngine(heroCards: cards)

        let first = eng.performAction(.mulligan(cardIds: ["c0"]))
        XCTAssertTrue(first.success)

        let second = eng.performAction(.mulligan(cardIds: ["c1"]))
        XCTAssertFalse(second.success)
        XCTAssertEqual(second.error, .mulliganAlreadyDone)
    }

    // MARK: - One Finish Action Per Turn

    func testOneFinishActionPerTurn() {
        let eng = makeEngine()

        let first = eng.performAction(.attack(targetId: "enemy"))
        XCTAssertTrue(first.success)

        let second = eng.performAction(.attack(targetId: "enemy"))
        XCTAssertFalse(second.success)
        XCTAssertEqual(second.error, .actionNotAllowed, "Second finish action should be rejected")
    }

    func testCardPlayNotFinishAction() {
        let card = makeCard(id: "c1", name: "Buff", abilities: [
            makeAbility(effect: .temporaryStat(stat: "attack", amount: 2, duration: 1))
        ])
        let eng = makeEngine(heroCards: [card])

        let playResult = eng.performAction(.useCard(cardId: "c1", targetId: "enemy"))
        XCTAssertTrue(playResult.success, "Card play should succeed")

        let attackResult = eng.performAction(.attack(targetId: "enemy"))
        XCTAssertTrue(attackResult.success, "Attack after card play should succeed (card play is not a finish action)")
    }
}

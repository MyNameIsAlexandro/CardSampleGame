import Testing
import SpriteKit
import TwilightEngine
@testable import EchoScenes

@Suite("CardNode Tests")
struct CardNodeTests {

    private func makeCard() -> Card {
        Card(
            id: "test_strike",
            name: "Strike",
            type: .spell,
            description: "Deal damage",
            abilities: [
                CardAbility(id: "a1", name: "Strike", description: "Damage",
                           effect: .damage(amount: 3, type: .physical))
            ]
        )
    }

    @Test("CardNode has expected children")
    func testStructure() {
        let node = CardNode(card: makeCard())
        // background + name + power + type + cost = 5
        #expect(node.children.count == 5)
    }

    @Test("CardNode shows cost label")
    func testCostLabel() {
        let card = Card(
            id: "costly",
            name: "Fireball",
            type: .spell,
            description: "Boom",
            cost: 2
        )
        let node = CardNode(card: card)
        let labels = node.children.compactMap { $0 as? SKLabelNode }
        let costLabel = labels.first { $0.text == "2" && $0.fontColor == CombatSceneTheme.faith }
        #expect(costLabel != nil)
    }

    @Test("CardNode stores card reference")
    func testCardReference() {
        let card = makeCard()
        let node = CardNode(card: card)
        #expect(node.card.id == card.id)
    }

    @Test("CardNode name includes card id")
    func testNodeName() {
        let node = CardNode(card: makeCard())
        #expect(node.name == "card_test_strike")
    }

    @Test("Selection changes stroke color")
    func testSelection() {
        let node = CardNode(card: makeCard())
        let bg = node.children.first as! SKShapeNode

        node.setSelected(true)
        #expect(bg.strokeColor == CombatSceneTheme.highlight)

        node.setSelected(false)
        #expect(bg.strokeColor == CombatSceneTheme.muted)
    }

    @Test("Exhaust card shows keyword label")
    func testExhaustKeyword() {
        let card = Card(
            id: "ex", name: "Sacrifice", type: .spell,
            description: "Once",
            abilities: [CardAbility(id: "a1", name: "Hit", description: "Hit",
                                   effect: .damage(amount: 1, type: .physical))],
            exhaust: true
        )
        let node = CardNode(card: card)
        // background + name + power + type + cost + keyword = 6
        #expect(node.children.count == 6)
        let labels = node.children.compactMap { $0 as? SKLabelNode }
        #expect(labels.contains(where: { $0.text == "Exhaust" }))
    }
}

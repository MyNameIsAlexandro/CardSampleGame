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
        // background + name + power + type = 4
        #expect(node.children.count == 4)
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
}

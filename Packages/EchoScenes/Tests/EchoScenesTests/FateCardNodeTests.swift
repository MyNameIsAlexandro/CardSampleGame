import Testing
import SpriteKit
@testable import EchoScenes

@Suite("FateCardNode Tests")
struct FateCardNodeTests {

    @Test("FateCardNode has back and face children")
    func testStructure() {
        let node = FateCardNode()
        #expect(node.children.count == 2)
    }

    @Test("Color is green for positive value")
    func testPositiveColor() {
        let color = FateCardNode.color(for: 2, isCritical: false)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(g > r)
        #expect(g > b)
    }

    @Test("Color is red for negative value")
    func testNegativeColor() {
        let color = FateCardNode.color(for: -1, isCritical: false)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(r > g)
        #expect(r > b)
    }

    @Test("Color is gold for critical")
    func testCriticalColor() {
        let color = FateCardNode.color(for: 1, isCritical: true)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        // Theme highlight: warm gold (0.90, 0.75, 0.30)
        #expect(r > 0.8)
        #expect(g > 0.6)
        #expect(b < 0.4)
    }

    @Test("Reveal configures face node color and label")
    func testRevealConfiguresFace() {
        let node = FateCardNode()
        // Call reveal — we can't easily wait for SKAction, but we verify it doesn't crash
        // and the face node gets configured
        node.reveal(value: 2, isCritical: false) {}

        // The face node (second child) should have fill color set
        let faceNode = node.children[1] as! SKShapeNode
        #expect(faceNode.fillColor == FateCardNode.color(for: 2, isCritical: false))

        // Label inside face node
        let label = faceNode.children.first as! SKLabelNode
        #expect(label.text == "+2")
    }

    @Test("Reveal shows CRIT for critical cards")
    func testRevealCritical() {
        let node = FateCardNode()
        node.reveal(value: 1, isCritical: true) {}

        let faceNode = node.children[1] as! SKShapeNode
        let label = faceNode.children.first as! SKLabelNode
        #expect(label.text == "CRIT")
    }
}

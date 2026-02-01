import SpriteKit

/// Visual representation of a Fate card draw in SpriteKit combat.
/// Shows a card back, flips to reveal the modifier value.
public final class FateCardNode: SKNode {

    // MARK: - Constants

    public static let cardSize = CGSize(width: 60, height: 84)

    // MARK: - Child Nodes

    private let backNode: SKShapeNode
    private let faceNode: SKShapeNode
    private let valueLabel: SKLabelNode

    // MARK: - Init

    public override init() {
        let size = Self.cardSize
        let corner: CGFloat = 8

        // Card back (dark with "?" symbol)
        backNode = SKShapeNode(rectOf: size, cornerRadius: corner)
        backNode.fillColor = SKColor(white: 0.15, alpha: 1)
        backNode.strokeColor = SKColor(white: 0.4, alpha: 1)
        backNode.lineWidth = 2

        let questionMark = SKLabelNode(fontNamed: "AvenirNext-Bold")
        questionMark.text = "?"
        questionMark.fontSize = 28
        questionMark.fontColor = SKColor(white: 0.5, alpha: 1)
        questionMark.verticalAlignmentMode = .center
        questionMark.horizontalAlignmentMode = .center
        backNode.addChild(questionMark)

        // Card face (colored by value, hidden initially)
        faceNode = SKShapeNode(rectOf: size, cornerRadius: corner)
        faceNode.strokeColor = SKColor(white: 0.6, alpha: 1)
        faceNode.lineWidth = 2
        faceNode.xScale = 0 // hidden via scale

        valueLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        valueLabel.fontSize = 24
        valueLabel.fontColor = .white
        valueLabel.verticalAlignmentMode = .center
        valueLabel.horizontalAlignmentMode = .center
        faceNode.addChild(valueLabel)

        super.init()

        addChild(backNode)
        addChild(faceNode)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("Not implemented")
    }

    // MARK: - Configuration

    /// Returns the fill color for a given fate value.
    public static func color(for value: Int, isCritical: Bool) -> SKColor {
        if isCritical { return SKColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1) } // gold
        if value > 0 { return SKColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1) }   // green
        if value < 0 { return SKColor(red: 0.9, green: 0.25, blue: 0.2, alpha: 1) }   // red
        return SKColor(red: 0.85, green: 0.75, blue: 0.3, alpha: 1)                    // yellow (neutral)
    }

    /// Flip-reveal the card with the fate value.
    public func reveal(value: Int, isCritical: Bool, completion: @escaping () -> Void) {
        let color = Self.color(for: value, isCritical: isCritical)
        faceNode.fillColor = color

        if isCritical {
            valueLabel.text = "CRIT"
        } else {
            valueLabel.text = value > 0 ? "+\(value)" : "\(value)"
        }

        let flipDuration: TimeInterval = 0.15

        // Collapse back → expand face
        let collapseBack = SKAction.scaleX(to: 0, duration: flipDuration)
        collapseBack.timingMode = .easeIn

        let expandFace = SKAction.scaleX(to: 1.0, duration: flipDuration)
        expandFace.timingMode = .easeOut

        backNode.run(collapseBack)
        faceNode.run(SKAction.sequence([
            SKAction.wait(forDuration: flipDuration),
            expandFace
        ])) {
            completion()
        }
    }
}

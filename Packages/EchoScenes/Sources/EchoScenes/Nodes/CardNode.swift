import SpriteKit
import TwilightEngine

/// SpriteKit node representing a playable card in the player's hand.
public final class CardNode: SKNode {

    public static let cardSize = CGSize(width: 55, height: 80)

    public let card: Card

    private let background: SKShapeNode
    private let nameLabel: SKLabelNode
    private let powerLabel: SKLabelNode
    private let typeLabel: SKLabelNode
    private let costLabel: SKLabelNode
    private let keywordLabel: SKLabelNode?

    public init(card: Card) {
        self.card = card
        let size = Self.cardSize
        let corner: CGFloat = 6

        background = SKShapeNode(rectOf: size, cornerRadius: corner)
        background.fillColor = CombatSceneTheme.cardBack
        background.strokeColor = CombatSceneTheme.muted
        background.lineWidth = 1.5

        // Card name (top)
        nameLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        nameLabel.text = String(card.name.prefix(8))
        nameLabel.fontSize = 9
        nameLabel.fontColor = .white
        nameLabel.position = CGPoint(x: 0, y: size.height / 2 - 14)
        nameLabel.verticalAlignmentMode = .center

        // Power value (center)
        powerLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        let displayValue = Self.displayValue(for: card)
        powerLabel.text = displayValue
        powerLabel.fontSize = 20
        powerLabel.fontColor = Self.valueColor(for: card)
        powerLabel.position = CGPoint(x: 0, y: 0)
        powerLabel.verticalAlignmentMode = .center

        // Type indicator (bottom)
        typeLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        typeLabel.text = Self.typeIcon(for: card)
        typeLabel.fontSize = 10
        typeLabel.fontColor = CombatSceneTheme.muted
        typeLabel.position = CGPoint(x: 0, y: -size.height / 2 + 12)
        typeLabel.verticalAlignmentMode = .center

        // Cost badge (top-left)
        costLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        costLabel.text = "\(card.cost ?? 1)"
        costLabel.fontSize = 9
        costLabel.fontColor = CombatSceneTheme.faith
        costLabel.position = CGPoint(x: -size.width / 2 + 10, y: size.height / 2 - 14)
        costLabel.verticalAlignmentMode = .center

        // Keywords (bottom, above type)
        var keywords: [String] = []
        if card.exhaust { keywords.append("Exhaust") }
        keywords.append(contentsOf: card.traits.prefix(2))

        if !keywords.isEmpty {
            let lbl = SKLabelNode(fontNamed: "AvenirNext-Medium")
            lbl.text = keywords.joined(separator: " · ")
            lbl.fontSize = 7
            lbl.fontColor = CombatSceneTheme.spirit
            lbl.position = CGPoint(x: 0, y: -size.height / 2 + 22)
            lbl.verticalAlignmentMode = .center
            keywordLabel = lbl
        } else {
            keywordLabel = nil
        }

        super.init()
        name = "card_\(card.id)"

        addChild(background)
        addChild(nameLabel)
        addChild(powerLabel)
        addChild(typeLabel)
        addChild(costLabel)
        if let kw = keywordLabel { addChild(kw) }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("Not implemented")
    }

    // MARK: - Selection

    public func setSelected(_ selected: Bool) {
        background.strokeColor = selected ? CombatSceneTheme.highlight : CombatSceneTheme.muted
        background.lineWidth = selected ? 2.5 : 1.5
    }

    // MARK: - Helpers

    private static func displayValue(for card: Card) -> String {
        if let ability = card.abilities.first {
            switch ability.effect {
            case .damage(let amount, _): return "\(amount)"
            case .heal(let amount): return "+\(amount)"
            case .drawCards(let count): return "+\(count)"
            default: break
            }
        }
        if let power = card.power, power > 0 { return "\(power)" }
        return "•"
    }

    private static func valueColor(for card: Card) -> SKColor {
        if let ability = card.abilities.first {
            switch ability.effect {
            case .damage: return CombatSceneTheme.health
            case .heal: return CombatSceneTheme.success
            case .drawCards: return CombatSceneTheme.spirit
            default: break
            }
        }
        return .white
    }

    private static func typeIcon(for card: Card) -> String {
        if let ability = card.abilities.first {
            switch ability.effect {
            case .damage: return "⚔"
            case .heal: return "♥"
            case .drawCards: return "♦"
            default: break
            }
        }
        return "✦"
    }
}

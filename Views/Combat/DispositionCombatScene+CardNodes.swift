/// Файл: Views/Combat/DispositionCombatScene+CardNodes.swift
/// Назначение: Card node creation and visual styling for the player's hand.
/// Зона ответственности: makeCardNode, gradient textures, card accent colors, type icons, idle sway.
/// Контекст: Phase 3 Disposition Combat. Extension of DispositionCombatScene.

import SpriteKit
import TwilightEngine

// MARK: - Card Node Building

extension DispositionCombatScene {

    func makeCardNode(card: Card) -> SKNode {
        let cardSize = RitualTheme.cardSize
        let container = SKNode()
        let accent = cardAccentColor(for: card.type)

        // Shadow beneath card
        let shadow = SKShapeNode(rectOf: CGSize(width: cardSize.width - 4, height: cardSize.height - 4), cornerRadius: 10)
        shadow.fillColor = SKColor(white: 0, alpha: 0.35)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 2, y: -3)
        shadow.zPosition = -1
        container.addChild(shadow)

        // Gradient background with rounded corners
        let bgSprite = SKSpriteNode(
            texture: makeGradientTexture(
                size: cardSize,
                topColor: accent.withAlphaComponent(0.25),
                bottomColor: SKColor(red: 0.08, green: 0.06, blue: 0.12, alpha: 1),
                cornerRadius: 10
            ),
            size: cardSize
        )
        bgSprite.name = "cardBg"
        container.addChild(bgSprite)

        // Glowing border
        let border = SKShapeNode(rectOf: cardSize, cornerRadius: 10)
        border.fillColor = .clear
        border.strokeColor = accent.withAlphaComponent(0.5)
        border.lineWidth = 1.5
        border.glowWidth = 1
        border.name = "cardBorder"
        container.addChild(border)

        // Cost badge (top-left circle)
        let cost = card.cost ?? 0
        if cost > 0 {
            let badgePos = CGPoint(x: -cardSize.width / 2 + 15, y: cardSize.height / 2 - 15)

            let costBg = SKShapeNode(circleOfRadius: 11)
            costBg.fillColor = SKColor(red: 0.10, green: 0.08, blue: 0.20, alpha: 0.9)
            costBg.strokeColor = SKColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 0.5)
            costBg.lineWidth = 1
            costBg.position = badgePos
            costBg.zPosition = 2
            container.addChild(costBg)

            let costLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
            costLabel.text = "\(cost)"
            costLabel.fontSize = 11
            costLabel.fontColor = SKColor(red: 0.5, green: 0.75, blue: 1.0, alpha: 1)
            costLabel.verticalAlignmentMode = .center
            costLabel.horizontalAlignmentMode = .center
            costLabel.position = badgePos
            costLabel.zPosition = 3
            container.addChild(costLabel)
        }

        // Type icon (top-right)
        let typeIcon = SKLabelNode(fontNamed: "AvenirNext-Bold")
        typeIcon.text = cardTypeIcon(for: card.type)
        typeIcon.fontSize = 14
        typeIcon.verticalAlignmentMode = .center
        typeIcon.horizontalAlignmentMode = .center
        typeIcon.position = CGPoint(x: cardSize.width / 2 - 15, y: cardSize.height / 2 - 15)
        typeIcon.zPosition = 2
        container.addChild(typeIcon)

        // Large center icon
        let centerIcon = SKLabelNode(fontNamed: "AvenirNext-Bold")
        centerIcon.text = cardTypeIcon(for: card.type)
        centerIcon.fontSize = 30
        centerIcon.alpha = 0.25
        centerIcon.verticalAlignmentMode = .center
        centerIcon.horizontalAlignmentMode = .center
        centerIcon.position = CGPoint(x: 0, y: 18)
        centerIcon.zPosition = 1
        container.addChild(centerIcon)

        // Divider
        let dividerY: CGFloat = -8
        let divider = SKShapeNode(rectOf: CGSize(width: cardSize.width - 16, height: 0.5))
        divider.fillColor = accent.withAlphaComponent(0.25)
        divider.strokeColor = .clear
        divider.position = CGPoint(x: 0, y: dividerY)
        divider.zPosition = 2
        container.addChild(divider)

        // Card name
        let nameLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        nameLabel.text = card.name
        nameLabel.fontSize = 11
        nameLabel.fontColor = .white
        nameLabel.numberOfLines = 2
        nameLabel.preferredMaxLayoutWidth = cardSize.width - 14
        nameLabel.verticalAlignmentMode = .top
        nameLabel.horizontalAlignmentMode = .center
        nameLabel.position = CGPoint(x: 0, y: dividerY - 4)
        nameLabel.zPosition = 2
        container.addChild(nameLabel)

        // Short effect text
        if !card.description.isEmpty {
            let desc = card.description.count > 30
                ? String(card.description.prefix(27)) + "..."
                : card.description
            let effectLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
            effectLabel.text = desc
            effectLabel.fontSize = 8
            effectLabel.fontColor = SKColor(white: 0.6, alpha: 1)
            effectLabel.numberOfLines = 2
            effectLabel.preferredMaxLayoutWidth = cardSize.width - 14
            effectLabel.verticalAlignmentMode = .bottom
            effectLabel.horizontalAlignmentMode = .center
            effectLabel.position = CGPoint(x: 0, y: -cardSize.height / 2 + 6)
            effectLabel.zPosition = 2
            container.addChild(effectLabel)
        }

        return container
    }

    // MARK: - Idle Sway

    func addCardSway(to node: SKNode, index: Int) {
        let amp = RitualTheme.swayAmplitude
        let dur = RitualTheme.swayCycleDuration
        let stagger = RitualTheme.swayStagger * Double(index)

        let sway = SKAction.sequence([
            SKAction.wait(forDuration: stagger),
            SKAction.repeatForever(SKAction.sequence([
                SKAction.rotate(byAngle: amp, duration: dur / 2),
                SKAction.rotate(byAngle: -amp * 2, duration: dur),
                SKAction.rotate(byAngle: amp, duration: dur / 2)
            ]))
        ])
        node.run(sway, withKey: "cardSway")
    }

    // MARK: - Card Accent Colors

    func cardAccentColor(for type: CardType) -> SKColor {
        switch type {
        case .attack, .weapon:
            return SKColor(red: 0.85, green: 0.25, blue: 0.20, alpha: 1)
        case .defense, .armor:
            return SKColor(red: 0.25, green: 0.50, blue: 0.85, alpha: 1)
        case .blessing:
            return SKColor(red: 0.25, green: 0.75, blue: 0.40, alpha: 1)
        case .spell, .ritual:
            return SKColor(red: 0.60, green: 0.30, blue: 0.80, alpha: 1)
        case .item, .artifact:
            return SKColor(red: 0.80, green: 0.65, blue: 0.20, alpha: 1)
        case .character, .ally:
            return SKColor(red: 0.30, green: 0.70, blue: 0.70, alpha: 1)
        default:
            return SKColor(red: 0.45, green: 0.35, blue: 0.60, alpha: 1)
        }
    }

    // MARK: - Card Type Icons

    func cardTypeIcon(for type: CardType) -> String {
        switch type {
        case .attack, .weapon: return "⚔"
        case .defense, .armor: return "🛡"
        case .blessing:        return "✦"
        case .spell, .ritual:  return "✧"
        case .item, .artifact: return "◆"
        case .character, .ally: return "♚"
        default:               return "✦"
        }
    }

    // MARK: - Gradient Texture

    func makeGradientTexture(
        size: CGSize,
        topColor: SKColor,
        bottomColor: SKColor,
        cornerRadius: CGFloat
    ) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).addClip()

            let colors = [topColor.cgColor, bottomColor.cgColor] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(
                colorsSpace: colorSpace, colors: colors, locations: [0, 1]
            ) else { return }
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: size.width / 2, y: 0),
                end: CGPoint(x: size.width / 2, y: size.height),
                options: []
            )
        }
        return SKTexture(image: image)
    }
}

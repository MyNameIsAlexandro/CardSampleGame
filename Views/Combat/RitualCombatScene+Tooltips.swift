/// Файл: Views/Combat/RitualCombatScene+Tooltips.swift
/// Назначение: Тултип карты по long-press — показ полных характеристик.
/// Зона ответственности: Tooltip creation & dismissal. Keeps GameLoop under 600 lines.
/// Контекст: Phase 3 Ritual Combat (R9). Epic 7 — Long-Press Tooltip.

import SpriteKit
import TwilightEngine

// MARK: - Card Tooltip

extension RitualCombatScene {

    /// Show a tooltip for the given card above the hand area.
    func showCardTooltip(cardId: String) {
        dismissCardTooltip()
        guard let sim = simulation,
              let card = sim.hand.first(where: { $0.id == cardId }) else { return }

        let tooltip = SKNode()
        tooltip.name = "cardTooltip"
        tooltip.zPosition = 70

        let width: CGFloat = 200
        let height: CGFloat = 100
        let bg = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 10)
        bg.fillColor = SKColor(red: 0.10, green: 0.08, blue: 0.14, alpha: 0.95)
        bg.strokeColor = SKColor(red: 0.50, green: 0.40, blue: 0.60, alpha: 1)
        bg.lineWidth = 1.5
        tooltip.addChild(bg)

        let nameLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        nameLabel.text = card.name
        nameLabel.fontSize = 13
        nameLabel.fontColor = .white
        nameLabel.horizontalAlignmentMode = .center
        nameLabel.verticalAlignmentMode = .center
        nameLabel.position = CGPoint(x: 0, y: 30)
        tooltip.addChild(nameLabel)

        var statsText = "\(cardTypeIcon(card.type))"
        if let power = card.power, power > 0 { statsText += "  Сила: \(power)" }
        if let cost = card.cost, cost > 0 { statsText += "  Цена: \(cost)" }

        let statsLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        statsLabel.text = statsText
        statsLabel.fontSize = 11
        statsLabel.fontColor = SKColor(red: 0.80, green: 0.70, blue: 0.50, alpha: 1)
        statsLabel.horizontalAlignmentMode = .center
        statsLabel.verticalAlignmentMode = .center
        statsLabel.position = CGPoint(x: 0, y: 8)
        tooltip.addChild(statsLabel)

        let descLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        descLabel.text = String(card.description.prefix(40))
        descLabel.fontSize = 10
        descLabel.fontColor = SKColor(white: 0.65, alpha: 1)
        descLabel.horizontalAlignmentMode = .center
        descLabel.verticalAlignmentMode = .center
        descLabel.position = CGPoint(x: 0, y: -14)
        tooltip.addChild(descLabel)

        let centerX = RitualCombatScene.sceneSize.width / 2
        tooltip.position = CGPoint(x: centerX, y: 200)
        tooltip.alpha = 0

        let layer = overlayLayer ?? self
        layer.addChild(tooltip)
        tooltip.run(SKAction.fadeIn(withDuration: 0.15))

        onHaptic?("light")
    }

    /// Dismiss any visible card tooltip.
    func dismissCardTooltip() {
        let layer = overlayLayer ?? self
        if let existing = layer.childNode(withName: "cardTooltip") {
            existing.run(SKAction.fadeOut(withDuration: 0.1)) {
                existing.removeFromParent()
            }
        }
    }
}

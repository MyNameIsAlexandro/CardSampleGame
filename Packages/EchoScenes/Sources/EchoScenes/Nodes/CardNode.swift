/// Файл: Packages/EchoScenes/Sources/EchoScenes/Nodes/CardNode.swift
/// Назначение: Содержит реализацию файла CardNode.swift.
/// Зона ответственности: Реализует визуально-сценовый слой EchoScenes.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import SpriteKit
import TwilightEngine
import Foundation

private func L(_ key: String) -> String {
    NSLocalizedString(key, bundle: .main, comment: "")
}
private func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, bundle: .main, comment: ""), arguments: args)
}

/// SpriteKit node representing a playable card in the player's hand.
///
/// Layout (100x140):
/// ┌────────────────────────┐
/// │ (1)  Концентрация      │  cost badge left, name right of it
/// │ ┌────────────────────┐ │
/// │ │      ✦  (icon)     │ │  illustration (46pt)
/// │ └────────────────────┘ │
/// │        +2 ♥            │  value (22pt)
/// │                        │
/// │  Сосредоточься.        │  description (9pt, ≤3 lines)
/// │  Возьми 1 карту.       │
/// │    · Истощение         │  keywords (8pt)
/// └────────────────────────┘
///
/// Name limit for content editors: up to 14 characters.
public final class CardNode: SKNode {

    public static let cardSize = CGSize(width: 100, height: 140)

    public let card: Card

    private let background: SKShapeNode

    public init(card: Card) {
        self.card = card
        let w = Self.cardSize.width
        let halfW = w / 2
        let halfH = Self.cardSize.height / 2

        background = SKShapeNode(rectOf: Self.cardSize, cornerRadius: 10)
        background.fillColor = CombatSceneTheme.cardBack
        background.strokeColor = CombatSceneTheme.muted
        background.lineWidth = 1.5

        super.init()
        name = "card_\(card.id)"
        addChild(background)

        // --- Cost badge (top-left) ---
        let badgeR: CGFloat = 11
        let badge = SKShapeNode(circleOfRadius: badgeR)
        badge.fillColor = CombatSceneTheme.faith.withAlphaComponent(0.35)
        badge.strokeColor = CombatSceneTheme.faith
        badge.lineWidth = 1.5
        badge.position = CGPoint(x: -halfW + badgeR + 3, y: halfH - badgeR - 3)
        badge.zPosition = 3
        addChild(badge)

        let costLbl = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        costLbl.text = "\(card.cost ?? 1)"
        costLbl.fontSize = 12
        costLbl.fontColor = CombatSceneTheme.faith
        costLbl.verticalAlignmentMode = .center
        costLbl.horizontalAlignmentMode = .center
        badge.addChild(costLbl)

        // --- Name (top, right of badge, up to 2 lines) ---
        let nameLeftEdge = -halfW + badgeR * 2 + 7
        let nameMaxW = halfW - nameLeftEdge - 4  // right margin 4pt from card edge
        let nameLbl = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        nameLbl.text = card.name
        nameLbl.fontSize = 9
        nameLbl.fontColor = .white
        nameLbl.position = CGPoint(x: nameLeftEdge + nameMaxW / 2, y: halfH - badgeR - 3)
        nameLbl.verticalAlignmentMode = .center
        nameLbl.horizontalAlignmentMode = .center
        nameLbl.numberOfLines = 2
        nameLbl.preferredMaxLayoutWidth = nameMaxW
        addChild(nameLbl)

        // --- Illustration area ---
        let illusColor = Self.illustrationColor(for: card)
        let illusH: CGFloat = 46
        let illusY: CGFloat = halfH - 42
        let illusBox = SKShapeNode(rectOf: CGSize(width: w - 10, height: illusH), cornerRadius: 5)
        illusBox.fillColor = illusColor.withAlphaComponent(0.2)
        illusBox.strokeColor = illusColor.withAlphaComponent(0.4)
        illusBox.lineWidth = 1
        illusBox.position = CGPoint(x: 0, y: illusY)
        addChild(illusBox)

        let iconLbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
        iconLbl.text = Self.typeIcon(for: card)
        iconLbl.fontSize = 26
        iconLbl.fontColor = illusColor
        iconLbl.verticalAlignmentMode = .center
        iconLbl.horizontalAlignmentMode = .center
        illusBox.addChild(iconLbl)

        // --- Value (below illustration) ---
        let valueText = Self.displayValue(for: card)
        if !valueText.isEmpty {
            let valueLbl = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            valueLbl.text = valueText
            valueLbl.fontSize = 22
            valueLbl.fontColor = Self.valueColor(for: card)
            valueLbl.position = CGPoint(x: 0, y: illusY - illusH / 2 - 16)
            valueLbl.verticalAlignmentMode = .center
            addChild(valueLbl)
        }

        // --- Description (up to 3 lines) ---
        let descText = card.description
        if !descText.isEmpty {
            let descLbl = SKLabelNode(fontNamed: "AvenirNext-Regular")
            descLbl.text = descText
            descLbl.fontSize = 9
            descLbl.fontColor = CombatSceneTheme.muted
            descLbl.position = CGPoint(x: 0, y: -halfH + 28)
            descLbl.verticalAlignmentMode = .center
            descLbl.horizontalAlignmentMode = .center
            descLbl.numberOfLines = 3
            descLbl.preferredMaxLayoutWidth = w - 10
            addChild(descLbl)
        }

        // --- Keywords / traits (bottom) ---
        var keywords: [String] = []
        if card.exhaust { keywords.append(L("combat.keyword.exhaust")) }
        keywords.append(contentsOf: card.traits.prefix(2))
        if !keywords.isEmpty {
            let kwLbl = SKLabelNode(fontNamed: "AvenirNext-Medium")
            kwLbl.text = keywords.joined(separator: " · ")
            kwLbl.fontSize = 8
            kwLbl.fontColor = CombatSceneTheme.spirit
            kwLbl.position = CGPoint(x: 0, y: -halfH + 10)
            kwLbl.verticalAlignmentMode = .center
            addChild(kwLbl)
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("Not implemented")
    }

    // MARK: - Selection

    public private(set) var isCardSelected = false

    public func setSelected(_ selected: Bool) {
        isCardSelected = selected
        background.strokeColor = selected ? CombatSceneTheme.highlight : CombatSceneTheme.muted
        background.lineWidth = selected ? 2.5 : 1.5
    }

    public func setSelectedAnimated(_ selected: Bool) {
        let wasSelected = isCardSelected
        setSelected(selected)
        guard wasSelected != selected else { return }
        let dy: CGFloat = selected ? 14 : -14
        run(SKAction.moveBy(x: 0, y: dy, duration: 0.15))
    }

    public func setDimmed(_ dimmed: Bool) {
        alpha = dimmed ? 0.4 : 1.0
    }

    // MARK: - Helpers

    private static func displayValue(for card: Card) -> String {
        if let ability = card.abilities.first {
            switch ability.effect {
            case .damage(let amount, _): return "\(amount) ⚔"
            case .heal(let amount): return "+\(amount) ♥"
            case .drawCards(let count): return "+\(count) ♦"
            default: break
            }
        }
        if let power = card.power, power > 0 { return "\(power)" }
        return ""
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

    private static func illustrationColor(for card: Card) -> SKColor {
        if let ability = card.abilities.first {
            switch ability.effect {
            case .damage: return CombatSceneTheme.health
            case .heal: return CombatSceneTheme.success
            case .drawCards: return CombatSceneTheme.spirit
            default: break
            }
        }
        return CombatSceneTheme.primary
    }
}

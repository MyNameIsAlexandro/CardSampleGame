/// Файл: Packages/EchoScenes/Sources/EchoScenes/Nodes/FateCardNode.swift
/// Назначение: Содержит реализацию файла FateCardNode.swift.
/// Зона ответственности: Реализует визуально-сценовый слой EchoScenes.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import SpriteKit
import Foundation

private func L(_ key: String) -> String {
    NSLocalizedString(key, bundle: .main, comment: "")
}

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
        backNode.fillColor = CombatSceneTheme.cardBack
        backNode.strokeColor = CombatSceneTheme.muted
        backNode.lineWidth = 2

        let questionMark = SKLabelNode(fontNamed: "AvenirNext-Bold")
        questionMark.text = "?"
        questionMark.fontSize = 28
        questionMark.fontColor = CombatSceneTheme.muted
        questionMark.verticalAlignmentMode = .center
        questionMark.horizontalAlignmentMode = .center
        backNode.addChild(questionMark)

        // Card face (colored by value, hidden initially)
        faceNode = SKShapeNode(rectOf: size, cornerRadius: corner)
        faceNode.strokeColor = CombatSceneTheme.muted
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
        if isCritical { return CombatSceneTheme.highlight }
        if value > 0 { return CombatSceneTheme.success }
        if value < 0 { return CombatSceneTheme.health }
        return CombatSceneTheme.faith
    }

    /// Flip-reveal the card with the fate value.
    public func reveal(value: Int, isCritical: Bool, completion: @escaping () -> Void) {
        let color = Self.color(for: value, isCritical: isCritical)
        faceNode.fillColor = color

        if isCritical {
            valueLabel.text = L("combat.fate.crit")
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

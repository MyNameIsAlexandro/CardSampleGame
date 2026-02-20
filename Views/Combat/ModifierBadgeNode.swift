/// Файл: Views/Combat/ModifierBadgeNode.swift
/// Назначение: Small badge showing an active combat modifier with icon, value, and animations.
/// Зона ответственности: Visual representation of temporary combat effects in DispositionCombat.
/// Контекст: Phase 3 Disposition Combat HUD improvement.

import SpriteKit

/// Displays a single combat modifier badge (e.g., defend reduction, provoke penalty).
final class ModifierBadgeNode: SKNode {

    // MARK: - Types

    enum ModifierType: String {
        case defend
        case adapt
        case sacrificeBuff
        case provoke
        case plea
    }

    // MARK: - Child Nodes

    private let background: SKShapeNode
    private let iconLabel: SKLabelNode
    private let valueLabel: SKLabelNode

    // MARK: - State

    let modifierType: ModifierType
    private(set) var currentValue: Int

    // MARK: - Factory

    static func make(type: ModifierType, value: Int) -> ModifierBadgeNode {
        return ModifierBadgeNode(type: type, value: value)
    }

    // MARK: - Init

    private init(type: ModifierType, value: Int) {
        self.modifierType = type
        self.currentValue = value

        let config = ModifierBadgeNode.config(for: type)

        background = SKShapeNode(rect: CGRect(x: -25, y: -10, width: 50, height: 20), cornerRadius: 5)
        background.fillColor = config.color.withAlphaComponent(0.15)
        background.strokeColor = config.color.withAlphaComponent(0.6)
        background.lineWidth = 1

        iconLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        iconLabel.text = config.icon
        iconLabel.fontSize = 10
        iconLabel.verticalAlignmentMode = .center
        iconLabel.horizontalAlignmentMode = .center
        iconLabel.position = CGPoint(x: -14, y: 0)

        valueLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        valueLabel.text = "\(value)"
        valueLabel.fontSize = 11
        valueLabel.fontColor = config.color
        valueLabel.verticalAlignmentMode = .center
        valueLabel.horizontalAlignmentMode = .center
        valueLabel.position = CGPoint(x: 8, y: 0)

        super.init()

        self.name = type.rawValue
        addChild(background)
        addChild(iconLabel)
        addChild(valueLabel)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Update

    func updateValue(_ newValue: Int) {
        guard newValue != currentValue else { return }
        currentValue = newValue
        valueLabel.text = "\(newValue)"

        let pop = SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.08),
            SKAction.scale(to: 1.0, duration: 0.08)
        ])
        run(pop)

        let originalColor = valueLabel.fontColor
        valueLabel.fontColor = .white
        valueLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.1),
            SKAction.run { [weak self] in self?.valueLabel.fontColor = originalColor }
        ]))
    }

    // MARK: - Animations

    func animateAppear() {
        setScale(0)
        alpha = 1
        let scaleIn = SKAction.scale(to: 1.0, duration: 0.2)
        scaleIn.timingMode = .easeOut
        run(scaleIn)

        background.glowWidth = 4
        background.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.2),
            SKAction.run { [weak self] in self?.background.glowWidth = 0 }
        ]))
    }

    func animateDisappear(completion: @escaping () -> Void) {
        let scaleOut = SKAction.scale(to: 0, duration: 0.15)
        scaleOut.timingMode = .easeIn
        let fade = SKAction.fadeOut(withDuration: 0.15)
        run(SKAction.group([scaleOut, fade])) {
            completion()
        }
    }

    // MARK: - Configuration

    private struct BadgeConfig {
        let icon: String
        let color: SKColor
    }

    private static func config(for type: ModifierType) -> BadgeConfig {
        switch type {
        case .defend:
            return BadgeConfig(icon: "🛡", color: SKColor(red: 0.3, green: 0.7, blue: 0.9, alpha: 1))
        case .adapt:
            return BadgeConfig(icon: "↻", color: SKColor(red: 0.9, green: 0.8, blue: 0.3, alpha: 1))
        case .sacrificeBuff:
            return BadgeConfig(icon: "🔥", color: SKColor(red: 0.9, green: 0.4, blue: 0.2, alpha: 1))
        case .provoke:
            return BadgeConfig(icon: "⚡", color: SKColor(red: 0.9, green: 0.5, blue: 0.2, alpha: 1))
        case .plea:
            return BadgeConfig(icon: "💔", color: SKColor(red: 0.7, green: 0.3, blue: 0.6, alpha: 1))
        }
    }
}

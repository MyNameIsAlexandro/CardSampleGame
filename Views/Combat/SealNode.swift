/// Файл: Views/Combat/SealNode.swift
/// Назначение: Визуальный узел печати ритуального действия (⚔/💬/⏳).
/// Зона ответственности: Presentation-only — отображение, пульсация, glow. Без доменной логики.
/// Контекст: Phase 3 Ritual Combat (R5). Reference: RITUAL_COMBAT_TEST_MODEL.md §3.3

import SpriteKit

// MARK: - Seal Type

/// The three ritual seal variants corresponding to combat actions.
enum SealType: String, CaseIterable {
    case strike
    case speak
    case wait

    var icon: String {
        switch self {
        case .strike: return "⚔"
        case .speak:  return "💬"
        case .wait:   return "⏳"
        }
    }
}

// MARK: - Seal Node

/// A diegetic ritual seal representing a combat action choice.
/// Pure visual node — receives state via method calls, no stored simulation reference.
///
/// Usage:
///   1. Init with `SealType`
///   2. `setActive(_:)` to show/hide
///   3. `updateGlow(color:)` to sync with resonance color
final class SealNode: SKNode {

    // MARK: - Constants

    static let size = CGSize(width: 60, height: 80)

    // MARK: - Properties

    let sealType: SealType
    private(set) var isActive: Bool = false

    // MARK: - Child Nodes

    private let stoneNode: SKShapeNode
    private let iconLabel: SKLabelNode
    private let glowNode: SKShapeNode

    // MARK: - Init

    init(type: SealType) {
        self.sealType = type

        let stone = SKShapeNode(rectOf: SealNode.size, cornerRadius: 10)
        stone.fillColor = SKColor(red: 0.15, green: 0.12, blue: 0.18, alpha: 1)
        stone.strokeColor = SKColor(red: 0.40, green: 0.35, blue: 0.45, alpha: 1)
        stone.lineWidth = 1.5
        self.stoneNode = stone

        let icon = SKLabelNode(fontNamed: "AvenirNext-Bold")
        icon.text = type.icon
        icon.fontSize = 26
        icon.verticalAlignmentMode = .center
        icon.horizontalAlignmentMode = .center
        self.iconLabel = icon

        let glow = SKShapeNode(rectOf: CGSize(width: SealNode.size.width + 6,
                                               height: SealNode.size.height + 6),
                                cornerRadius: 12)
        glow.fillColor = .clear
        glow.strokeColor = SKColor(red: 0.50, green: 0.40, blue: 0.55, alpha: 1)
        glow.lineWidth = 2
        glow.alpha = 0
        self.glowNode = glow

        super.init()

        addChild(glowNode)
        addChild(stoneNode)
        addChild(iconLabel)

        alpha = 0.15
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Active State

    /// Show or hide the seal with animation.
    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active

        removeAllActions()
        glowNode.removeAllActions()

        if active {
            run(SKAction.fadeAlpha(to: 1.0, duration: 0.25))
            glowNode.run(SKAction.fadeAlpha(to: 0.6, duration: 0.25))
            startPulse()
        } else {
            run(SKAction.fadeAlpha(to: 0.15, duration: 0.25))
            glowNode.run(SKAction.fadeAlpha(to: 0.0, duration: 0.25))
        }
    }

    // MARK: - Glow

    /// Update the glow border color to match current resonance.
    func updateGlow(color: SKColor) {
        glowNode.strokeColor = color
    }

    // MARK: - Pulse Animation

    private func startPulse() {
        let scaleUp = SKAction.scale(to: 1.08, duration: 1.25)
        scaleUp.timingMode = .easeInEaseOut
        let scaleDown = SKAction.scale(to: 1.0, duration: 1.25)
        scaleDown.timingMode = .easeInEaseOut
        let pulse = SKAction.sequence([scaleUp, scaleDown])
        stoneNode.run(SKAction.repeatForever(pulse), withKey: "pulse")
    }
}

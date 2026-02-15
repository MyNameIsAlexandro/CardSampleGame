/// Файл: Views/Combat/RitualCircleNode.swift
/// Назначение: Визуальный узел ритуального круга — зона коммита карты с effort-glow.
/// Зона ответственности: Presentation-only — отображение круга, glow пропорционально effort.
/// Контекст: Phase 3 Ritual Combat (R5). Reference: RITUAL_COMBAT_TEST_MODEL.md §3.3

import SpriteKit

// MARK: - Ritual Circle Node

/// Diegetic card commitment zone — a ritual circle that glows with effort intensity.
/// Pure visual node — state set via method calls, no stored simulation reference.
///
/// Usage:
///   1. Add to scene
///   2. `setCard(present:)` when card enters/leaves the circle
///   3. `updateEffortGlow(effortBonus:maxEffort:)` each frame
///   4. `updateGlowColor(_:)` to sync resonance tint
final class RitualCircleNode: SKNode {

    // MARK: - Constants

    static let nodeSize = CGSize(width: 120, height: 120)
    private let circleRadius: CGFloat = 55

    // MARK: - State

    private(set) var hasCard: Bool = false

    // MARK: - Child Nodes

    private let borderNode: SKShapeNode
    private let glowNode: SKShapeNode
    private let runeRing: SKShapeNode

    // MARK: - Init

    override init() {
        let border = SKShapeNode(circleOfRadius: 55)
        border.fillColor = .clear
        border.strokeColor = SKColor(red: 0.40, green: 0.35, blue: 0.45, alpha: 1)
        border.lineWidth = 2
        border.alpha = 0.5
        self.borderNode = border

        let glow = SKShapeNode(circleOfRadius: 60)
        glow.fillColor = .clear
        glow.strokeColor = SKColor(red: 0.50, green: 0.40, blue: 0.55, alpha: 1)
        glow.lineWidth = 4
        glow.alpha = 0
        glow.glowWidth = 6
        self.glowNode = glow

        let rune = SKShapeNode(circleOfRadius: 48)
        rune.fillColor = .clear
        rune.strokeColor = SKColor(red: 0.35, green: 0.30, blue: 0.40, alpha: 1)
        rune.lineWidth = 1
        let dashPattern: [CGFloat] = [8, 6]
        rune.path = RitualCircleNode.dashedCirclePath(radius: 48, pattern: dashPattern)
        self.runeRing = rune

        super.init()

        addChild(glowNode)
        addChild(borderNode)
        addChild(runeRing)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Card Presence

    /// Update visual state when a card enters or leaves the circle.
    func setCard(present: Bool) {
        guard present != hasCard else { return }
        hasCard = present

        borderNode.removeAllActions()
        if present {
            borderNode.run(SKAction.fadeAlpha(to: 1.0, duration: 0.2))
            startRuneRotation()
        } else {
            borderNode.run(SKAction.fadeAlpha(to: 0.5, duration: 0.2))
            runeRing.removeAllActions()
        }
    }

    // MARK: - Effort Glow

    /// Update glow intensity proportional to effort bonus.
    /// - Parameters:
    ///   - effortBonus: Current effort burn count (0...max)
    ///   - maxEffort: Maximum allowed effort burns
    func updateEffortGlow(effortBonus: Int, maxEffort: Int) {
        guard maxEffort > 0 else {
            glowNode.alpha = 0
            return
        }
        let ratio = CGFloat(effortBonus) / CGFloat(maxEffort)
        let targetAlpha: CGFloat = 0.3 + ratio * 0.7
        glowNode.removeAllActions()
        glowNode.run(SKAction.fadeAlpha(to: targetAlpha, duration: 0.2))
    }

    /// Update glow color to match current resonance.
    func updateGlowColor(_ color: SKColor) {
        glowNode.strokeColor = color
    }

    // MARK: - Rune Animation

    private func startRuneRotation() {
        let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 12.0)
        runeRing.run(SKAction.repeatForever(rotate), withKey: "runeRotate")
    }

    // MARK: - Dashed Circle Helper

    private static func dashedCirclePath(radius: CGFloat, pattern: [CGFloat]) -> CGPath {
        let path = CGMutablePath()
        let circumference = 2 * .pi * radius
        let totalPattern = pattern.reduce(0, +)
        guard totalPattern > 0 else {
            path.addEllipse(in: CGRect(x: -radius, y: -radius,
                                       width: radius * 2, height: radius * 2))
            return path
        }

        var angle: CGFloat = 0
        let segments = Int(circumference / totalPattern)
        for _ in 0..<segments {
            let dashAngle = (pattern[0] / circumference) * .pi * 2
            let gapAngle = (pattern[1] / circumference) * .pi * 2

            path.addArc(center: .zero, radius: radius,
                        startAngle: angle, endAngle: angle + dashAngle,
                        clockwise: false)
            angle += dashAngle + gapAngle
        }
        return path
    }
}

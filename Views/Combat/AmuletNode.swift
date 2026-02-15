/// Файл: Views/Combat/AmuletNode.swift
/// Назначение: HUD-узел каменного амулета — отображение HP героя с критическим режимом.
/// Зона ответственности: Presentation-only — HP label, damage/heal flash, critical pulse.
/// Контекст: Phase 3 Ritual Combat (R8). Reference: RITUAL_COMBAT_TEST_MODEL.md §3.6

import SpriteKit

// MARK: - Amulet Node

/// Diegetic HP display — a stone amulet showing hero health.
/// Pure visual node — state set via method calls, no stored simulation reference.
///
/// Usage:
///   1. Add to scene
///   2. `updateHP(current:max:)` when HP changes
///   3. `playDamageFlash()` / `playHealFlash()` for feedback
final class AmuletNode: SKNode {

    // MARK: - Constants

    static let nodeSize = CGSize(width: 80, height: 80)
    private let criticalThreshold: CGFloat = 0.25

    // MARK: - State

    private var isCritical: Bool = false

    // MARK: - Child Nodes

    private let stoneNode: SKShapeNode
    private let hpLabel: SKLabelNode
    private let shadowLabel: SKLabelNode

    // MARK: - Init

    override init() {
        let stone = SKShapeNode(rectOf: AmuletNode.nodeSize, cornerRadius: 16)
        stone.fillColor = SKColor(red: 0.18, green: 0.15, blue: 0.12, alpha: 1)
        stone.strokeColor = SKColor(red: 0.45, green: 0.40, blue: 0.35, alpha: 1)
        stone.lineWidth = 2
        self.stoneNode = stone

        let shadow = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        shadow.fontSize = 18
        shadow.fontColor = .black
        shadow.verticalAlignmentMode = .center
        shadow.horizontalAlignmentMode = .center
        shadow.position = CGPoint(x: 1, y: -1)
        self.shadowLabel = shadow

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.fontSize = 18
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        self.hpLabel = label

        super.init()

        addChild(stoneNode)
        addChild(shadowLabel)
        addChild(hpLabel)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - HP Update

    /// Update displayed HP value.
    func updateHP(current: Int, max: Int) {
        let text = "\u{2665} \(current)/\(max)"
        hpLabel.text = text
        shadowLabel.text = text

        let ratio = max > 0 ? CGFloat(current) / CGFloat(max) : 1.0
        let shouldBeCritical = ratio < criticalThreshold && ratio > 0

        if shouldBeCritical && !isCritical {
            isCritical = true
            startCriticalPulse()
        } else if !shouldBeCritical && isCritical {
            isCritical = false
            stopCriticalPulse()
        }
    }

    // MARK: - Damage Flash

    /// Shake + red flash on taking damage.
    func playDamageFlash() {
        let dx: CGFloat = 4
        let shake = SKAction.sequence([
            SKAction.moveBy(x: dx, y: 0, duration: 0.03),
            SKAction.moveBy(x: -dx * 2, y: 0, duration: 0.03),
            SKAction.moveBy(x: dx, y: 0, duration: 0.03)
        ])

        let flash = SKAction.sequence([
            SKAction.run { [weak self] in
                self?.stoneNode.fillColor = SKColor(red: 0.60, green: 0.15, blue: 0.15, alpha: 1)
            },
            SKAction.wait(forDuration: 0.1),
            SKAction.run { [weak self] in
                self?.stoneNode.fillColor = SKColor(red: 0.18, green: 0.15, blue: 0.12, alpha: 1)
            }
        ])

        run(SKAction.group([shake, flash]))
    }

    // MARK: - Heal Flash

    /// Green pulse on healing.
    func playHealFlash() {
        let flash = SKAction.sequence([
            SKAction.run { [weak self] in
                self?.stoneNode.fillColor = SKColor(red: 0.15, green: 0.45, blue: 0.20, alpha: 1)
            },
            SKAction.wait(forDuration: 0.15),
            SKAction.run { [weak self] in
                self?.stoneNode.fillColor = SKColor(red: 0.18, green: 0.15, blue: 0.12, alpha: 1)
            }
        ])
        run(flash)
    }

    // MARK: - Critical Pulse

    private func startCriticalPulse() {
        hpLabel.fontColor = SKColor(red: 0.90, green: 0.35, blue: 0.35, alpha: 1)
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.6, duration: 0.3),
            SKAction.fadeAlpha(to: 1.0, duration: 0.3)
        ])
        hpLabel.run(SKAction.repeatForever(pulse), withKey: "criticalPulse")
    }

    private func stopCriticalPulse() {
        hpLabel.removeAction(forKey: "criticalPulse")
        hpLabel.alpha = 1.0
        hpLabel.fontColor = .white
    }
}

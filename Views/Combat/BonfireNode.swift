/// Файл: Views/Combat/BonfireNode.swift
/// Назначение: Визуальный узел костра — зона сожжения карт (effort burn) с огненными частицами.
/// Зона ответственности: Presentation-only — огонь, частицы, burn/undo анимации. Без доменной логики.
/// Контекст: Phase 3 Ritual Combat (R5). Reference: RITUAL_COMBAT_TEST_MODEL.md §3.3

import SpriteKit

// MARK: - Bonfire Node

/// Diegetic effort-burn zone — a firepit that grows with each burned card.
/// Pure visual node — state set via method calls, no stored simulation reference.
///
/// Usage:
///   1. Add to scene
///   2. `setBurnCount(_:max:)` when effort changes
///   3. `playBurnAnimation()` on card burn
///   4. `playUndoAnimation()` on burn undo
final class BonfireNode: SKNode {

    // MARK: - Constants

    static let nodeSize = CGSize(width: 100, height: 100)
    private let pitRadius: CGFloat = 35

    // MARK: - State

    private(set) var burnCount: Int = 0

    // MARK: - Child Nodes

    private let baseNode: SKShapeNode
    private let embersNode: SKShapeNode
    private var emitterNode: SKEmitterNode?

    // MARK: - Init

    override init() {
        let base = SKShapeNode(circleOfRadius: 35)
        base.fillColor = SKColor(red: 0.12, green: 0.08, blue: 0.06, alpha: 1)
        base.strokeColor = SKColor(red: 0.35, green: 0.25, blue: 0.15, alpha: 1)
        base.lineWidth = 2
        self.baseNode = base

        let embers = SKShapeNode(circleOfRadius: 20)
        embers.fillColor = SKColor(red: 0.25, green: 0.10, blue: 0.05, alpha: 1)
        embers.strokeColor = .clear
        embers.alpha = 0.5
        self.embersNode = embers

        super.init()

        addChild(baseNode)
        addChild(embersNode)
        setupEmitter()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Burn Count

    /// Update fire intensity based on current burn count.
    /// - Parameters:
    ///   - count: Number of cards burned (0...max)
    ///   - max: Maximum allowed burns
    func setBurnCount(_ count: Int, max: Int) {
        burnCount = count
        updateFireLevel(count: count, maxBurns: max)
    }

    // MARK: - Burn Animation

    /// Flash burst when a card is burned.
    func playBurnAnimation() {
        guard let emitter = emitterNode else { return }

        let savedRate = emitter.particleBirthRate
        emitter.particleBirthRate = 40
        emitter.particleColor = SKColor(red: 1.0, green: 0.85, blue: 0.40, alpha: 1)

        let burst = SKAction.sequence([
            SKAction.wait(forDuration: 0.15),
            SKAction.run { [weak self] in
                self?.restoreFireLevel()
            }
        ])
        run(burst, withKey: "burnBurst")

        embersNode.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 1.0, duration: 0.08),
            SKAction.fadeAlpha(to: emberAlpha(), duration: 0.2)
        ]))

        let _ = savedRate
    }

    /// Reverse visual on burn undo.
    func playUndoAnimation() {
        guard let emitter = emitterNode else { return }

        emitter.particleBirthRate = 0
        emitter.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.1),
            SKAction.run { [weak self] in
                self?.restoreFireLevel()
            }
        ]))

        embersNode.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.2, duration: 0.1),
            SKAction.fadeAlpha(to: emberAlpha(), duration: 0.15)
        ]))
    }

    // MARK: - Fire Level

    private func updateFireLevel(count: Int, maxBurns: Int) {
        guard let emitter = emitterNode else { return }

        if count == 0 {
            emitter.particleBirthRate = 2
            emitter.particleColor = SKColor(red: 0.50, green: 0.25, blue: 0.10, alpha: 1)
        } else if count == 1 {
            emitter.particleBirthRate = 8
            emitter.particleColor = SKColor(red: 0.85, green: 0.45, blue: 0.15, alpha: 1)
        } else {
            let intensity = CGFloat(min(count, maxBurns)) / CGFloat(max(maxBurns, 1))
            emitter.particleBirthRate = 8 + intensity * 12
            let r: CGFloat = 0.85 + intensity * 0.15
            let g: CGFloat = 0.45 + intensity * 0.40
            let b: CGFloat = 0.15 + intensity * 0.25
            emitter.particleColor = SKColor(red: r, green: g, blue: b, alpha: 1)
        }

        embersNode.run(SKAction.fadeAlpha(to: emberAlpha(), duration: 0.2))
    }

    private func restoreFireLevel() {
        updateFireLevel(count: burnCount, maxBurns: Swift.max(burnCount, 1))
    }

    private func emberAlpha() -> CGFloat {
        return burnCount == 0 ? 0.3 : min(0.5 + CGFloat(burnCount) * 0.15, 1.0)
    }

    // MARK: - Emitter Setup

    private func setupEmitter() {
        let e = SKEmitterNode()
        e.particleBirthRate = 2
        e.particleLifetime = 1.5
        e.particleLifetimeRange = 0.5
        e.emissionAngle = .pi / 2
        e.emissionAngleRange = .pi / 4
        e.particleSpeed = 20
        e.particleSpeedRange = 10
        e.particleAlpha = 0.7
        e.particleAlphaSpeed = -0.4
        e.particleScale = 0.03
        e.particleScaleRange = 0.02
        e.particleColor = SKColor(red: 0.50, green: 0.25, blue: 0.10, alpha: 1)
        e.particleColorBlendFactor = 1.0
        e.particleBlendMode = .add
        e.position = .zero
        e.particlePositionRange = CGVector(dx: 30, dy: 10)
        e.zPosition = 1
        addChild(e)
        emitterNode = e
    }
}

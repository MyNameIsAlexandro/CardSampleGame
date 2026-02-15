/// Файл: Views/Combat/ResonanceAtmosphereController.swift
/// Назначение: Контроллер визуальной атмосферы резонанса (цвет, частицы, альфа).
/// Зона ответственности: Read-only observer — читает resonance/phase, выдаёт visual params.
/// Контекст: Phase 3 Ritual Combat (R7). Reference: RITUAL_COMBAT_TEST_MODEL.md §3.4

import SpriteKit

// MARK: - Atmosphere Output

/// Visual parameters computed from resonance state.
struct AtmosphereVisuals: Equatable {
    let ambientColor: SKColor
    let ambientAlpha: CGFloat
    let particleIntensity: CGFloat
}

// MARK: - Resonance Atmosphere Controller

/// Pure presentation controller — reads resonance values, outputs visual parameters.
/// Does NOT call any CombatSimulation mutation methods.
/// Allowed reads: resonance value, phase, isOver (computed properties only).
///
/// Usage:
///   1. `attach(to:sceneSize:)` to connect to a scene node
///   2. `update(resonance:)` each frame to sync visuals
///   3. `detach()` to clean up nodes
final class ResonanceAtmosphereController {

    // MARK: - Visual State

    /// Current computed visual parameters (always available, even without scene)
    private(set) var currentVisuals: AtmosphereVisuals

    // MARK: - Scene Attachment

    /// Parent node for atmosphere layers. Nil = headless mode.
    weak var parentNode: SKNode?

    /// Full-screen ambient color overlay
    private var overlayNode: SKSpriteNode?

    /// Continuous ambient particle emitter
    private var emitterNode: SKEmitterNode?

    /// Base particle birth rate before intensity scaling
    private let baseBirthRate: CGFloat = 5.0

    // MARK: - Init

    init() {
        self.currentVisuals = AtmosphereVisuals(
            ambientColor: .black,
            ambientAlpha: 0.3,
            particleIntensity: 0.0
        )
    }

    // MARK: - Scene Integration

    /// Attach atmosphere layers to a scene node.
    func attach(to node: SKNode, sceneSize: CGSize) {
        detach()
        parentNode = node

        let overlay = SKSpriteNode(color: .black, size: sceneSize)
        overlay.alpha = 0.3
        overlay.zPosition = -5
        overlay.blendMode = .alpha
        node.addChild(overlay)
        overlayNode = overlay

        let emitter = makeAmbientEmitter(size: sceneSize)
        node.addChild(emitter)
        emitterNode = emitter
    }

    /// Remove atmosphere layers from scene.
    func detach() {
        overlayNode?.removeFromParent()
        overlayNode = nil
        emitterNode?.removeFromParent()
        emitterNode = nil
        parentNode = nil
    }

    // MARK: - Update

    /// Update atmosphere from current resonance value.
    /// - Parameter resonance: World resonance value (-100...100)
    func update(resonance: Float) {
        let normalized = CGFloat((resonance + 100) / 200) // 0...1
        let color: SKColor
        let alpha: CGFloat
        let intensity: CGFloat

        if resonance < -30 {
            color = SKColor(red: 0.3, green: 0.1, blue: 0.4, alpha: 1.0)
            alpha = 0.5
            intensity = CGFloat(abs(resonance)) / 100.0
        } else if resonance > 30 {
            color = SKColor(red: 0.9, green: 0.7, blue: 0.2, alpha: 1.0)
            alpha = 0.4
            intensity = CGFloat(resonance) / 100.0
        } else {
            color = SKColor(red: 0.5, green: 0.4, blue: 0.3, alpha: 1.0)
            alpha = 0.3
            intensity = normalized * 0.3
        }

        currentVisuals = AtmosphereVisuals(
            ambientColor: color,
            ambientAlpha: alpha,
            particleIntensity: intensity
        )

        applyVisuals()
    }

    // MARK: - Apply to Scene Nodes

    private func applyVisuals() {
        guard let overlay = overlayNode else { return }

        overlay.removeAllActions()
        let colorize = SKAction.colorize(
            with: currentVisuals.ambientColor,
            colorBlendFactor: 1.0,
            duration: 0.3
        )
        let fade = SKAction.fadeAlpha(to: currentVisuals.ambientAlpha, duration: 0.3)
        overlay.run(SKAction.group([colorize, fade]))

        if let emitter = emitterNode {
            emitter.particleBirthRate = baseBirthRate * currentVisuals.particleIntensity
            emitter.particleColor = currentVisuals.ambientColor
        }
    }

    // MARK: - Emitter Factory

    private func makeAmbientEmitter(size: CGSize) -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleBirthRate = 0
        e.particleLifetime = 3.0
        e.particleLifetimeRange = 1.0
        e.emissionAngle = .pi / 2 // upward
        e.emissionAngleRange = .pi / 3
        e.particleSpeed = 15
        e.particleSpeedRange = 10
        e.particleAlpha = 0.4
        e.particleAlphaSpeed = -0.15
        e.particleScale = 0.04
        e.particleScaleRange = 0.02
        e.particleColor = .white
        e.particleColorBlendFactor = 1.0
        e.particleBlendMode = .add
        e.position = CGPoint(x: 0, y: -size.height / 2)
        e.particlePositionRange = CGVector(dx: size.width, dy: 0)
        e.zPosition = -4
        return e
    }
}

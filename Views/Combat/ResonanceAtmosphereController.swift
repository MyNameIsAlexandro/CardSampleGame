/// Файл: Views/Combat/ResonanceAtmosphereController.swift
/// Назначение: Контроллер визуальной атмосферы резонанса — HSL-интерполяция, виньетка, частицы.
/// Зона ответственности: Read-only observer — читает resonance, выдаёт visual params.
/// Контекст: Phase 3 Ritual Combat (R7). Epic 6 — Smooth Interpolation & Vignette.

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
/// Uses continuous HSL interpolation instead of hard zone jumps.
/// Does NOT call any CombatSimulation mutation methods.
///
/// Color mapping (two-segment piecewise lerp):
///   - resonance -100: Hue 270° (Nav purple), high saturation
///   - resonance    0: Hue  35° (Yav amber), low saturation
///   - resonance +100: Hue  50° (Prav gold), high saturation
@MainActor
final class ResonanceAtmosphereController {

    // MARK: - Visual State

    private(set) var currentVisuals: AtmosphereVisuals

    // MARK: - Scene Attachment

    weak var parentNode: SKNode?
    private var overlayNode: SKSpriteNode?
    private var vignetteNode: SKShapeNode?
    private var emitterNode: SKEmitterNode?
    private let baseBirthRate: CGFloat = 5.0
    private var lastResonance: Float = 0

    // MARK: - Init

    init() {
        self.currentVisuals = AtmosphereVisuals(
            ambientColor: .black,
            ambientAlpha: 0.3,
            particleIntensity: 0.0
        )
    }

    // MARK: - Scene Integration

    func attach(to node: SKNode, sceneSize: CGSize) {
        detach()
        parentNode = node

        let overlay = SKSpriteNode(color: .black, size: sceneSize)
        overlay.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        overlay.alpha = 0.3
        overlay.zPosition = -5
        overlay.blendMode = .alpha
        node.addChild(overlay)
        overlayNode = overlay

        let vignette = makeVignette(size: sceneSize)
        node.addChild(vignette)
        vignetteNode = vignette

        let emitter = makeAmbientEmitter(size: sceneSize)
        node.addChild(emitter)
        emitterNode = emitter
    }

    func detach() {
        overlayNode?.removeFromParent()
        overlayNode = nil
        vignetteNode?.removeFromParent()
        vignetteNode = nil
        emitterNode?.removeFromParent()
        emitterNode = nil
        parentNode = nil
    }

    // MARK: - Update

    /// Update atmosphere from current resonance value.
    func update(resonance: Float) {
        let clamped = max(-100, min(100, resonance))
        let normalized = CGFloat((clamped + 100) / 200) // 0...1

        let color = interpolateColor(normalized: normalized)
        let absRes = abs(clamped)
        let alpha: CGFloat = 0.3 + CGFloat(absRes) / 100.0 * 0.2
        let intensity = CGFloat(absRes) / 100.0

        currentVisuals = AtmosphereVisuals(
            ambientColor: color,
            ambientAlpha: alpha,
            particleIntensity: intensity
        )

        let animated = abs(resonance - lastResonance) > 0.01
        lastResonance = resonance

        if animated {
            applyVisuals(duration: 0.5)
        } else {
            applyVisuals(duration: 0.0)
        }

        updateVignette(resonance: clamped)
    }

    // MARK: - HSL Color Interpolation

    /// Two-segment piecewise HSL interpolation.
    /// Nav purple (270°) → Yav amber (35°) → Prav gold (50°).
    private func interpolateColor(normalized: CGFloat) -> SKColor {
        let hue: CGFloat
        let saturation: CGFloat
        let lightness: CGFloat

        if normalized < 0.5 {
            let t = normalized / 0.5
            hue = lerp(270, 35, t: t)
            saturation = lerp(0.70, 0.40, t: t)
            lightness = lerp(0.35, 0.50, t: t)
        } else {
            let t = (normalized - 0.5) / 0.5
            hue = lerp(35, 50, t: t)
            saturation = lerp(0.40, 0.75, t: t)
            lightness = lerp(0.50, 0.55, t: t)
        }

        return hslToSKColor(h: hue, s: saturation, l: lightness)
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    /// Convert HSL to SKColor via intermediate RGB.
    private func hslToSKColor(h: CGFloat, s: CGFloat, l: CGFloat) -> SKColor {
        let hNorm = h / 360.0
        let c = (1 - abs(2 * l - 1)) * s
        let x = c * (1 - abs((hNorm * 6).truncatingRemainder(dividingBy: 2) - 1))
        let m = l - c / 2

        let r1, g1, b1: CGFloat
        let sector = Int(hNorm * 6) % 6
        switch sector {
        case 0: (r1, g1, b1) = (c, x, 0)
        case 1: (r1, g1, b1) = (x, c, 0)
        case 2: (r1, g1, b1) = (0, c, x)
        case 3: (r1, g1, b1) = (0, x, c)
        case 4: (r1, g1, b1) = (x, 0, c)
        default: (r1, g1, b1) = (c, 0, x)
        }

        return SKColor(red: r1 + m, green: g1 + m, blue: b1 + m, alpha: 1)
    }

    // MARK: - Apply to Scene Nodes

    private func applyVisuals(duration: TimeInterval) {
        guard let overlay = overlayNode else { return }

        overlay.removeAllActions()
        if duration > 0 {
            let colorize = SKAction.colorize(
                with: currentVisuals.ambientColor,
                colorBlendFactor: 1.0,
                duration: duration
            )
            let fade = SKAction.fadeAlpha(to: currentVisuals.ambientAlpha, duration: duration)
            overlay.run(SKAction.group([colorize, fade]))
        } else {
            overlay.color = currentVisuals.ambientColor
            overlay.alpha = currentVisuals.ambientAlpha
        }

        if let emitter = emitterNode {
            emitter.particleBirthRate = baseBirthRate * currentVisuals.particleIntensity
            emitter.particleColor = currentVisuals.ambientColor
        }
    }

    // MARK: - Vignette

    private func makeVignette(size: CGSize) -> SKShapeNode {
        let vignette = SKShapeNode(rectOf: size, cornerRadius: 0)
        vignette.fillColor = .clear
        vignette.strokeColor = SKColor(white: 0, alpha: 1)
        vignette.lineWidth = size.width * 0.35
        vignette.position = CGPoint(x: size.width / 2, y: size.height / 2)
        vignette.alpha = 0
        vignette.zPosition = -3
        return vignette
    }

    private func updateVignette(resonance: Float) {
        let absRes = abs(resonance)
        let targetAlpha: CGFloat = CGFloat(absRes) / 100.0 * 0.4
        vignetteNode?.run(SKAction.fadeAlpha(to: targetAlpha, duration: 0.5))
    }

    // MARK: - Emitter Factory

    private func makeAmbientEmitter(size: CGSize) -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleBirthRate = 0
        e.particleLifetime = 3.0
        e.particleLifetimeRange = 1.0
        e.emissionAngle = .pi / 2
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

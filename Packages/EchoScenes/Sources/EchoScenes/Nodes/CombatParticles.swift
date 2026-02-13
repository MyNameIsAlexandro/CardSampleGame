/// Файл: Packages/EchoScenes/Sources/EchoScenes/Nodes/CombatParticles.swift
/// Назначение: Содержит реализацию файла CombatParticles.swift.
/// Зона ответственности: Реализует визуально-сценовый слой EchoScenes.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import SpriteKit

/// Programmatic particle emitters for combat effects (no .sks files needed).
public enum CombatParticles {

    /// Short burst of white sparks on hit.
    public static func attackImpact() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 60
        emitter.numParticlesToEmit = 15
        emitter.particleLifetime = 0.4
        emitter.particleLifetimeRange = 0.2
        emitter.emissionAngleRange = .pi * 2
        emitter.particleSpeed = 80
        emitter.particleSpeedRange = 40
        emitter.particleAlpha = 0.9
        emitter.particleAlphaSpeed = -2.0
        emitter.particleScale = 0.08
        emitter.particleScaleRange = 0.04
        emitter.particleColor = .white
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBlendMode = .add
        emitter.zPosition = 40
        return emitter
    }

    /// Gold sparks burst for critical hits — more particles, bigger.
    public static func criticalHit() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 120
        emitter.numParticlesToEmit = 35
        emitter.particleLifetime = 0.6
        emitter.particleLifetimeRange = 0.3
        emitter.emissionAngleRange = .pi * 2
        emitter.particleSpeed = 120
        emitter.particleSpeedRange = 60
        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -1.5
        emitter.particleScale = 0.12
        emitter.particleScaleRange = 0.06
        emitter.particleColor = CombatSceneTheme.highlight
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBlendMode = .add
        emitter.zPosition = 40
        return emitter
    }

    /// Green ascending particles for healing.
    public static func healEffect() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 30
        emitter.numParticlesToEmit = 12
        emitter.particleLifetime = 0.8
        emitter.particleLifetimeRange = 0.3
        emitter.emissionAngle = .pi / 2 // upward
        emitter.emissionAngleRange = .pi / 4
        emitter.particleSpeed = 40
        emitter.particleSpeedRange = 20
        emitter.particleAlpha = 0.8
        emitter.particleAlphaSpeed = -1.0
        emitter.particleScale = 0.06
        emitter.particleScaleRange = 0.03
        emitter.particleColor = CombatSceneTheme.success
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBlendMode = .add
        emitter.zPosition = 40
        return emitter
    }
}

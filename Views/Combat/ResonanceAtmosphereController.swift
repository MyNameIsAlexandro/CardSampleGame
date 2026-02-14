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
final class ResonanceAtmosphereController {

    /// Current visual state
    private(set) var currentVisuals: AtmosphereVisuals

    init() {
        self.currentVisuals = AtmosphereVisuals(
            ambientColor: .black,
            ambientAlpha: 0.3,
            particleIntensity: 0.0
        )
    }

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
    }
}

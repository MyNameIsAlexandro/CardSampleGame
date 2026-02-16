/// Файл: Views/Combat/RitualCombatSceneView.swift
/// Назначение: SwiftUI-обёртка для RitualCombatScene (SpriteView bridge).
/// Зона ответственности: Мост SwiftUI ↔ SpriteKit для ритуального боя.
/// Контекст: Phase 3 Ritual Combat (R9). Принимает CombatSimulation и строит сцену.

import SwiftUI
import SpriteKit
import TwilightEngine

/// SwiftUI wrapper for `RitualCombatScene`.
/// Accepts a `CombatSimulation` and wires callbacks before presenting via SpriteView.
struct RitualCombatSceneView: View {

    let simulation: CombatSimulation
    var onCombatEnd: ((RitualCombatResult) -> Void)?
    var onSoundEffect: ((String) -> Void)?
    var onHaptic: ((String) -> Void)?

    var body: some View {
        SpriteView(scene: makeScene())
            .ignoresSafeArea()
    }

    private func makeScene() -> RitualCombatScene {
        let scene = RitualCombatScene(size: RitualCombatScene.sceneSize)
        scene.scaleMode = .aspectFill
        scene.backgroundColor = SKColor(red: 0.08, green: 0.06, blue: 0.10, alpha: 1)
        scene.onCombatEnd = onCombatEnd
        scene.onSoundEffect = onSoundEffect
        scene.onHaptic = onHaptic
        scene.configure(with: simulation)
        return scene
    }
}

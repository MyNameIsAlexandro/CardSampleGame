/// Файл: Views/Combat/DispositionCombatSceneView.swift
/// Назначение: SwiftUI-обёртка для DispositionCombatScene (SpriteView bridge).
/// Зона ответственности: Мост SwiftUI ↔ SpriteKit для Disposition Combat.
/// Контекст: Phase 3 Disposition Combat. Принимает DispositionCombatSimulation и строит сцену.

import SwiftUI
import SpriteKit
import TwilightEngine

/// SwiftUI wrapper for `DispositionCombatScene`.
/// Accepts a `DispositionCombatSimulation` and wires callbacks before presenting via SpriteView.
struct DispositionCombatSceneView: View {

    let simulation: DispositionCombatSimulation
    var onCombatEnd: ((DispositionCombatResult) -> Void)?
    var onSoundEffect: ((String) -> Void)?
    var onHaptic: ((String) -> Void)?

    var body: some View {
        SpriteView(scene: makeScene())
            .ignoresSafeArea()
    }

    private func makeScene() -> DispositionCombatScene {
        let scene = DispositionCombatScene(size: DispositionCombatScene.sceneSize)
        scene.scaleMode = .aspectFill
        scene.onCombatEnd = onCombatEnd
        scene.onSoundEffect = onSoundEffect
        scene.onHaptic = onHaptic
        scene.configure(with: simulation)
        return scene
    }
}

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
        GeometryReader { geo in
            SpriteView(scene: makeScene(viewSize: geo.size))
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }

    private func makeScene(viewSize: CGSize) -> DispositionCombatScene {
        let sceneW: CGFloat = 390
        let sceneH = viewSize.height * (sceneW / max(viewSize.width, 1))
        let scene = DispositionCombatScene(size: CGSize(width: sceneW, height: sceneH))
        scene.scaleMode = .aspectFill
        scene.onCombatEnd = onCombatEnd
        scene.onSoundEffect = onSoundEffect
        scene.onHaptic = onHaptic
        scene.configure(with: simulation)
        return scene
    }
}

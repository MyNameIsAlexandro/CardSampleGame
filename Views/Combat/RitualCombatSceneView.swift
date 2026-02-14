/// Файл: Views/Combat/RitualCombatSceneView.swift
/// Назначение: SwiftUI-обёртка для RitualCombatScene (SpriteView bridge).
/// Зона ответственности: Мост SwiftUI ↔ SpriteKit для ритуального боя.
/// Контекст: Phase 3 Ritual Combat (R2). Паттерн аналогичен CombatSceneView.

import SwiftUI
import SpriteKit

/// SwiftUI wrapper for `RitualCombatScene`.
/// Follows the same SpriteView bridge pattern as EchoScenes.CombatSceneView.
struct RitualCombatSceneView: View {

    let scene: RitualCombatScene

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
    }
}

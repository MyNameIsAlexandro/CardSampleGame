/// Файл: Views/Combat/RitualCombatScene.swift
/// Назначение: SpriteKit-сцена ритуального боя (Стол Волхва).
/// Зона ответственности: Визуализация боя, делегирование логики в CombatSimulation.
/// Контекст: Phase 3 Ritual Combat (R2). Не обращается к ECS напрямую.

import SpriteKit
import TwilightEngine

/// Ritual Combat scene — portrait 390x700 "Sorcerer's Table" aesthetic.
/// All game logic delegated to `CombatSimulation` API. No direct ECS access.
final class RitualCombatScene: SKScene {

    // MARK: - Configuration

    /// Portrait scene size (Tarot card aesthetic)
    static let sceneSize = CGSize(width: 390, height: 700)

    // MARK: - Combat State

    /// Pure-logic combat simulation (owned, not engine/bridge)
    private(set) var simulation: CombatSimulation?

    /// Callback when combat ends
    var onCombatEnd: ((CombatOutcome) -> Void)?

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        backgroundColor = .black
        scaleMode = .aspectFill
    }

    // MARK: - Setup

    /// Configure scene with a combat simulation instance.
    func configure(with simulation: CombatSimulation) {
        self.simulation = simulation
    }
}

// MARK: - Combat Outcome

/// Result of ritual combat for callback propagation.
enum CombatOutcome {
    case victory
    case defeat
}

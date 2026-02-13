/// Файл: Packages/EchoScenes/Tests/EchoScenesTests/CombatSceneTests.swift
/// Назначение: Содержит реализацию файла CombatSceneTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import Testing
import SpriteKit
import EchoEngine
import TwilightEngine
@testable import EchoScenes

@Suite("CombatScene Tests")
struct CombatSceneTests {

    private func makeEnemy() -> EnemyDefinition {
        EnemyDefinition(
            id: "test_wolf",
            name: .key("wolf"),
            description: .key("wolf_desc"),
            health: 6,
            power: 2,
            defense: 1
        )
    }

    private func makeFateCards() -> [FateCard] {
        (0..<10).map { i in
            FateCard(
                id: "fate_\(i)",
                modifier: (i % 3) - 1,
                name: "Fate \(i)"
            )
        }
    }

    @Test("CombatScene configures and begins combat")
    func testConfigure() {
        let scene = CombatScene(size: CGSize(width: 390, height: 700))
        scene.configure(
            enemyDefinition: makeEnemy(),
            playerStrength: 8,
            playerDeck: [],
            fateCards: makeFateCards(),
            seed: 42
        )

        #expect(scene.simulation != nil)
        #expect(scene.simulation.phase == .setup)
    }

    @Test("CombatScene didMove sets up render group and begins combat")
    func testDidMove() {
        let scene = CombatScene(size: CGSize(width: 390, height: 700))
        scene.configure(
            enemyDefinition: makeEnemy(),
            playerStrength: 8,
            fateCards: makeFateCards(),
            seed: 42
        )

        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        view.presentScene(scene)

        #expect(scene.renderGroup != nil)
        #expect(scene.simulation.phase == .playerTurn)
        #expect(scene.renderGroup.registry.count >= 2) // player + enemy nodes
    }

    @Test("Full combat via scene runs to completion")
    func testFullCombat() {
        let scene = CombatScene(size: CGSize(width: 390, height: 700))
        scene.configure(
            enemyDefinition: makeEnemy(),
            playerStrength: 12,
            fateCards: makeFateCards(),
            seed: 42
        )

        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        view.presentScene(scene)

        // Simulate taps on attack button — run combat loop manually
        var turns = 0
        while !scene.simulation.isOver && turns < 20 {
            scene.simulation.playerAttack()
            if scene.simulation.isOver { break }
            scene.simulation.resolveEnemyTurn()
            turns += 1
        }

        #expect(scene.simulation.isOver)
        #expect(scene.simulation.outcome != nil)
    }
}

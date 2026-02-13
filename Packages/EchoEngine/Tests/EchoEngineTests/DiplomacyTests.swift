/// Файл: Packages/EchoEngine/Tests/EchoEngineTests/DiplomacyTests.swift
/// Назначение: Содержит реализацию файла DiplomacyTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import Testing
import FirebladeECS
import TwilightEngine
@testable import EchoEngine

@Suite("Diplomacy Tests")
struct DiplomacyTests {

    // MARK: - Helpers

    private func makeEnemy(health: Int = 10, will: Int = 8) -> EnemyDefinition {
        EnemyDefinition(
            id: "test_diplo",
            name: .key("diplo_enemy"),
            description: .key("diplo_enemy_desc"),
            health: health,
            power: 3,
            defense: 1,
            will: will > 0 ? will : nil
        )
    }

    private func makeSim(
        enemyWill: Int = 8,
        enemyHealth: Int = 10,
        playerStrength: Int = 5,
        fateCards: [FateCard] = [],
        seed: UInt64 = 42
    ) -> CombatSimulation {
        let enemy = makeEnemy(health: enemyHealth, will: enemyWill)
        return CombatSimulation.create(
            enemyDefinition: enemy,
            playerStrength: playerStrength,
            fateCards: fateCards,
            seed: seed
        )
    }

    // MARK: - playerInfluence Tests

    @Test("playerInfluence damages will, not health")
    func testInfluenceDamagesWill() {
        let sim = makeSim(enemyWill: 10, enemyHealth: 20)
        sim.beginCombat()

        let initialHealth = sim.enemyHealth
        sim.playerInfluence()

        #expect(sim.enemyWill < 10, "Will should decrease")
        #expect(sim.enemyHealth == initialHealth, "Health should not change")
    }

    @Test("playerInfluence returns influenceNotAvailable for enemy without will")
    func testInfluenceNotAvailable() {
        let sim = makeSim(enemyWill: 0)
        sim.beginCombat()

        let event = sim.playerInfluence()

        if case .influenceNotAvailable = event {
            // Expected
        } else {
            #expect(Bool(false), "Expected influenceNotAvailable, got \(event)")
        }
    }

    @Test("Enemy with will=0 after influence triggers pacified victory")
    func testPacifiedVictory() {
        // Low will enemy — one influence should pacify
        let sim = makeSim(enemyWill: 1, playerStrength: 10)
        sim.beginCombat()

        sim.playerInfluence()

        #expect(sim.enemyWill == 0)
        // Need to check victory after end turn
        sim.endTurn()
        let event = sim.resolveEnemyTurn()
        // Combat should be over since will is depleted
        // The victory check happens in resolveEnemyTurn
        _ = event
        #expect(sim.outcome == .victory(.pacified))
    }

    @Test("Enemy killed via health=0 gives killed victory")
    func testKilledVictory() {
        let sim = makeSim(enemyWill: 10, enemyHealth: 1, playerStrength: 20)
        sim.beginCombat()

        sim.playerAttack()

        sim.endTurn()
        sim.resolveEnemyTurn()

        #expect(sim.outcome == .victory(.killed))
    }

    // MARK: - Track Switching Tests

    @Test("Switching from physical to spiritual sets surprise bonus")
    func testSwitchToSpiritualGivesSurpriseBonus() {
        let sim = makeSim(enemyWill: 20)
        sim.beginCombat()

        guard let player = sim.playerEntity else {
            #expect(Bool(false), "No player"); return
        }

        // Player starts on physical track
        let diplomacy: DiplomacyComponent = sim.nexus.get(unsafe: player.identifier)
        #expect(diplomacy.currentTrack == .physical)

        // Influence switches to spiritual
        sim.playerInfluence()

        #expect(diplomacy.currentTrack == .spiritual)
        #expect(diplomacy.surpriseBonus == 2)
    }

    @Test("Switching from spiritual to physical sets rage shield")
    func testSwitchToPhysicalGivesRageShield() {
        let sim = makeSim(enemyWill: 20)
        sim.beginCombat()

        guard let player = sim.playerEntity else {
            #expect(Bool(false), "No player"); return
        }

        // First switch to spiritual
        sim.playerInfluence()
        let diplomacy: DiplomacyComponent = sim.nexus.get(unsafe: player.identifier)
        #expect(diplomacy.currentTrack == .spiritual)

        // Now attack physically — switches back
        sim.playerAttack()

        #expect(diplomacy.currentTrack == .physical)
        #expect(diplomacy.rageShield == 2)
    }

    @Test("Escalation penalties decay each round")
    func testEscalationDecay() {
        let sim = makeSim(enemyWill: 50, enemyHealth: 50)
        sim.beginCombat()

        guard let player = sim.playerEntity else {
            #expect(Bool(false), "No player"); return
        }

        // Switch to spiritual → surprise bonus
        sim.playerInfluence()
        let diplomacy: DiplomacyComponent = sim.nexus.get(unsafe: player.identifier)
        #expect(diplomacy.surpriseBonus == 2)

        // End turn and resolve enemy → advances round → ticks diplomacy
        sim.endTurn()
        sim.resolveEnemyTurn()

        #expect(diplomacy.surpriseBonus == 1, "Surprise bonus should decay by 1")

        // Another round
        sim.playerInfluence() // stay on spiritual, no switch
        sim.endTurn()
        sim.resolveEnemyTurn()

        #expect(diplomacy.surpriseBonus == 0, "Surprise bonus should fully decay")
    }

    // MARK: - DiplomacyComponent Tests

    @Test("DiplomacyComponent not assigned when enemy has no will")
    func testNoDiplomacyWithoutWill() {
        let sim = makeSim(enemyWill: 0)
        guard let player = sim.playerEntity else {
            #expect(Bool(false), "No player"); return
        }

        #expect(!player.has(DiplomacyComponent.self))
    }

    @Test("DiplomacyComponent assigned when enemy has will")
    func testDiplomacyWithWill() {
        let sim = makeSim(enemyWill: 5)
        guard let player = sim.playerEntity else {
            #expect(Bool(false), "No player"); return
        }

        #expect(player.has(DiplomacyComponent.self))
    }
}

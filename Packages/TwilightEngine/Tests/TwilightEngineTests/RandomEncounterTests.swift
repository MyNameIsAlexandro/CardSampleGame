/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/RandomEncounterTests.swift
/// Назначение: Содержит реализацию файла RandomEncounterTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import Testing
@testable import TwilightEngine

@Suite("Random Encounter Tests", .serialized)
struct RandomEncounterTests {

    private func makeEngine() -> TwilightGameEngine {
        TestEngineFactory.makeEngine(seed: 42)
    }

    /// Setup engine with blocked scripted events and safe tension level
    private func setupForEncounters(tension: Int = 90) -> TwilightGameEngine {
        let engine = makeEngine()
        engine.initializeNewGame(playerName: "Test", heroId: nil, startingDeck: [])
        engine.blockAllScriptedEvents()
        engine.setWorldTension(min(tension, 99)) // Must stay below 100 (game over)
        return engine
    }

    /// Try to get a random encounter, returns the event if found
    private func findRandomEncounter(_ engine: TwilightGameEngine, maxAttempts: Int = 10) -> GameEvent? {
        for _ in 0..<maxAttempts {
            if engine.isGameOver { break }
            engine.performAction(.dismissCurrentEvent)
            let result = engine.performAction(.explore)
            if result.success, let event = engine.currentEvent,
               event.id.hasPrefix("random_encounter_") {
                return event
            }
        }
        return nil
    }

    // MARK: - Tests

    @Test("Explore with high tension generates random encounter")
    func testHighTensionRandomEncounter() {
        let engine = setupForEncounters(tension: 90)
        let encounter = findRandomEncounter(engine)
        #expect(encounter != nil, "Expected random encounter with tension=90 within 10 attempts")
    }

    @Test("Random encounter has combat event structure")
    func testRandomEncounterStructure() {
        let engine = setupForEncounters(tension: 90)
        guard let event = findRandomEncounter(engine) else {
            #expect(Bool(false), "No random encounter generated")
            return
        }

        #expect(event.eventType == .combat)
        #expect(event.monsterCard != nil)
        #expect(event.choices.count == 2)
        #expect(event.choices[0].id == "fight")
        #expect(event.choices[1].id == "flee")
        #expect(event.choices[1].consequences.healthChange == -2)
    }

    @Test("Random encounter monster comes from ContentRegistry")
    func testRandomEncounterUsesRegistryEnemies() {
        let engine = setupForEncounters(tension: 90)
        let allEnemyIds = Set(engine.services.contentRegistry.getAllEnemies().map { $0.id })
        #expect(!allEnemyIds.isEmpty)

        guard let event = findRandomEncounter(engine) else {
            #expect(Bool(false), "No random encounter generated")
            return
        }

        #expect(allEnemyIds.contains(event.monsterCard!.id))
    }

    @Test("Low tension produces fewer random encounters than high tension")
    func testLowTensionFewerEncounters() {
        // Low tension engine (chance = 5%)
        let lowEngine = setupForEncounters(tension: 0)
        var lowCount = 0
        for _ in 0..<8 {
            if lowEngine.isGameOver { break }
            lowEngine.performAction(.dismissCurrentEvent)
            let result = lowEngine.performAction(.explore)
            if result.success, let event = lowEngine.currentEvent,
               event.id.hasPrefix("random_encounter_") {
                lowCount += 1
            }
        }

        // High tension engine (chance = 45%)
        let highEngine = setupForEncounters(tension: 90)
        var highCount = 0
        for _ in 0..<8 {
            if highEngine.isGameOver { break }
            highEngine.performAction(.dismissCurrentEvent)
            let result = highEngine.performAction(.explore)
            if result.success, let event = highEngine.currentEvent,
               event.id.hasPrefix("random_encounter_") {
                highCount += 1
            }
        }

        // High tension should produce more encounters on average
        // This is a statistical test; very unlikely to fail with these parameters
        #expect(highCount >= lowCount, "High tension (\(highCount)) should produce >= encounters than low tension (\(lowCount))")
    }
}

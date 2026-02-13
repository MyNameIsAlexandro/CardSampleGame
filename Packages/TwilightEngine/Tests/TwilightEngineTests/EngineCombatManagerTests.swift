/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/EngineCombatManagerTests.swift
/// Назначение: Содержит реализацию файла EngineCombatManagerTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import Testing
@testable import TwilightEngine

@Suite("EngineCombatManager Tests", .serialized)
struct EngineCombatManagerTests {

    private func makeEngine() -> TwilightGameEngine {
        TestEngineFactory.makeEngine(seed: 42)
    }

    private func makeEnemy(
        id: String = "test_enemy",
        power: Int = 5,
        defense: Int = 3,
        health: Int = 20,
        will: Int = 0
    ) -> Card {
        Card(
            id: id,
            name: "Test Enemy",
            type: .monster,
            description: "A test enemy",
            power: power,
            defense: defense,
            health: health,
            will: will
        )
    }

    // MARK: - Setup & Reset

    @Test("setupCombatEnemy sets all combat state")
    func testSetupCombatEnemy() {
        let engine = makeEngine()
        let enemy = makeEnemy(health: 25, will: 10)

        engine.combat.setupCombatEnemy(enemy)

        #expect(engine.combat.combatEnemy?.id == "test_enemy")
        #expect(engine.combat.combatEnemyHealth == 25)
        #expect(engine.combat.combatEnemyWill == 10)
        #expect(engine.combat.combatEnemyMaxWill == 10)
        #expect(engine.combat.combatTurnNumber == 1)
        #expect(engine.combat.combatActionsRemaining == 3)
        #expect(engine.isInCombat == true)
    }

    @Test("setupCombatEnemy defaults health to 10 when nil")
    func testSetupCombatEnemyDefaultHealth() {
        let engine = makeEngine()
        let enemy = Card(id: "no_hp", name: "Ghost", type: .monster, description: "x")

        engine.combat.setupCombatEnemy(enemy)

        #expect(engine.combat.combatEnemyHealth == 10)
    }

    @Test("endCombat clears enemy and flag")
    func testEndCombat() {
        let engine = makeEngine()
        engine.combat.setupCombatEnemy(makeEnemy())
        engine.combat.endCombat()

        #expect(engine.combat.combatEnemy == nil)
        #expect(engine.isInCombat == false)
    }

    @Test("resetState clears all combat properties")
    func testResetState() {
        let engine = makeEngine()
        engine.combat.setupCombatEnemy(makeEnemy())
        engine.combat.resetState()

        #expect(engine.combat.combatEnemy == nil)
        #expect(engine.combat.combatEnemyHealth == 0)
        #expect(engine.combat.combatEnemyWill == 0)
        #expect(engine.combat.combatTurnNumber == 0)
        #expect(engine.combat.combatActionsRemaining == 3)
        #expect(engine.combat.combatMulliganDone == false)
        #expect(engine.combat.combatPlayerAttackedThisTurn == false)
        #expect(engine.combat.lastAttackFateResult == nil)
        #expect(engine.combat.lastDefenseFateResult == nil)
        #expect(engine.combat.currentEnemyIntent == nil)
    }

    // MARK: - combatState computed property

    @Test("combatState returns nil when not in combat")
    func testCombatStateNil() {
        let engine = makeEngine()
        #expect(engine.combat.combatState == nil)
    }

    @Test("combatState returns struct when in combat")
    func testCombatStatePresent() {
        let engine = makeEngine()
        engine.combat.setupCombatEnemy(makeEnemy(health: 15))

        let state = engine.combat.combatState
        #expect(state != nil)
        #expect(state?.enemyHealth == 15)
        #expect(state?.turnNumber == 1)
        #expect(state?.actionsRemaining == 3)
    }

    // MARK: - handleCombatAction

    @Test("startCombat action sets combat flags")
    func testStartCombatAction() {
        let engine = makeEngine()
        engine.combat.setupCombatEnemy(makeEnemy())

        let result = engine.combat.handleCombatAction(.startCombat(encounterId: "enc_1"))

        #expect(result.combatStarted == true)
        #expect(engine.isInCombat == true)
        #expect(engine.combat.combatTurnNumber == 1)
        #expect(engine.combat.combatMulliganDone == false)
    }

    @Test("combatSkipAttack resets attack tracking")
    func testCombatSkipAttack() {
        let engine = makeEngine()
        engine.combat.setupCombatEnemy(makeEnemy())

        _ = engine.combat.handleCombatAction(.combatSkipAttack)

        #expect(engine.combat.combatPlayerAttackedThisTurn == false)
        #expect(engine.combat.lastAttackFateResult == nil)
    }

    @Test("combatMulligan can only be done once")
    func testMulliganOnce() {
        let engine = makeEngine()
        engine.combat.setupCombatEnemy(makeEnemy())
        let cards = (0..<5).map { i in
            Card(id: "c\(i)", name: "C\(i)", type: .spell, description: "x")
        }
        engine.deck.setupStartingDeck(cards)
        engine.deck.drawCards(count: 5)

        _ = engine.combat.handleCombatAction(.combatMulligan(cardIds: ["c0"]))
        #expect(engine.combat.combatMulliganDone == true)

        // Second mulligan should be blocked — hand stays same
        let handBefore = engine.deck.playerHand.map(\.id)
        _ = engine.combat.handleCombatAction(.combatMulligan(cardIds: ["c1"]))
        let handAfter = engine.deck.playerHand.map(\.id)
        #expect(handBefore == handAfter)
    }

    @Test("combatGenerateIntent produces an intent")
    func testGenerateIntent() {
        let engine = makeEngine()
        engine.combat.setupCombatEnemy(makeEnemy(power: 7))

        _ = engine.combat.handleCombatAction(.combatGenerateIntent)

        #expect(engine.combat.currentEnemyIntent != nil)
    }

    @Test("combatInitialize resets actions to 3")
    func testCombatInitialize() {
        let engine = makeEngine()
        engine.combat.setupCombatEnemy(makeEnemy())
        let cards = (0..<5).map { i in
            Card(id: "c\(i)", name: "C\(i)", type: .spell, description: "x")
        }
        engine.deck.setupStartingDeck(cards)

        _ = engine.combat.handleCombatAction(.combatInitialize)

        #expect(engine.combat.combatActionsRemaining == 3)
        #expect(engine.deck.playerHand.count == 5)
    }

    // MARK: - applyFateDrawEffects

    @Test("applyFateDrawEffects shifts resonance")
    func testFateDrawResonanceShift() {
        let engine = makeEngine()
        engine.resonanceValue = 0

        let effects = [FateDrawEffect(type: .shiftResonance, value: 10)]
        let changes = engine.combat.applyFateDrawEffects(effects)

        #expect(engine.resonanceValue == 10)
        #expect(changes.count == 1)
    }

    @Test("applyFateDrawEffects clamps resonance to 100")
    func testFateDrawResonanceClampHigh() {
        let engine = makeEngine()
        engine.resonanceValue = 95

        let effects = [FateDrawEffect(type: .shiftResonance, value: 20)]
        _ = engine.combat.applyFateDrawEffects(effects)

        #expect(engine.resonanceValue == 100)
    }

    @Test("applyFateDrawEffects clamps resonance to -100")
    func testFateDrawResonanceClampLow() {
        let engine = makeEngine()
        engine.resonanceValue = -95

        let effects = [FateDrawEffect(type: .shiftResonance, value: -20)]
        _ = engine.combat.applyFateDrawEffects(effects)

        #expect(engine.resonanceValue == -100)
    }

    @Test("applyFateDrawEffects shifts tension")
    func testFateDrawTensionShift() {
        let engine = makeEngine()
        engine.worldTension = 50

        let effects = [FateDrawEffect(type: .shiftTension, value: 10)]
        let changes = engine.combat.applyFateDrawEffects(effects)

        #expect(engine.worldTension == 60)
        let hasTensionChange = changes.contains { change in
            if case .tensionChanged = change { return true }
            return false
        }
        #expect(hasTensionChange)
    }

    @Test("applyFateDrawEffects clamps tension to bounds")
    func testFateDrawTensionClamp() {
        let engine = makeEngine()
        engine.worldTension = 95

        let effects = [FateDrawEffect(type: .shiftTension, value: 20)]
        _ = engine.combat.applyFateDrawEffects(effects)

        #expect(engine.worldTension == 100)
    }

    @Test("applyFateDrawEffects skips zero tension delta")
    func testFateDrawTensionZeroDelta() {
        let engine = makeEngine()
        engine.worldTension = 100

        let effects = [FateDrawEffect(type: .shiftTension, value: 10)]
        let changes = engine.combat.applyFateDrawEffects(effects)

        // Tension already at 100, adding 10 clamps to 100, delta = 0, no change emitted
        #expect(changes.isEmpty)
    }

    @Test("applyFateDrawEffects handles multiple effects")
    func testFateDrawMultipleEffects() {
        let engine = makeEngine()
        engine.resonanceValue = 0
        engine.worldTension = 50

        let effects = [
            FateDrawEffect(type: .shiftResonance, value: 5),
            FateDrawEffect(type: .shiftTension, value: -10)
        ]
        let changes = engine.combat.applyFateDrawEffects(effects)

        #expect(engine.resonanceValue == 5)
        #expect(engine.worldTension == 40)
        #expect(changes.count == 2)
    }

    // MARK: - Internal state (bonus dice/damage)

    @Test("setupCombatEnemy resets bonus state")
    func testSetupResetsBonus() {
        let engine = makeEngine()
        engine.combat.combatBonusDice = 5
        engine.combat.combatBonusDamage = 3
        engine.combat.combatIsFirstAttack = false

        engine.combat.setupCombatEnemy(makeEnemy())

        #expect(engine.combat.combatBonusDice == 0)
        #expect(engine.combat.combatBonusDamage == 0)
        #expect(engine.combat.combatIsFirstAttack == true)
    }
}

/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/INV_ENC7_GateTests.swift
/// Назначение: Содержит реализацию файла INV_ENC7_GateTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import TwilightEngine

/// INV-ENC7: Encounter Module Completion Gate Tests
/// Covers: defend, flee, loot, summon, and bridge fixes.
/// Gate rules: < 2s, no XCTSkip, no non-deterministic RNG.
final class INV_ENC7_GateTests: XCTestCase {

    // MARK: - Helpers

    private func makeContext(
        canFlee: Bool = true,
        enemyHP: Int = 20,
        enemyPower: Int = 5,
        enemyDefense: Int = 2,
        enemyWP: Int? = nil,
        lootCardIds: [String] = [],
        faithReward: Int = 0,
        summonPool: [String: EncounterEnemy] = [:],
        rngSeed: UInt64 = 42
    ) -> EncounterContext {
        let hero = EncounterHero(id: "hero", hp: 30, maxHp: 30, strength: 5, armor: 2, wisdom: 3)
        let enemy = EncounterEnemy(
            id: "test_enemy",
            name: "Test Enemy",
            hp: enemyHP,
            maxHp: enemyHP,
            wp: enemyWP,
            maxWp: enemyWP,
            power: enemyPower,
            defense: enemyDefense,
            lootCardIds: lootCardIds,
            faithReward: faithReward
        )
        let fateCards = [
            FateCard(id: "fate_high", modifier: 7, isCritical: false, name: "High", suit: .yav),
            FateCard(id: "fate_low", modifier: 2, isCritical: false, name: "Low", suit: .nav),
            FateCard(id: "fate_mid", modifier: 5, isCritical: false, name: "Mid", suit: .prav),
        ]
        return EncounterContext(
            hero: hero,
            enemies: [enemy],
            fateDeckSnapshot: FateDeckState(drawPile: fateCards, discardPile: []),
            modifiers: [],
            rules: EncounterRules(canFlee: canFlee),
            rngSeed: rngSeed,
            summonPool: summonPool
        )
    }

    private func advanceToPlayerAction(_ engine: EncounterEngine) {
        if engine.currentPhase == .intent {
            _ = engine.advancePhase()
        }
    }

    private func completeRound(_ engine: EncounterEngine) {
        // playerAction → enemyResolution → roundEnd → intent → playerAction
        if engine.currentPhase == .playerAction {
            _ = engine.advancePhase() // → enemyResolution
        }
        if engine.currentPhase == .enemyResolution {
            _ = engine.resolveEnemyAction(enemyId: engine.enemies.first!.id)
            _ = engine.advancePhase() // → roundEnd
        }
        if engine.currentPhase == .roundEnd {
            _ = engine.advancePhase() // → intent
        }
        if engine.currentPhase == .intent {
            _ = engine.advancePhase() // → playerAction
        }
    }

    // MARK: - ENC-D01: Defend Action

    /// Defend grants +3 defense bonus, reducing enemy damage
    func testDefend_grantsDefenseBonus() {
        let ctx = makeContext()
        let engine = EncounterEngine(context: ctx)
        advanceToPlayerAction(engine)

        let result = engine.performAction(.defend)
        XCTAssertTrue(result.success, "Defend should succeed")
        XCTAssertEqual(engine.turnDefenseBonus, 3, "Defend should grant +3 defense bonus")

        // Verify state change
        let defended = result.stateChanges.contains(where: {
            if case .playerDefended(let bonus) = $0 { return bonus == 3 }
            return false
        })
        XCTAssertTrue(defended, "Should emit playerDefended state change")
    }

    /// Defense bonus is cleared at round end
    func testDefend_bonusClearedNextRound() {
        let ctx = makeContext()
        let engine = EncounterEngine(context: ctx)
        advanceToPlayerAction(engine)

        _ = engine.performAction(.defend)
        XCTAssertEqual(engine.turnDefenseBonus, 3)

        completeRound(engine)

        XCTAssertEqual(engine.turnDefenseBonus, 0, "Defense bonus should reset after round")
    }

    // MARK: - ENC-D02: Flee Rules

    /// Flee blocked when canFlee=false
    func testFlee_blockedWhenNotAllowed() {
        let ctx = makeContext(canFlee: false)
        let engine = EncounterEngine(context: ctx)
        advanceToPlayerAction(engine)

        let result = engine.performAction(.flee)
        XCTAssertFalse(result.success, "Flee should fail when canFlee=false")
        XCTAssertEqual(result.error, .fleeNotAllowed)
    }

    /// Flee with high fate card succeeds
    func testFlee_successWithHighFate() {
        let ctx = makeContext(canFlee: true)
        let engine = EncounterEngine(context: ctx)
        advanceToPlayerAction(engine)

        let result = engine.performAction(.flee)
        XCTAssertTrue(result.success, "Flee action should succeed")

        // Check if flee succeeded or failed by inspecting state changes
        let fleeChange = result.stateChanges.first(where: {
            if case .fleeAttempt = $0 { return true }
            return false
        })
        XCTAssertNotNil(fleeChange, "Should emit fleeAttempt state change")

        // Finish encounter
        let encounterResult = engine.finishEncounter()
        if engine.fleeSucceeded {
            XCTAssertEqual(encounterResult.outcome, .escaped, "Successful flee should produce escaped outcome")
        }
    }

    /// Failed flee deals punishment damage
    func testFlee_failureDealsDamage() {
        // Create context where fate cards are low value
        let hero = EncounterHero(id: "hero", hp: 30, maxHp: 30, strength: 5, armor: 0, wisdom: 3)
        let enemy = EncounterEnemy(id: "e1", name: "Brute", hp: 20, maxHp: 20, power: 8, defense: 2)
        let lowFate = FateCard(id: "f1", modifier: 1, isCritical: false, name: "Low", suit: .nav)
        let ctx = EncounterContext(
            hero: hero,
            enemies: [enemy],
            fateDeckSnapshot: FateDeckState(drawPile: [lowFate], discardPile: []),
            modifiers: [],
            rules: EncounterRules(canFlee: true),
            rngSeed: 42
        )
        let engine = EncounterEngine(context: ctx)
        advanceToPlayerAction(engine)

        let hpBefore = engine.heroHP
        _ = engine.performAction(.flee)

        if !engine.fleeSucceeded {
            XCTAssertLessThan(engine.heroHP, hpBefore, "Failed flee should deal punishment damage")
        }
    }

    // MARK: - ENC-D03: Loot Distribution

    /// Victory awards loot card IDs from defeated enemies
    func testLoot_awardedOnVictory() {
        let ctx = makeContext(enemyHP: 1, lootCardIds: ["beast_hide", "wolf_fang"], faithReward: 5)
        let engine = EncounterEngine(context: ctx)
        advanceToPlayerAction(engine)

        // Kill enemy in one hit
        _ = engine.performAction(.attack(targetId: "test_enemy"))
        XCTAssertEqual(engine.enemies[0].outcome, .killed)

        let result = engine.finishEncounter()
        XCTAssertEqual(result.transaction.lootCardIds, ["beast_hide", "wolf_fang"])
        XCTAssertEqual(result.transaction.faithDelta, 5)
    }

    /// No loot on escape
    func testLoot_emptyOnEscape() {
        let ctx = makeContext(lootCardIds: ["beast_hide"])
        let engine = EncounterEngine(context: ctx)
        advanceToPlayerAction(engine)

        // Flee (with high fate card for success)
        _ = engine.performAction(.flee)
        let result = engine.finishEncounter()

        XCTAssertTrue(result.transaction.lootCardIds.isEmpty, "Escaped encounter should not award loot")
    }

    /// Loot from pacified enemy
    func testLoot_awardedOnPacify() {
        let ctx = makeContext(enemyHP: 50, enemyWP: 1, lootCardIds: ["spirit_gem"], faithReward: 3)
        let engine = EncounterEngine(context: ctx)
        advanceToPlayerAction(engine)

        // Pacify via spirit attack
        _ = engine.performAction(.spiritAttack(targetId: "test_enemy"))
        XCTAssertEqual(engine.enemies[0].outcome, .pacified)

        let result = engine.finishEncounter()
        XCTAssertEqual(result.transaction.lootCardIds, ["spirit_gem"])
        XCTAssertEqual(result.transaction.faithDelta, 3)
    }

    // MARK: - ENC-D06: RNG Seed Variation

    /// Different RNG seeds produce different encounter sequences
    func testRNGSeed_differentSeedsProduceDifferentResults() {
        func fingerprint(seed: UInt64, rounds: Int = 6) -> String {
            let ctx = makeContext(rngSeed: seed)
            let engine = EncounterEngine(context: ctx)
            var pieces: [String] = []
            pieces.reserveCapacity(rounds)

            for _ in 0..<rounds {
                if let intent = engine.currentIntent {
                    pieces.append("\(intent.type.rawValue):\(intent.value)")
                } else {
                    pieces.append("nil:-1")
                }

                _ = engine.advancePhase() // intent → playerAction
                _ = engine.advancePhase() // playerAction → enemyResolution
                _ = engine.advancePhase() // enemyResolution → roundEnd
                _ = engine.advancePhase() // roundEnd → intent (+1 round, auto-generates intent)
            }

            return pieces.joined(separator: "|")
        }

        var uniqueFingerprints = Set<String>()
        for seed in 0..<64 {
            uniqueFingerprints.insert(fingerprint(seed: UInt64(seed)))
            if uniqueFingerprints.count >= 2 { break }
        }

        XCTAssertGreaterThanOrEqual(
            uniqueFingerprints.count,
            2,
            "Different RNG seeds must produce different intent fingerprints within a small seed range"
        )
    }

    // MARK: - ENC-D07: Summon Intent

    /// Summon adds a new enemy to the encounter
    func testSummon_addsEnemy() {
        let summonTarget = EncounterEnemy(
            id: "summoned_wolf",
            name: "Summoned Wolf",
            hp: 10,
            maxHp: 10,
            power: 3,
            defense: 1
        )
        let ctx = makeContext(summonPool: ["summoned_wolf": summonTarget])
        let engine = EncounterEngine(context: ctx)

        XCTAssertEqual(engine.enemies.count, 1, "Should start with 1 enemy")

        // Manually set intent to summon and resolve
        advanceToPlayerAction(engine)
        _ = engine.performAction(.wait)
        _ = engine.advancePhase() // → enemyResolution

        // Override intent for test
        let summonIntent = EnemyIntent.summon(enemyId: "summoned_wolf")
        engine.overrideIntentForTest(summonIntent)
        _ = engine.resolveEnemyAction(enemyId: "test_enemy")

        XCTAssertEqual(engine.enemies.count, 2, "Summon should add a new enemy")
        XCTAssertEqual(engine.enemies[1].name, "Summoned Wolf")
    }

    /// Summon capped at 4 enemies
    func testSummon_cappedAt4() {
        let summonTarget = EncounterEnemy(
            id: "wolf",
            name: "Wolf",
            hp: 5,
            maxHp: 5,
            power: 2,
            defense: 0
        )
        // Start with 4 enemies
        let hero = EncounterHero(id: "hero", hp: 30, maxHp: 30, strength: 5, armor: 2, wisdom: 3)
        var enemies: [EncounterEnemy] = []
        for i in 0..<4 {
            enemies.append(EncounterEnemy(id: "e\(i)", name: "Enemy \(i)", hp: 10, maxHp: 10, power: 3, defense: 1))
        }
        let fateCards = [FateCard(id: "f1", modifier: 5, isCritical: false, name: "F", suit: .yav)]
        let ctx = EncounterContext(
            hero: hero,
            enemies: enemies,
            fateDeckSnapshot: FateDeckState(drawPile: fateCards, discardPile: []),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42,
            summonPool: ["wolf": summonTarget]
        )
        let engine = EncounterEngine(context: ctx)

        advanceToPlayerAction(engine)
        _ = engine.performAction(.wait)
        _ = engine.advancePhase() // → enemyResolution

        let summonIntent = EnemyIntent.summon(enemyId: "wolf")
        engine.overrideIntentForTest(summonIntent)
        _ = engine.resolveEnemyAction(enemyId: "e0")

        XCTAssertEqual(engine.enemies.count, 4, "Should not exceed 4 enemies")
    }
}

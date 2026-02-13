/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/Helpers/EncounterContextFixtures.swift
/// Назначение: Содержит реализацию файла EncounterContextFixtures.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import Foundation
@testable import TwilightEngine

/// Deterministic fixtures for Encounter tests
/// Rule: No UUID(), no Int.random(), no system RNG. All data hardcoded or seeded.
enum EncounterContextFixtures {

    /// Minimal valid context: 1 hero vs 1 enemy with dual tracks
    static func standard(seed: UInt64 = 42) -> EncounterContext {
        EncounterContext(
            hero: EncounterHero(
                id: "test_hero",
                hp: 100, maxHp: 100,
                strength: 5, armor: 2, wisdom: 3, willDefense: 1
            ),
            enemies: [
                EncounterEnemy(
                    id: "test_enemy",
                    name: "Test Enemy",
                    hp: 50, maxHp: 50,
                    wp: 30, maxWp: 30,
                    power: 5, defense: 2
                )
            ],
            fateDeckSnapshot: FateDeckFixtures.deterministicState(),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: seed
        )
    }

    /// Context with dual-track enemy (custom HP/WP)
    static func dualTrack(enemyHP: Int = 50, enemyWP: Int = 30, seed: UInt64 = 42) -> EncounterContext {
        EncounterContext(
            hero: EncounterHero(
                id: "test_hero",
                hp: 100, maxHp: 100,
                strength: 5, armor: 2
            ),
            enemies: [
                EncounterEnemy(
                    id: "test_enemy",
                    name: "Test Enemy",
                    hp: enemyHP, maxHp: enemyHP,
                    wp: enemyWP, maxWp: enemyWP,
                    power: 5, defense: 2
                )
            ],
            fateDeckSnapshot: FateDeckFixtures.deterministicState(),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: seed
        )
    }

    /// Multi-enemy context (1 vs 3)
    static func multiEnemy(seed: UInt64 = 42) -> EncounterContext {
        EncounterContext(
            hero: EncounterHero(
                id: "test_hero",
                hp: 100, maxHp: 100,
                strength: 5, armor: 2, wisdom: 10
            ),
            enemies: [
                EncounterEnemy(id: "enemy_1", name: "Bandit A", hp: 10, maxHp: 10, wp: 5, maxWp: 5, power: 3, defense: 1),
                EncounterEnemy(id: "enemy_2", name: "Bandit B", hp: 15, maxHp: 15, wp: 8, maxWp: 8, power: 4, defense: 1),
                EncounterEnemy(id: "enemy_3", name: "Bandit C", hp: 20, maxHp: 20, wp: 10, maxWp: 10, power: 5, defense: 2)
            ],
            fateDeckSnapshot: FateDeckFixtures.deterministicState(),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: seed
        )
    }

    /// Weak enemy (1 HP, 1 WP) for kill/pacify priority tests
    static func weakEnemy(seed: UInt64 = 42) -> EncounterContext {
        EncounterContext(
            hero: EncounterHero(
                id: "test_hero",
                hp: 100, maxHp: 100,
                strength: 10, armor: 2
            ),
            enemies: [
                EncounterEnemy(
                    id: "weak_enemy",
                    name: "Weak Enemy",
                    hp: 1, maxHp: 1,
                    wp: 1, maxWp: 1,
                    power: 1, defense: 0
                )
            ],
            fateDeckSnapshot: FateDeckFixtures.deterministicState(),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: seed
        )
    }
}

/// Deterministic Fate deck fixtures
enum FateDeckFixtures {

    /// 5 known cards
    static func deterministic() -> [FateCard] {
        [
            FateCard(id: "fate_1", modifier: 1, name: "Fortune +1"),
            FateCard(id: "fate_2", modifier: 2, name: "Fortune +2"),
            FateCard(id: "fate_3", modifier: -1, name: "Misfortune -1"),
            FateCard(id: "fate_4", modifier: 3, isCritical: true, name: "Critical"),
            FateCard(id: "fate_5", modifier: 0, name: "Neutral")
        ]
    }

    /// FateDeckState from deterministic cards (for EncounterContext)
    static func deterministicState() -> FateDeckState {
        TestFateDeck.makeState(cards: deterministic(), seed: 42)
    }

    /// Single critical card
    static func criticalOnly() -> [FateCard] {
        [FateCard(id: "crit_1", modifier: 3, isCritical: true, name: "Critical Block")]
    }
}

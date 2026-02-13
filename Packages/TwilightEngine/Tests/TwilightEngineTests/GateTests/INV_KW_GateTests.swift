/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/GateTests/INV_KW_GateTests.swift
/// Назначение: Содержит реализацию файла INV_KW_GateTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import TwilightEngine

/// INV-KW: Keyword Effect Gate Tests
/// Verifies that all 5 fate keywords produce correct special effects
/// in combat (physical/spiritual) and defense contexts.
/// Gate rules: < 2s, no XCTSkip, no non-deterministic RNG.
final class INV_KW_GateTests: XCTestCase {

    // MARK: - Helpers

    /// Create encounter context with a single-card fate deck bearing the given keyword
    func makeContext(keyword: FateKeyword, suit: FateCardSuit? = nil, heroHP: Int = 50, seed: UInt64 = 42) -> EncounterContext {
        let fateCard = FateCard(id: "kw_card", modifier: 2, name: "KW Card", suit: suit, keyword: keyword)
        return EncounterContext(
            hero: EncounterHero(id: "hero", hp: heroHP, maxHp: 100, strength: 5, armor: 2, wisdom: 5, willDefense: 1),
            enemies: [
                EncounterEnemy(id: "enemy", name: "Enemy", hp: 50, maxHp: 50, wp: 30, maxWp: 30, power: 10, defense: 3)
            ],
            fateDeckSnapshot: TestFateDeck.makeState(cards: [fateCard], seed: seed),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: seed
        )
    }

    func startAndAttack(_ engine: EncounterEngine) -> EncounterActionResult {
        _ = engine.generateIntent(for: "enemy")
        _ = engine.advancePhase() // → playerAction
        return engine.performAction(.attack(targetId: "enemy"))
    }

    func startAndSpiritAttack(_ engine: EncounterEngine) -> EncounterActionResult {
        _ = engine.generateIntent(for: "enemy")
        _ = engine.advancePhase() // → playerAction
        return engine.performAction(.spiritAttack(targetId: "enemy"))
    }
    /// Helper: create context with a card that has realm and faith cost
    func makeCardContext(realm: Realm, faithCost: Int = 2, resonance: Float = 0) -> EncounterContext {
        let card = Card(
            id: "realm_card", name: "Realm Card", type: .spell, description: "Test",
            abilities: [CardAbility(id: "a1", name: "Hit", description: "dmg", effect: .damage(amount: 1, type: .physical))],
            realm: realm, faithCost: faithCost
        )
        let fateCard = FateCard(id: "fate1", modifier: 1, name: "Fate", suit: nil, keyword: nil)
        return EncounterContext(
            hero: EncounterHero(id: "hero", hp: 50, maxHp: 100, strength: 5, armor: 2, wisdom: 5, willDefense: 1),
            enemies: [
                EncounterEnemy(id: "enemy", name: "Enemy", hp: 50, maxHp: 50, wp: 30, maxWp: 30, power: 10, defense: 3)
            ],
            fateDeckSnapshot: TestFateDeck.makeState(cards: [fateCard], seed: 42),
            modifiers: [],
            rules: EncounterRules(),
            rngSeed: 42,
            worldResonance: resonance,
            heroCards: [card],
            heroFaith: 10
        )
    }
}

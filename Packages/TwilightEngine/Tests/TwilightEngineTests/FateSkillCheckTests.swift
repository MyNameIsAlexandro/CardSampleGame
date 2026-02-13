/// Файл: Packages/TwilightEngine/Tests/TwilightEngineTests/FateSkillCheckTests.swift
/// Назначение: Содержит реализацию файла FateSkillCheckTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import TwilightEngine
import TwilightEngineDevTools

/// Tests for Fate Deck integration with SkillCheckResolver (Task 4.1)
final class FateSkillCheckTests: XCTestCase {

    // MARK: - SkillCheckResolver with Fate Deck

    func testSkillCheckUseFateDeckWhenAvailable() {
        let resolver = SkillCheckResolver()
        // Create a deck with only +3 cards (guaranteed success)
        let cards = [FateCard(id: "f1", modifier: 3, isCritical: true, isSticky: false, name: "Crit")]
        resolver.fateDeck = TestFateDeck.makeManager(cards: cards, seed: 42)

        let challenge = MiniGameChallenge(
            id: "test",
            type: .skillCheck,
            difficulty: 1,
            rewards: MiniGameRewards(flagsToSet: ["test_passed"])
        )
        let context = MiniGameContext(
            playerHealth: 10, playerMaxHealth: 10,
            playerStrength: 5, playerFaith: 3, playerBalance: 50,
            playerResources: [:], worldTension: 0, currentFlags: [:]
        )

        let result = resolver.resolve(challenge: challenge, context: context, rng: TestRNG.make(seed: 42))
        // strength(5) + fateModifier(3) = 8 >= difficulty*3 = 3
        XCTAssertTrue(result.stateChanges.contains(.flagSet(key: "test_passed", value: true)),
                      "Skill check with strong fate card should succeed")
    }

    func testSkillCheckFailsWithBadFateCard() {
        let resolver = SkillCheckResolver()
        // Create a deck with only -2 cards
        let cards = [FateCard(id: "f1", modifier: -2, isCritical: false, isSticky: true, name: "Curse")]
        resolver.fateDeck = TestFateDeck.makeManager(cards: cards, seed: 42)

        let challenge = MiniGameChallenge(
            id: "test",
            type: .skillCheck,
            difficulty: 3, // targetNumber = 9
            rewards: MiniGameRewards(flagsToSet: ["test_passed"])
        )
        let context = MiniGameContext(
            playerHealth: 10, playerMaxHealth: 10,
            playerStrength: 5, playerFaith: 3, playerBalance: 50,
            playerResources: [:], worldTension: 0, currentFlags: [:]
        )

        let result = resolver.resolve(challenge: challenge, context: context, rng: TestRNG.make(seed: 42))
        // strength(5) + fateModifier(-2) = 3 < targetNumber(9)
        XCTAssertFalse(result.stateChanges.contains(.flagSet(key: "test_passed", value: true)),
                       "Skill check with bad fate card should fail")
    }

    func testSkillCheckFallbackWithoutFateDeck() {
        let resolver = SkillCheckResolver()
        // No fateDeck set — should use WorldRNG fallback

        let challenge = MiniGameChallenge(
            id: "test",
            type: .skillCheck,
            difficulty: 1
        )
        let context = MiniGameContext(
            playerHealth: 10, playerMaxHealth: 10,
            playerStrength: 5, playerFaith: 3, playerBalance: 50,
            playerResources: [:], worldTension: 0, currentFlags: [:]
        )

        // Should not crash — falls back to RNG
        let result = resolver.resolve(challenge: challenge, context: context, rng: TestRNG.make(seed: 42))
        XCTAssertTrue(result.completed, "Skill check should complete even without fate deck")
    }

    func testSkillCheckDrawsFateCard() {
        let resolver = SkillCheckResolver()
        let cards = [
            FateCard(id: "f1", modifier: 0, isCritical: false, isSticky: false, name: "A"),
            FateCard(id: "f2", modifier: 1, isCritical: false, isSticky: false, name: "B"),
        ]
        let deck = TestFateDeck.makeManager(cards: cards, seed: 42)
        resolver.fateDeck = deck

        let challenge = MiniGameChallenge(id: "test", type: .skillCheck, difficulty: 1)
        let context = MiniGameContext(
            playerHealth: 10, playerMaxHealth: 10,
            playerStrength: 5, playerFaith: 3, playerBalance: 50,
            playerResources: [:], worldTension: 0, currentFlags: [:]
        )

        _ = resolver.resolve(challenge: challenge, context: context, rng: TestRNG.make(seed: 42))

        // One card should have been drawn (moved to discard)
        XCTAssertEqual(deck.discardPile.count, 1, "Fate deck should have one card in discard after skill check")
    }

    // MARK: - Engine Fate Deck Setup

    func testEngineSetupFateDeck() {
        let engine = TestEngineFactory.makeEngine(seed: 42)
        XCTAssertNil(engine.fateDeck, "Fate deck should be nil before setup")

        let cards = [FateCard(id: "f1", modifier: 0, isCritical: false, isSticky: false, name: "Test")]
        engine.setupFateDeck(cards: cards)

        XCTAssertNotNil(engine.fateDeck, "Fate deck should be set after setup")
        XCTAssertEqual(engine.fateDeck?.drawPile.count, 1)
    }

    // MARK: - MiniGameDispatcher Fate Deck Wiring

    func testDispatcherPassesFateDeckToResolver() {
        let dispatcher = MiniGameDispatcher(rng: TestRNG.make(seed: 42))
        let cards = [FateCard(id: "f1", modifier: 3, isCritical: true, isSticky: false, name: "Crit")]
        let deck = TestFateDeck.makeManager(cards: cards, seed: 42)
        dispatcher.setFateDeck(deck)

        let challenge = MiniGameChallenge(
            id: "test",
            type: .skillCheck,
            difficulty: 1,
            rewards: MiniGameRewards(flagsToSet: ["wired"])
        )
        let context = MiniGameContext(
            playerHealth: 10, playerMaxHealth: 10,
            playerStrength: 5, playerFaith: 3, playerBalance: 50,
            playerResources: [:], worldTension: 0, currentFlags: [:]
        )

        let result = dispatcher.dispatch(challenge: challenge, context: context)
        XCTAssertTrue(result.stateChanges.contains(.flagSet(key: "wired", value: true)),
                      "Dispatcher should route skill check through fate deck")
    }
}

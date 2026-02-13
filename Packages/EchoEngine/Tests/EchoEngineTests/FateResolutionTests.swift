/// Файл: Packages/EchoEngine/Tests/EchoEngineTests/FateResolutionTests.swift
/// Назначение: Содержит реализацию файла FateResolutionTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import Testing
import FirebladeECS
import TwilightEngine
@testable import EchoEngine

@Suite("Fate Resolution Tests")
struct FateResolutionTests {

    // MARK: - Helpers

    private func makeFateCard(
        id: String = "test",
        baseValue: Int = 1,
        suit: FateCardSuit? = nil,
        keyword: FateKeyword? = nil,
        isCritical: Bool = false
    ) -> FateCard {
        FateCard(
            id: id,
            modifier: baseValue,
            isCritical: isCritical,
            name: "Test",
            suit: suit,
            keyword: keyword
        )
    }

    private func makeService() -> FateResolutionService {
        FateResolutionService()
    }

    // MARK: - FateResolutionService Tests

    @Test("Resolve returns nil when deck is empty")
    func testResolveEmptyDeck() {
        let service = makeService()
        let rng = WorldRNG(seed: 1)
        let deck = FateDeckManager(cards: [], rng: rng)

        let result = service.resolve(context: .combatPhysical, fateDeck: deck, worldResonance: 0)

        #expect(result == nil)
    }

    @Test("Resolve returns card with effectiveValue")
    func testResolveBasic() {
        let service = makeService()
        let rng = WorldRNG(seed: 1)
        let card = makeFateCard(baseValue: 2)
        let deck = FateDeckManager(cards: [card], rng: rng)

        let result = service.resolve(context: .combatPhysical, fateDeck: deck, worldResonance: 0)

        #expect(result != nil)
        #expect(result!.effectiveValue == 2)
        #expect(result!.keyword == nil)
        #expect(result!.keywordEffect == .none)
    }

    @Test("Surge keyword gives bonusDamage in combatPhysical context")
    func testSurgeKeyword() {
        let service = makeService()
        let rng = WorldRNG(seed: 1)
        let card = makeFateCard(baseValue: 1, keyword: .surge)
        let deck = FateDeckManager(cards: [card], rng: rng)

        let result = service.resolve(context: .combatPhysical, fateDeck: deck, worldResonance: 0)!

        #expect(result.keyword == .surge)
        #expect(result.keywordEffect.bonusDamage == 2)
    }

    @Test("Focus keyword gives ignore_armor special in combatPhysical")
    func testFocusKeyword() {
        let service = makeService()
        let rng = WorldRNG(seed: 1)
        let card = makeFateCard(baseValue: 0, keyword: .focus)
        let deck = FateDeckManager(cards: [card], rng: rng)

        let result = service.resolve(context: .combatPhysical, fateDeck: deck, worldResonance: 0)!

        #expect(result.keywordEffect.special == "ignore_armor")
        #expect(result.keywordEffect.bonusDamage == 1)
    }

    @Test("Ward keyword gives fortify special in defense context")
    func testWardDefense() {
        let service = makeService()
        let rng = WorldRNG(seed: 1)
        let card = makeFateCard(baseValue: 1, keyword: .ward)
        let deck = FateDeckManager(cards: [card], rng: rng)

        let result = service.resolve(context: .defense, fateDeck: deck, worldResonance: 0)!

        #expect(result.keywordEffect.bonusValue == 3)
        #expect(result.keywordEffect.special == "fortify")
    }

    @Test("Shadow keyword gives evade special in defense context")
    func testShadowDefenseEvade() {
        let service = makeService()
        let rng = WorldRNG(seed: 1)
        let card = makeFateCard(baseValue: 0, keyword: .shadow)
        let deck = FateDeckManager(cards: [card], rng: rng)

        let result = service.resolve(context: .defense, fateDeck: deck, worldResonance: 0)!

        #expect(result.keywordEffect.special == "evade")
    }

    // MARK: - Suit Match Tests

    @Test("Nav suit matches combatPhysical")
    func testNavSuitMatchPhysical() {
        #expect(FateResolutionService.suitMatches(suit: .nav, context: .combatPhysical))
        #expect(!FateResolutionService.suitMatches(suit: .nav, context: .combatSpiritual))
    }

    @Test("Prav suit matches combatSpiritual")
    func testPravSuitMatchSpiritual() {
        #expect(FateResolutionService.suitMatches(suit: .prav, context: .combatSpiritual))
        #expect(!FateResolutionService.suitMatches(suit: .prav, context: .combatPhysical))
    }

    @Test("Suit match amplifies keyword effect")
    func testSuitMatchAmplifies() {
        let service = makeService()
        let rng = WorldRNG(seed: 1)
        // Nav suit + combatPhysical = match → surge bonusDamage doubled (2 * 2.0 = 4)
        let card = makeFateCard(baseValue: 1, suit: .nav, keyword: .surge)
        let deck = FateDeckManager(cards: [card], rng: rng)

        let result = service.resolve(context: .combatPhysical, fateDeck: deck, worldResonance: 0)!

        #expect(result.suitMatch == true)
        #expect(result.keywordEffect.bonusDamage == 4) // 2 * 2.0 matchMultiplier
    }

    @Test("Suit mismatch nullifies keyword effect")
    func testSuitMismatchNullifies() {
        let service = makeService()
        let rng = WorldRNG(seed: 1)
        // Prav suit + combatPhysical = mismatch → keyword suppressed
        let card = makeFateCard(baseValue: 1, suit: .prav, keyword: .surge)
        let deck = FateDeckManager(cards: [card], rng: rng)

        let result = service.resolve(context: .combatPhysical, fateDeck: deck, worldResonance: 0)!

        #expect(result.suitMatch == false)
        #expect(result.keywordEffect.bonusDamage == 0)
    }

    @Test("Critical card is reported in resolution")
    func testCriticalCard() {
        let service = makeService()
        let rng = WorldRNG(seed: 1)
        let card = makeFateCard(baseValue: 3, isCritical: true)
        let deck = FateDeckManager(cards: [card], rng: rng)

        let result = service.resolve(context: .combatPhysical, fateDeck: deck, worldResonance: 0)!

        #expect(result.isCritical == true)
    }

    // MARK: - Integration with CombatSystem

    @Test("playerAttack applies keyword bonusDamage from surge")
    func testPlayerAttackWithSurge() {
        let rng = WorldRNG(seed: 1)
        let nexus = Nexus()

        // Surge card with nav suit for match
        let card = makeFateCard(baseValue: 1, suit: .nav, keyword: .surge)
        let fateDeck = FateDeckManager(cards: [card], rng: rng)

        let combat = nexus.createEntity()
        combat.assign(CombatStateComponent())
        combat.assign(ResonanceComponent(value: 0))
        combat.assign(FateDeckComponent(fateDeck: fateDeck))

        let player = nexus.createEntity()
        player.assign(PlayerTagComponent(name: "Hero", strength: 3))
        player.assign(HealthComponent(current: 10, max: 10))

        let enemy = nexus.createEntity()
        enemy.assign(EnemyTagComponent(definitionId: "wolf", power: 4, defense: 2))
        enemy.assign(HealthComponent(current: 20, max: 20))
        enemy.assign(IntentComponent())

        let system = CombatSystem()
        let event = system.playerAttack(player: player, enemy: enemy, nexus: nexus)

        // strength(3) + keywordBonus(4, surge matched) + fateValue(1) = 8
        // 8 >= defense(2) → damage = 8 - 2 + 1 = 7
        if case .playerAttacked(let damage, _, _, let resolution) = event {
            #expect(damage == 7)
            #expect(resolution != nil)
            #expect(resolution?.suitMatch == true)
            #expect(resolution?.keyword == .surge)
        } else {
            #expect(Bool(false), "Expected playerAttacked")
        }
    }

    @Test("playerAttack with focus ignore_armor bypasses defense")
    func testPlayerAttackIgnoreArmor() {
        let rng = WorldRNG(seed: 1)
        let nexus = Nexus()

        let card = makeFateCard(baseValue: 0, keyword: .focus)
        let fateDeck = FateDeckManager(cards: [card], rng: rng)

        let combat = nexus.createEntity()
        combat.assign(CombatStateComponent())
        combat.assign(ResonanceComponent(value: 0))
        combat.assign(FateDeckComponent(fateDeck: fateDeck))

        let player = nexus.createEntity()
        player.assign(PlayerTagComponent(name: "Hero", strength: 2))
        player.assign(HealthComponent(current: 10, max: 10))

        let enemy = nexus.createEntity()
        enemy.assign(EnemyTagComponent(definitionId: "wolf", power: 4, defense: 10))
        enemy.assign(HealthComponent(current: 20, max: 20))
        enemy.assign(IntentComponent())

        let system = CombatSystem()
        let event = system.playerAttack(player: player, enemy: enemy, nexus: nexus)

        // strength(2) + keywordBonus(1, focus) + fateValue(0) = 3, defense ignored (0)
        // 3 >= 0 → damage = 3 - 0 + 1 = 4
        if case .playerAttacked(let damage, _, _, let resolution) = event {
            #expect(damage == 4)
            #expect(resolution?.keywordEffect.special == "ignore_armor")
        } else {
            #expect(Bool(false), "Expected playerAttacked")
        }
    }

    @Test("Enemy attack with ward keyword reduces damage extra")
    func testEnemyAttackWithWardDefense() {
        let rng = WorldRNG(seed: 1)
        let nexus = Nexus()

        // Ward card in defense context → bonusValue 3
        let card = makeFateCard(baseValue: 1, keyword: .ward)
        let fateDeck = FateDeckManager(cards: [card], rng: rng)

        let combat = nexus.createEntity()
        combat.assign(CombatStateComponent())
        combat.assign(ResonanceComponent(value: 0))
        combat.assign(FateDeckComponent(fateDeck: fateDeck))

        let player = nexus.createEntity()
        player.assign(PlayerTagComponent(name: "Hero", strength: 3))
        player.assign(HealthComponent(current: 20, max: 20))
        player.assign(StatusEffectComponent())

        let enemy = nexus.createEntity()
        enemy.assign(EnemyTagComponent(definitionId: "wolf", power: 4, defense: 2))
        enemy.assign(HealthComponent(current: 10, max: 10))
        // Enemy intends to attack for 6
        enemy.assign(IntentComponent(intent: .attack(damage: 6)))

        let system = CombatSystem()
        let event = system.resolveEnemyIntent(enemy: enemy, player: player, nexus: nexus)

        // Enemy attacks for 6, defense reduction = fateValue(1) + keywordBonus(3) = 4
        // actualDamage = max(0, 6 - 4) = 2
        if case .enemyAttacked(let damage, _, _, _) = event {
            #expect(damage == 2)
        } else {
            #expect(Bool(false), "Expected enemyAttacked")
        }
    }

    @Test("Enemy attack with shadow evade results in zero damage")
    func testEnemyAttackWithShadowEvade() {
        let rng = WorldRNG(seed: 1)
        let nexus = Nexus()

        let card = makeFateCard(baseValue: 0, keyword: .shadow)
        let fateDeck = FateDeckManager(cards: [card], rng: rng)

        let combat = nexus.createEntity()
        combat.assign(CombatStateComponent())
        combat.assign(ResonanceComponent(value: 0))
        combat.assign(FateDeckComponent(fateDeck: fateDeck))

        let player = nexus.createEntity()
        player.assign(PlayerTagComponent(name: "Hero", strength: 3))
        player.assign(HealthComponent(current: 20, max: 20))
        player.assign(StatusEffectComponent())

        let enemy = nexus.createEntity()
        enemy.assign(EnemyTagComponent(definitionId: "wolf", power: 4, defense: 2))
        enemy.assign(HealthComponent(current: 10, max: 10))
        enemy.assign(IntentComponent(intent: .attack(damage: 10)))

        let system = CombatSystem()
        let event = system.resolveEnemyIntent(enemy: enemy, player: player, nexus: nexus)

        // Shadow evade → 0 damage
        if case .enemyAttacked(let damage, _, _, _) = event {
            #expect(damage == 0)
            let health: HealthComponent = nexus.get(unsafe: player.identifier)
            #expect(health.current == 20)
        } else {
            #expect(Bool(false), "Expected enemyAttacked")
        }
    }
}

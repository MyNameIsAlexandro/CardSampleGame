/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Combat/CombatSimulation.swift
/// Назначение: Pure-logic state machine для Ritual Combat (Phase 3).
/// Зона ответственности: Управление hand/effort/selection/enemies, делегирование расчётов в CombatCalculator.
/// Контекст: R1 Effort mechanic. Не содержит UI. Reference: RITUAL_COMBAT_TEST_MODEL.md §3.2

import Foundation

/// Pure-logic combat simulation for Ritual Combat.
/// State is `public internal(set)`; mutations only through designated methods.
/// Delegates attack math to `CombatCalculator`.
public final class CombatSimulation {

    // MARK: - Public State (read-only externally, mutable within module)

    /// Cards currently in hand
    public internal(set) var hand: [Card]

    /// Cards discarded (recyclable)
    public internal(set) var discardPile: [Card] = []

    /// Cards exhausted (removed from play)
    public internal(set) var exhaustPile: [Card] = []

    /// Current effort bonus (number of cards burned this turn)
    public internal(set) var effortBonus: Int = 0

    /// IDs of cards burned for effort this turn
    public internal(set) var effortCardIds: [String] = []

    /// IDs of cards selected for the current action
    public internal(set) var selectedCardIds: Set<String> = []

    /// Available energy for card play
    public internal(set) var energy: Int

    /// Energy reserved by played cards
    public internal(set) var reservedEnergy: Int

    /// Maximum cards that can be burned for effort per turn
    public let maxEffort: Int

    /// Hero hit points
    public internal(set) var heroHP: Int

    /// Hero maximum hit points (immutable, set at combat start)
    public let heroMaxHP: Int

    /// Hero base strength (physical attack base)
    public let heroStrength: Int

    /// Hero wisdom (spirit attack base)
    public let heroWisdom: Int

    /// Hero armor value
    public let heroArmor: Int

    /// Mutable enemy states
    public internal(set) var enemies: [EncounterEnemyState]

    /// Current phase of combat
    public internal(set) var phase: CombatSimulationPhase = .playerAction

    /// Current round number
    public internal(set) var round: Int = 1

    /// Number of cards in fate draw pile
    public var fateDeckCount: Int { fateDeck.drawPile.count }

    /// Number of cards in fate discard pile
    public var fateDiscardCount: Int { fateDeck.discardPile.count }

    // MARK: - Internal State

    let rng: WorldRNG
    var fateDeck: FateDeckManager
    let worldResonance: Float
    let balanceConfig: CombatBalanceConfig

    // MARK: - Init

    public init(
        hand: [Card],
        heroHP: Int,
        heroStrength: Int,
        heroWisdom: Int = 0,
        heroArmor: Int,
        enemies: [EncounterEnemy],
        fateDeckState: FateDeckState,
        rngSeed: UInt64,
        worldResonance: Float = 0,
        balanceConfig: CombatBalanceConfig = .default,
        maxEffort: Int = 2,
        energy: Int = 3,
        reservedEnergy: Int = 0
    ) {
        self.hand = hand
        self.heroHP = heroHP
        self.heroMaxHP = heroHP
        self.heroStrength = heroStrength
        self.heroWisdom = heroWisdom > 0 ? heroWisdom : heroStrength
        self.heroArmor = heroArmor
        self.enemies = enemies.map { EncounterEnemyState(from: $0) }
        self.worldResonance = worldResonance
        self.balanceConfig = balanceConfig
        self.maxEffort = maxEffort
        self.energy = energy
        self.reservedEnergy = reservedEnergy

        self.rng = WorldRNG(seed: rngSeed)
        self.fateDeck = FateDeckManager(cards: [], rng: rng)
        self.fateDeck.restoreState(fateDeckState)
    }

    /// Internal init for restore (takes pre-built state directly)
    init(
        hand: [Card],
        discardPile: [Card],
        exhaustPile: [Card],
        effortBonus: Int,
        effortCardIds: [String],
        selectedCardIds: Set<String>,
        energy: Int,
        reservedEnergy: Int,
        maxEffort: Int,
        heroHP: Int,
        heroMaxHP: Int,
        heroStrength: Int,
        heroWisdom: Int,
        heroArmor: Int,
        enemies: [EncounterEnemyState],
        fateDeckState: FateDeckState,
        rngSeed: UInt64,
        rngState: UInt64,
        worldResonance: Float,
        balanceConfig: CombatBalanceConfig,
        phase: CombatSimulationPhase,
        round: Int
    ) {
        self.hand = hand
        self.discardPile = discardPile
        self.exhaustPile = exhaustPile
        self.effortBonus = effortBonus
        self.effortCardIds = effortCardIds
        self.selectedCardIds = selectedCardIds
        self.energy = energy
        self.reservedEnergy = reservedEnergy
        self.maxEffort = maxEffort
        self.heroHP = heroHP
        self.heroMaxHP = heroMaxHP
        self.heroStrength = heroStrength
        self.heroWisdom = heroWisdom
        self.heroArmor = heroArmor
        self.enemies = enemies
        self.worldResonance = worldResonance
        self.balanceConfig = balanceConfig
        self.phase = phase
        self.round = round

        self.rng = WorldRNG(seed: rngSeed)
        self.rng.restoreState(rngState)
        self.fateDeck = FateDeckManager(cards: [], rng: rng)
        self.fateDeck.restoreState(fateDeckState)
    }

    // MARK: - Card Selection

    /// Select a card for the current action.
    public func selectCard(_ cardId: String) {
        guard hand.contains(where: { $0.id == cardId }) else { return }
        selectedCardIds.insert(cardId)
    }

    /// Remove a card from the ritual circle selection.
    public func deselectCard(_ cardId: String) {
        selectedCardIds.remove(cardId)
    }

    // MARK: - Standard Test Fixture

    /// Creates a standard fixture for testing:
    /// hero (str=5, armor=0, hp=100, maxEffort=2), 5 cards, 1 enemy (hp=10, wp=8, def=0).
    public static func makeStandard(seed: UInt64 = 42) -> CombatSimulation {
        let cards = (0..<5).map { i in
            Card(
                id: "card_\(["a", "b", "c", "d", "e"][i])",
                name: "Test Card \(i)",
                type: .item,
                description: "Test card for fixture"
            )
        }

        let fateCards = [
            FateCard(id: "fate_test_1", modifier: 1, name: "Test Fate 1"),
            FateCard(id: "fate_test_2", modifier: 0, name: "Test Fate 2"),
            FateCard(id: "fate_test_3", modifier: -1, name: "Test Fate 3")
        ]

        let fateRng = WorldRNG(seed: seed)
        let fateDeckManager = FateDeckManager(cards: fateCards, rng: fateRng)
        let fateDeckState = fateDeckManager.getState()

        let enemy = EncounterEnemy(
            id: "enemy",
            name: "Test Enemy",
            hp: 10,
            maxHp: 10,
            wp: 8,
            maxWp: 8,
            defense: 0
        )

        return CombatSimulation(
            hand: cards,
            heroHP: 100,
            heroStrength: 5,
            heroArmor: 0,
            enemies: [enemy],
            fateDeckState: fateDeckState,
            rngSeed: seed,
            worldResonance: 0,
            balanceConfig: .default,
            maxEffort: 2,
            energy: 3,
            reservedEnergy: 0
        )
    }
}

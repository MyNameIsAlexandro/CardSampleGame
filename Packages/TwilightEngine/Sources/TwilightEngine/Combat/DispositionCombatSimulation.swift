/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Combat/DispositionCombatSimulation.swift
/// Назначение: Pure-logic state machine для Disposition Combat (Phase 3).
/// Зона ответственности: Управление disposition track, momentum, energy, sacrifice; делегирование расчётов в DispositionCalculator.
/// Контекст: Disposition combat — дуальный исход (destroyed/subjugated). Epic 21: plea backlash. Reference: RITUAL_COMBAT_TEST_MODEL.md §3.1

import Foundation

// MARK: - Supporting Types

/// Outcome of a disposition combat encounter.
public enum DispositionOutcome: Equatable, Codable, Sendable {
    /// Enemy is destroyed (disposition reached -100)
    case destroyed
    /// Enemy is subjugated (disposition reached +100)
    case subjugated
}

/// Type of player action in disposition combat.
public enum DispositionActionType: Equatable, Codable, Sendable {
    case strike
    case influence
    case sacrifice
}

// MARK: - DispositionCombatSimulation

/// Pure-logic struct for Disposition Combat Phase 3.
/// State is `public private(set)`; mutations only through designated methods.
/// Delegates power math to `DispositionCalculator`.
public struct DispositionCombatSimulation: Equatable {

    // MARK: - Disposition Track

    /// Current disposition value, clamped to [-100, +100].
    /// Negative = toward destruction, positive = toward subjugation.
    public private(set) var disposition: Int

    /// Combat outcome, set when disposition reaches -100 or +100.
    public private(set) var outcome: DispositionOutcome?

    // MARK: - Momentum

    /// Current streak action type (nil if no actions taken yet).
    public private(set) var streakType: DispositionActionType?

    /// Number of consecutive actions of the same type.
    public private(set) var streakCount: Int = 0

    /// Last action type played (for threat bonus calculation).
    public private(set) var lastActionType: DispositionActionType?

    // MARK: - Energy

    /// Current energy available for card play.
    public private(set) var energy: Int

    /// Energy granted at the start of each turn.
    public let startingEnergy: Int

    // MARK: - Sacrifice

    /// Whether a sacrifice has been used this turn (max 1 per turn).
    public private(set) var sacrificeUsedThisTurn: Bool = false

    /// Enemy buff accumulated from sacrifices (+1 per sacrifice).
    public private(set) var enemySacrificeBuff: Int = 0

    // MARK: - Card Zones

    /// Cards currently in hand.
    public private(set) var hand: [Card]

    /// Cards discarded (recyclable).
    public private(set) var discardPile: [Card] = []

    /// Cards exhausted (removed from play permanently).
    public private(set) var exhaustPile: [Card] = []

    // MARK: - Hero

    /// Hero hit points.
    public private(set) var heroHP: Int

    /// Hero maximum hit points.
    public let heroMaxHP: Int

    // MARK: - Combat Context

    /// Resonance zone for this combat.
    public let resonanceZone: ResonanceZone

    /// Enemy type identifier (for affinity matrix lookup).
    public let enemyType: String

    /// Enemy defend reduction applied to next strike.
    public private(set) var defendReduction: Int = 0

    /// Enemy provoke penalty applied to next influence.
    public private(set) var provokePenalty: Int = 0

    /// Enemy adapt penalty applied when matching streak type.
    public private(set) var adaptPenalty: Int = 0

    /// Plea backlash: next strike costs hero HP (INV-DC-034).
    public private(set) var pleaBacklash: Int = 0

    // MARK: - Echo State (Epic 18, INV-DC-019..021)

    /// Last played card ID for Echo replay (INV-DC-019).
    public private(set) var lastPlayedCardId: String?

    /// Last played action type for Echo replay.
    public private(set) var lastPlayedAction: DispositionActionType?

    /// Last played base power for Echo replay.
    public private(set) var lastPlayedBasePower: Int = 0

    /// Last fate modifier used (stored for Echo).
    public private(set) var lastFateModifier: Int = 0

    /// Whether Echo has been used this action (INV-DC-021: no new fate draw).
    public private(set) var echoUsedThisAction: Bool = false

    // MARK: - Determinism

    /// Deterministic RNG for this combat.
    public let rng: WorldRNG

    /// Original seed for reproducibility.
    public let seed: UInt64

    // MARK: - Factory

    /// Create a new disposition combat simulation.
    /// Starting disposition is resolved via `AffinityMatrix`.
    public static func create(
        enemyType: String,
        heroHP: Int,
        heroMaxHP: Int,
        hand: [Card],
        resonanceZone: ResonanceZone,
        seed: UInt64,
        situationModifier: Int = 0,
        startingEnergy: Int = 3
    ) -> DispositionCombatSimulation {
        let heroWorld = resonanceZone
        let startDisposition = AffinityMatrix.startingDisposition(
            heroWorld: heroWorld,
            enemyType: enemyType,
            situationModifier: situationModifier
        )

        return DispositionCombatSimulation(
            disposition: clampDisposition(startDisposition),
            energy: startingEnergy,
            startingEnergy: startingEnergy,
            hand: hand,
            heroHP: heroHP,
            heroMaxHP: heroMaxHP,
            resonanceZone: resonanceZone,
            enemyType: enemyType,
            rng: WorldRNG(seed: seed),
            seed: seed
        )
    }

    // MARK: - Standard Test Fixture

    /// Creates a standard fixture for testing:
    /// hero (hp=100), 5 cards (cost=1, power=5), enemy type "bandit", zone .yav, disposition=0.
    public static func makeStandard(seed: UInt64 = 42) -> DispositionCombatSimulation {
        let cards = (0..<5).map { i in
            Card(
                id: "card_\(["a", "b", "c", "d", "e"][i])",
                name: "Test Card \(i)",
                type: .item,
                description: "Test card for fixture",
                power: 5,
                cost: 1
            )
        }

        return DispositionCombatSimulation(
            disposition: 0,
            energy: 3,
            startingEnergy: 3,
            hand: cards,
            heroHP: 100,
            heroMaxHP: 100,
            resonanceZone: .yav,
            enemyType: "bandit",
            rng: WorldRNG(seed: seed),
            seed: seed
        )
    }

    // MARK: - Init

    /// Memberwise initializer (internal for restore/testing).
    public init(
        disposition: Int,
        energy: Int,
        startingEnergy: Int,
        hand: [Card],
        heroHP: Int,
        heroMaxHP: Int,
        resonanceZone: ResonanceZone,
        enemyType: String,
        rng: WorldRNG,
        seed: UInt64
    ) {
        self.disposition = Self.clampDisposition(disposition)
        self.energy = energy
        self.startingEnergy = startingEnergy
        self.hand = hand
        self.heroHP = heroHP
        self.heroMaxHP = heroMaxHP
        self.resonanceZone = resonanceZone
        self.enemyType = enemyType
        self.rng = rng
        self.seed = seed
    }

    // MARK: - Equatable (WorldRNG excluded — compared by seed)

    public static func == (lhs: DispositionCombatSimulation, rhs: DispositionCombatSimulation) -> Bool {
        return lhs.disposition == rhs.disposition
            && lhs.outcome == rhs.outcome
            && lhs.streakType == rhs.streakType
            && lhs.streakCount == rhs.streakCount
            && lhs.lastActionType == rhs.lastActionType
            && lhs.energy == rhs.energy
            && lhs.startingEnergy == rhs.startingEnergy
            && lhs.sacrificeUsedThisTurn == rhs.sacrificeUsedThisTurn
            && lhs.enemySacrificeBuff == rhs.enemySacrificeBuff
            && lhs.hand == rhs.hand
            && lhs.discardPile == rhs.discardPile
            && lhs.exhaustPile == rhs.exhaustPile
            && lhs.heroHP == rhs.heroHP
            && lhs.heroMaxHP == rhs.heroMaxHP
            && lhs.resonanceZone == rhs.resonanceZone
            && lhs.enemyType == rhs.enemyType
            && lhs.seed == rhs.seed
            && lhs.defendReduction == rhs.defendReduction
            && lhs.provokePenalty == rhs.provokePenalty
            && lhs.adaptPenalty == rhs.adaptPenalty
            && lhs.pleaBacklash == rhs.pleaBacklash
            && lhs.lastPlayedCardId == rhs.lastPlayedCardId
            && lhs.lastPlayedAction == rhs.lastPlayedAction
            && lhs.lastPlayedBasePower == rhs.lastPlayedBasePower
            && lhs.lastFateModifier == rhs.lastFateModifier
            && lhs.echoUsedThisAction == rhs.echoUsedThisAction
    }

    // MARK: - Player Actions

    /// Play a card as a strike (disposition decreases).
    /// Returns `true` if the action was executed, `false` if rejected.
    @discardableResult
    public mutating func playStrike(cardId: String, targetId: String, fateModifier: Int = 0, fateKeyword: FateKeyword? = nil) -> Bool {
        guard outcome == nil else { return false }
        guard let cardIndex = hand.firstIndex(where: { $0.id == cardId }) else { return false }

        let card = hand[cardIndex]
        let cardCost = card.cost ?? 1
        guard energy >= cardCost else { return false }

        let basePower = card.power ?? 1

        // Focus: ignore Defend at disposition < -30 (INV-DC-022)
        let effectiveDefend: Int
        if DispositionCalculator.focusIgnoresDefend(disposition: disposition, fateKeyword: fateKeyword) {
            effectiveDefend = 0
        } else {
            effectiveDefend = defendReduction
        }

        // Shadow: extra switch penalty at disposition < -30 (INV-DC-024)
        let shadowPenalty = DispositionCalculator.shadowSwitchPenalty(
            disposition: disposition, fateKeyword: fateKeyword
        )

        let effectivePower = DispositionCalculator.effectivePower(
            basePower: basePower,
            streakCount: nextStreakCount(for: .strike),
            previousStreakCount: streakCount,
            lastActionType: lastActionType,
            currentActionType: .strike,
            fateKeyword: fateKeyword,
            fateModifier: fateModifier,
            resonanceZone: resonanceZone,
            defendReduction: effectiveDefend + shadowPenalty,
            adaptPenalty: currentAdaptPenalty(for: .strike)
        )

        energy -= cardCost
        let played = hand.remove(at: cardIndex)
        discardPile.append(played)

        disposition = Self.clampDisposition(disposition - effectivePower)
        defendReduction = 0

        // Plea backlash: next strike costs hero HP (INV-DC-034)
        if pleaBacklash > 0 {
            heroHP = max(0, heroHP - pleaBacklash)
            pleaBacklash = 0
        }

        // Ward: cancel Prav resonance backlash (INV-DC-023)
        if (resonanceZone == .prav || resonanceZone == .deepPrav) && fateKeyword != .ward {
            heroHP = max(0, heroHP - 1)
        }

        // Store Echo state (INV-DC-019)
        lastPlayedCardId = cardId
        lastPlayedAction = .strike
        lastPlayedBasePower = basePower
        lastFateModifier = fateModifier
        echoUsedThisAction = false

        updateMomentum(action: .strike)
        resolveOutcome()

        return true
    }

    /// Play a card as influence (disposition increases).
    /// Returns `true` if the action was executed, `false` if rejected.
    @discardableResult
    public mutating func playInfluence(cardId: String, fateModifier: Int = 0, fateKeyword: FateKeyword? = nil) -> Bool {
        guard outcome == nil else { return false }
        guard let cardIndex = hand.firstIndex(where: { $0.id == cardId }) else { return false }

        let card = hand[cardIndex]
        let cardCost = card.cost ?? 1
        guard energy >= cardCost else { return false }

        let basePower = card.power ?? 1

        // Shadow: extra switch penalty at disposition < -30 (INV-DC-024)
        let shadowPenalty = DispositionCalculator.shadowSwitchPenalty(
            disposition: disposition, fateKeyword: fateKeyword
        )

        let effectivePower = DispositionCalculator.effectivePower(
            basePower: basePower,
            streakCount: nextStreakCount(for: .influence),
            previousStreakCount: streakCount,
            lastActionType: lastActionType,
            currentActionType: .influence,
            fateKeyword: fateKeyword,
            fateModifier: fateModifier,
            resonanceZone: resonanceZone,
            defendReduction: shadowPenalty,
            adaptPenalty: currentAdaptPenalty(for: .influence)
        )

        // Focus: ignore Provoke at disposition > +30 (INV-DC-049)
        let effectiveProvoke: Int
        if DispositionCalculator.focusIgnoresProvoke(disposition: disposition, fateKeyword: fateKeyword) {
            effectiveProvoke = 0
        } else {
            effectiveProvoke = provokePenalty
        }

        let effectiveShift = max(0, effectivePower - effectiveProvoke)

        energy -= cardCost
        let played = hand.remove(at: cardIndex)
        discardPile.append(played)

        disposition = Self.clampDisposition(disposition + effectiveShift)
        provokePenalty = 0

        // Store Echo state (INV-DC-019)
        lastPlayedCardId = cardId
        lastPlayedAction = .influence
        lastPlayedBasePower = basePower
        lastFateModifier = fateModifier
        echoUsedThisAction = false

        updateMomentum(action: .influence)
        resolveOutcome()

        return true
    }

    /// Play a card as sacrifice (card is exhausted, +1 energy back, enemy gets +1 buff).
    /// Returns `true` if the action was executed, `false` if rejected.
    @discardableResult
    public mutating func playCardAsSacrifice(cardId: String) -> Bool {
        guard outcome == nil else { return false }
        guard !sacrificeUsedThisTurn else { return false }
        guard let cardIndex = hand.firstIndex(where: { $0.id == cardId }) else { return false }

        let card = hand[cardIndex]
        let cardCost = card.cost ?? 1

        let actualCost: Int
        if resonanceZone == .nav || resonanceZone == .deepNav {
            actualCost = max(0, cardCost - 1)
        } else {
            actualCost = cardCost
        }
        guard energy >= actualCost else { return false }

        energy -= actualCost

        let played = hand.remove(at: cardIndex)
        exhaustPile.append(played)

        energy += 1
        sacrificeUsedThisTurn = true
        enemySacrificeBuff += 1

        if resonanceZone == .prav || resonanceZone == .deepPrav {
            if !hand.isEmpty {
                let shouldExhaustExtra = rng.nextBool(probability: 0.5)
                if shouldExhaustExtra {
                    let extraIndex = rng.nextInt(in: 0...(hand.count - 1))
                    let extraCard = hand.remove(at: extraIndex)
                    exhaustPile.append(extraCard)
                }
            }
        }

        // Store Echo state — sacrifice blocks Echo (INV-DC-018)
        lastPlayedCardId = cardId
        lastPlayedAction = .sacrifice
        lastPlayedBasePower = 0
        lastFateModifier = 0
        echoUsedThisAction = false

        updateMomentum(action: .sacrifice)

        return true
    }

    // MARK: - Echo Action (Epic 18, INV-DC-019..021)

    /// Play Echo: free replay of last action at 0 energy cost.
    /// Returns false if: no previous action, last action was sacrifice, outcome reached.
    /// INV-DC-018: Echo blocked after sacrifice.
    /// INV-DC-020: Echo continues the streak.
    /// INV-DC-021: No new fate draw — uses stored fateModifier.
    @discardableResult
    public mutating func playEcho(fateModifier: Int = 0) -> Bool {
        guard outcome == nil else { return false }
        guard let lastAction = lastPlayedAction else { return false }
        guard lastAction != .sacrifice else { return false }

        echoUsedThisAction = true

        let effectivePower = DispositionCalculator.effectivePower(
            basePower: lastPlayedBasePower,
            streakCount: nextStreakCount(for: lastAction),
            previousStreakCount: streakCount,
            lastActionType: lastActionType,
            currentActionType: lastAction,
            fateKeyword: nil,
            fateModifier: fateModifier,
            resonanceZone: resonanceZone,
            defendReduction: lastAction == .strike ? defendReduction : 0,
            adaptPenalty: currentAdaptPenalty(for: lastAction)
        )

        switch lastAction {
        case .strike:
            disposition = Self.clampDisposition(disposition - effectivePower)
            defendReduction = 0
        case .influence:
            let effectiveShift = max(0, effectivePower - provokePenalty)
            disposition = Self.clampDisposition(disposition + effectiveShift)
            provokePenalty = 0
        case .sacrifice:
            break
        }

        updateMomentum(action: lastAction)
        resolveOutcome()
        return true
    }

    // MARK: - Turn State

    /// Whether the player's turn is effectively over (no energy to play cards).
    /// When true, no card can be played since all cards cost >= 1 (INV-DC-047).
    public var isAutoTurnEnd: Bool {
        energy <= 0 && outcome == nil
    }

    // MARK: - Turn Management

    /// End the current player turn.
    public mutating func endPlayerTurn() {
        sacrificeUsedThisTurn = false
    }

    /// Begin a new player turn (resets energy).
    public mutating func beginPlayerTurn() {
        energy = startingEnergy
        sacrificeUsedThisTurn = false
    }

    /// Apply enemy attack damage to hero HP (INV-DC-056).
    /// Damage is increased by accumulated sacrifice buff.
    public mutating func applyEnemyAttack(damage: Int) {
        let totalDamage = damage + enemySacrificeBuff
        heroHP = max(0, heroHP - totalDamage)
    }

    /// Apply enemy defend effect (reduces next strike).
    public mutating func applyEnemyDefend(value: Int) {
        defendReduction = value
    }

    /// Apply enemy provoke effect (reduces next influence).
    public mutating func applyEnemyProvoke(value: Int) {
        provokePenalty = value
    }

    /// Apply enemy adapt effect (penalizes streak-matching action).
    public mutating func applyEnemyAdapt(streakBonus: Int) {
        adaptPenalty = max(3, streakBonus)
    }

    /// Clear adapt penalty (after it has been applied).
    public mutating func clearAdaptPenalty() {
        adaptPenalty = 0
    }

    /// Apply a direct disposition shift (for enemy actions like Rage/Plea, INV-DC-033/034).
    public mutating func applyDispositionShift(_ shift: Int) {
        disposition = Self.clampDisposition(disposition + shift)
        resolveOutcome()
    }

    /// Set plea backlash: next strike costs hero HP (INV-DC-034).
    public mutating func applyPleaBacklash(hpLoss: Int) {
        pleaBacklash = hpLoss
    }

    // MARK: - Private Helpers

    /// Clamp disposition to valid range [-100, +100].
    private static func clampDisposition(_ value: Int) -> Int {
        return min(100, max(-100, value))
    }

    /// Update momentum tracking after an action.
    private mutating func updateMomentum(action: DispositionActionType) {
        if action == streakType {
            streakCount += 1
        } else {
            streakType = action
            streakCount = 1
        }
        lastActionType = action
    }

    /// Compute the streak count that would apply if the given action is played next.
    private func nextStreakCount(for action: DispositionActionType) -> Int {
        if action == streakType {
            return streakCount + 1
        }
        return 1
    }

    /// Compute adapt penalty applicable for the given action type.
    private func currentAdaptPenalty(for action: DispositionActionType) -> Int {
        guard adaptPenalty > 0 else { return 0 }
        guard let currentStreak = streakType, currentStreak == action else { return 0 }
        return adaptPenalty
    }

    /// Check if disposition has reached an outcome threshold.
    private mutating func resolveOutcome() {
        if disposition <= -100 {
            outcome = .destroyed
        } else if disposition >= 100 {
            outcome = .subjugated
        }
    }
}

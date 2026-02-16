/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Combat/CombatSimulation+Commit.swift
/// Назначение: Commit атаки через CombatCalculator, snapshot/restore для save/load.
/// Зона ответственности: Делегирование расчёта в CombatCalculator, сериализация состояния.
/// Контекст: R1 Effort mechanic. Reference: RITUAL_COMBAT_TEST_MODEL.md §3.2

import Foundation

// MARK: - Commit & Snapshot

extension CombatSimulation {

    /// Commit a physical attack against a target enemy.
    ///
    /// Delegates to `CombatCalculator.calculateAttackWithFate` with current effort bonus.
    /// Applies damage to the target, moves selected cards to discard, resets effort state.
    ///
    /// - Parameter targetId: ID of the enemy to attack
    /// - Returns: Full `FateAttackResult` with breakdown
    public func commitAttack(targetId: String) -> FateAttackResult {
        let playerContext = CombatPlayerContext(
            health: heroHP,
            maxHealth: heroMaxHP,
            faith: 0,
            balance: 50,
            strength: heroStrength,
            activeCurses: [],
            heroBonusDice: 0,
            heroDamageBonus: 0
        )

        let selectedCardPower = hand
            .filter { selectedCardIds.contains($0.id) }
            .reduce(0) { $0 + ($1.power ?? 0) }

        guard let targetIndex = enemies.firstIndex(where: { $0.id == targetId }) else {
            return FateAttackResult(
                baseStrength: heroStrength,
                cardPower: selectedCardPower,
                effortBonus: effortBonus,
                fateDrawResult: nil,
                totalAttack: 0,
                defenseValue: 0,
                isHit: false,
                damage: 0,
                fateDrawEffects: [],
                specialEffects: []
            )
        }

        let target = enemies[targetIndex]

        let result = CombatCalculator.calculateAttackWithFate(
            context: playerContext,
            fateDeck: fateDeck,
            worldResonance: worldResonance,
            effortCards: effortBonus,
            monsterDefense: target.defense,
            bonusDamage: 0,
            cardPower: selectedCardPower,
            rng: rng
        )

        if result.isHit {
            enemies[targetIndex].hp = max(0, enemies[targetIndex].hp - result.damage)
        }

        let selectedCards = hand.filter { selectedCardIds.contains($0.id) }
        hand.removeAll { selectedCardIds.contains($0.id) }
        discardPile.append(contentsOf: selectedCards)
        selectedCardIds.removeAll()
        effortBonus = 0
        effortCardIds.removeAll()

        return result
    }

    /// Commit a spiritual influence against a target enemy's will.
    ///
    /// Delegates to `CombatCalculator.calculateSpiritAttack` with current effort bonus.
    /// Applies WP damage to the target, moves selected cards to discard, resets effort state.
    ///
    /// - Parameter targetId: ID of the enemy to influence
    /// - Returns: Full `SpiritAttackResult` with breakdown
    public func commitInfluence(targetId: String) -> SpiritAttackResult {
        let playerContext = CombatPlayerContext(
            health: heroHP,
            maxHealth: heroMaxHP,
            faith: 0,
            balance: 50,
            strength: heroStrength,
            wisdom: heroWisdom,
            activeCurses: [],
            heroBonusDice: 0,
            heroDamageBonus: 0
        )

        let selectedCardPower = hand
            .filter { selectedCardIds.contains($0.id) }
            .reduce(0) { $0 + ($1.power ?? 0) }

        guard let targetIndex = enemies.firstIndex(where: { $0.id == targetId }),
              let currentWP = enemies[targetIndex].wp else {
            return SpiritAttackResult(
                damage: 0, baseStat: 0, cardPower: selectedCardPower, fateModifier: 0,
                newWill: 0, isPacified: false, fateDrawEffects: []
            )
        }

        let result = CombatCalculator.calculateSpiritAttack(
            context: playerContext,
            enemyCurrentWill: currentWP,
            fateDeck: fateDeck,
            worldResonance: worldResonance,
            effortCards: effortBonus,
            bonusDamage: selectedCardPower,
            rng: rng
        )

        enemies[targetIndex].wp = result.newWill

        let selectedCards = hand.filter { selectedCardIds.contains($0.id) }
        hand.removeAll { selectedCardIds.contains($0.id) }
        discardPile.append(contentsOf: selectedCards)
        selectedCardIds.removeAll()
        effortBonus = 0
        effortCardIds.removeAll()

        return result
    }

    // MARK: - Snapshot

    /// Capture a complete snapshot of the current state.
    public func snapshot() -> CombatSnapshot {
        CombatSnapshot(
            heroHP: heroHP,
            heroMaxHP: heroMaxHP,
            heroStrength: heroStrength,
            heroWisdom: heroWisdom,
            heroArmor: heroArmor,
            hand: hand,
            discardPile: discardPile,
            exhaustPile: exhaustPile,
            effortBonus: effortBonus,
            effortCardIds: effortCardIds,
            selectedCardIds: selectedCardIds,
            maxEffort: maxEffort,
            energy: energy,
            reservedEnergy: reservedEnergy,
            enemies: enemies,
            fateDeckState: fateDeck.getState(),
            rngState: rng.currentState(),
            worldResonance: worldResonance,
            balanceConfig: balanceConfig,
            phase: phase,
            round: round
        )
    }

    // MARK: - Phase Control

    /// Transition to a new combat phase.
    public func setPhase(_ newPhase: CombatSimulationPhase) {
        phase = newPhase
    }

    /// Resolve the enemy turn: each living enemy deals their power as damage to the hero.
    /// Automatically advances phase to `.playerAction` (or `.finished` if hero is defeated)
    /// and increments the round counter.
    ///
    /// - Returns: Array of (enemyId, damage) pairs for visual feedback.
    public func resolveEnemyTurn() -> [(enemyId: String, damage: Int)] {
        var attacks: [(String, Int)] = []
        for enemy in enemies where enemy.hp > 0 && !enemy.isPacified {
            let damage = enemy.power
            heroHP = Swift.max(0, heroHP - damage)
            attacks.append((enemy.id, damage))
        }

        if heroHP <= 0 {
            phase = .finished
        } else {
            round += 1
            phase = .playerAction
        }
        return attacks
    }

    // MARK: - Restore

    /// Recreate a CombatSimulation from a saved snapshot.
    public static func restore(from snapshot: CombatSnapshot) -> CombatSimulation {
        CombatSimulation(
            hand: snapshot.hand,
            discardPile: snapshot.discardPile,
            exhaustPile: snapshot.exhaustPile,
            effortBonus: snapshot.effortBonus,
            effortCardIds: snapshot.effortCardIds,
            selectedCardIds: snapshot.selectedCardIds,
            energy: snapshot.energy,
            reservedEnergy: snapshot.reservedEnergy,
            maxEffort: snapshot.maxEffort,
            heroHP: snapshot.heroHP,
            heroMaxHP: snapshot.heroMaxHP,
            heroStrength: snapshot.heroStrength,
            heroWisdom: snapshot.heroWisdom,
            heroArmor: snapshot.heroArmor,
            enemies: snapshot.enemies,
            fateDeckState: snapshot.fateDeckState,
            rngSeed: 0,
            rngState: snapshot.rngState,
            worldResonance: snapshot.worldResonance,
            balanceConfig: snapshot.balanceConfig,
            phase: snapshot.phase,
            round: snapshot.round
        )
    }
}

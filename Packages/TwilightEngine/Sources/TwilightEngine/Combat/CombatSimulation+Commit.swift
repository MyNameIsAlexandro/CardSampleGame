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
            maxHealth: heroHP,
            faith: 0,
            balance: 50,
            strength: heroStrength,
            activeCurses: [],
            heroBonusDice: 0,
            heroDamageBonus: 0
        )

        guard let targetIndex = enemies.firstIndex(where: { $0.id == targetId }) else {
            return FateAttackResult(
                baseStrength: heroStrength,
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

    // MARK: - Snapshot

    /// Capture a complete snapshot of the current state.
    public func snapshot() -> CombatSnapshot {
        CombatSnapshot(
            heroHP: heroHP,
            heroStrength: heroStrength,
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
            heroStrength: snapshot.heroStrength,
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

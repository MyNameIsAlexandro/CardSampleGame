/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Combat/CombatCalculator.swift
/// Назначение: Содержит реализацию файла CombatCalculator.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// Combat calculator - computes attack result with full breakdown.
public struct CombatCalculator {

    // MARK: - Attack with Fate Deck (Unified Resolution)

    /// Calculate attack using Fate Deck instead of dice.
    /// Formula: totalAttack = baseStrength + effortBonus + fateEffectiveValue
    /// Hit if totalAttack >= monsterDefense
    /// Damage = max(1, totalAttack - monsterDefense + 2) + bonusDamage + modifiers
    public static func calculateAttackWithFate(
        context: CombatPlayerContext,
        fateDeck: FateDeckManager?,
        worldResonance: Float,
        effortCards: Int,
        monsterDefense: Int,
        bonusDamage: Int,
        cardPower: Int = 0,
        rng: WorldRNG
    ) -> FateAttackResult {
        let baseStrength = context.strength
        let effortBonus = max(0, effortCards)

        // Draw fate card (replaces dice roll)
        let fateResult: FateDrawResult?
        let fateValue: Int
        if let deck = fateDeck, let result = deck.drawAndResolve(worldResonance: worldResonance) {
            fateResult = result
            fateValue = result.effectiveValue
        } else {
            fateResult = nil
            fateValue = rng.nextInt(in: -1...2)  // fallback if no deck
        }

        let totalAttack = baseStrength + cardPower + effortBonus + fateValue + bonusDamage
        let isHit = totalAttack >= monsterDefense

        // Damage calculation
        var damage = 0
        var specialEffects: [CombatEffect] = []

        if isHit {
            var baseDamage = max(1, totalAttack - monsterDefense + 2)

            // Apply curse modifiers
            if context.activeCurses.contains(.weakness) {
                baseDamage = max(1, baseDamage - 1)
                specialEffects.append(CombatEffect(
                    icon: "💀",
                    description: "Weakness: -1 damage",
                    type: .debuff
                ))
            }
            if context.activeCurses.contains(.shadowOfNav) {
                baseDamage += 3
                specialEffects.append(CombatEffect(
                    icon: "💀",
                    description: "Shadow of Nav: +3 damage",
                    type: .buff
                ))
            }

            // Hero damage bonus
            if context.heroDamageBonus > 0 {
                baseDamage += context.heroDamageBonus
                specialEffects.append(CombatEffect(
                    icon: "⭐",
                    description: "Hero ability: +\(context.heroDamageBonus) damage",
                    type: .buff
                ))
            }

            damage = max(1, baseDamage)
        }

        return FateAttackResult(
            baseStrength: baseStrength,
            cardPower: cardPower,
            effortBonus: effortBonus,
            fateDrawResult: fateResult,
            totalAttack: totalAttack,
            defenseValue: monsterDefense,
            isHit: isHit,
            damage: damage,
            fateDrawEffects: fateResult?.drawEffects ?? [],
            specialEffects: specialEffects
        )
    }

    // MARK: - Attack Calculation with CombatPlayerContext

    /// Calculate player attack using CombatPlayerContext (Engine-First Architecture)
    /// Replaces legacy calculatePlayerAttack that used Player model
    public static func calculatePlayerAttack(
        context: CombatPlayerContext,
        monsterDefense: Int,
        monsterCurrentHP: Int,
        monsterMaxHP: Int,
        bonusDice: Int,
        bonusDamage: Int,
        isFirstAttack: Bool,
        rng: WorldRNG
    ) -> CombatResult {

        var modifiers: [CombatModifier] = []
        var damageModifiers: [CombatModifier] = []
        let specialEffects: [CombatEffect] = []

        let isTargetFullHP = monsterCurrentHP == monsterMaxHP

        // Roll dice
        var totalDice = 1 + bonusDice

        // Hero ability: bonus dice (e.g., Tracker on first attack)
        let heroBonusDice = context.getHeroBonusDice(isFirstAttack: isFirstAttack)
        if heroBonusDice > 0 {
            totalDice += heroBonusDice
            modifiers.append(CombatModifier(
                source: .heroAbility,
                value: 0,  // Doesn't add to attack directly, only the dice roll
                description: L10n.calcHeroAbilityDice.localized(with: heroBonusDice)
            ))
        }

        var diceRolls: [Int] = []
        for _ in 0..<totalDice {
            diceRolls.append(rng.nextInt(in: 1...6))
        }

        // Create attack roll
        let attackRoll = AttackRoll(
            baseStrength: context.strength,
            diceRolls: diceRolls,
            bonusDice: bonusDice,
            bonusDamage: bonusDamage,
            modifiers: modifiers
        )

        let isHit = attackRoll.total >= monsterDefense

        var damageCalculation: DamageCalculation? = nil

        if isHit {
            let baseDamage = max(1, attackRoll.total - monsterDefense + 2)

            // Curse damage modifiers
            if context.hasCurse(.weakness) {
                damageModifiers.append(CombatModifier(
                    source: .curse,
                    value: -1,
                    description: L10n.calcCurseWeakness.localized
                ))
            }

            if context.hasCurse(.shadowOfNav) {
                damageModifiers.append(CombatModifier(
                    source: .curse,
                    value: +3,
                    description: L10n.calcCurseShadowOfNav.localized
                ))
            }

            // Hero ability damage bonus (checks conditions like HP < 50% or target at full HP)
            let heroDamageBonus = context.getHeroDamageBonus(targetFullHP: isTargetFullHP)
            if heroDamageBonus > 0 {
                damageModifiers.append(CombatModifier(
                    source: .heroAbility,
                    value: heroDamageBonus,
                    description: L10n.calcHeroAbility.localized
                ))
            }

            damageCalculation = DamageCalculation(
                base: baseDamage,
                modifiers: damageModifiers
            )
        }

        return CombatResult(
            isHit: isHit,
            attackRoll: attackRoll,
            defenseValue: monsterDefense,
            damageCalculation: damageCalculation,
            specialEffects: specialEffects
        )
    }

    // MARK: - Spirit Attack (Pacify Path)

    /// Calculate spirit/will damage for the Pacify path (decoupled from engine).
    /// Uses player wisdom or intelligence from CombatPlayerContext.
    public static func calculateSpiritAttack(
        context: CombatPlayerContext,
        enemyCurrentWill: Int,
        fateDeck: FateDeckManager?,
        worldResonance: Float = 0.0,
        effortCards: Int = 0,
        bonusDamage: Int = 0,
        rng: WorldRNG
    ) -> SpiritAttackResult {
        let baseStat = max(context.wisdom, context.intelligence, 1)
        let effortBonus = max(0, effortCards)

        // Draw fate card for modifier (resonance-aware)
        let fateModifier: Int
        var fateResult: FateDrawResult?
        var fateDrawEffects: [FateDrawEffect] = []
        if let deck = fateDeck, let result = deck.drawAndResolve(worldResonance: worldResonance) {
            fateResult = result
            fateModifier = result.effectiveValue
            fateDrawEffects = result.drawEffects
        } else {
            fateModifier = rng.nextInt(in: -1...2)
        }

        let damage = max(1, baseStat + effortBonus + fateModifier + bonusDamage)
        let newWill = max(0, enemyCurrentWill - damage)

        return SpiritAttackResult(
            damage: damage,
            baseStat: baseStat,
            cardPower: bonusDamage,
            fateModifier: fateModifier,
            newWill: newWill,
            isPacified: newWill <= 0,
            fateDrawResult: fateResult,
            fateDrawEffects: fateDrawEffects
        )
    }

}

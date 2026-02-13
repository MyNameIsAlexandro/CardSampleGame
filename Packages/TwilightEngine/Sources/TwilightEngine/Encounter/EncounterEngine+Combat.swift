/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Encounter/EncounterEngine+Combat.swift
/// Назначение: Содержит реализацию файла EncounterEngine+Combat.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

extension EncounterEngine {

    func performPhysicalAttack(targetId: String) -> EncounterActionResult {
        guard let idx = findEnemyIndex(id: targetId) else {
            return .fail(.invalidTarget)
        }
        var changes: [EncounterStateChange] = []
        var surpriseBonus = 0

        if lastAttackTrack == .spiritual {
            surpriseBonus = context.balanceConfig?.escalationSurpriseBonus ?? 3
            let delta: Float = context.balanceConfig?.escalationResonanceShift ?? -5.0
            accumulatedResonanceDelta += delta
            changes.append(.resonanceShifted(delta: delta, newValue: context.worldResonance + accumulatedResonanceDelta))
        }

        var keywordBonus = 0
        var ignoreArmor = false
        var vampirism = false
        var echoCardReturn = false
        let fateResult = drawFate()
        if let fateResult = fateResult {
            changes.append(.fateDraw(cardId: fateResult.card.id, value: fateResult.effectiveValue))
            if let keyword = fateResult.card.keyword {
                let effect = KeywordInterpreter.resolveWithAlignment(
                    keyword: keyword,
                    context: .combatPhysical,
                    baseValue: fateResult.effectiveValue,
                    isMatch: isSuitMatch(fateResult.card.suit, for: .combatPhysical),
                    isMismatch: isSuitMismatch(fateResult.card.suit, for: .combatPhysical),
                    matchMultiplier: matchMultiplier
                )
                keywordBonus = effect.bonusDamage
                switch effect.special {
                case "ignore_armor": ignoreArmor = true
                case "ambush": vampirism = true
                case "echo_strike": echoCardReturn = true
                default: break
                }
            }
        }

        var weaknessMultiplier: Double = 1.0
        if let fateResult = fateResult, let keyword = fateResult.card.keyword {
            let keywordValue = keyword.rawValue.lowercased()
            if enemies[idx].weaknesses.contains(keywordValue) {
                weaknessMultiplier = 1.5
                changes.append(.weaknessTriggered(enemyId: targetId, keyword: keywordValue))
            } else if enemies[idx].strengths.contains(keywordValue) {
                weaknessMultiplier = 0.67
                changes.append(.resistanceTriggered(enemyId: targetId, keyword: keywordValue))
            }
        }

        let resonanceModifierValue = resonanceModifier(for: enemies[idx])
        let abilityArmor = enemies[idx].abilities.reduce(0) { sum, ability in
            if case .armor(let value) = ability.effect { return sum + value }
            return sum
        }
        let armor = ignoreArmor ? 0 : max(0, enemies[idx].defense + resonanceModifierValue.defenseDelta + abilityArmor)
        let rawDamage = context.hero.strength + turnAttackBonus - armor + surpriseBonus + keywordBonus
        let damage = max(1, Int(Double(rawDamage) * weaknessMultiplier))
        enemies[idx].hp = max(0, enemies[idx].hp - damage)
        lastAttackTrack = .physical

        changes.append(.enemyHPChanged(enemyId: targetId, delta: -damage, newValue: enemies[idx].hp))

        if vampirism {
            let heal = max(1, damage / 2)
            heroHP = min(context.hero.maxHp, heroHP + heal)
            changes.append(.playerHPChanged(delta: heal, newValue: heroHP))
        }

        if echoCardReturn, let lastCard = cardDiscardPile.last {
            cardDiscardPile.removeLast()
            hand.append(lastCard)
        }

        if enemies[idx].hp == 0 {
            enemies[idx].outcome = .killed
            changes.append(.enemyKilled(enemyId: targetId))
        }

        return .ok(changes)
    }

    func performSpiritAttack(targetId: String) -> EncounterActionResult {
        guard let idx = findEnemyIndex(id: targetId) else {
            return .fail(.invalidTarget)
        }
        guard enemies[idx].hasSpiritTrack else {
            return .fail(.actionNotAllowed)
        }
        var changes: [EncounterStateChange] = []

        if lastAttackTrack == .physical {
            let shieldValue = context.balanceConfig?.deEscalationRageShield ?? 3
            enemies[idx].rageShield = shieldValue
            changes.append(.rageShieldApplied(enemyId: targetId, value: shieldValue))
        }

        var keywordBonus = 0
        var resonancePush = false
        var echoCardReturn = false
        let fateResult = drawFate()
        if let fateResult = fateResult {
            changes.append(.fateDraw(cardId: fateResult.card.id, value: fateResult.effectiveValue))
            if let keyword = fateResult.card.keyword {
                let effect = KeywordInterpreter.resolveWithAlignment(
                    keyword: keyword,
                    context: .combatSpiritual,
                    baseValue: fateResult.effectiveValue,
                    isMatch: isSuitMatch(fateResult.card.suit, for: .combatSpiritual),
                    isMismatch: isSuitMismatch(fateResult.card.suit, for: .combatSpiritual),
                    matchMultiplier: matchMultiplier
                )
                keywordBonus = effect.bonusDamage
                switch effect.special {
                case "resonance_push": resonancePush = true
                case "will_pierce": keywordBonus += 1
                case "echo_prayer": echoCardReturn = true
                default: break
                }
            }
        }

        if resonancePush {
            let delta: Float = 3.0
            accumulatedResonanceDelta += delta
            changes.append(.resonanceShifted(delta: delta, newValue: context.worldResonance + accumulatedResonanceDelta))
        }

        var weaknessMultiplier: Double = 1.0
        if let fateResult = fateResult, let keyword = fateResult.card.keyword {
            let keywordValue = keyword.rawValue.lowercased()
            if enemies[idx].weaknesses.contains(keywordValue) {
                weaknessMultiplier = 1.5
                changes.append(.weaknessTriggered(enemyId: targetId, keyword: keywordValue))
            } else if enemies[idx].strengths.contains(keywordValue) {
                weaknessMultiplier = 0.67
                changes.append(.resistanceTriggered(enemyId: targetId, keyword: keywordValue))
            }
        }

        let rawDamage = context.hero.wisdom + turnInfluenceBonus + keywordBonus - enemies[idx].rageShield - enemies[idx].spiritDefense
        let damage = max(1, Int(Double(rawDamage) * weaknessMultiplier))
        let currentWP = enemies[idx].wp ?? 0
        let newWP = max(0, currentWP - damage)
        enemies[idx].wp = newWP
        enemies[idx].rageShield = 0
        lastAttackTrack = .spiritual

        changes.append(.enemyWPChanged(enemyId: targetId, delta: -damage, newValue: newWP))

        if echoCardReturn, let lastCard = cardDiscardPile.last {
            cardDiscardPile.removeLast()
            hand.append(lastCard)
        }

        if newWP == 0 && enemies[idx].hp > 0 {
            enemies[idx].outcome = .pacified
            changes.append(.enemyPacified(enemyId: targetId))
        }

        return .ok(changes)
    }
}

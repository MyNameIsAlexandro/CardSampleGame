/// Файл: Views/Combat/EncounterViewModel+StateSyncAndLog.swift
/// Назначение: Содержит реализацию файла EncounterViewModel+StateSyncAndLog.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine

/// Синхронизация состояния и combat log для `EncounterViewModel`.
@MainActor
extension EncounterViewModel {

    // MARK: - State Sync

    func syncState() {
        phase = eng.currentPhase
        round = eng.currentRound
        heroHP = eng.heroHP
        enemies = eng.enemies
        isFinished = eng.isFinished
        fateDeckDrawCount = eng.fateDeckDrawCount
        fateDeckDiscardCount = eng.fateDeckDiscardCount
        hand = eng.hand
        heroFaith = eng.heroFaith
        pendingFateChoice = eng.pendingFateChoice
        heroDiscardCount = eng.cardDiscardPile.count
        heroDeckCount = eng.heroCardPoolCount
        turnAttackBonus = eng.turnAttackBonus
        turnInfluenceBonus = eng.turnInfluenceBonus
        turnDefenseBonus = eng.turnDefenseBonus
    }

    // MARK: - Log Helpers

    func processStateChanges(_ changes: [EncounterStateChange]) {
        for change in changes {
            switch change {
            case .enemyHPChanged(_, let delta, let newValue):
                if delta < 0 { addDamageDealt(-delta) }
                logEntry(L10n.encounterLogBodyDamage.localized(with: -delta, newValue))
            case .enemyWPChanged(_, let delta, let newValue):
                logEntry(L10n.encounterLogWillDamage.localized(with: -delta, newValue))
            case .playerHPChanged(let delta, let newValue):
                if delta < 0 { addDamageTaken(-delta) }
                if delta < 0 {
                    HapticManager.shared.play(.heavy)
                    SoundManager.shared.play(.damageTaken)
                    logEntry(L10n.encounterLogPlayerTakesDamage.localized(with: -delta, newValue))
                }
            case .enemyKilled(let enemyId):
                let name = eng.enemies.first(where: { $0.id == enemyId })?.name ?? enemyId
                HapticManager.shared.play(.heavy)
                SoundManager.shared.play(.enemyDefeated)
                logEntry(L10n.encounterLogEnemySlain.localized(with: name))
            case .enemyPacified(let enemyId):
                let name = eng.enemies.first(where: { $0.id == enemyId })?.name ?? enemyId
                HapticManager.shared.play(.success)
                SoundManager.shared.play(.enemyDefeated)
                logEntry(L10n.encounterLogEnemyPacified.localized(with: name))
            case .fateDraw(_, let value):
                incrementFateCardsDrawn()
                let cardName: String
                if let result = eng.lastFateDrawResult {
                    lastFateResult = result
                    showFateReveal = true
                    SoundManager.shared.play(result.isCritical ? .fateCritical : .fateReveal)
                    HapticManager.shared.play(result.isCritical ? .heavy : .light)
                    cardName = result.card.name
                } else {
                    cardName = "?"
                }
                let sign = value >= 0 ? "+" : ""
                logEntry(L10n.encounterLogFateDraw.localized(with: cardName, "\(sign)\(value)"))
            case .resonanceShifted(let delta, _):
                let sign = delta >= 0 ? "+" : ""
                logEntry(L10n.encounterLogResonanceShift.localized(with: "\(sign)\(String(format: "%.0f", delta))"))
            case .rageShieldApplied(_, let value):
                logEntry(L10n.encounterLogRageShield.localized(with: value))
            case .cardPlayed(_, let name):
                incrementCardsPlayed()
                logEntry(L10n.encounterLogCardPlayed.localized(with: name))
            case .faithChanged(let delta, _):
                if delta < 0 {
                    logEntry(L10n.combatFaithSpent.localized(with: -delta))
                }
            case .fateChoicePending:
                showFateChoice = true
            case .playerDefended(let bonus):
                logEntry(L10n.encounterLogPlayerDefends.localized(with: bonus))
            case .fleeAttempt(let success, let damage):
                if success {
                    logEntry(L10n.encounterLogFleeSuccess.localized)
                } else {
                    logEntry(L10n.encounterLogFleeDamage.localized(with: damage))
                }
            case .enemySummoned(_, let enemyName):
                logEntry(L10n.encounterLogEnemySummoned.localized(with: enemyName))
            case .cardDrawn:
                break
            case .encounterEnded:
                break
            case .weaknessTriggered(let enemyId, let keyword):
                let name = eng.enemies.first(where: { $0.id == enemyId })?.name ?? enemyId
                logEntry(L10n.combatWeaknessTriggered.localized(with: name, keyword))
            case .resistanceTriggered(let enemyId, let keyword):
                let name = eng.enemies.first(where: { $0.id == enemyId })?.name ?? enemyId
                logEntry(L10n.combatResistanceTriggered.localized(with: name, keyword))
            case .abilityTriggered(let enemyId, _, let effect):
                let name = eng.enemies.first(where: { $0.id == enemyId })?.name ?? enemyId
                logEntry(L10n.combatAbilityTriggered.localized(with: name, effect))
            }
        }
    }

    func logEntry(_ text: String) {
        combatLog.append(text)
        if combatLog.count > 10 {
            combatLog.removeFirst()
        }
    }

    // MARK: - Intent Localization

    /// Localize intent for combat log (mirrors EnemyIntentView.intentDetail)
    func localizedIntentDetail(_ intent: EnemyIntent) -> String {
        switch intent.type {
        case .attack: return L10n.combatIntentDetailAttack.localized(with: intent.value)
        case .ritual: return L10n.combatIntentDetailRitual.localized
        case .block: return L10n.combatIntentDetailBlock.localized(with: intent.value)
        case .buff: return L10n.combatIntentDetailBuff.localized(with: intent.value)
        case .heal: return L10n.combatIntentDetailHeal.localized(with: intent.value)
        case .summon: return L10n.combatIntentDetailSummon.localized
        case .prepare: return L10n.combatIntentDetailPrepare.localized
        case .restoreWP: return L10n.combatIntentDetailRestoreWP.localized(with: intent.value)
        case .debuff: return L10n.combatIntentDetailDebuff.localized(with: intent.value)
        case .defend: return L10n.combatIntentDetailDefend.localized(with: intent.value)
        }
    }
}

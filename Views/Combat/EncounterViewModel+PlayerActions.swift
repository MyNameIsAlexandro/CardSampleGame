/// Файл: Views/Combat/EncounterViewModel+PlayerActions.swift
/// Назначение: Содержит реализацию файла EncounterViewModel+PlayerActions.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine

/// Действия игрока и mulligan для `EncounterViewModel`.
@MainActor
extension EncounterViewModel {

    // MARK: - Mulligan

    func toggleMulliganCard(id: String) {
        if mulliganSelection.contains(id) {
            mulliganSelection.remove(id)
        } else {
            mulliganSelection.insert(id)
        }
    }

    func confirmMulligan() {
        if !mulliganSelection.isEmpty {
            let result = eng.performAction(.mulligan(cardIds: Array(mulliganSelection)))
            if result.success {
                processStateChanges(result.stateChanges)
            }
        }
        mulliganSelection = []
        showMulligan = false
        syncState()
    }

    func skipMulligan() {
        mulliganSelection = []
        showMulligan = false
    }

    // MARK: - Player Actions

    func performAttack() {
        guard phase == .playerAction, !isProcessingEnemyTurn, let target = selectedTarget else { return }
        fateContext = .attack
        let result = eng.performAction(.attack(targetId: target.id))
        if !result.success { return }
        HapticManager.shared.play(.medium)
        SoundManager.shared.play(.attackHit)
        lastChanges = result.stateChanges
        processStateChanges(result.stateChanges)
        syncState()

        if showFateReveal {
            pendingContinuation = { [weak self] in self?.advanceAfterPlayerAction() }
        } else {
            advanceAfterPlayerAction()
        }
    }

    func performInfluence() {
        guard phase == .playerAction, !isProcessingEnemyTurn, let target = selectedTarget else { return }
        guard target.hasSpiritTrack else { return }
        fateContext = .attack
        let result = eng.performAction(.spiritAttack(targetId: target.id))
        if !result.success { return }
        HapticManager.shared.play(.medium)
        SoundManager.shared.play(.influence)
        lastChanges = result.stateChanges
        processStateChanges(result.stateChanges)
        syncState()

        if showFateReveal {
            pendingContinuation = { [weak self] in self?.advanceAfterPlayerAction() }
        } else {
            advanceAfterPlayerAction()
        }
    }

    func performWait() {
        guard phase == .playerAction, !isProcessingEnemyTurn else { return }
        let result = eng.performAction(.wait)
        if !result.success { return }
        HapticManager.shared.play(.light)
        lastChanges = result.stateChanges
        logEntry(L10n.encounterLogPlayerWaits.localized)
        syncState()
        advanceAfterPlayerAction()
    }

    func dismissFateReveal() {
        showFateReveal = false
        lastFateResult = nil

        if let continuation = pendingContinuation {
            pendingContinuation = nil
            continuation()
        }
    }

    func resolveFateChoice(optionIndex: Int) {
        let result = eng.performAction(.resolveFateChoice(optionIndex: optionIndex))
        lastChanges = result.stateChanges
        processStateChanges(result.stateChanges)
        showFateChoice = false
        pendingFateChoice = nil
        syncState()

        if let continuation = pendingContinuation {
            pendingContinuation = nil
            continuation()
        }
    }

    func playCard(_ card: Card) {
        guard phase == .playerAction, !isProcessingEnemyTurn else { return }

        if card.faithCost > heroFaith {
            insufficientFaithCardId = card.id
            HapticManager.shared.play(.error)
            SoundManager.shared.play(.attackBlock)
            logEntry(L10n.combatFaithInsufficient.localized)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if insufficientFaithCardId == card.id {
                    insufficientFaithCardId = nil
                }
            }
            return
        }

        let cardName = card.name
        let result = eng.performAction(.useCard(cardId: card.id, targetId: enemy?.id))
        if !result.success {
            if result.error == .insufficientFaith {
                insufficientFaithCardId = card.id
                logEntry(L10n.combatFaithInsufficient.localized)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    if insufficientFaithCardId == card.id {
                        insufficientFaithCardId = nil
                    }
                }
            }
            return
        }
        lastChanges = result.stateChanges
        processStateChanges(result.stateChanges)
        syncState()

        HapticManager.shared.play(.medium)
        SoundManager.shared.play(.cardPlay)
        lastPlayedCardName = cardName
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if lastPlayedCardName == cardName {
                lastPlayedCardName = nil
            }
        }
    }

    func performFlee() {
        guard phase == .playerAction, !isProcessingEnemyTurn else { return }
        let fleeResult = eng.performAction(.flee)
        if !fleeResult.success {
            if fleeResult.error == .fleeNotAllowed {
                logEntry(L10n.encounterLogFleeBlocked.localized)
                HapticManager.shared.play(.error)
            }
            return
        }
        processStateChanges(fleeResult.stateChanges)
        syncState()

        if eng.fleeSucceeded {
            SoundManager.shared.play(.flee)
            HapticManager.shared.play(.success)
            finishWithResult()
        } else {
            HapticManager.shared.play(.warning)
            logEntry(L10n.encounterLogFleeFailed.localized)
            advanceAfterPlayerAction()
        }
    }
}

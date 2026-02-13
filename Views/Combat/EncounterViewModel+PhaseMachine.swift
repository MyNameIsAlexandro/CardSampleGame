/// Файл: Views/Combat/EncounterViewModel+PhaseMachine.swift
/// Назначение: Содержит реализацию файла EncounterViewModel+PhaseMachine.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine

/// Переходы фаз и завершение encounter для `EncounterViewModel`.
@MainActor
extension EncounterViewModel {

    // MARK: - Phase Machine

    func advanceAfterPlayerAction() {
        isProcessingEnemyTurn = true

        _ = eng.advancePhase()
        syncState()

        if checkEncounterEnd() {
            isProcessingEnemyTurn = false
            return
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            resolveEnemyTurn()
        }
    }

    func resolveEnemyTurn() {
        for enemyState in enemies where enemyState.isAlive && enemyState.outcome == nil {
            fateContext = .defense
            let result = eng.resolveEnemyAction(enemyId: enemyState.id)
            lastChanges = result.stateChanges
            processStateChanges(result.stateChanges)
            syncState()
        }

        if showFateReveal {
            pendingContinuation = { [weak self] in
                self?.delayedAdvanceToNextRound()
            }
            return
        }

        delayedAdvanceToNextRound()
    }

    func delayedAdvanceToNextRound() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            advanceToNextRound()
        }
    }

    func advanceToNextRound() {
        if checkEncounterEnd() {
            isProcessingEnemyTurn = false
            return
        }

        let handBefore = eng.hand.map { $0.id }
        _ = eng.advancePhase()
        syncState()

        let handAfter = eng.hand
        let newCards = handAfter.filter { !handBefore.contains($0.id) }
        if let drawn = newCards.first {
            logEntry(L10n.combatCardDrawn.localized(with: drawn.name))
            lastDrawnCardId = drawn.id
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if lastDrawnCardId == drawn.id {
                    lastDrawnCardId = nil
                }
            }
        }

        _ = eng.advancePhase()
        syncState()

        for enemyState in enemies where enemyState.isAlive && enemyState.outcome == nil {
            let intent = eng.generateIntent(for: enemyState.id)
            if enemyState.id == (selectedTarget?.id ?? enemies.first(where: { $0.isAlive })?.id) {
                currentIntent = intent
                logEntry(L10n.encounterLogRoundEnemyPrepares.localized(with: round, localizedIntentDetail(intent)))
            }
        }

        _ = eng.advancePhase()
        syncState()

        isProcessingEnemyTurn = false
    }

    func checkEncounterEnd() -> Bool {
        let allDown = enemies.allSatisfy { !$0.isAlive || $0.isPacified }
        if !enemies.isEmpty && allDown {
            finishWithResult()
            return true
        }
        if heroHP <= 0 {
            finishWithResult()
            return true
        }
        return false
    }

    func finishWithResult() {
        let result = eng.finishEncounter()
        encounterResult = result
        isFinished = true
        showCombatOver = true

        if case .victory = result.outcome {
            HapticManager.shared.play(.success)
            SoundManager.shared.play(.victory)
        } else {
            HapticManager.shared.play(.error)
            SoundManager.shared.play(.defeat)
        }
    }
}

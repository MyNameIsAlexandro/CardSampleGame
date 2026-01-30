import SwiftUI
import TwilightEngine

// MARK: - Encounter ViewModel

/// Bridges EncounterEngine (pure state machine) with SwiftUI reactivity.
/// Owns the engine, mirrors state into @Published properties, drives phase loop.
///
/// The phase loop pauses whenever a Fate Card is drawn, showing FateCardRevealView.
/// On dismiss the loop resumes from where it left off.
final class EncounterViewModel: ObservableObject {

    // MARK: - Mirrored State

    @Published var phase: EncounterPhase = .intent
    @Published var round: Int = 1
    @Published var heroHP: Int = 0
    @Published var heroMaxHP: Int = 0
    @Published var enemy: EncounterEnemyState?
    @Published var currentIntent: EnemyIntent?
    @Published var isFinished: Bool = false
    @Published var lastChanges: [EncounterStateChange] = []
    @Published var combatLog: [String] = []
    @Published var fateDeckDrawCount: Int = 0
    @Published var fateDeckDiscardCount: Int = 0

    // MARK: - Outcome

    @Published var encounterResult: EncounterResult?
    @Published var showCombatOver: Bool = false

    // MARK: - Fate Animation

    @Published var showFateReveal: Bool = false
    @Published var lastFateResult: FateDrawResult?
    @Published var fateContext: FateContext = .attack

    // MARK: - Private

    private var engine: EncounterEngine?
    private var context: EncounterContext?

    /// Non-nil engine; callers must ensure startEncounter() was called.
    private var eng: EncounterEngine {
        guard let engine else { fatalError("EncounterEngine not initialized — call startEncounter() first") }
        return engine
    }

    /// Continuation point after fate reveal is dismissed.
    private var pendingContinuation: (() -> Void)?

    // MARK: - Init

    init() {}

    func configure(context: EncounterContext) {
        self.context = context
        self.heroHP = context.hero.hp
        self.heroMaxHP = context.hero.maxHp
    }

    // MARK: - Lifecycle

    func startEncounter() {
        guard let context = context else { return }
        engine = EncounterEngine(context: context)
        syncState()

        // Auto-advance: generate first intent
        if let enemyState = enemy {
            let intent = eng.generateIntent(for: enemyState.id)
            currentIntent = intent
            logEntry(L10n.encounterLogEnemyPrepares.localized(with: intent.description))
        }

        // Move to player action
        _ = eng.advancePhase()
        syncState()
    }

    // MARK: - Player Actions

    func performAttack() {
        guard phase == .playerAction, let enemyState = enemy else { return }
        fateContext = .attack
        let result = eng.performAction(.attack(targetId: enemyState.id))
        lastChanges = result.stateChanges
        processStateChanges(result.stateChanges)
        syncState()

        // If fate card was drawn, pause for reveal; otherwise continue
        if showFateReveal {
            pendingContinuation = { [weak self] in self?.advanceAfterPlayerAction() }
        } else {
            advanceAfterPlayerAction()
        }
    }

    func performInfluence() {
        guard phase == .playerAction, let enemyState = enemy else { return }
        guard enemyState.hasSpiritTrack else { return }
        fateContext = .attack
        let result = eng.performAction(.spiritAttack(targetId: enemyState.id))
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
        guard phase == .playerAction else { return }
        let result = eng.performAction(.wait)
        lastChanges = result.stateChanges
        logEntry(L10n.encounterLogPlayerWaits.localized)
        syncState()
        advanceAfterPlayerAction()
    }

    func dismissFateReveal() {
        showFateReveal = false
        lastFateResult = nil

        // Resume the paused phase loop
        if let continuation = pendingContinuation {
            pendingContinuation = nil
            continuation()
        }
    }

    func performFlee() {
        guard phase == .playerAction else { return }
        _ = eng.performAction(.flee)
        let result = eng.finishEncounter()
        encounterResult = result
        showCombatOver = true
        isFinished = true
    }

    // MARK: - Phase Machine

    private func advanceAfterPlayerAction() {
        // Advance to enemy resolution
        _ = eng.advancePhase()
        syncState()

        // Check if encounter ended during player action (enemy killed/pacified)
        if checkEncounterEnd() { return }

        // Resolve enemy action
        if let enemyState = enemy, enemyState.isAlive {
            fateContext = .defense
            let result = eng.resolveEnemyAction(enemyId: enemyState.id)
            lastChanges = result.stateChanges
            processStateChanges(result.stateChanges)
            syncState()
        }

        // If defense fate card was drawn, pause for reveal; resume in advanceToNextRound
        if showFateReveal {
            pendingContinuation = { [weak self] in self?.advanceToNextRound() }
            return
        }

        advanceToNextRound()
    }

    private func advanceToNextRound() {
        // Check if encounter ended after enemy action
        if checkEncounterEnd() { return }

        // Advance to round end
        _ = eng.advancePhase()
        syncState()

        // Advance to next round intent phase
        _ = eng.advancePhase()
        syncState()

        // Generate next intent
        if let enemyState = enemy, enemyState.isAlive {
            let intent = eng.generateIntent(for: enemyState.id)
            currentIntent = intent
            logEntry(L10n.encounterLogRoundEnemyPrepares.localized(with: round, intent.description))
        }

        // Advance to player action
        _ = eng.advancePhase()
        syncState()
    }

    private func checkEncounterEnd() -> Bool {
        // Check victory: all enemies dead or pacified
        if let e = enemy, (!e.isAlive || e.isPacified) {
            finishWithResult()
            return true
        }
        // Check defeat: hero HP <= 0
        if heroHP <= 0 {
            finishWithResult()
            return true
        }
        return false
    }

    private func finishWithResult() {
        let result = eng.finishEncounter()
        encounterResult = result
        isFinished = true
        showCombatOver = true
    }

    // MARK: - State Sync

    private func syncState() {
        phase = eng.currentPhase
        round = eng.currentRound
        heroHP = eng.heroHP
        enemy = eng.enemies.first
        isFinished = eng.isFinished
        fateDeckDrawCount = eng.fateDeckDrawCount
        fateDeckDiscardCount = eng.fateDeckDiscardCount
    }

    // MARK: - Log Helpers

    private func processStateChanges(_ changes: [EncounterStateChange]) {
        for change in changes {
            switch change {
            case .enemyHPChanged(_, let delta, let newValue):
                logEntry(L10n.encounterLogBodyDamage.localized(with: -delta, newValue))
            case .enemyWPChanged(_, let delta, let newValue):
                logEntry(L10n.encounterLogWillDamage.localized(with: -delta, newValue))
            case .playerHPChanged(let delta, let newValue):
                if delta < 0 {
                    logEntry(L10n.encounterLogPlayerTakesDamage.localized(with: -delta, newValue))
                }
            case .enemyKilled(let enemyId):
                logEntry(L10n.encounterLogEnemySlain.localized(with: enemyId))
            case .enemyPacified(let enemyId):
                logEntry(L10n.encounterLogEnemyPacified.localized(with: enemyId))
            case .fateDraw(let cardId, let value):
                if let result = eng.lastFateDrawResult {
                    lastFateResult = result
                    showFateReveal = true
                }
                let sign = value >= 0 ? "+" : ""
                logEntry(L10n.encounterLogFateDraw.localized(with: cardId, "\(sign)\(value)"))
            case .resonanceShifted(let delta, _):
                let sign = delta >= 0 ? "+" : ""
                logEntry(L10n.encounterLogResonanceShift.localized(with: "\(sign)\(String(format: "%.0f", delta))"))
            case .rageShieldApplied(_, let value):
                logEntry(L10n.encounterLogRageShield.localized(with: value))
            case .encounterEnded:
                break
            }
        }
    }

    private func logEntry(_ text: String) {
        combatLog.append(text)
        if combatLog.count > 10 {
            combatLog.removeFirst()
        }
    }
}

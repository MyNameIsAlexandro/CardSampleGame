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
    @Published var enemies: [EncounterEnemyState] = []
    @Published var selectedTargetId: String?
    @Published var currentIntent: EnemyIntent?

    /// Primary enemy (first alive, or first) for backward-compatible UI
    var enemy: EncounterEnemyState? { enemies.first(where: { $0.isAlive }) ?? enemies.first }
    @Published var isFinished: Bool = false
    @Published var lastChanges: [EncounterStateChange] = []
    @Published var combatLog: [String] = []
    @Published var fateDeckDrawCount: Int = 0
    @Published var fateDeckDiscardCount: Int = 0
    @Published var hand: [Card] = []
    @Published var heroFaith: Int = 0
    @Published var pendingFateChoice: FateCard? = nil
    @Published var showFateChoice: Bool = false

    // MARK: - Hero Deck State

    @Published var heroDeckCount: Int = 0
    @Published var heroDiscardCount: Int = 0

    // MARK: - Mulligan State

    @Published var showMulligan: Bool = false
    @Published var mulliganSelection: Set<String> = []

    // MARK: - Card Play Feedback

    @Published var insufficientFaithCardId: String? = nil
    @Published var lastDrawnCardId: String? = nil
    @Published var lastPlayedCardName: String? = nil

    // MARK: - Phase Animation Lock

    @Published var isProcessingEnemyTurn: Bool = false

    // MARK: - Outcome

    @Published var encounterResult: EncounterResult?
    @Published var showCombatOver: Bool = false

    // MARK: - Turn Bonuses
    @Published var turnAttackBonus: Int = 0
    @Published var turnInfluenceBonus: Int = 0
    @Published var turnDefenseBonus: Int = 0

    // MARK: - Fate Animation

    @Published var showFateReveal: Bool = false
    @Published var lastFateResult: FateDrawResult?
    @Published var fateContext: FateContext = .attack

    // MARK: - Private

    private var engine: EncounterEngine?
    private var context: EncounterContext?

    /// The currently selected target enemy (defaults to first alive)
    var selectedTarget: EncounterEnemyState? {
        if let id = selectedTargetId { return enemies.first(where: { $0.id == id && $0.isAlive }) }
        return enemies.first(where: { $0.isAlive })
    }

    func selectTarget(_ id: String) {
        selectedTargetId = id
    }

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

    /// Get current encounter state for mid-combat save
    func getSaveState() -> EncounterSaveState? {
        return engine?.createSaveState()
    }

    /// Restore encounter from saved state (instead of startEncounter)
    func restoreEncounter(from state: EncounterSaveState) {
        engine = EncounterEngine.restore(from: state)
        syncState()
        // Skip mulligan on restore - combat already in progress
        showMulligan = false
    }

    func startEncounter() {
        guard let context = context else { return }
        engine = EncounterEngine(context: context)
        syncState()

        // Auto-advance: generate first intent
        if let enemyState = enemy {
            let intent = eng.generateIntent(for: enemyState.id)
            currentIntent = intent
            logEntry(L10n.encounterLogEnemyPrepares.localized(with: localizedIntentDetail(intent)))
        }

        // Move to player action
        _ = eng.advancePhase()
        syncState()

        // Show mulligan if player has cards AND pool has replacements
        if !hand.isEmpty && heroDeckCount > 0 {
            showMulligan = true
        }
    }

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

        // If fate card was drawn, pause for reveal; otherwise continue
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

        // Resume the paused phase loop
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
        // Resume pending continuation if any
        if let continuation = pendingContinuation {
            pendingContinuation = nil
            continuation()
        }
    }

    func playCard(_ card: Card) {
        guard phase == .playerAction, !isProcessingEnemyTurn else { return }

        // Pre-check faith affordability for UI feedback
        if card.faithCost > heroFaith {
            insufficientFaithCardId = card.id
            HapticManager.shared.play(.error)
            SoundManager.shared.play(.attackBlock)
            logEntry(L10n.combatFaithInsufficient.localized)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                if self?.insufficientFaithCardId == card.id {
                    self?.insufficientFaithCardId = nil
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    if self?.insufficientFaithCardId == card.id {
                        self?.insufficientFaithCardId = nil
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
        // Show played card name prominently
        lastPlayedCardName = cardName
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if self?.lastPlayedCardName == cardName {
                self?.lastPlayedCardName = nil
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
            // Failed flee: enemy still gets their turn
            HapticManager.shared.play(.warning)
            logEntry(L10n.encounterLogFleeFailed.localized)
            advanceAfterPlayerAction()
        }
    }

    // MARK: - Phase Machine

    private func advanceAfterPlayerAction() {
        isProcessingEnemyTurn = true

        // Advance to enemy resolution
        _ = eng.advancePhase()
        syncState()

        // Check if encounter ended during player action (enemy killed/pacified)
        if checkEncounterEnd() {
            isProcessingEnemyTurn = false
            return
        }

        // Delay enemy resolution so player sees "Ход врага" phase
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.resolveEnemyTurn()
        }
    }

    private func resolveEnemyTurn() {
        // Resolve enemy actions for all alive enemies
        for enemyState in enemies where enemyState.isAlive && enemyState.outcome == nil {
            fateContext = .defense
            let result = eng.resolveEnemyAction(enemyId: enemyState.id)
            lastChanges = result.stateChanges
            processStateChanges(result.stateChanges)
            syncState()
        }

        // If defense fate card was drawn, pause for reveal; resume in advanceToNextRound
        if showFateReveal {
            pendingContinuation = { [weak self] in
                self?.delayedAdvanceToNextRound()
            }
            return
        }

        delayedAdvanceToNextRound()
    }

    private func delayedAdvanceToNextRound() {
        // Brief pause after enemy resolution before next round
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.advanceToNextRound()
        }
    }

    private func advanceToNextRound() {
        // Check if encounter ended after enemy action
        if checkEncounterEnd() {
            isProcessingEnemyTurn = false
            return
        }

        let handBefore = eng.hand.map { $0.id }

        // Advance to round end (draws card here)
        _ = eng.advancePhase()
        syncState()

        // Check for drawn card
        let handAfter = eng.hand
        let newCards = handAfter.filter { !handBefore.contains($0.id) }
        if let drawn = newCards.first {
            logEntry(L10n.combatCardDrawn.localized(with: drawn.name))
            lastDrawnCardId = drawn.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                if self?.lastDrawnCardId == drawn.id {
                    self?.lastDrawnCardId = nil
                }
            }
        }

        // Advance to next round intent phase
        _ = eng.advancePhase()
        syncState()

        // Generate intents for all alive enemies (show primary enemy's intent)
        for enemyState in enemies where enemyState.isAlive && enemyState.outcome == nil {
            let intent = eng.generateIntent(for: enemyState.id)
            if enemyState.id == (selectedTarget?.id ?? enemies.first(where: { $0.isAlive })?.id) {
                currentIntent = intent
                logEntry(L10n.encounterLogRoundEnemyPrepares.localized(with: round, localizedIntentDetail(intent)))
            }
        }

        // Advance to player action
        _ = eng.advancePhase()
        syncState()

        isProcessingEnemyTurn = false
    }

    private func checkEncounterEnd() -> Bool {
        // Check victory: all enemies dead or pacified
        let allDown = enemies.allSatisfy { !$0.isAlive || $0.isPacified }
        if !enemies.isEmpty && allDown {
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

        // Victory/defeat feedback
        if case .victory = result.outcome {
            HapticManager.shared.play(.success)
            SoundManager.shared.play(.victory)
        } else {
            HapticManager.shared.play(.error)
            SoundManager.shared.play(.defeat)
        }
    }

    // MARK: - State Sync

    private func syncState() {
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

    private func processStateChanges(_ changes: [EncounterStateChange]) {
        for change in changes {
            switch change {
            case .enemyHPChanged(_, let delta, let newValue):
                logEntry(L10n.encounterLogBodyDamage.localized(with: -delta, newValue))
            case .enemyWPChanged(_, let delta, let newValue):
                logEntry(L10n.encounterLogWillDamage.localized(with: -delta, newValue))
            case .playerHPChanged(let delta, let newValue):
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

    private func logEntry(_ text: String) {
        combatLog.append(text)
        if combatLog.count > 10 {
            combatLog.removeFirst()
        }
    }

    // MARK: - Intent Localization

    /// Localize intent for combat log (mirrors EnemyIntentView.intentDetail)
    private func localizedIntentDetail(_ intent: EnemyIntent) -> String {
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

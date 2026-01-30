import SwiftUI
import TwilightEngine

// MARK: - Encounter ViewModel

/// Bridges EncounterEngine (pure state machine) with SwiftUI reactivity.
/// Owns the engine, mirrors state into @Published properties, drives phase loop.
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

    // MARK: - Outcome

    @Published var encounterResult: EncounterResult?
    @Published var showCombatOver: Bool = false

    // MARK: - Fate Animation

    @Published var showFateReveal: Bool = false
    @Published var lastFateResult: FateDrawResult?
    @Published var fateContext: FateContext = .attack

    // MARK: - Private

    private var engine: EncounterEngine!
    private var context: EncounterContext?

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
            let intent = engine.generateIntent(for: enemyState.id)
            currentIntent = intent
            logEntry("Враг готовит: \(intent.description)")
        }

        // Move to player action
        _ = engine.advancePhase()
        syncState()
    }

    // MARK: - Player Actions

    func performAttack() {
        guard phase == .playerAction, let enemyState = enemy else { return }
        fateContext = .attack
        let result = engine.performAction(.attack(targetId: enemyState.id))
        lastChanges = result.stateChanges
        processStateChanges(result.stateChanges)
        syncState()
        advanceAfterPlayerAction()
    }

    func performInfluence() {
        guard phase == .playerAction, let enemyState = enemy else { return }
        guard enemyState.hasSpiritTrack else { return }
        fateContext = .attack
        let result = engine.performAction(.spiritAttack(targetId: enemyState.id))
        lastChanges = result.stateChanges
        processStateChanges(result.stateChanges)
        syncState()
        advanceAfterPlayerAction()
    }

    func performWait() {
        guard phase == .playerAction else { return }
        let result = engine.performAction(.wait)
        lastChanges = result.stateChanges
        logEntry("Вы выжидаете.")
        syncState()
        advanceAfterPlayerAction()
    }

    func dismissFateReveal() {
        showFateReveal = false
        lastFateResult = nil
    }

    func performFlee() {
        guard phase == .playerAction else { return }
        _ = engine.performAction(.flee)
        let result = engine.finishEncounter()
        encounterResult = result
        showCombatOver = true
        isFinished = true
    }

    // MARK: - Phase Machine

    private func advanceAfterPlayerAction() {
        // Advance to enemy resolution
        _ = engine.advancePhase()
        syncState()

        // Check if encounter ended during player action (enemy killed/pacified)
        if checkEncounterEnd() { return }

        // Resolve enemy action
        if let enemyState = enemy, enemyState.isAlive {
            fateContext = .defense
            let result = engine.resolveEnemyAction(enemyId: enemyState.id)
            lastChanges = result.stateChanges
            processStateChanges(result.stateChanges)
            syncState()
        }

        // Check if encounter ended after enemy action
        if checkEncounterEnd() { return }

        // Advance to round end
        _ = engine.advancePhase()
        syncState()

        // Advance to next round intent phase
        _ = engine.advancePhase()
        syncState()

        // Generate next intent
        if let enemyState = enemy, enemyState.isAlive {
            let intent = engine.generateIntent(for: enemyState.id)
            currentIntent = intent
            logEntry("Ход \(round): Враг готовит \(intent.description)")
        }

        // Advance to player action
        _ = engine.advancePhase()
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
        let result = engine.finishEncounter()
        encounterResult = result
        isFinished = true
        showCombatOver = true
    }

    // MARK: - State Sync

    private func syncState() {
        phase = engine.currentPhase
        round = engine.currentRound
        heroHP = engine.heroHP
        enemy = engine.enemies.first
        isFinished = engine.isFinished
    }

    // MARK: - Log Helpers

    private func processStateChanges(_ changes: [EncounterStateChange]) {
        for change in changes {
            switch change {
            case .enemyHPChanged(_, let delta, let newValue):
                logEntry("Урон телу: \(-delta) (HP: \(newValue))")
            case .enemyWPChanged(_, let delta, let newValue):
                logEntry("Урон воле: \(-delta) (WP: \(newValue))")
            case .playerHPChanged(let delta, let newValue):
                if delta < 0 {
                    logEntry("Вы получили \(-delta) урона (HP: \(newValue))")
                }
            case .enemyKilled(let enemyId):
                logEntry("Враг \(enemyId) повержен!")
            case .enemyPacified(let enemyId):
                logEntry("Враг \(enemyId) усмирён!")
            case .fateDraw(let cardId, let value):
                if let result = engine.lastFateDrawResult {
                    lastFateResult = result
                    showFateReveal = true
                }
                logEntry("Карта судьбы: \(cardId) (\(value >= 0 ? "+" : "")\(value))")
            case .resonanceShifted(let delta, _):
                logEntry("Резонанс: \(delta >= 0 ? "+" : "")\(String(format: "%.0f", delta))")
            case .rageShieldApplied(_, let value):
                logEntry("Щит ярости: +\(value)")
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

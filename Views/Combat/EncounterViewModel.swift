/// Файл: Views/Combat/EncounterViewModel.swift
/// Назначение: Содержит реализацию файла EncounterViewModel.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine

// MARK: - Encounter ViewModel

/// Bridges EncounterEngine (pure state machine) with SwiftUI reactivity.
/// Owns the engine, mirrors state into @Published properties, drives phase loop.
///
/// The phase loop pauses whenever a Fate Card is drawn, showing FateCardRevealView.
/// On dismiss the loop resumes from where it left off.
@MainActor
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

    // MARK: - Combat Statistics

    private(set) var totalDamageDealt: Int = 0
    private(set) var totalDamageTaken: Int = 0
    private(set) var cardsPlayedCount: Int = 0
    private(set) var fateCardsDrawnCount: Int = 0

    func addDamageDealt(_ value: Int) {
        totalDamageDealt += value
    }

    func addDamageTaken(_ value: Int) {
        totalDamageTaken += value
    }

    func incrementCardsPlayed() {
        cardsPlayedCount += 1
    }

    func incrementFateCardsDrawn() {
        fateCardsDrawnCount += 1
    }

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
    var eng: EncounterEngine {
        guard let engine else { fatalError("EncounterEngine not initialized — call startEncounter() first") }
        return engine
    }

    /// Continuation point after fate reveal is dismissed.
    var pendingContinuation: (() -> Void)?

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
}

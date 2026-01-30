import SwiftUI
import TwilightEngine

/// New encounter-powered combat screen.
/// Layout: ResonanceWidget → EnemyPanel → HeroHealthBar → RoundInfoBar → CombatLog → ActionBar → FateDeckBar
/// Overlays: CombatOverView
struct CombatView: View {
    @ObservedObject var engine: TwilightGameEngine
    let onCombatEnd: (CombatOutcome) -> Void

    // MARK: - Legacy-compatible types

    enum CombatOutcome: Equatable {
        case victory(stats: CombatStats)
        case defeat(stats: CombatStats)
        case fled

        var isVictory: Bool {
            if case .victory = self { return true }
            return false
        }
    }

    struct CombatStats: Equatable {
        let turnsPlayed: Int
        let totalDamageDealt: Int
        let totalDamageTaken: Int
        let cardsPlayed: Int

        var summary: String {
            L10n.combatTurnsStats.localized(with: turnsPlayed, totalDamageDealt, totalDamageTaken)
        }
    }

    // MARK: - State

    @StateObject private var vm = EncounterViewModel()
    @State private var startHP: Int = 0
    @State private var didStart: Bool = false

    var body: some View {
        ZStack {
            AppColors.backgroundSystem
                .ignoresSafeArea()

            if didStart {
                mainContent
            } else {
                ProgressView()
            }
        }
        .onAppear { setupEncounter() }
    }

    // MARK: - Main Layout

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Resonance widget (compact)
            ResonanceWidget(engine: engine, compact: true)
                .padding(.horizontal)
                .padding(.top, Spacing.sm)

            // Enemy panel: intent + name + dual health bars
            EnemyPanel(
                enemy: vm.enemy,
                intent: vm.currentIntent
            )

            // Round info
            RoundInfoBar(round: vm.round, phase: vm.phase)

            // Hero health bar
            HeroHealthBar(currentHP: vm.heroHP, maxHP: vm.heroMaxHP)
                .padding(.horizontal)
                .padding(.vertical, Spacing.xs)

            Spacer()

            // Combat log
            CombatLogView(entries: vm.combatLog)
                .padding(.bottom, Spacing.xs)

            // Action buttons
            ActionBar(
                canAct: vm.phase == .playerAction && !vm.isFinished,
                hasSpiritTrack: vm.enemy?.hasSpiritTrack ?? false,
                onAttack: { vm.performAttack() },
                onInfluence: { vm.performInfluence() },
                onWait: { vm.performWait() }
            )
            .padding(.bottom, Spacing.sm)

            // Fate deck bar + flee
            FateDeckBar(
                drawCount: engine.fateDeckDrawCount,
                discardCount: engine.fateDeckDiscardCount,
                onFlee: { vm.performFlee() }
            )
        }
        .overlay {
            if vm.showCombatOver, let result = vm.encounterResult {
                CombatOverView(result: result) {
                    applyResultAndDismiss(result: result)
                }
            }
        }
    }

    // MARK: - Setup

    private func setupEncounter() {
        guard !didStart, let ctx = engine.makeEncounterContext() else { return }
        startHP = ctx.hero.hp
        vm.configure(context: ctx)
        vm.startEncounter()
        didStart = true
    }

    // MARK: - Result

    private func applyResultAndDismiss(result: EncounterResult) {
        engine.applyEncounterResult(result)

        let hpLost = max(0, startHP - vm.heroHP)
        let stats = CombatStats(
            turnsPlayed: vm.round,
            totalDamageDealt: 0,
            totalDamageTaken: hpLost,
            cardsPlayed: 0
        )

        let outcome: CombatOutcome
        switch result.outcome {
        case .victory:
            outcome = .victory(stats: stats)
        case .defeat:
            outcome = .defeat(stats: stats)
        case .escaped:
            outcome = .fled
        }

        onCombatEnd(outcome)
    }
}

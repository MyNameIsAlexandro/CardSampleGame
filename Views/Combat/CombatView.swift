import SwiftUI
import TwilightEngine

/// New encounter-powered combat screen.
/// Layout: ResonanceWidget → EnemyPanel → HeroHealthBar → RoundInfoBar → CombatLog → ActionBar → FateDeckBar
/// Overlays: CombatOverView, MulliganOverlay
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

    // UX-05: Floating damage numbers
    @State private var floatingDamage: FloatingNumber? = nil
    @State private var showDamageFlash: Bool = false

    var body: some View {
        ZStack {
            AppColors.backgroundSystem
                .ignoresSafeArea()

            if didStart {
                if vm.showMulligan {
                    VStack(spacing: 0) {
                        // Hero stats visible during mulligan
                        HeroPanel(engine: engine, compact: true)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.top, Spacing.sm)

                        Spacer()

                        MulliganOverlay(
                            hand: vm.hand,
                            selection: vm.mulliganSelection,
                            onToggle: { vm.toggleMulliganCard(id: $0) },
                            onConfirm: { vm.confirmMulligan() },
                            onSkip: { vm.skipMulligan() }
                        )

                        Spacer()
                    }
                } else {
                    mainContent
                }
            } else {
                ProgressView()
            }
        }
        .onAppear { setupEncounter() }
        .overlay(damageFlashOverlay)
        .overlay(floatingDamageOverlay)
        .onChange(of: vm.lastChanges) { changes in
            for change in changes {
                switch change {
                case .playerHPChanged(let delta, _) where delta < 0:
                    showFloatingDamage(value: -delta, isHero: true)
                    triggerDamageFlash()
                case .enemyHPChanged(_, let delta, _) where delta < 0:
                    showFloatingDamage(value: -delta, isHero: false)
                case .enemyWPChanged(_, let delta, _) where delta < 0:
                    showFloatingDamage(value: -delta, isHero: false)
                default:
                    break
                }
            }
        }
    }

    // MARK: - UX-05: Floating Damage Numbers

    @ViewBuilder
    private var floatingDamageOverlay: some View {
        if let dmg = floatingDamage {
            Text("-\(dmg.value)")
                .font(.title)
                .fontWeight(.black)
                .foregroundColor(dmg.isHero ? AppColors.danger : AppColors.warning)
                .shadow(color: .black, radius: 2)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(dmg.id)
                .position(x: UIScreen.main.bounds.width / 2,
                          y: dmg.isHero ? UIScreen.main.bounds.height * 0.55 : UIScreen.main.bounds.height * 0.2)
        }
    }

    // MARK: - UX-06: Damage Flash

    @ViewBuilder
    private var damageFlashOverlay: some View {
        if showDamageFlash {
            AppGradient.damageFlash
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    private func showFloatingDamage(value: Int, isHero: Bool) {
        withAnimation(AppAnimation.snap) {
            floatingDamage = FloatingNumber(value: value, isHero: isHero)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                floatingDamage = nil
            }
        }
    }

    private func triggerDamageFlash() {
        withAnimation(.easeIn(duration: 0.05)) {
            showDamageFlash = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: 0.2)) {
                showDamageFlash = false
            }
        }
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

            // Hero stats bar: HP + Faith + bonuses
            HStack(spacing: Spacing.md) {
                // HP
                HStack(spacing: Spacing.xxxs) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundColor(AppColors.health)
                    Text("\(vm.heroHP)/\(vm.heroMaxHP)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }

                // Faith
                HStack(spacing: Spacing.xxxs) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundColor(AppColors.faith)
                    Text("\(vm.heroFaith)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }

                // Attack bonus
                if vm.turnAttackBonus > 0 {
                    HStack(spacing: Spacing.xxxs) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundColor(AppColors.power)
                        Text("+\(vm.turnAttackBonus)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.power)
                    }
                }

                // Influence bonus
                if vm.turnInfluenceBonus > 0 {
                    HStack(spacing: Spacing.xxxs) {
                        Image(systemName: "bubble.left.fill")
                            .font(.caption2)
                            .foregroundColor(AppColors.info)
                        Text("+\(vm.turnInfluenceBonus)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.info)
                    }
                }

                // Defense bonus
                if vm.turnDefenseBonus > 0 {
                    HStack(spacing: Spacing.xxxs) {
                        Image(systemName: "shield.fill")
                            .font(.caption2)
                            .foregroundColor(AppColors.defense)
                        Text("+\(vm.turnDefenseBonus)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.defense)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(AppColors.cardBackground)

            // Hero HP bar
            HeroHealthBar(currentHP: vm.heroHP, maxHP: vm.heroMaxHP)
                .padding(.horizontal)
                .padding(.vertical, Spacing.xxxs)

            Spacer()

            // Played card banner
            if let cardName = vm.lastPlayedCardName {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "sparkles")
                        .foregroundColor(AppColors.warning)
                    Text(L10n.encounterLogCardPlayed.localized(with: cardName))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primary)
                }
                .padding(.vertical, Spacing.xs)
                .padding(.horizontal, Spacing.md)
                .background(AppColors.warning.opacity(Opacity.faint))
                .cornerRadius(CornerRadius.md)
                .transition(.scale.combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: vm.lastPlayedCardName != nil)
            }

            // Hero deck indicator
            HeroDeckIndicator(
                deckCount: vm.heroDeckCount,
                discardCount: vm.heroDiscardCount
            )

            // Player card hand
            CardHandView(
                cards: vm.hand,
                heroFaith: vm.heroFaith,
                insufficientFaithCardId: vm.insufficientFaithCardId,
                lastDrawnCardId: vm.lastDrawnCardId,
                isEnabled: vm.phase == .playerAction && !vm.isFinished && !vm.isProcessingEnemyTurn,
                onPlay: { vm.playCard($0) }
            )

            // Combat log
            CombatLogView(entries: vm.combatLog)
                .padding(.bottom, Spacing.xs)

            // Action buttons
            ActionBar(
                canAct: vm.phase == .playerAction && !vm.isFinished && !vm.isProcessingEnemyTurn,
                hasSpiritTrack: vm.enemy?.hasSpiritTrack ?? false,
                onAttack: { vm.performAttack() },
                onInfluence: { vm.performInfluence() },
                onWait: { vm.performWait() }
            )
            .padding(.bottom, Spacing.sm)

            // Fate deck bar + flee
            FateDeckBar(
                drawCount: vm.fateDeckDrawCount,
                discardCount: vm.fateDeckDiscardCount,
                faith: vm.heroFaith,
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
        .sheet(isPresented: $vm.showFateReveal) {
            if let result = vm.lastFateResult {
                FateCardRevealView(
                    result: result,
                    context: vm.fateContext,
                    worldResonance: engine.resonanceValue,
                    onDismiss: { vm.dismissFateReveal() }
                )
            }
        }
        .sheet(isPresented: $vm.showFateChoice) {
            if let card = vm.pendingFateChoice {
                FateCardChoiceSheet(card: card) { index in
                    vm.resolveFateChoice(optionIndex: index)
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

// MARK: - Floating Number Model

private struct FloatingNumber: Equatable {
    let id = UUID()
    let value: Int
    let isHero: Bool

    static func == (lhs: FloatingNumber, rhs: FloatingNumber) -> Bool {
        lhs.id == rhs.id
    }
}

import SwiftUI
import TwilightEngine

/// New encounter-powered combat screen.
/// Layout: ResonanceWidget → EnemyPanel → HeroHealthBar → RoundInfoBar → CombatLog → ActionBar → FateDeckBar
/// Overlays: CombatOverView, MulliganOverlay
struct CombatView: View {
    @ObservedObject var engineVM: GameEngineObservable
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
    var savedState: EncounterSaveState? = nil

    // UX-05: Floating damage numbers
    @State private var floatingDamage: FloatingNumber? = nil
    @State private var showDamageFlash: Bool = false
    @State private var showSaveExitConfirm: Bool = false

    // Combat feedback overlay per enemy
    @State private var enemyFeedback: [String: CombatFeedback] = [:]

    var body: some View {
        ZStack {
            AppColors.backgroundSystem
                .ignoresSafeArea()

            if didStart {
                if vm.showMulligan {
                    VStack(spacing: 0) {
                        // Hero stats visible during mulligan
                        HeroPanel(vm: engineVM, compact: true)
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
                    showFloatingDamage(value: -delta, isHero: true, color: .damage)
                    triggerDamageFlash()
                case .playerHPChanged(let delta, _) where delta > 0:
                    showFloatingDamage(value: delta, isHero: true, color: .heal)
                case .enemyHPChanged(_, let delta, _) where delta < 0:
                    showFloatingDamage(value: -delta, isHero: false, color: .enemyDamage)
                case .enemyWPChanged(_, let delta, _) where delta < 0:
                    showFloatingDamage(value: -delta, isHero: false, color: .spiritDamage)
                case .weaknessTriggered(let enemyId, let keyword):
                    showEnemyFeedback(enemyId: enemyId, feedback: .weakness(keyword: keyword))
                case .resistanceTriggered(let enemyId, let keyword):
                    showEnemyFeedback(enemyId: enemyId, feedback: .resistance(keyword: keyword))
                case .abilityTriggered(let enemyId, _, let effect):
                    if effect.contains("regen") {
                        showEnemyFeedback(enemyId: enemyId, feedback: .abilityRegen(amount: 0))
                    } else if effect.contains("armor") {
                        showEnemyFeedback(enemyId: enemyId, feedback: .abilityArmor)
                    } else if effect.contains("bonus") || effect.contains("damage") {
                        showEnemyFeedback(enemyId: enemyId, feedback: .abilityBonusDamage)
                    }
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
            Text("\(dmg.floatingColor.prefix)\(dmg.value)")
                .font(.title)
                .fontWeight(.black)
                .foregroundColor(dmg.floatingColor.color)
                .shadow(color: AppColors.backgroundSystem, radius: 2)
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

    private func showFloatingDamage(value: Int, isHero: Bool, color: FloatingColor = .damage) {
        withAnimation(AppAnimation.snap) {
            floatingDamage = FloatingNumber(value: value, isHero: isHero, floatingColor: color)
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
            // Resonance widget (compact) + Save & Exit
            HStack {
                ResonanceWidget(vm: engineVM, compact: true)
                Spacer()
                Button {
                    showSaveExitConfirm = true
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.body)
                        .foregroundColor(AppColors.muted)
                }
            }
            .padding(.horizontal)
            .padding(.top, Spacing.sm)

            // Phase banner
            PhaseBanner(phase: vm.phase, round: vm.round)
                .padding(.top, Spacing.xs)

            // Enemy cards (horizontal scroll for multi-enemy)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(vm.enemies, id: \.id) { enemy in
                        EnemyCardView(
                            enemy: enemy,
                            intent: enemy.id == (vm.selectedTarget?.id ?? vm.enemy?.id) ? vm.currentIntent : nil,
                            isSelected: vm.enemies.count > 1 && enemy.id == (vm.selectedTargetId ?? vm.enemy?.id),
                            feedbackType: enemyFeedback[enemy.id],
                            onTap: { vm.selectTarget(enemy.id) }
                        )
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
            .padding(.vertical, Spacing.xs)

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

                // Attack bonus capsule
                if vm.turnAttackBonus > 0 {
                    bonusCapsule(icon: "flame.fill", value: vm.turnAttackBonus, color: AppColors.power)
                        .transition(.scale.combined(with: .opacity))
                }

                // Influence bonus capsule
                if vm.turnInfluenceBonus > 0 {
                    bonusCapsule(icon: "bubble.left.fill", value: vm.turnInfluenceBonus, color: AppColors.info)
                        .transition(.scale.combined(with: .opacity))
                }

                // Defense bonus capsule
                if vm.turnDefenseBonus > 0 {
                    bonusCapsule(icon: "shield.fill", value: vm.turnDefenseBonus, color: AppColors.defense)
                        .transition(.scale.combined(with: .opacity))
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
                attackBonus: vm.turnAttackBonus,
                influenceBonus: vm.turnInfluenceBonus,
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
                CombatOverView(
                    result: result,
                    turnsPlayed: vm.round,
                    totalDamageDealt: vm.totalDamageDealt,
                    cardsPlayed: vm.cardsPlayedCount
                ) {
                    applyResultAndDismiss(result: result)
                }
            }
        }
        .sheet(isPresented: $vm.showFateReveal) {
            if let result = vm.lastFateResult {
                FateCardRevealView(
                    result: result,
                    context: vm.fateContext,
                    worldResonance: engineVM.engine.resonanceValue,
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
        .alert(L10n.combatSaveExitTitle.localized, isPresented: $showSaveExitConfirm) {
            Button(L10n.combatSaveExitConfirm.localized, role: .destructive) {
                saveAndExit()
            }
            Button(L10n.combatSaveExitCancel.localized, role: .cancel) {}
        } message: {
            Text(L10n.combatSaveExitMessage.localized)
        }
    }

    // MARK: - Bonus Capsule

    private func bonusCapsule(icon: String, value: Int, color: Color) -> some View {
        HStack(spacing: Spacing.xxxs) {
            Image(systemName: icon)
                .font(.caption2)
            Text("+\(value)")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xxxs)
        .background(color.opacity(Opacity.high))
        .cornerRadius(CornerRadius.sm)
    }

    // MARK: - Enemy Feedback

    private func showEnemyFeedback(enemyId: String, feedback: CombatFeedback) {
        withAnimation(.easeIn(duration: 0.15)) {
            enemyFeedback[enemyId] = feedback
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                enemyFeedback[enemyId] = nil
            }
        }
    }

    // MARK: - Setup

    private func setupEncounter() {
        guard !didStart else { return }
        if let saved = savedState {
            startHP = saved.context.hero.hp
            vm.restoreEncounter(from: saved)
            didStart = true
        } else if let ctx = engineVM.engine.makeEncounterContext() {
            startHP = ctx.hero.hp
            vm.configure(context: ctx)
            vm.startEncounter()
            didStart = true
        }
    }

    // MARK: - Save & Exit

    private func saveAndExit() {
        if let state = vm.getSaveState() {
            engineVM.engine.pendingEncounterState = state
        }
        onCombatEnd(.fled)
    }

    // MARK: - Result

    private func applyResultAndDismiss(result: EncounterResult) {
        engineVM.engine.applyEncounterResult(result)

        let stats = CombatStats(
            turnsPlayed: vm.round,
            totalDamageDealt: vm.totalDamageDealt,
            totalDamageTaken: vm.totalDamageTaken,
            cardsPlayed: vm.cardsPlayedCount
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

        // PG-04: Record encounter in ProfileManager
        let profileManager = ProfileManager.shared
        for (enemyId, entityOutcome) in result.perEntityOutcomes {
            let profileOutcome: EncounterOutcomeType
            switch entityOutcome {
            case .killed: profileOutcome = .defeated
            case .pacified: profileOutcome = .pacified
            case .escaped: profileOutcome = .fled
            case .alive: profileOutcome = .lost
            }
            profileManager.recordEncounter(
                enemyId: enemyId,
                day: engineVM.engine.currentDay,
                outcome: profileOutcome
            )
        }
        profileManager.recordCombatStats(
            damageDealt: vm.totalDamageDealt,
            damageTaken: vm.totalDamageTaken,
            cardsPlayed: vm.cardsPlayedCount,
            fateCardsDrawn: vm.fateCardsDrawnCount
        )
        // Check for new achievements
        let newUnlocks = AchievementEngine.evaluateNewUnlocks(profile: profileManager.profile)
        for id in newUnlocks {
            profileManager.recordAchievement(id)
        }

        onCombatEnd(outcome)
    }
}

// MARK: - Floating Number Model

private enum FloatingColor {
    case damage      // red — hero takes damage
    case heal        // green — hero heals
    case enemyDamage // yellow — enemy HP damage
    case spiritDamage // blue — enemy WP damage

    var color: Color {
        switch self {
        case .damage: return AppColors.danger
        case .heal: return AppColors.success
        case .enemyDamage: return AppColors.warning
        case .spiritDamage: return AppColors.spirit
        }
    }

    var prefix: String {
        switch self {
        case .damage: return "-"
        case .heal: return "+"
        case .enemyDamage: return "-"
        case .spiritDamage: return "-"
        }
    }
}

private struct FloatingNumber: Equatable {
    let id = UUID()
    let value: Int
    let isHero: Bool
    let floatingColor: FloatingColor

    static func == (lhs: FloatingNumber, rhs: FloatingNumber) -> Bool {
        lhs.id == rhs.id
    }
}

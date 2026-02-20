/// Файл: Views/EventView.swift
/// Назначение: Содержит реализацию файла EventView.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine

/// Экран события кампании.
/// Все изменения состояния проходят через action-пайплайн движка, UI только отображает состояние.
struct EventView: View {
    // MARK: - Engine-First Architecture
    @ObservedObject var vm: GameEngineObservable

    let event: GameEvent
    let regionId: String
    let onChoiceSelected: (EventChoice) -> Void
    let onDismiss: () -> Void

    @State private var selectedChoice: EventChoice?
    @State private var showingResult = false
    @State private var resultMessage: String = ""
    @State private var activeDispositionCombat: ActiveEventDispositionCombat?
    @State private var combatVictory: Bool?

    // MARK: - Initialization (Engine-First only)

    init(
        vm: GameEngineObservable,
        event: GameEvent,
        regionId: String,
        onChoiceSelected: @escaping (EventChoice) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.vm = vm
        self.event = event
        self.regionId = regionId
        self.onChoiceSelected = onChoiceSelected
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    // Hero Panel (consistent design across all screens)
                    HeroPanel(vm: vm, compact: true)
                        .padding(.horizontal)

                    // Event header
                    eventHeader

                    Divider()

                    // Event description
                    Text(event.description)
                        .font(.body)
                        .foregroundColor(AppColors.muted)
                        .padding(.horizontal)

                    Divider()

                    // Choices
                    VStack(spacing: Spacing.md) {
                        Text(L10n.eventChooseAction.localized)
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(event.choices) { choice in
                            choiceButton(choice)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle(event.title)
            .background(AppColors.backgroundSystem)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColors.backgroundSystem, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(AppColors.primary)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.uiClose.localized) {
                        onDismiss()
                    }
                }
            }
            .alert(L10n.uiResult.localized, isPresented: $showingResult) {
                Button(L10n.buttonOk.localized) {
                    // Note: onChoiceSelected is already called in handleCombatEnd for combat victories
                    // or in handleNonCombatChoice for non-combat choices
                    onDismiss()
                }
            } message: {
                Text(resultMessage)
            }
            .fullScreenCover(item: $activeDispositionCombat) { combat in
                DispositionCombatSceneView(
                    simulation: combat.simulation,
                    onCombatEnd: { result in
                        DispositionCombatBridge.applyCombatResult(result, to: vm.engine)
                        let stats = AppCombatStats(
                            turnsPlayed: result.turnsPlayed, totalDamageDealt: 0,
                            totalDamageTaken: 0, cardsPlayed: result.cardsPlayed)
                        handleCombatEnd(outcome: result.outcome == .defeated
                            ? .defeat(stats: stats) : .victory(stats: stats))
                    },
                    onSoundEffect: Self.playSoundEffect,
                    onHaptic: Self.playHaptic
                )
            }
        }
    }

    // MARK: - Event Header

    var eventHeader: some View {
        HStack(spacing: Spacing.md) {
            // Event type icon
            ZStack {
                Circle()
                    .fill(eventTypeColor.opacity(Opacity.faint))
                    .frame(width: Sizes.iconRegion, height: Sizes.iconRegion)

                Image(systemName: event.eventType.icon)
                    .font(.title2)
                    .foregroundColor(eventTypeColor)
            }

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(event.eventType.displayName)
                    .font(.caption)
                    .foregroundColor(AppColors.muted)

                Text(event.title)
                    .font(.title3)
                    .fontWeight(.bold)
            }

            Spacer()
        }
        .padding(.horizontal)
    }

    // MARK: - Hero Stats (now uses HeroPanel component)
    // Old heroStatsBar removed - using unified HeroPanel component instead

    var eventTypeColor: Color {
        switch event.eventType {
        case .combat: return AppColors.danger
        case .ritual: return AppColors.dark
        case .narrative: return AppColors.primary
        case .exploration: return AppColors.info
        case .worldShift: return AppColors.power
        }
    }

    // MARK: - Choice Button

    func choiceButton(_ choice: EventChoice) -> some View {
        let canChoose = canMeetRequirementsEngine(choice)
        let isCombatChoice = event.eventType == .combat &&
                             choice.id == event.choices.first?.id &&
                             event.monsterCard != nil

        return Button {
            guard canChoose else { return }

            // Defer all state changes to avoid "Publishing changes from within view updates"
            DispatchQueue.main.async {
                selectedChoice = choice

                // Check if this is a combat choice
                if isCombatChoice {
                    initiateCombat(choice: choice)
                } else {
                    onChoiceSelected(choice)
                    onDismiss()
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(choice.text)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(canChoose ? .primary : AppColors.secondary)

                // Requirements
                if let requirements = choice.requirements {
                    requirementsView(requirements, canMeet: canChoose)
                }

                // Preview consequences (only positive ones)
                consequencesPreview(choice.consequences)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(canChoose ? AppColors.cardBackground : AppColors.secondary.opacity(Opacity.faint))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .stroke(canChoose ? AppColors.primary.opacity(Opacity.medium) : Color.clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canChoose)
    }

    func requirementsView(_ requirements: EventRequirements, canMeet: Bool) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            if let minFaith = requirements.minimumFaith {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                    Text(L10n.eventRequiresFaith.localized(with: minFaith))
                        .font(.caption2)
                    // Engine-First: read from engine
                    Text(L10n.eventYouHaveFaith.localized(with: vm.engine.player.faith))
                        .font(.caption2)
                        .foregroundColor(vm.engine.player.faith >= minFaith ? AppColors.success : AppColors.danger)
                }
                .foregroundColor(AppColors.muted)
            }

            if let minHealth = requirements.minimumHealth {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                    Text(L10n.eventRequiresHealth.localized(with: minHealth))
                        .font(.caption2)
                    // Engine-First: read from engine
                    Text(L10n.eventYouHaveHealth.localized(with: vm.engine.player.health))
                        .font(.caption2)
                        .foregroundColor(vm.engine.player.health >= minHealth ? AppColors.success : AppColors.danger)
                }
                .foregroundColor(AppColors.muted)
            }

            if let reqBalance = requirements.requiredBalance {
                // Engine-First: read from engine
                let playerBalanceEnum = getBalanceEnum(vm.engine.player.balance)
                let meetsRequirement = playerBalanceEnum == reqBalance

                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.caption2)
                    Text(L10n.eventRequiresPath.localized(with: balanceText(reqBalance)))
                        .font(.caption2)
                    Text(L10n.eventYourPath.localized(with: balanceText(playerBalanceEnum)))
                        .font(.caption2)
                        .foregroundColor(meetsRequirement ? AppColors.success : AppColors.danger)
                }
                .foregroundColor(AppColors.muted)
            }
        }
    }

    func consequencesPreview(_ consequences: EventConsequences) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxxs) {
            if let faithChange = consequences.faithChange, faithChange != 0 {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: faithChange > 0 ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                    Text(L10n.eventFaithChange.localized(with: faithChange > 0 ? "+" : "", faithChange))
                        .font(.caption2)
                }
                .foregroundColor(faithChange > 0 ? AppColors.success : AppColors.warning)
            }

            if let healthChange = consequences.healthChange, healthChange != 0 {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: healthChange > 0 ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                    Text(L10n.eventHealthChange.localized(with: healthChange > 0 ? "+" : "", healthChange))
                        .font(.caption2)
                }
                .foregroundColor(healthChange > 0 ? AppColors.success : AppColors.danger)
            }

            if let balanceChange = consequences.balanceChange, balanceChange != 0 {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: balanceChange > 0 ? "sun.max.fill" : "moon.fill")
                        .font(.caption2)
                    Text(balanceChange > 0 ? L10n.eventBalanceToLight.localized : L10n.eventBalanceToDark.localized)
                        .font(.caption2)
                }
                .foregroundColor(balanceChange > 0 ? AppColors.light : AppColors.dark)
            }

            if let reputationChange = consequences.reputationChange, reputationChange != 0 {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: reputationChange > 0 ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                        .font(.caption2)
                    Text(L10n.eventReputationChange.localized(with: reputationChange > 0 ? "+" : "", reputationChange))
                        .font(.caption2)
                }
                .foregroundColor(reputationChange > 0 ? AppColors.success : AppColors.danger)
            }

            if consequences.addCards != nil {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "rectangle.stack.fill.badge.plus")
                        .font(.caption2)
                    Text(L10n.eventReceiveCard.localized)
                        .font(.caption2)
                }
                .foregroundColor(AppColors.primary)
            }

            if consequences.addCurse != nil {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text(L10n.eventReceiveCurse.localized)
                        .font(.caption2)
                }
                .foregroundColor(AppColors.danger)
            }
        }
    }

    // MARK: - Combat Management

    func initiateCombat(choice _: EventChoice) {
        let actionResult = vm.engine.performAction(.startCombat(encounterId: event.id))
        guard actionResult.success else {
            resultMessage = actionResult.error?.localizedDescription ?? ActionError.noActiveCombat.localizedDescription
            showingResult = true
            return
        }

        let difficultyRaw = UserDefaults.standard.string(forKey: "gameDifficulty") ?? "normal"
        let difficulty = DifficultyLevel(rawValue: difficultyRaw) ?? .normal
        guard let snapshot = vm.engine.makeExternalCombatSnapshot(difficulty: difficulty) else {
            resultMessage = ActionError.noActiveCombat.localizedDescription
            showingResult = true
            return
        }

        initiateDispositionCombat(snapshot: snapshot)
    }

    private func initiateDispositionCombat(snapshot: ExternalCombatSnapshot) {
        let enemyTypeName = Self.affinityEnemyType(snapshot.enemyDefinition.enemyType)
        let zone: TwilightEngine.ResonanceZone = snapshot.resonance < -60
            ? .deepNav
            : snapshot.resonance < -20 ? .nav
            : snapshot.resonance > 60 ? .deepPrav
            : snapshot.resonance > 20 ? .prav
            : .yav

        let sim = DispositionCombatSimulation.create(
            enemyType: enemyTypeName,
            heroHP: snapshot.hero.hp,
            heroMaxHP: snapshot.hero.maxHp,
            hand: snapshot.encounterHeroCards,
            resonanceZone: zone,
            seed: snapshot.seed,
            vulnerabilityRegistry: VulnerabilityRegistry.makeTestDataset()
        )

        activeDispositionCombat = ActiveEventDispositionCombat(simulation: sim)
    }

    /// Map EnemyType enum to AffinityMatrix string key.
    private static func affinityEnemyType(_ type: EnemyType) -> String {
        switch type {
        case .human: return "человек"
        case .spirit: return "дух"
        case .beast: return "зверь"
        case .undead: return "нежить"
        case .demon: return "нечисть"
        case .boss: return "бандит"
        }
    }

    static func playSoundEffect(_ name: String) {
        SoundManager.shared.play(SoundManager.SoundEffect(rawValue: name) ?? .buttonTap)
    }

    static func playHaptic(_ name: String) {
        switch name {
        case "light": HapticManager.shared.play(.light)
        case "medium": HapticManager.shared.play(.medium)
        case "heavy": HapticManager.shared.play(.heavy)
        case "success": HapticManager.shared.play(.success)
        case "error": HapticManager.shared.play(.error)
        default: HapticManager.shared.play(.light)
        }
    }

    func handleCombatEnd(outcome: AppCombatOutcome) {
        // Apply non-combat consequences from the choice (if victory)
        if outcome.isVictory, let choice = selectedChoice {
            onChoiceSelected(choice)
        }

        // Combat already shows its own victory/defeat screen, no need for additional alert
        // Just close combat and dismiss event view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            activeDispositionCombat = nil
            // Small delay before dismissing to allow animation to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                onDismiss()
            }
        }
    }

    // MARK: - Helpers

    /// Engine-based requirement checking
    func canMeetRequirementsEngine(_ choice: EventChoice) -> Bool {
        guard let requirements = choice.requirements else { return true }

        // Check minimum faith
        if let minFaith = requirements.minimumFaith {
            if vm.engine.player.faith < minFaith {
                return false
            }
        }

        // Check minimum health
        if let minHealth = requirements.minimumHealth {
            if vm.engine.player.health < minHealth {
                return false
            }
        }

        // Check balance requirement
        if let reqBalance = requirements.requiredBalance {
            let playerBalanceEnum = getBalanceEnum(vm.engine.player.balance)
            if playerBalanceEnum != reqBalance {
                return false
            }
        }

        return true
    }

    func balanceText(_ balance: CardBalance) -> String {
        switch balance {
        case .light: return L10n.tmBalanceLightGenitive.localized
        case .neutral: return L10n.tmBalanceNeutralGenitive.localized
        case .dark: return L10n.tmBalanceDarkGenitive.localized
        }
    }

    func getBalanceEnum(_ balanceValue: Int) -> CardBalance {
        if balanceValue >= 70 {        // Light path (70-100)
            return .light
        } else if balanceValue <= 30 { // Dark path (0-30)
            return .dark
        } else {                       // Neutral (30-70)
            return .neutral
        }
    }
}

// MARK: - Active Combat Wrapper

private struct ActiveEventDispositionCombat: Identifiable {
    let id = UUID()
    let simulation: DispositionCombatSimulation
}

// MARK: - Preview

struct EventView_Previews: PreviewProvider {
    static var previews: some View {
        // Engine-First: Use engine for preview
        let engine = TwilightGameEngine()
        engine.initializeNewGame(playerName: "Волхв", heroId: nil, startingDeck: [])
        let vm = GameEngineObservable(engine: engine)

        let event = GameEvent(
            id: "preview_event",
            eventType: .narrative,
            title: "Тестовое событие",
            description: "Это тестовое событие для предварительного просмотра",
            choices: [
                EventChoice(
                    id: "preview_choice_1",
                    text: "Выбор 1",
                    consequences: EventConsequences(
                        faithChange: 5,
                        message: "Результат выбора 1"
                    )
                ),
                EventChoice(
                    id: "preview_choice_2",
                    text: "Выбор 2",
                    requirements: EventRequirements(minimumFaith: 10),
                    consequences: EventConsequences(
                        faithChange: -3,
                        healthChange: -2,
                        message: "Результат выбора 2"
                    )
                )
            ]
        )

        return EventView(
            vm: vm,
            event: event,
            regionId: "preview_region",
            onChoiceSelected: { _ in },
            onDismiss: { }
        )
    }
}

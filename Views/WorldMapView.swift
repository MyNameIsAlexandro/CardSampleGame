/// Файл: Views/WorldMapView.swift
/// Назначение: Содержит реализацию файла WorldMapView.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine

/// Главный экран путешествия по миру.
/// Отображает регионы и читает состояние только из `TwilightGameEngine`.
struct WorldMapView: View {
    // MARK: - Engine-First Architecture
    // Engine is the ONLY source of truth for UI
    @ObservedObject var vm: GameEngineObservable
    let cardFactory: CardFactory
    var onExit: (() -> Void)? = nil
    var onAutoSave: (() -> Void)? = nil

    @State private var selectedRegion: EngineRegionState?
    @State private var showingExitConfirmation = false
    @State private var showingGameOver = false
    @State private var showingTravelTransition = false
    @State private var showingEventLog = false
    @State private var showingDayEvent = false
    @State private var currentDayEvent: DayEvent?

    // MARK: - Initialization (Engine-First only)

    init(
        vm: GameEngineObservable,
        cardFactory: CardFactory,
        onExit: (() -> Void)? = nil,
        onAutoSave: (() -> Void)? = nil
    ) {
        self.vm = vm
        self.cardFactory = cardFactory
        self.onExit = onExit
        self.onAutoSave = onAutoSave
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Hero Panel (persistent, consistent design across all screens)
                HeroPanel(vm: vm)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.top, Spacing.xxs)

                // Resonance gauge
                ResonanceWidget(vm: vm)

                Divider()
                    .padding(.vertical, Spacing.xxs)

                // Top bar with world info
                worldInfoBar

                Divider()

                // Regions list (Engine-First: reads from vm.engine.regionsArray)
                if vm.engine.regionsArray.isEmpty {
                    // Show loading state if regions aren't loaded yet
                    VStack(spacing: Spacing.lg) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(L10n.worldLoading.localized)
                            .font(.headline)
                            .foregroundColor(AppColors.muted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: Spacing.md) {
                            ForEach(vm.engine.regionsArray, id: \.id) { region in
                                EngineRegionCardView(
                                    region: region,
                                    isCurrentLocation: region.id == vm.engine.currentRegionId
                                )
                                .onTapGesture {
                                    selectedRegion = region
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(AppColors.backgroundSystem)
            .navigationTitle(L10n.tmGameTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColors.backgroundSystem, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(AppColors.primary)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if onExit != nil {
                        Button(action: {
                            showingExitConfirmation = true
                        }) {
                            HStack(spacing: Spacing.xxs) {
                                Image(systemName: "chevron.left")
                                Text(L10n.uiMenuButton.localized)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingEventLog = true
                    }) {
                        Image(systemName: "book.closed")
                    }
                }
            }
            .sheet(isPresented: $showingEventLog) {
                EngineEventLogView(vm: vm)
            }
            .sheet(item: $selectedRegion) { region in
                EngineRegionDetailView(
                    region: region,
                    vm: vm,
                    cardFactory: cardFactory,
                    onDismiss: {
                        selectedRegion = nil
                    },
                    onRegionChange: { newRegion in
                        selectedRegion = newRegion
                    }
                )
            }
            .alert(L10n.uiExit.localized + "?", isPresented: $showingExitConfirmation) {
                Button(L10n.uiCancel.localized, role: .cancel) { }
                Button(L10n.uiExit.localized, role: .destructive) {
                    onExit?()
                }
            } message: {
                Text(L10n.uiProgressSaved.localized)
            }
            .alert(currentDayEvent?.title ?? L10n.worldEvent.localized, isPresented: $showingDayEvent) {
                Button(L10n.buttonUnderstood.localized, role: .cancel) {
                    currentDayEvent = nil
                }
            } message: {
                if let event = currentDayEvent {
                    Text(L10n.dayNumber.localized(with: event.day) + "\n\n\(event.description)")
                }
            }
            .fullScreenCover(isPresented: $showingGameOver) {
                if let result = vm.engine.gameResult {
                    GameOverView(result: result, vm: vm) {
                        // PG-05: Record playthrough end in ProfileManager
                        ProfileManager.shared.recordPlaythroughEnd(daysSurvived: vm.engine.currentDay)
                        let newUnlocks = AchievementEngine.evaluateNewUnlocks(profile: ProfileManager.shared.profile)
                        for id in newUnlocks {
                            ProfileManager.shared.recordAchievement(id)
                        }
                        showingGameOver = false
                        onExit?()
                    }
                }
            }
            // UX-10: Travel transition overlay
            .overlay {
                if showingTravelTransition {
                    ZStack {
                        AppColors.backgroundSystem.opacity(Opacity.high)
                            .ignoresSafeArea()
                        VStack(spacing: Spacing.md) {
                            Image(systemName: "figure.walk")
                                .font(.system(size: Sizes.iconXL))
                                .foregroundColor(AppColors.primary)
                            ProgressView()
                                .tint(AppColors.primary)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .onChange(of: vm.engine.isGameOver) { isOver in
                if isOver {
                    showingGameOver = true
                }
            }
            .onChange(of: vm.engine.currentRegionId) { _ in
                // UX-10: Show travel flash
                HapticManager.shared.play(.light)
                withAnimation(.easeIn(duration: 0.15)) { showingTravelTransition = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeOut(duration: 0.3)) { showingTravelTransition = false }
                }
            }
            .onChange(of: vm.engine.currentDay) { newDay in
                // Auto-save every 3 days (SAV-04)
                if newDay > 1 && newDay % 3 == 1 {
                    onAutoSave?()
                }
            }
            .onChange(of: vm.engine.isInCombat) { inCombat in
                // Auto-save after combat ends (SAV-04)
                if !inCombat {
                    onAutoSave?()
                }
            }
            .onChange(of: vm.engine.lastDayEvent?.id) { _ in
                if let event = vm.engine.lastDayEvent {
                    currentDayEvent = event
                    showingDayEvent = true
                    // Dismiss via Engine action (Engine-First)
                    vm.engine.performAction(.dismissDayEvent)
                }
            }
        }
    }

    // MARK: - World Info Bar

    var worldInfoBar: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                // World Tension
                VStack(alignment: .leading, spacing: Spacing.xxxs) {
                    Text(L10n.tooltipBalance.localized)
                        .font(.caption2)
                        .foregroundColor(AppColors.muted)
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(tensionColor)
                        Text("\(vm.engine.worldTension)%")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                }

                Spacer()

                // World Light/Dark Balance (Явь vs Навь)
                VStack(spacing: Spacing.xxxs) {
                    Text(L10n.worldLabel.localized)
                        .font(.caption2)
                        .foregroundColor(AppColors.muted)
                    Text(vm.engine.worldBalanceDescription)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(balanceColor)
                }

                Spacer()

                // Days passed
                VStack(alignment: .trailing, spacing: Spacing.xxxs) {
                    Text(L10n.daysInJourney.localized)
                        .font(.caption2)
                        .foregroundColor(AppColors.muted)
                    Text("\(vm.engine.currentDay)")
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }
            .padding(.horizontal)

            // Tension progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(AppColors.secondary.opacity(Opacity.faint))
                        .frame(height: Sizes.progressThin)

                    Rectangle()
                        .fill(tensionColor)
                        .frame(
                            width: geometry.size.width * CGFloat(vm.engine.worldTension) / 100,
                            height: Sizes.progressThin
                        )
                }
            }
            .frame(height: Sizes.progressThin)
            .padding(.horizontal)
        }
        .padding(.vertical, Spacing.sm)
        .background(AppColors.cardBackground)
    }

    var tensionColor: Color {
        switch vm.engine.worldTension {
        case 0..<30: return AppColors.success
        case 30..<60: return AppColors.warning
        case 60..<80: return AppColors.warning
        default: return AppColors.danger
        }
    }

    var balanceColor: Color {
        switch vm.engine.lightDarkBalance {
        case 0..<30: return AppColors.dark      // Тьма
        case 30..<70: return AppColors.neutral  // Нейтрально
        case 70...100: return AppColors.light   // Свет
        default: return AppColors.neutral
        }
    }
}

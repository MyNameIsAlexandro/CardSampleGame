import SwiftUI
import TwilightEngine

struct WorldMapView: View {
    // MARK: - Engine-First Architecture
    // Engine is the ONLY source of truth for UI
    @ObservedObject var vm: GameEngineObservable
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

    init(vm: GameEngineObservable, onExit: (() -> Void)? = nil, onAutoSave: (() -> Void)? = nil) {
        self.vm = vm
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
// MARK: - Event Log Entry View

struct EventLogEntryView: View {
    let entry: EventLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header
            HStack {
                Image(systemName: entry.type.icon)
                    .foregroundColor(typeColor)

                Text(L10n.dayNumber.localized(with: entry.dayNumber))
                    .font(.caption)
                    .fontWeight(.bold)

                Spacer()

                Text(entry.regionName)
                    .font(.caption)
                    .foregroundColor(AppColors.muted)
            }

            // Event title
            Text(entry.eventTitle)
                .font(.subheadline)
                .fontWeight(.semibold)

            // Choice made
            HStack {
                Image(systemName: "arrow.turn.down.right")
                    .font(.caption2)
                    .foregroundColor(AppColors.muted)
                Text(entry.choiceMade)
                    .font(.caption)
                    .foregroundColor(AppColors.muted)
            }

            // Outcome
            Text(entry.outcome)
                .font(.caption)
                .italic()
        }
        .padding(.vertical, Spacing.xxs)
    }

    var typeColor: Color {
        switch entry.type {
        case .combat: return AppColors.danger
        case .exploration: return AppColors.primary
        case .choice: return AppColors.warning
        case .quest: return AppColors.dark
        case .travel: return AppColors.success
        case .worldChange: return AppColors.light
        }
    }
}

// MARK: - Engine-First Region Card View

struct EngineRegionCardView: View {
    let region: EngineRegionState
    let isCurrentLocation: Bool

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(stateColor.opacity(Opacity.faint))
                    .frame(width: Sizes.iconRegion, height: Sizes.iconRegion)

                Image(systemName: region.type.icon)
                    .font(.title2)
                    .foregroundColor(stateColor)
            }

            // Info
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack {
                    Text(region.name)
                        .font(.headline)
                        .fontWeight(.bold)

                    if isCurrentLocation {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(AppColors.primary)
                    }
                }

                HStack(spacing: Spacing.sm) {
                    Text(region.state.emoji)
                        .font(.caption)
                    Text(region.state.displayName)
                        .font(.caption)
                        .foregroundColor(AppColors.muted)

                    Spacer()

                    Text(region.type.displayName)
                        .font(.caption2)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.xxxs)
                        .background(AppColors.secondary.opacity(Opacity.faint))
                        .cornerRadius(CornerRadius.sm)
                }

                // Anchor info
                if let anchor = region.anchor {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "flame")
                            .font(.caption2)
                            .foregroundColor(AppColors.power)
                        Text(anchor.name)
                            .font(.caption2)
                            .foregroundColor(AppColors.muted)
                        Spacer()
                        Text("\(anchor.integrity)%")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(anchorIntegrityColor(anchor.integrity))
                    }
                }

                // Reputation
                if region.reputation != 0 {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: region.reputation > 0 ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                            .font(.caption2)
                            .foregroundColor(region.reputation > 0 ? AppColors.success : AppColors.danger)
                        Text(L10n.regionReputation.localized + ": \(region.reputation > 0 ? "+" : "")\(region.reputation)")
                            .font(.caption2)
                            .foregroundColor(AppColors.muted)
                    }
                }
            }

            Spacer()

            // Arrow
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(AppColors.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(AppColors.cardBackground)
                .shadow(color: isCurrentLocation ? AppColors.primary.opacity(Opacity.light) : .clear, radius: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(isCurrentLocation ? AppColors.regionCurrent : .clear, lineWidth: 2)
        )
    }

    var stateColor: Color {
        switch region.state {
        case .stable: return AppColors.success
        case .borderland: return AppColors.warning
        case .breach: return AppColors.danger
        }
    }

    func anchorIntegrityColor(_ integrity: Int) -> Color {
        switch integrity {
        case 70...100: return AppColors.success
        case 30..<70: return AppColors.warning
        default: return AppColors.danger
        }
    }
}

// MARK: - Engine-First Region Detail View

struct EngineRegionDetailView: View {
    let region: EngineRegionState
    @ObservedObject var vm: GameEngineObservable
    let onDismiss: () -> Void
    var onRegionChange: ((EngineRegionState?) -> Void)? = nil

    @State private var showingActionConfirmation = false
    @State private var selectedAction: EngineRegionAction?
    @State private var eventToShow: GameEvent?
    @State private var showingNoEventsAlert = false
    @State private var showingActionError = false
    @State private var actionErrorMessage = ""

    // Card received notification
    @State private var showingCardNotification = false
    @State private var receivedCardNames: [String] = []

    enum EngineRegionAction {
        case travel
        case rest
        case trade
        case strengthenAnchor
        case explore
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Hero Panel (persistent, consistent design across all screens)
                HeroPanel(vm: vm)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.xl) {
                        // Region header
                        regionHeader

                        // Risk display for non-stable regions
                        if region.state != .stable {
                            riskInfoSection
                        }

                        Divider()

                        // Anchor section
                        if let anchor = region.anchor {
                            anchorSection(anchor: anchor)
                            Divider()
                        }

                        // Available actions
                        actionsSection
                    }
                    .padding()
                }
            }
            .background(AppColors.backgroundSystem)
            .navigationTitle(region.name)
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
            .alert(actionConfirmationTitle, isPresented: $showingActionConfirmation) {
                Button(L10n.buttonConfirm.localized) {
                    if let action = selectedAction {
                        performAction(action)
                    }
                }
                Button(L10n.uiCancel.localized, role: .cancel) { }
            } message: {
                Text(actionConfirmationMessage)
            }
            .alert(L10n.nothingFound.localized, isPresented: $showingNoEventsAlert) {
                Button(L10n.buttonUnderstood.localized, role: .cancel) { }
            } message: {
                Text(L10n.noEventsInRegion.localized)
            }
            .alert(L10n.actionImpossible.localized, isPresented: $showingActionError) {
                Button(L10n.buttonUnderstood.localized, role: .cancel) { }
            } message: {
                Text(actionErrorMessage)
            }
            .sheet(item: $eventToShow) { event in
                EventView(
                    vm: vm,
                    event: event,
                    regionId: region.id,
                    onChoiceSelected: { choice in
                        handleEventChoice(choice, event: event)
                    },
                    onDismiss: {
                        eventToShow = nil
                        // Dismiss current event in engine
                        vm.engine.performAction(.dismissCurrentEvent)
                    }
                )
            }
            .onChange(of: vm.engine.currentEvent?.id) { _ in
                // When engine triggers an event, show it
                if let event = vm.engine.currentEvent {
                    eventToShow = event
                }
            }
            .overlay {
                // Card received notification overlay
                if showingCardNotification && !receivedCardNames.isEmpty {
                    cardReceivedNotificationView
                }
            }
        }
    }

    // MARK: - Card Received Notification View

    var cardReceivedNotificationView: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(Opacity.medium)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: AnimationDuration.slow)) {
                        showingCardNotification = false
                    }
                }

            VStack(spacing: Spacing.xl) {
                // Header
                VStack(spacing: Spacing.sm) {
                    Text("🃏")
                        .font(.system(size: Sizes.iconHero))

                    Text(L10n.cardsReceived.localized)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text(L10n.addedToDeck.localized)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(Opacity.high))
                }

                // Cards list
                VStack(spacing: Spacing.md) {
                    ForEach(receivedCardNames, id: \.self) { cardName in
                        HStack {
                            Image(systemName: "rectangle.stack.badge.plus")
                                .foregroundColor(AppColors.faith)
                            Text(cardName)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.smd)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(AppColors.dark.opacity(Opacity.mediumHigh))
                        )
                    }
                }

                // Dismiss button
                Button(action: {
                    withAnimation(.easeOut(duration: AnimationDuration.slow)) {
                        showingCardNotification = false
                    }
                }) {
                    Text(L10n.buttonGreat.localized)
                        .font(.headline)
                        .foregroundColor(AppColors.backgroundSystem)
                        .frame(minWidth: Sizes.buttonMinWidth)
                        .padding()
                        .background(AppColors.primary)
                        .cornerRadius(CornerRadius.lg)
                }
            }
            .padding(Spacing.xxl)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.xxl)
                    .fill(AppColors.backgroundSystem.opacity(Opacity.almostOpaque))
                    .shadow(radius: Spacing.xl)
            )
            .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: - Region Header

    var regionHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: region.type.icon)
                    .font(.largeTitle)
                    .foregroundColor(stateColor)

                VStack(alignment: .leading) {
                    Text(region.type.displayName)
                        .font(.subheadline)
                        .foregroundColor(AppColors.muted)

                    HStack {
                        Text(region.state.emoji)
                        Text(region.state.displayName)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(stateColor)
                    }
                }

                Spacer()

                // Current location indicator
                if isPlayerHere {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "person.fill")
                        Text(L10n.youAreHere.localized)
                    }
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.backgroundSystem)
                    .padding(.horizontal, Spacing.smd)
                    .padding(.vertical, Spacing.xs)
                    .background(AppColors.primary)
                    .cornerRadius(CornerRadius.lg)
                }
            }

            Text(regionDescription)
                .font(.body)
                .foregroundColor(AppColors.muted)
        }
    }

    var regionDescription: String {
        switch region.state {
        case .stable:
            return L10n.regionDescStable.localized
        case .borderland:
            return L10n.regionDescBorderland.localized
        case .breach:
            return L10n.regionDescBreach.localized
        }
    }

    // MARK: - Risk Info Section

    var riskInfoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(region.state == .breach ? AppColors.danger : AppColors.warning)
                Text(L10n.warningTitle.localized)
                    .font(.caption)
                    .fontWeight(.bold)
            }

            Text(L10n.warningHighDanger.localized)
                .font(.caption)
                .foregroundColor(AppColors.muted)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(region.state == .breach ? AppColors.danger.opacity(0.1) : AppColors.warning.opacity(0.1))
        )
    }

    // MARK: - Anchor Section

    func anchorSection(anchor: EngineAnchorState) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(L10n.anchorOfYav.localized)
                .font(.headline)

            HStack(spacing: Spacing.md) {
                Image(systemName: "flame")
                    .font(.title)
                    .foregroundColor(AppColors.power)
                    .frame(width: Sizes.iconHero, height: Sizes.iconHero)
                    .background(Circle().fill(AppColors.power.opacity(Opacity.faint)))

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(anchor.name)
                        .font(.subheadline)
                        .fontWeight(.bold)

                    // Integrity bar
                    HStack(spacing: Spacing.xxs) {
                        Text(L10n.anchorIntegrity.localized + ":")
                            .font(.caption2)
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(AppColors.secondary.opacity(Opacity.faint))
                                    .frame(height: Sizes.progressMedium)

                                Rectangle()
                                    .fill(anchorIntegrityColor(anchor.integrity))
                                    .frame(
                                        width: geometry.size.width * CGFloat(anchor.integrity) / 100,
                                        height: Sizes.progressMedium
                                    )
                            }
                        }
                        .frame(height: Sizes.progressMedium)

                        Text("\(anchor.integrity)%")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(anchorIntegrityColor(anchor.integrity))
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(AppColors.backgroundTertiary)
            )
        }
    }

    // MARK: - Actions Section

    var isPlayerHere: Bool {
        region.id == vm.engine.currentRegionId
    }

    var actionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(L10n.availableActions.localized)
                .font(.headline)

            VStack(spacing: Spacing.sm) {
                // Travel action - only if player is NOT here
                if !isPlayerHere {
                    let canTravel = vm.engine.canTravelTo(regionId: region.id)
                    let routingHint = vm.engine.getRoutingHint(to: region.id)
                    let travelCost = vm.engine.calculateTravelCost(to: region.id)
                    let dayWord = travelCost == 1 ? L10n.dayWord1.localized : L10n.dayWord234.localized

                    actionButton(
                        title: canTravel ? L10n.actionTravelTo.localized(with: travelCost, dayWord) : L10n.actionRegionFar.localized,
                        icon: canTravel ? "arrow.right.circle.fill" : "xmark.circle",
                        color: canTravel ? AppColors.primary : AppColors.secondary,
                        enabled: canTravel
                    ) {
                        selectedAction = .travel
                        showingActionConfirmation = true
                    }

                    if canTravel {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(AppColors.muted)
                            Text(L10n.actionMoveToRegionHint.localized)
                                .font(.caption)
                                .foregroundColor(AppColors.muted)
                        }
                        .padding(.vertical, Spacing.sm)
                    } else {
                        // Show routing hint for distant regions
                        HStack {
                            Image(systemName: "map")
                                .foregroundColor(AppColors.warning)
                            if !routingHint.isEmpty {
                                Text(L10n.goThroughFirst.localized(with: routingHint.joined(separator: ", ")))
                                    .font(.caption)
                                    .foregroundColor(AppColors.warning)
                            } else {
                                Text(L10n.actionRegionNotDirectlyAccessible.localized)
                                    .font(.caption)
                                    .foregroundColor(AppColors.warning)
                            }
                        }
                        .padding(.vertical, Spacing.sm)
                    }
                }

                // Actions available ONLY if player is in the region
                if isPlayerHere {
                    // Rest action
                    actionButton(
                        title: L10n.actionRestHeal.localized(with: 3),
                        icon: "bed.double.fill",
                        color: AppColors.success,
                        enabled: region.canRest
                    ) {
                        selectedAction = .rest
                        showingActionConfirmation = true
                    }

                    // Trade action
                    actionButton(
                        title: L10n.actionTradeName.localized,
                        icon: "cart.fill",
                        color: AppColors.warning,
                        enabled: region.canTrade
                    ) {
                        selectedAction = .trade
                        showingActionConfirmation = true
                    }

                    // Strengthen anchor
                    if region.anchor != nil {
                        actionButton(
                            title: L10n.actionAnchorCost.localized(with: 5, 20),
                            icon: "hammer.fill",
                            color: AppColors.dark,
                            enabled: vm.engine.player.canAffordFaith(5)
                        ) {
                            selectedAction = .strengthenAnchor
                            showingActionConfirmation = true
                        }
                    }

                    // Explore (only if events available)
                    let hasEvents = vm.engine.hasAvailableEventsInCurrentRegion()
                    actionButton(
                        title: L10n.actionExploreName.localized,
                        icon: "magnifyingglass",
                        color: AppColors.info,
                        enabled: hasEvents
                    ) {
                        selectedAction = .explore
                        showingActionConfirmation = true
                    }
                }
            }
        }
    }

    func actionButton(
        title: String,
        icon: String,
        color: Color,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.body)
                Text(title)
                    .font(.body)
                Spacer()
            }
            .padding()
            .foregroundColor(enabled ? .white : AppColors.muted)
            .background(enabled ? color : AppColors.cardBackground)
            .cornerRadius(CornerRadius.md)
        }
        .disabled(!enabled)
    }

    // MARK: - Helpers

    var stateColor: Color {
        switch region.state {
        case .stable: return AppColors.success
        case .borderland: return AppColors.warning
        case .breach: return AppColors.danger
        }
    }

    func anchorIntegrityColor(_ integrity: Int) -> Color {
        switch integrity {
        case 70...100: return AppColors.success
        case 30..<70: return AppColors.warning
        default: return AppColors.danger
        }
    }

    // MARK: - Action Handling

    var actionConfirmationTitle: String {
        guard let action = selectedAction else { return L10n.confirmationTitle.localized }
        switch action {
        case .travel: return L10n.actionTravel.localized
        case .rest: return L10n.actionRest.localized
        case .trade: return L10n.actionTrade.localized
        case .strengthenAnchor: return L10n.actionStrengthenAnchor.localized
        case .explore: return L10n.actionExploreRegion.localized
        }
    }

    var actionConfirmationMessage: String {
        guard let action = selectedAction else { return "" }
        switch action {
        case .travel:
            let days = vm.engine.calculateTravelCost(to: region.id)
            let dayWord = days == 1 ? L10n.dayWord1.localized : L10n.dayWord234.localized
            return L10n.confirmTravel.localized(with: region.name, days, dayWord)
        case .rest:
            return L10n.confirmRest.localized(with: 3)
        case .trade:
            return L10n.confirmTrade.localized
        case .strengthenAnchor:
            return L10n.confirmStrengthenAnchor.localized(with: 5, 20)
        case .explore:
            return L10n.confirmExplore.localized
        }
    }

    // MARK: - Actions via Engine

    func performAction(_ action: EngineRegionAction) {
        switch action {
        case .travel:
            let result = vm.engine.performAction(.travel(toRegionId: region.id))
            if result.success {
                vm.engine.addLogEntry(
                    regionName: region.name,
                    eventTitle: L10n.journalEntryTravel.localized,
                    choiceMade: L10n.journalEntryTravelChoice.localized,
                    outcome: L10n.journalEntryTravelOutcome.localized(with: region.name),
                    type: .travel
                )
                // После перемещения показываем новый регион (текущую локацию)
                if let newRegion = vm.engine.regionsArray.first(where: { $0.id == vm.engine.currentRegionId }) {
                    onRegionChange?(newRegion)
                } else {
                    onDismiss()
                }
            } else {
                // Show error to user
                actionErrorMessage = errorMessage(for: result.error)
                showingActionError = true
            }

        case .rest:
            let result = vm.engine.performAction(.rest)
            if result.success {
                vm.engine.addLogEntry(
                    regionName: region.name,
                    eventTitle: L10n.journalRestTitle.localized,
                    choiceMade: L10n.journalRestChoice.localized,
                    outcome: L10n.journalRestOutcome.localized,
                    type: .exploration
                )
            }

        case .trade:
            // Phase 4: Implement trade/market view
            break

        case .strengthenAnchor:
            let result = vm.engine.performAction(.strengthenAnchor)
            if result.success {
                vm.engine.addLogEntry(
                    regionName: region.name,
                    eventTitle: L10n.journalAnchorTitle.localized,
                    choiceMade: L10n.journalAnchorChoice.localized,
                    outcome: L10n.journalAnchorOutcome.localized,
                    type: .worldChange
                )
            }

        case .explore:
            let result = vm.engine.performAction(.explore)
            if result.success {
                // Check if an event was triggered
                if result.currentEvent == nil {
                    // No event available - show alert
                    showingNoEventsAlert = true
                    vm.engine.addLogEntry(
                        regionName: region.name,
                        eventTitle: L10n.journalEntryExplore.localized,
                        choiceMade: L10n.journalEntryExploreChoice.localized,
                        outcome: L10n.journalEntryExploreNothing.localized,
                        type: .exploration
                    )
                }
                // If event was triggered, it will be shown via onChange of vm.engine.currentEvent
            }
        }
    }

    // MARK: - Error Messages

    func errorMessage(for error: ActionError?) -> String {
        guard let error = error else { return L10n.errorUnknown.localized }
        switch error {
        case .regionNotNeighbor:
            return L10n.errorRegionFar.localized
        case .regionNotAccessible:
            return L10n.errorRegionInaccessible.localized
        case .healthTooLow:
            return L10n.errorHealthLow.localized
        case .insufficientResources(let resource, let required, let available):
            return L10n.errorInsufficientResource.localized(with: resource, required, available)
        case .invalidAction(let reason):
            return reason
        case .combatInProgress:
            return L10n.errorInCombat.localized
        case .eventInProgress:
            return L10n.errorFinishEvent.localized
        default:
            return L10n.errorActionFailed.localized(with: "\(error)")
        }
    }

    // MARK: - Event Choice Handling

    func handleEventChoice(_ choice: EventChoice, event: GameEvent) {
        // Check for card rewards before processing
        var cardsToNotify: [String] = []
        if let cardIDs = choice.consequences.addCards {
            for cardID in cardIDs {
                if let card = CardFactory.shared.getCard(id: cardID) {
                    cardsToNotify.append(card.name)
                }
            }
        }

        // Execute choice via engine
        if let choiceIndex = event.choices.firstIndex(where: { $0.id == choice.id }) {
            let result = vm.engine.performAction(.chooseEventOption(eventId: event.id, choiceIndex: choiceIndex))

            if result.success {
                // Log the event
                let logType: EventLogType = event.eventType == .combat ? .combat : .exploration
                let outcomeMessage = choice.consequences.message ?? L10n.journalChoiceMade.localized
                vm.engine.addLogEntry(
                    regionName: region.name,
                    eventTitle: event.title,
                    choiceMade: choice.text,
                    outcome: outcomeMessage,
                    type: logType
                )
            }
        }

        // Dismiss event view
        eventToShow = nil
        vm.engine.performAction(.dismissCurrentEvent)

        // Show card received notification if cards were gained
        if !cardsToNotify.isEmpty {
            receivedCardNames = cardsToNotify
            // Delay slightly to allow event sheet to dismiss first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showingCardNotification = true
                }
            }
        }
    }
}

// MARK: - Engine-First Event Log View

struct EngineEventLogView: View {
    @ObservedObject var vm: GameEngineObservable
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                if vm.engine.publishedEventLog.isEmpty {
                    Text(L10n.journalEmpty.localized)
                        .foregroundColor(AppColors.muted)
                        .padding()
                } else {
                    ForEach(vm.engine.publishedEventLog.reversed()) { entry in
                        EventLogEntryView(entry: entry)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.backgroundSystem)
            .navigationTitle(L10n.journalTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColors.backgroundSystem, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(AppColors.primary)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.uiClose.localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

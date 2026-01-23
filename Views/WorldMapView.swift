import SwiftUI

struct WorldMapView: View {
    // MARK: - Engine-First Architecture
    // Engine is the ONLY source of truth for UI
    @ObservedObject var engine: TwilightGameEngine
    var onExit: (() -> Void)? = nil

    // MARK: - Legacy Support (for gradual migration)
    // These will be removed once all Views are migrated
    private var worldState: WorldState?
    private var player: Player?

    @State private var selectedRegion: EngineRegionState?
    @State private var showingExitConfirmation = false
    @State private var showingEventLog = false
    @State private var showingDayEvent = false
    @State private var currentDayEvent: DayEvent?

    // MARK: - Initialization (Engine-First)

    init(engine: TwilightGameEngine, onExit: (() -> Void)? = nil) {
        self.engine = engine
        self.onExit = onExit
        self.worldState = nil
        self.player = nil
    }

    // MARK: - Legacy Initialization (for backwards compatibility during migration)

    init(worldState: WorldState, player: Player, onExit: (() -> Void)? = nil) {
        // Create new engine connected to legacy
        let newEngine = TwilightGameEngine()
        newEngine.connectToLegacy(worldState: worldState, player: player)
        self.engine = newEngine
        self.onExit = onExit
        self.worldState = worldState
        self.player = player
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Hero Panel (persistent, consistent design across all screens)
                HeroPanel(engine: engine)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)

                Divider()
                    .padding(.vertical, 4)

                // Top bar with world info
                worldInfoBar

                Divider()

                // Regions list (Engine-First: reads from engine.regionsArray)
                if engine.regionsArray.isEmpty {
                    // Show loading state if regions aren't loaded yet
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(L10n.worldLoading.localized)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(engine.regionsArray, id: \.id) { region in
                                EngineRegionCardView(
                                    region: region,
                                    isCurrentLocation: region.id == engine.currentRegionId
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
            .navigationTitle(L10n.tmGameTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if onExit != nil {
                        Button(action: {
                            showingExitConfirmation = true
                        }) {
                            HStack(spacing: 4) {
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
                EngineEventLogView(engine: engine)
            }
            .sheet(item: $selectedRegion) { region in
                EngineRegionDetailView(
                    region: region,
                    engine: engine,
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
            .onChange(of: engine.lastDayEvent?.id) { _ in
                if let event = engine.lastDayEvent {
                    currentDayEvent = event
                    showingDayEvent = true
                    // Dismiss via Engine action (Engine-First)
                    engine.performAction(.dismissDayEvent)
                }
            }
        }
    }

    // MARK: - Player Info (now uses HeroPanel component)
    // Old playerInfoBar removed - using unified HeroPanel component instead

    // MARK: - World Info Bar (Engine-First: reads from engine.*)

    var worldInfoBar: some View {
        VStack(spacing: 8) {
            HStack {
                // World Tension
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.tooltipBalance.localized)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(tensionColor)
                        Text("\(engine.worldTension)%")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                }

                Spacer()

                // World Light/Dark Balance (Явь vs Навь)
                VStack(spacing: 2) {
                    Text(L10n.worldLabel.localized)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(engine.worldBalanceDescription)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(balanceColor)
                }

                Spacer()

                // Days passed
                VStack(alignment: .trailing, spacing: 2) {
                    Text(L10n.daysInJourney.localized)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(engine.currentDay)")
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }
            .padding(.horizontal)

            // Tension progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)

                    Rectangle()
                        .fill(tensionColor)
                        .frame(
                            width: geometry.size.width * CGFloat(engine.worldTension) / 100,
                            height: 4
                        )
                }
            }
            .frame(height: 4)
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
    }

    var tensionColor: Color {
        switch engine.worldTension {
        case 0..<30: return .green
        case 30..<60: return .yellow
        case 60..<80: return .orange
        default: return .red
        }
    }

    var balanceColor: Color {
        switch engine.lightDarkBalance {
        case 0..<30: return .purple      // Тьма
        case 30..<70: return .gray       // Нейтрально
        case 70...100: return .yellow    // Свет
        default: return .gray
        }
    }
}
// MARK: - Event Log Entry View (shared between legacy and Engine views)

struct EventLogEntryView: View {
    let entry: EventLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                    .foregroundColor(.secondary)
            }

            // Event title
            Text(entry.eventTitle)
                .font(.subheadline)
                .fontWeight(.semibold)

            // Choice made
            HStack {
                Image(systemName: "arrow.turn.down.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(entry.choiceMade)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Outcome
            Text(entry.outcome)
                .font(.caption)
                .italic()
        }
        .padding(.vertical, 4)
    }

    var typeColor: Color {
        switch entry.type {
        case .combat: return .red
        case .exploration: return .blue
        case .choice: return .orange
        case .quest: return .purple
        case .travel: return .green
        case .worldChange: return .yellow
        }
    }
}

// MARK: - Engine-First Region Card View

struct EngineRegionCardView: View {
    let region: EngineRegionState
    let isCurrentLocation: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(stateColor.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: region.type.icon)
                    .font(.title2)
                    .foregroundColor(stateColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(region.name)
                        .font(.headline)
                        .fontWeight(.bold)

                    if isCurrentLocation {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }

                HStack(spacing: 8) {
                    Text(region.state.emoji)
                        .font(.caption)
                    Text(region.state.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(region.type.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }

                // Anchor info
                if let anchor = region.anchor {
                    HStack(spacing: 4) {
                        Image(systemName: "flame")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text(anchor.name)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(anchor.integrity)%")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(anchorIntegrityColor(anchor.integrity))
                    }
                }

                // Reputation
                if region.reputation != 0 {
                    HStack(spacing: 4) {
                        Image(systemName: region.reputation > 0 ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                            .font(.caption2)
                            .foregroundColor(region.reputation > 0 ? .green : .red)
                        Text(L10n.regionReputation.localized + ": \(region.reputation > 0 ? "+" : "")\(region.reputation)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Arrow
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: isCurrentLocation ? .blue.opacity(0.3) : .clear, radius: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrentLocation ? Color.blue : Color.clear, lineWidth: 2)
        )
    }

    var stateColor: Color {
        switch region.state {
        case .stable: return .green
        case .borderland: return .orange
        case .breach: return .red
        }
    }

    func anchorIntegrityColor(_ integrity: Int) -> Color {
        switch integrity {
        case 70...100: return .green
        case 30..<70: return .orange
        default: return .red
        }
    }
}

// MARK: - Engine-First Region Detail View

struct EngineRegionDetailView: View {
    let region: EngineRegionState
    @ObservedObject var engine: TwilightGameEngine
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
                HeroPanel(engine: engine)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
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
            .navigationTitle(region.name)
            .navigationBarTitleDisplayMode(.inline)
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
                    engine: engine,
                    event: event,
                    regionId: region.id,
                    onChoiceSelected: { choice in
                        handleEventChoice(choice, event: event)
                    },
                    onDismiss: {
                        eventToShow = nil
                        // Dismiss current event in engine
                        engine.performAction(.dismissCurrentEvent)
                    }
                )
            }
            .onChange(of: engine.currentEvent?.id) { _ in
                // When engine triggers an event, show it
                if let event = engine.currentEvent {
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
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showingCardNotification = false
                    }
                }

            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("🃏")
                        .font(.system(size: 48))

                    Text(L10n.cardsReceived.localized)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text(L10n.addedToDeck.localized)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }

                // Cards list
                VStack(spacing: 12) {
                    ForEach(receivedCardNames, id: \.self) { cardName in
                        HStack {
                            Image(systemName: "rectangle.stack.badge.plus")
                                .foregroundColor(.yellow)
                            Text(cardName)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.purple.opacity(0.6))
                        )
                    }
                }

                // Dismiss button
                Button(action: {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showingCardNotification = false
                    }
                }) {
                    Text(L10n.buttonGreat.localized)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(minWidth: 120)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.systemBackground).opacity(0.95))
                    .shadow(radius: 20)
            )
            .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: - Region Header

    var regionHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: region.type.icon)
                    .font(.largeTitle)
                    .foregroundColor(stateColor)

                VStack(alignment: .leading) {
                    Text(region.type.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

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
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                        Text(L10n.youAreHere.localized)
                    }
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
            }

            Text(regionDescription)
                .font(.body)
                .foregroundColor(.secondary)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(region.state == .breach ? .red : .orange)
                Text(L10n.warningTitle.localized)
                    .font(.caption)
                    .fontWeight(.bold)
            }

            Text(L10n.warningHighDanger.localized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(region.state == .breach ? Color.red.opacity(0.1) : Color.orange.opacity(0.1))
        )
    }

    // MARK: - Anchor Section

    func anchorSection(anchor: EngineAnchorState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.anchorOfYav.localized)
                .font(.headline)

            HStack(spacing: 12) {
                Image(systemName: "flame")
                    .font(.title)
                    .foregroundColor(.orange)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Color.orange.opacity(0.2)))

                VStack(alignment: .leading, spacing: 4) {
                    Text(anchor.name)
                        .font(.subheadline)
                        .fontWeight(.bold)

                    // Integrity bar
                    HStack(spacing: 4) {
                        Text(L10n.anchorIntegrity.localized + ":")
                            .font(.caption2)
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 6)

                                Rectangle()
                                    .fill(anchorIntegrityColor(anchor.integrity))
                                    .frame(
                                        width: geometry.size.width * CGFloat(anchor.integrity) / 100,
                                        height: 6
                                    )
                            }
                        }
                        .frame(height: 6)

                        Text("\(anchor.integrity)%")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(anchorIntegrityColor(anchor.integrity))
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.tertiarySystemBackground))
            )
        }
    }

    // MARK: - Actions Section

    var isPlayerHere: Bool {
        region.id == engine.currentRegionId
    }

    var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.availableActions.localized)
                .font(.headline)

            VStack(spacing: 8) {
                // Travel action - only if player is NOT here
                if !isPlayerHere {
                    let canTravel = engine.canTravelTo(regionId: region.id)
                    let routingHint = engine.getRoutingHint(to: region.id)
                    let travelCost = engine.calculateTravelCost(to: region.id)
                    let dayWord = travelCost == 1 ? L10n.dayWord1.localized : L10n.dayWord234.localized

                    actionButton(
                        title: canTravel ? L10n.actionTravelTo.localized(with: travelCost, dayWord) : L10n.actionRegionFar.localized,
                        icon: canTravel ? "arrow.right.circle.fill" : "xmark.circle",
                        color: canTravel ? .blue : .gray,
                        enabled: canTravel
                    ) {
                        selectedAction = .travel
                        showingActionConfirmation = true
                    }

                    if canTravel {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                            Text(L10n.actionMoveToRegionHint.localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        // Show routing hint for distant regions
                        HStack {
                            Image(systemName: "map")
                                .foregroundColor(.orange)
                            if !routingHint.isEmpty {
                                Text(L10n.goThroughFirst.localized(with: routingHint.joined(separator: ", ")))
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            } else {
                                Text(L10n.actionRegionNotDirectlyAccessible.localized)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                // Actions available ONLY if player is in the region
                if isPlayerHere {
                    // Rest action
                    actionButton(
                        title: L10n.actionRestHeal.localized(with: 3),
                        icon: "bed.double.fill",
                        color: .green,
                        enabled: region.canRest
                    ) {
                        selectedAction = .rest
                        showingActionConfirmation = true
                    }

                    // Trade action
                    actionButton(
                        title: L10n.actionTradeName.localized,
                        icon: "cart.fill",
                        color: .orange,
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
                            color: .purple,
                            enabled: engine.canAffordFaith(5)
                        ) {
                            selectedAction = .strengthenAnchor
                            showingActionConfirmation = true
                        }
                    }

                    // Explore (only if events available)
                    let hasEvents = engine.hasAvailableEventsInCurrentRegion()
                    actionButton(
                        title: L10n.actionExploreName.localized,
                        icon: "magnifyingglass",
                        color: .cyan,
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
            .foregroundColor(enabled ? .white : .gray)
            .background(enabled ? color : Color.gray.opacity(0.3))
            .cornerRadius(10)
        }
        .disabled(!enabled)
    }

    // MARK: - Helpers

    var stateColor: Color {
        switch region.state {
        case .stable: return .green
        case .borderland: return .orange
        case .breach: return .red
        }
    }

    func anchorIntegrityColor(_ integrity: Int) -> Color {
        switch integrity {
        case 70...100: return .green
        case 30..<70: return .orange
        default: return .red
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
            let days = engine.calculateTravelCost(to: region.id)
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
            let result = engine.performAction(.travel(toRegionId: region.id))
            if result.success {
                engine.addLogEntry(
                    regionName: region.name,
                    eventTitle: L10n.journalEntryTravel.localized,
                    choiceMade: L10n.journalEntryTravelChoice.localized,
                    outcome: L10n.journalEntryTravelOutcome.localized(with: region.name),
                    type: .travel
                )
                // После перемещения показываем новый регион (текущую локацию)
                if let newRegion = engine.regionsArray.first(where: { $0.id == engine.currentRegionId }) {
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
            let result = engine.performAction(.rest)
            if result.success {
                engine.addLogEntry(
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
            let result = engine.performAction(.strengthenAnchor)
            if result.success {
                engine.addLogEntry(
                    regionName: region.name,
                    eventTitle: L10n.journalAnchorTitle.localized,
                    choiceMade: L10n.journalAnchorChoice.localized,
                    outcome: L10n.journalAnchorOutcome.localized,
                    type: .worldChange
                )
            }

        case .explore:
            let result = engine.performAction(.explore)
            if result.success {
                // Check if an event was triggered
                if result.currentEvent == nil {
                    // No event available - show alert
                    showingNoEventsAlert = true
                    engine.addLogEntry(
                        regionName: region.name,
                        eventTitle: L10n.journalEntryExplore.localized,
                        choiceMade: L10n.journalEntryExploreChoice.localized,
                        outcome: L10n.journalEntryExploreNothing.localized,
                        type: .exploration
                    )
                }
                // If event was triggered, it will be shown via onChange of engine.currentEvent
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
            let result = engine.performAction(.chooseEventOption(eventId: event.id, choiceIndex: choiceIndex))

            if result.success {
                // Log the event
                let logType: EventLogType = event.eventType == .combat ? .combat : .exploration
                let outcomeMessage = choice.consequences.message ?? L10n.journalChoiceMade.localized
                engine.addLogEntry(
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
        engine.performAction(.dismissCurrentEvent)

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
    @ObservedObject var engine: TwilightGameEngine
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                if engine.publishedEventLog.isEmpty {
                    Text(L10n.journalEmpty.localized)
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(engine.publishedEventLog.reversed()) { entry in
                        EventLogEntryView(entry: entry)
                    }
                }
            }
            .navigationTitle(L10n.journalTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
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

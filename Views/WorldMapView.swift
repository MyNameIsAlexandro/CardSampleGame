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
                // Top bar with world info
                worldInfoBar

                Divider()

                // Player info bar
                playerInfoBar

                Divider()

                // Regions list (Engine-First: reads from engine.regionsArray)
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
                Button(L10n.buttonOk.localized, role: .cancel) { }
                Button(L10n.uiExit.localized) {
                    onExit?()
                }
            } message: {
                Text(L10n.uiProgressSaved.localized)
            }
            .alert(currentDayEvent?.title ?? "Событие мира", isPresented: $showingDayEvent) {
                Button("Понятно", role: .cancel) {
                    currentDayEvent = nil
                }
            } message: {
                if let event = currentDayEvent {
                    Text("День \(event.day)\n\n\(event.description)")
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

    // MARK: - Player Info Bar (Engine-First: reads from engine.player*)

    var playerInfoBar: some View {
        HStack(spacing: 16) {
            // Player name
            VStack(alignment: .leading, spacing: 2) {
                Text(engine.playerName)
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text("Странник")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Health
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundColor(.red)
                Text("\(engine.playerHealth)/\(engine.playerMaxHealth)")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.red.opacity(0.1))
            .cornerRadius(6)

            // Faith
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundColor(.yellow)
                Text("\(engine.playerFaith)")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(6)

            // Balance (0-100 scale)
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: getBalanceIcon(engine.playerBalance))
                        .font(.caption)
                        .foregroundColor(getPlayerBalanceColor(engine.playerBalance))
                    Text("\(engine.playerBalance)")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text(engine.playerBalanceDescription)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(getPlayerBalanceColor(engine.playerBalance).opacity(0.1))
                .cornerRadius(6)

                // Balance progress bar (0-100 visualization)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background with color zones
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.purple.opacity(0.3))  // Dark zone (0-30)
                                .frame(width: geometry.size.width * 0.3)
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))    // Neutral zone (30-70)
                                .frame(width: geometry.size.width * 0.4)
                            Rectangle()
                                .fill(Color.yellow.opacity(0.3))  // Light zone (70-100)
                                .frame(width: geometry.size.width * 0.3)
                        }
                        .frame(height: 4)

                        // Current balance indicator
                        Rectangle()
                            .fill(getPlayerBalanceColor(engine.playerBalance))
                            .frame(
                                width: geometry.size.width * CGFloat(engine.playerBalance) / 100,
                                height: 4
                            )
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
    }

    func getBalanceIcon(_ balance: Int) -> String {
        if balance >= 70 {
            return "sun.max.fill"      // Light path (70-100)
        } else if balance <= 30 {
            return "moon.fill"          // Dark path (0-30)
        } else {
            return "circle.lefthalf.filled"  // Neutral (30-70)
        }
    }

    func getPlayerBalanceColor(_ balance: Int) -> Color {
        if balance >= 70 {
            return .yellow              // Light path (70-100)
        } else if balance <= 30 {
            return .purple              // Dark path (0-30)
        } else {
            return .gray                // Neutral (30-70)
        }
    }

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

                // Balance
                VStack(spacing: 2) {
                    Text("Баланс")
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
                    Text("Дней в пути")
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

// MARK: - Region Card View

struct RegionCardView: View {
    let region: Region
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
                        Image(systemName: anchor.type.icon)
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
                        Text("Репутация: \(region.reputation > 0 ? "+" : "")\(region.reputation)")
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

// MARK: - Region Detail View

struct RegionDetailView: View {
    let region: Region
    @ObservedObject var worldState: WorldState
    @ObservedObject var player: Player
    @ObservedObject var engine: TwilightGameEngine  // Audit v1.1 Issue #4
    let onDismiss: () -> Void
    @State private var showingActionConfirmation = false
    @State private var selectedAction: RegionAction?
    @State private var eventToShow: GameEvent?
    @State private var showingNoEventsAlert = false

    enum RegionAction {
        case travel
        case rest
        case trade
        case strengthenAnchor
        case explore
    }

    var body: some View {
        NavigationView {
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

                    Divider()

                    // Quest info
                    if !region.activeQuests.isEmpty {
                        questsSection
                    }
                }
                .padding()
            }
            .navigationTitle(region.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        onDismiss()
                    }
                }
            }
            .sheet(item: $eventToShow) { event in
                EventView(
                    event: event,
                    player: player,
                    worldState: worldState,
                    regionId: region.id,
                    onChoiceSelected: { choice in
                        handleEventChoice(choice, event: event)
                    },
                    onDismiss: {
                        eventToShow = nil
                    }
                )
            }
            .alert(actionConfirmationTitle, isPresented: $showingActionConfirmation) {
                Button("Подтвердить") {
                    if let action = selectedAction {
                        performAction(action)
                    }
                }
                Button("Отмена", role: .cancel) { }
            } message: {
                Text(actionConfirmationMessage)
            }
            .alert("Ничего не найдено", isPresented: $showingNoEventsAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("В этом регионе сейчас нет доступных событий для исследования.")
            }
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

                // Индикатор текущей локации
                if isPlayerHere {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                        Text("Вы здесь")
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
            return "Регион спокоен. Влияние Нави минимально. Здесь безопасно отдыхать и торговать."
        case .borderland:
            return "Регион балансирует между Явью и Навью. Повышенная опасность, но и больше возможностей."
        case .breach:
            return "Навь активно проникает в регион. Очень опасно. Требуется восстановление якоря."
        }
    }

    // MARK: - Risk Info Section

    var riskInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(region.state == .breach ? .red : .orange)
                Text("Модификаторы боя")
                    .font(.caption)
                    .fontWeight(.bold)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Сила врагов:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("+\(region.state.enemyPowerBonus)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }

                HStack {
                    Text("Защита врагов:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("+\(region.state.enemyDefenseBonus)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }

                HStack {
                    Text("Здоровье врагов:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("+\(region.state.enemyHealthBonus)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(region.state == .breach ? Color.red.opacity(0.1) : Color.orange.opacity(0.1))
        )
    }

    // MARK: - Anchor Section

    func anchorSection(anchor: Anchor) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Якорь Яви")
                .font(.headline)

            HStack(spacing: 12) {
                Image(systemName: anchor.type.icon)
                    .font(.title)
                    .foregroundColor(.orange)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Color.orange.opacity(0.2)))

                VStack(alignment: .leading, spacing: 4) {
                    Text(anchor.name)
                        .font(.subheadline)
                        .fontWeight(.bold)

                    Text(anchor.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Integrity bar
                    HStack(spacing: 4) {
                        Text("Целостность:")
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

                    // Influence
                    HStack(spacing: 4) {
                        Text("Влияние:")
                            .font(.caption2)
                        Text(influenceText(anchor.influence))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(influenceColor(anchor.influence))
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

    func influenceText(_ influence: CardBalance) -> String {
        switch influence {
        case .light: return "Свет"
        case .neutral: return "Нейтрально"
        case .dark: return "Тьма"
        }
    }

    func influenceColor(_ influence: CardBalance) -> Color {
        switch influence {
        case .light: return .yellow
        case .neutral: return .gray
        case .dark: return .purple
        }
    }

    // MARK: - Actions Section

    /// Проверка, находится ли игрок в этом регионе
    var isPlayerHere: Bool {
        region.id == worldState.currentRegionId
    }

    var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Доступные действия")
                .font(.headline)

            VStack(spacing: 8) {
                // Travel action - только если игрок НЕ здесь
                if !isPlayerHere {
                    actionButton(
                        title: "Отправиться",
                        icon: "arrow.right.circle.fill",
                        color: .blue,
                        enabled: true
                    ) {
                        selectedAction = .travel
                        showingActionConfirmation = true
                    }

                    // Сообщение о необходимости переместиться
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                        Text("Переместитесь в регион, чтобы взаимодействовать с ним")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                // Действия доступны ТОЛЬКО если игрок находится в регионе
                if isPlayerHere {
                    // Rest action
                    actionButton(
                        title: "Отдохнуть (+5 ❤️)",
                        icon: "bed.double.fill",
                        color: .green,
                        enabled: region.canRest
                    ) {
                        selectedAction = .rest
                        showingActionConfirmation = true
                    }

                    // Trade action
                    actionButton(
                        title: "Торговать",
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
                            title: "Укрепить якорь (-10 ✨, +20%)",
                            icon: "hammer.fill",
                            color: .purple,
                            enabled: player.faith >= 10
                        ) {
                            selectedAction = .strengthenAnchor
                            showingActionConfirmation = true
                        }
                    }

                    // Explore
                    actionButton(
                        title: "Исследовать",
                        icon: "magnifyingglass",
                        color: .cyan,
                        enabled: true
                    ) {
                        triggerExploration()
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

    // MARK: - Quests Section

    var questsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Активные квесты в регионе")
                .font(.headline)

            ForEach(region.activeQuests, id: \.self) { questId in
                if let quest = worldState.activeQuests.first(where: { $0.id.uuidString == questId }) {
                    questView(quest)
                }
            }
        }
    }

    func questView(_ quest: Quest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Quest title
            HStack {
                Image(systemName: quest.questType == .main ? "star.fill" : "scroll.fill")
                    .foregroundColor(quest.questType == .main ? .yellow : .blue)
                Text(quest.title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            // Quest description
            Text(quest.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            // Objectives
            VStack(alignment: .leading, spacing: 4) {
                ForEach(quest.objectives) { objective in
                    HStack(spacing: 8) {
                        Image(systemName: objective.completed ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(objective.completed ? .green : .gray)
                            .font(.caption)
                        Text(objective.description)
                            .font(.caption)
                            .foregroundColor(objective.completed ? .secondary : .primary)
                            .strikethrough(objective.completed)
                    }
                }
            }
            .padding(.leading, 8)

            // Progress indicator
            let completedCount = quest.objectives.filter { $0.completed }.count
            let totalCount = quest.objectives.count
            if totalCount > 0 {
                HStack(spacing: 4) {
                    Text("Прогресс:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(completedCount)/\(totalCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(completedCount == totalCount ? .green : .orange)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(quest.questType == .main ? Color.yellow.opacity(0.15) : Color.blue.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(quest.questType == .main ? Color.yellow.opacity(0.5) : Color.blue.opacity(0.3), lineWidth: 1)
        )
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

    // MARK: - Event Handling

    func triggerExploration() {
        // Get available events for this region (with tension and flag filtering)
        let availableEvents = worldState.getAvailableEvents(for: region)

        print("DEBUG: Region: \(region.name), Type: \(region.type), State: \(region.state)")
        print("DEBUG: World tension: \(worldState.worldTension)")
        print("DEBUG: Available events count: \(availableEvents.count)")
        for event in availableEvents {
            print("DEBUG: - Event: \(event.title) (weight: \(event.weight))")
        }

        // Weighted random selection
        if let selectedEvent = worldState.selectWeightedRandomEvent(from: availableEvents) {
            eventToShow = selectedEvent
        } else {
            // No events available - show alert
            showingNoEventsAlert = true
        }
    }

    func handleEventChoice(_ choice: EventChoice, event: GameEvent) {
        // Apply consequences
        worldState.applyConsequences(
            choice.consequences,
            to: player,
            in: region.id
        )

        // Check quest objectives based on event completion
        worldState.checkQuestObjectivesByEvent(
            eventTitle: event.title,
            choiceText: choice.text,
            player: player
        )

        // Mark event as completed if it's one-time
        if event.oneTime {
            worldState.markEventCompleted(event.id)
        }

        // Записать событие в журнал
        let logType: EventLogType = event.eventType == .combat ? .combat : .exploration
        let outcomeMessage = choice.consequences.message ?? "Выбор сделан"
        worldState.logEvent(
            regionName: region.name,
            eventTitle: event.title,
            choiceMade: choice.text,
            outcome: outcomeMessage,
            type: logType
        )

        // Исследование события тратит день (кроме instant событий)
        if !event.instant {
            worldState.advanceDayForUI()
        }
    }

    // MARK: - Action Handling

    var actionConfirmationTitle: String {
        guard let action = selectedAction else { return "Подтверждение" }
        switch action {
        case .travel: return "Отправиться в регион"
        case .rest: return "Отдохнуть"
        case .trade: return "Торговать"
        case .strengthenAnchor: return "Укрепить якорь"
        case .explore: return "Исследовать"
        }
    }

    var actionConfirmationMessage: String {
        guard let action = selectedAction else { return "" }
        switch action {
        case .travel:
            let cost = worldState.calculateTravelCost(to: region.id)
            let dayWord = cost == 1 ? "день" : "дня"
            return "Отправиться в регион '\(region.name)'? Это займёт \(cost) \(dayWord) пути."
        case .rest:
            return "Отдохнуть в этом месте? Вы восстановите 5 здоровья."
        case .trade:
            return "Торговая система пока не реализована."
        case .strengthenAnchor:
            return "Укрепить якорь? Это стоит 10 веры и добавит 20% целостности."
        case .explore:
            return "Исследовать регион? Это займёт день."
        }
    }

    // MARK: - Actions via Engine (Audit v1.1 Issue #4)

    func performAction(_ action: RegionAction) {
        switch action {
        case .travel:
            // Use Engine for travel (Audit v1.1)
            let fromRegion = worldState.getCurrentRegion()?.name ?? "Неизвестно"
            let result = engine.performAction(.travel(toRegionId: region.id))

            if result.success {
                // Log travel (legacy logging still supported)
                let cost = worldState.calculateTravelCost(to: region.id)
                worldState.logTravel(from: fromRegion, to: region.name, days: cost)
                worldState.checkQuestObjectivesByRegion(regionId: region.id, player: player)
            }
            onDismiss()

        case .rest:
            // Use Engine for rest (Audit v1.1)
            let result = engine.performAction(.rest)

            if result.success {
                worldState.logEvent(
                    regionName: region.name,
                    eventTitle: "Отдых",
                    choiceMade: "Решил отдохнуть",
                    outcome: "Восстановлено здоровье",
                    type: .exploration
                )
            }

        case .trade:
            // Phase 4: Implement trade/market view
            break

        case .strengthenAnchor:
            // Use Engine for strengthen anchor (Audit v1.1)
            let result = engine.performAction(.strengthenAnchor)

            if result.success {
                worldState.logEvent(
                    regionName: region.name,
                    eventTitle: "Укрепление якоря",
                    choiceMade: "Потрачено вера",
                    outcome: "Якорь укреплён",
                    type: .worldChange
                )
            }

        case .explore:
            // This is handled separately by triggerExploration()
            break
        }
    }
}

// MARK: - Event Log View

struct EventLogView: View {
    @ObservedObject var worldState: WorldState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                if worldState.eventLog.isEmpty {
                    Text("Журнал пуст. Ваши приключения ещё впереди...")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(worldState.eventLog.reversed()) { entry in
                        EventLogEntryView(entry: entry)
                    }
                }
            }
            .navigationTitle("Журнал")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct EventLogEntryView: View {
    let entry: EventLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: entry.type.icon)
                    .foregroundColor(typeColor)

                Text("День \(entry.dayNumber)")
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
                        Text("Репутация: \(region.reputation > 0 ? "+" : "")\(region.reputation)")
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

    enum EngineRegionAction {
        case travel
        case rest
        case trade
        case strengthenAnchor
        case explore
    }

    var body: some View {
        NavigationView {
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
            .navigationTitle(region.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        onDismiss()
                    }
                }
            }
            .alert(actionConfirmationTitle, isPresented: $showingActionConfirmation) {
                Button("Подтвердить") {
                    if let action = selectedAction {
                        performAction(action)
                    }
                }
                Button("Отмена", role: .cancel) { }
            } message: {
                Text(actionConfirmationMessage)
            }
            .alert("Ничего не найдено", isPresented: $showingNoEventsAlert) {
                Button("Понятно", role: .cancel) { }
            } message: {
                Text("В этом регионе сейчас нечего исследовать. Попробуйте позже или посетите другой регион.")
            }
            .alert("Действие невозможно", isPresented: $showingActionError) {
                Button("Понятно", role: .cancel) { }
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
                        Text("Вы здесь")
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
            return "Регион спокоен. Влияние Нави минимально. Здесь безопасно отдыхать и торговать."
        case .borderland:
            return "Регион балансирует между Явью и Навью. Повышенная опасность, но и больше возможностей."
        case .breach:
            return "Навь активно проникает в регион. Очень опасно. Требуется восстановление якоря."
        }
    }

    // MARK: - Risk Info Section

    var riskInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(region.state == .breach ? .red : .orange)
                Text("Предупреждение")
                    .font(.caption)
                    .fontWeight(.bold)
            }

            Text("В этом регионе повышенная опасность. Будьте осторожны!")
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
            Text("Якорь Яви")
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
                        Text("Целостность:")
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
            Text("Доступные действия")
                .font(.headline)

            VStack(spacing: 8) {
                // Travel action - only if player is NOT here
                if !isPlayerHere {
                    let canTravel = engine.canTravelTo(regionId: region.id)
                    let routingHint = engine.getRoutingHint(to: region.id)

                    actionButton(
                        title: canTravel ? "Отправиться (1 день)" : "Регион далеко",
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
                            Text("Переместитесь в регион, чтобы взаимодействовать с ним")
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
                                Text("Сначала идите через: \(routingHint.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            } else {
                                Text("Регион недоступен напрямую")
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
                        title: "Отдохнуть (+3 ❤️)",
                        icon: "bed.double.fill",
                        color: .green,
                        enabled: region.canRest
                    ) {
                        selectedAction = .rest
                        showingActionConfirmation = true
                    }

                    // Trade action
                    actionButton(
                        title: "Торговать",
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
                            title: "Укрепить якорь (-5 ✨, +20%)",
                            icon: "hammer.fill",
                            color: .purple,
                            enabled: engine.canAffordFaith(5)
                        ) {
                            selectedAction = .strengthenAnchor
                            showingActionConfirmation = true
                        }
                    }

                    // Explore
                    actionButton(
                        title: "Исследовать",
                        icon: "magnifyingglass",
                        color: .cyan,
                        enabled: true
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
        guard let action = selectedAction else { return "Подтверждение" }
        switch action {
        case .travel: return "Отправиться в регион"
        case .rest: return "Отдохнуть"
        case .trade: return "Торговать"
        case .strengthenAnchor: return "Укрепить якорь"
        case .explore: return "Исследовать"
        }
    }

    var actionConfirmationMessage: String {
        guard let action = selectedAction else { return "" }
        switch action {
        case .travel:
            let days = engine.calculateTravelCost(to: region.id)
            let dayWord = days == 1 ? "день" : "дня"
            return "Отправиться в регион '\(region.name)'? Это займёт \(days) \(dayWord) пути."
        case .rest:
            return "Отдохнуть в этом месте? Вы восстановите 3 здоровья."
        case .trade:
            return "Торговая система пока не реализована."
        case .strengthenAnchor:
            return "Укрепить якорь? Это стоит 5 веры и добавит 20% целостности."
        case .explore:
            return "Исследовать регион? Это займёт день."
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
                    eventTitle: "Путешествие",
                    choiceMade: "Отправился в путь",
                    outcome: "Прибыл в \(region.name)",
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
                    eventTitle: "Отдых",
                    choiceMade: "Решил отдохнуть",
                    outcome: "Восстановлено здоровье",
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
                    eventTitle: "Укрепление якоря",
                    choiceMade: "Потрачена вера",
                    outcome: "Якорь укреплён",
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
                        eventTitle: "Исследование",
                        choiceMade: "Исследовал регион",
                        outcome: "Ничего интересного не найдено",
                        type: .exploration
                    )
                }
                // If event was triggered, it will be shown via onChange of engine.currentEvent
            }
        }
    }

    // MARK: - Error Messages

    func errorMessage(for error: ActionError?) -> String {
        guard let error = error else { return "Неизвестная ошибка" }
        switch error {
        case .regionNotNeighbor:
            return "Этот регион слишком далеко. Сначала переместитесь в соседний регион."
        case .regionNotAccessible:
            return "Этот регион недоступен."
        case .healthTooLow:
            return "У вас слишком мало здоровья для этого действия."
        case .insufficientResources(let resource, let required, let available):
            return "Недостаточно \(resource): нужно \(required), есть \(available)."
        case .invalidAction(let reason):
            return reason
        case .combatInProgress:
            return "Невозможно во время боя."
        case .eventInProgress:
            return "Сначала завершите текущее событие."
        default:
            return "Действие невозможно: \(error)"
        }
    }

    // MARK: - Event Choice Handling

    func handleEventChoice(_ choice: EventChoice, event: GameEvent) {
        // Execute choice via engine
        if let choiceIndex = event.choices.firstIndex(where: { $0.id == choice.id }) {
            let result = engine.performAction(.chooseEventOption(eventId: event.id, choiceIndex: choiceIndex))

            if result.success {
                // Log the event
                let logType: EventLogType = event.eventType == .combat ? .combat : .exploration
                let outcomeMessage = choice.consequences.message ?? "Выбор сделан"
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
                    Text("Журнал пуст. Ваши приключения ещё впереди...")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(engine.publishedEventLog.reversed()) { entry in
                        EventLogEntryView(entry: entry)
                    }
                }
            }
            .navigationTitle("Журнал")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
    }
}

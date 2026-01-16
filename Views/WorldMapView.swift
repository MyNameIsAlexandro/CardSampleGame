import SwiftUI

struct WorldMapView: View {
    @ObservedObject var worldState: WorldState
    @ObservedObject var player: Player
    var onExit: (() -> Void)? = nil

    @State private var selectedRegion: Region?
    @State private var showingRegionDetails = false
    @State private var showingExitConfirmation = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Top bar with world info
                worldInfoBar

                Divider()

                // Player info bar
                playerInfoBar

                Divider()

                // Regions list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(worldState.regions) { region in
                            RegionCardView(
                                region: region,
                                isCurrentLocation: region.id == worldState.currentRegionId
                            )
                            .onTapGesture {
                                selectedRegion = region
                                showingRegionDetails = true
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Карта Мира")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if onExit != nil {
                        Button(action: {
                            showingExitConfirmation = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Меню")
                            }
                        }
                    }
                }
            }
            .sheet(item: $selectedRegion) { region in
                RegionDetailView(
                    region: region,
                    worldState: worldState,
                    player: player,
                    onDismiss: {
                        selectedRegion = nil
                        showingRegionDetails = false
                    }
                )
            }
            .alert("Выйти в меню?", isPresented: $showingExitConfirmation) {
                Button("Отмена", role: .cancel) { }
                Button("Выйти") {
                    onExit?()
                }
            } message: {
                Text("Прогресс будет сохранен")
            }
        }
    }

    // MARK: - Player Info Bar

    var playerInfoBar: some View {
        HStack(spacing: 16) {
            // Player name
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
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
                Text("\(player.health)/\(player.maxHealth)")
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
                Text("\(player.faith)")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(6)

            // Balance
            HStack(spacing: 4) {
                Image(systemName: getBalanceIcon(player.balance))
                    .font(.caption)
                    .foregroundColor(getPlayerBalanceColor(player.balance))
                Text("\(abs(player.balance))")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(getPlayerBalanceColor(player.balance).opacity(0.1))
            .cornerRadius(6)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
    }

    func getBalanceIcon(_ balance: Int) -> String {
        if balance >= 30 {
            return "sun.max.fill"
        } else if balance <= -30 {
            return "moon.fill"
        } else {
            return "circle.lefthalf.filled"
        }
    }

    func getPlayerBalanceColor(_ balance: Int) -> Color {
        if balance >= 30 {
            return .yellow
        } else if balance <= -30 {
            return .purple
        } else {
            return .gray
        }
    }

    // MARK: - World Info Bar

    var worldInfoBar: some View {
        VStack(spacing: 8) {
            HStack {
                // World Tension
                VStack(alignment: .leading, spacing: 2) {
                    Text("Напряжение")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(tensionColor)
                        Text("\(worldState.worldTension)%")
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
                    Text(worldState.balanceDescription)
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
                    Text("\(worldState.daysPassed)")
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
                            width: geometry.size.width * CGFloat(worldState.worldTension) / 100,
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
        switch worldState.worldTension {
        case 0..<30: return .green
        case 30..<60: return .yellow
        case 60..<80: return .orange
        default: return .red
        }
    }

    var balanceColor: Color {
        switch worldState.lightDarkBalance {
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
    let onDismiss: () -> Void
    @State private var showingActionConfirmation = false
    @State private var selectedAction: RegionAction?
    @State private var showingEvent = false
    @State private var currentEvent: GameEvent?

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
            .sheet(isPresented: $showingEvent) {
                if let event = currentEvent {
                    EventView(
                        event: event,
                        player: player,
                        worldState: worldState,
                        regionId: region.id,
                        onChoiceSelected: { choice in
                            handleEventChoice(choice)
                        },
                        onDismiss: {
                            showingEvent = false
                            currentEvent = nil
                        }
                    )
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

    var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Доступные действия")
                .font(.headline)

            VStack(spacing: 8) {
                // Travel action
                if region.id != worldState.currentRegionId {
                    actionButton(
                        title: "Отправиться",
                        icon: "arrow.right.circle.fill",
                        color: .blue,
                        enabled: true
                    ) {
                        selectedAction = .travel
                        showingActionConfirmation = true
                    }
                }

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
                        enabled: true
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
            Text("Активные квесты")
                .font(.headline)

            ForEach(region.activeQuests, id: \.self) { questId in
                HStack {
                    Image(systemName: "scroll.fill")
                        .foregroundColor(.yellow)
                    Text("Квест активен")
                        .font(.subheadline)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.yellow.opacity(0.1))
                )
            }
        }
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
        // Get available events for this region
        let availableEvents = worldState.getAvailableEvents(for: region)

        // Pick a random event
        if let randomEvent = availableEvents.randomElement() {
            currentEvent = randomEvent
            showingEvent = true
        } else {
            // No events available - could show a message
            print("No events available in this region")
        }
    }

    func handleEventChoice(_ choice: EventChoice) {
        // Apply consequences
        worldState.applyConsequences(
            choice.consequences,
            to: player,
            in: region.id
        )

        // Mark event as completed if it's one-time
        if let event = currentEvent, event.oneTime {
            worldState.markEventCompleted(event.id)
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
            return "Отправиться в регион '\(region.name)'? Это займет день пути."
        case .rest:
            return "Отдохнуть в этом месте? Вы восстановите 5 здоровья."
        case .trade:
            return "Торговая система пока не реализована."
        case .strengthenAnchor:
            return "Укрепить якорь? Это стоит 10 веры и добавит 20% целостности."
        case .explore:
            return "Исследовать регион?"
        }
    }

    func performAction(_ action: RegionAction) {
        switch action {
        case .travel:
            // Move to this region
            worldState.moveToRegion(region.id)
            onDismiss()

        case .rest:
            // Rest and heal
            player.heal(5)
            worldState.daysPassed += 1

        case .trade:
            // TODO: Implement trade/market view
            break

        case .strengthenAnchor:
            // Strengthen anchor if player has enough faith
            if player.spendFaith(10) {
                _ = worldState.strengthenAnchor(in: region.id, amount: 20)
            }

        case .explore:
            // This is handled separately by triggerExploration()
            break
        }
    }
}

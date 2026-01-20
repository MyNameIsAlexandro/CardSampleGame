import SwiftUI

/// Event view with Engine-First Architecture
/// - All state mutations go through engine.performAction()
/// - UI reads state from engine properties
struct EventView: View {
    // MARK: - Engine-First Architecture
    @ObservedObject var engine: TwilightGameEngine

    let event: GameEvent
    let regionId: UUID
    let onChoiceSelected: (EventChoice) -> Void
    let onDismiss: () -> Void

    // MARK: - Legacy Support (for backwards compatibility)
    private var legacyPlayer: Player?
    private var legacyWorldState: WorldState?

    @State private var selectedChoice: EventChoice?
    @State private var showingResult = false
    @State private var resultMessage: String = ""
    @State private var combatMonster: Card?
    @State private var combatVictory: Bool?

    // MARK: - Computed Properties (Engine-First with legacy fallback)

    private var player: Player? {
        legacyPlayer
    }

    // MARK: - Initialization (Engine-First)

    init(
        engine: TwilightGameEngine,
        event: GameEvent,
        regionId: UUID,
        onChoiceSelected: @escaping (EventChoice) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.engine = engine
        self.event = event
        self.regionId = regionId
        self.onChoiceSelected = onChoiceSelected
        self.onDismiss = onDismiss
        self.legacyPlayer = nil
        self.legacyWorldState = nil
    }

    // MARK: - Legacy Initialization (for backwards compatibility)

    init(
        event: GameEvent,
        player: Player,
        worldState: WorldState,
        regionId: UUID,
        onChoiceSelected: @escaping (EventChoice) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        // Create engine connected to legacy
        let newEngine = TwilightGameEngine()
        newEngine.connectToLegacy(worldState: worldState, player: player)
        self.engine = newEngine
        self.event = event
        self.regionId = regionId
        self.onChoiceSelected = onChoiceSelected
        self.onDismiss = onDismiss
        self.legacyPlayer = player
        self.legacyWorldState = worldState
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Hero Panel (consistent design across all screens)
                    HeroPanel(engine: engine, compact: true)
                        .padding(.horizontal)

                    // Event header
                    eventHeader

                    Divider()

                    // Event description
                    Text(event.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    Divider()

                    // Choices
                    VStack(spacing: 12) {
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
            .navigationBarTitleDisplayMode(.inline)
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
            .fullScreenCover(item: $combatMonster) { _ in
                // Combat already set up in initiateCombat via engine.setupCombatEnemy
                CombatView(
                    engine: engine,
                    onCombatEnd: { outcome in
                        handleCombatEnd(outcome: outcome)
                    }
                )
            }
        }
    }

    // MARK: - Event Header

    var eventHeader: some View {
        HStack(spacing: 12) {
            // Event type icon
            ZStack {
                Circle()
                    .fill(eventTypeColor.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: event.eventType.icon)
                    .font(.title2)
                    .foregroundColor(eventTypeColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(event.eventType.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)

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
        case .combat: return .red
        case .ritual: return .purple
        case .narrative: return .blue
        case .exploration: return .cyan
        case .worldShift: return .orange
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
            VStack(alignment: .leading, spacing: 8) {
                Text(choice.text)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(canChoose ? .primary : .gray)

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
                RoundedRectangle(cornerRadius: 12)
                    .fill(canChoose ? Color(UIColor.secondarySystemBackground) : Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(canChoose ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canChoose)
    }

    func requirementsView(_ requirements: EventRequirements, canMeet: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let minFaith = requirements.minimumFaith {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                    Text(L10n.eventRequiresFaith.localized(with: minFaith))
                        .font(.caption2)
                    // Engine-First: read from engine
                    Text(L10n.eventYouHaveFaith.localized(with: engine.playerFaith))
                        .font(.caption2)
                        .foregroundColor(engine.playerFaith >= minFaith ? .green : .red)
                }
                .foregroundColor(.secondary)
            }

            if let minHealth = requirements.minimumHealth {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                    Text(L10n.eventRequiresHealth.localized(with: minHealth))
                        .font(.caption2)
                    // Engine-First: read from engine
                    Text(L10n.eventYouHaveHealth.localized(with: engine.playerHealth))
                        .font(.caption2)
                        .foregroundColor(engine.playerHealth >= minHealth ? .green : .red)
                }
                .foregroundColor(.secondary)
            }

            if let reqBalance = requirements.requiredBalance {
                // Engine-First: read from engine
                let playerBalanceEnum = getBalanceEnum(engine.playerBalance)
                let meetsRequirement = playerBalanceEnum == reqBalance

                HStack(spacing: 4) {
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.caption2)
                    Text(L10n.eventRequiresPath.localized(with: balanceText(reqBalance)))
                        .font(.caption2)
                    Text(L10n.eventYourPath.localized(with: balanceText(playerBalanceEnum)))
                        .font(.caption2)
                        .foregroundColor(meetsRequirement ? .green : .red)
                }
                .foregroundColor(.secondary)
            }
        }
    }

    func consequencesPreview(_ consequences: EventConsequences) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let faithChange = consequences.faithChange, faithChange != 0 {
                HStack(spacing: 4) {
                    Image(systemName: faithChange > 0 ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                    Text(L10n.eventFaithChange.localized(with: faithChange > 0 ? "+" : "", faithChange))
                        .font(.caption2)
                }
                .foregroundColor(faithChange > 0 ? .green : .orange)
            }

            if let healthChange = consequences.healthChange, healthChange != 0 {
                HStack(spacing: 4) {
                    Image(systemName: healthChange > 0 ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                    Text(L10n.eventHealthChange.localized(with: healthChange > 0 ? "+" : "", healthChange))
                        .font(.caption2)
                }
                .foregroundColor(healthChange > 0 ? .green : .red)
            }

            if let balanceChange = consequences.balanceChange, balanceChange != 0 {
                HStack(spacing: 4) {
                    Image(systemName: balanceChange > 0 ? "sun.max.fill" : "moon.fill")
                        .font(.caption2)
                    Text(balanceChange > 0 ? L10n.eventBalanceToLight.localized : L10n.eventBalanceToDark.localized)
                        .font(.caption2)
                }
                .foregroundColor(balanceChange > 0 ? .yellow : .purple)
            }

            if let reputationChange = consequences.reputationChange, reputationChange != 0 {
                HStack(spacing: 4) {
                    Image(systemName: reputationChange > 0 ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                        .font(.caption2)
                    Text(L10n.eventReputationChange.localized(with: reputationChange > 0 ? "+" : "", reputationChange))
                        .font(.caption2)
                }
                .foregroundColor(reputationChange > 0 ? .green : .red)
            }

            if consequences.addCards != nil {
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.stack.fill.badge.plus")
                        .font(.caption2)
                    Text(L10n.eventReceiveCard.localized)
                        .font(.caption2)
                }
                .foregroundColor(.blue)
            }

            if consequences.addCurse != nil {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text(L10n.eventReceiveCurse.localized)
                        .font(.caption2)
                }
                .foregroundColor(.red)
            }
        }
    }

    // MARK: - Combat Management

    func initiateCombat(choice: EventChoice) {
        guard let monster = event.monsterCard else { return }

        // Engine-First: Get combat context from engine or legacy
        let regionState = engine.currentRegion?.state ?? .stable
        let combatContext = CombatContext(
            regionState: regionState,
            playerCurses: player?.activeCurses.map { $0.type } ?? []
        )

        // Создать врага с модификаторами региона
        var adjustedMonster = monster
        if let baseHealth = monster.health {
            adjustedMonster.health = combatContext.adjustedEnemyHealth(baseHealth)
        }
        if let basePower = monster.power {
            adjustedMonster.power = combatContext.adjustedEnemyPower(basePower)
        }
        if let baseDefense = monster.defense {
            adjustedMonster.defense = combatContext.adjustedEnemyDefense(baseDefense)
        }

        // Setup combat in engine first, then show fullScreenCover
        engine.setupCombatEnemy(adjustedMonster)
        combatMonster = adjustedMonster
    }

    func handleCombatEnd(outcome: CombatView.CombatOutcome) {
        // Apply non-combat consequences from the choice (if victory)
        if outcome.isVictory, let choice = selectedChoice {
            onChoiceSelected(choice)
        }

        // Combat already shows its own victory/defeat screen, no need for additional alert
        // Just close combat and dismiss event view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            combatMonster = nil
            // Small delay before dismissing to allow animation to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                onDismiss()
            }
        }
    }

    // MARK: - Helpers

    func canMeetRequirements(_ choice: EventChoice) -> Bool {
        guard let requirements = choice.requirements else { return true }
        // Engine-First: check requirements using engine state or legacy fallback
        if let ws = legacyWorldState, let p = legacyPlayer {
            return requirements.canMeet(with: p, worldState: ws)
        }
        // TODO: Implement pure engine-based requirement checking
        return true
    }

    /// Engine-based requirement checking
    func canMeetRequirementsEngine(_ choice: EventChoice) -> Bool {
        guard let requirements = choice.requirements else { return true }

        // Check minimum faith
        if let minFaith = requirements.minimumFaith {
            if engine.playerFaith < minFaith {
                return false
            }
        }

        // Check minimum health
        if let minHealth = requirements.minimumHealth {
            if engine.playerHealth < minHealth {
                return false
            }
        }

        // Check balance requirement
        if let reqBalance = requirements.requiredBalance {
            let playerBalanceEnum = getBalanceEnum(engine.playerBalance)
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

// MARK: - Preview

struct EventView_Previews: PreviewProvider {
    static var previews: some View {
        let player = Player(
            name: "Волхв",
            health: 20,
            maxHealth: 20,
            maxHandSize: 5,
            faith: 10,
            balance: 0
        )

        let worldState = WorldState()

        let event = GameEvent(
            eventType: .narrative,
            title: "Тестовое событие",
            description: "Это тестовое событие для предварительного просмотра",
            choices: [
                EventChoice(
                    text: "Выбор 1",
                    consequences: EventConsequences(
                        faithChange: 5,
                        message: "Результат выбора 1"
                    )
                ),
                EventChoice(
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
            event: event,
            player: player,
            worldState: worldState,
            regionId: UUID(),
            onChoiceSelected: { _ in },
            onDismiss: { }
        )
    }
}

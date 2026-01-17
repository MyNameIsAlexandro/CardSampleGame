import SwiftUI

struct EventView: View {
    let event: GameEvent
    let player: Player
    let worldState: WorldState
    let regionId: UUID
    let onChoiceSelected: (EventChoice) -> Void
    let onDismiss: () -> Void

    @State private var selectedChoice: EventChoice?
    @State private var showingResult = false
    @State private var resultMessage: String = ""
    @State private var combatMonster: Card?
    @State private var combatVictory: Bool?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
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
                        Text("Выберите действие:")
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
                    Button("Закрыть") {
                        onDismiss()
                    }
                }
            }
            .alert("Результат", isPresented: $showingResult) {
                Button("ОК") {
                    if let choice = selectedChoice {
                        onChoiceSelected(choice)
                    }
                    onDismiss()
                }
            } message: {
                Text(resultMessage)
            }
            .fullScreenCover(item: $combatMonster) { monster in
                CombatView(
                    player: player,
                    monster: Binding(
                        get: { combatMonster ?? monster },
                        set: { combatMonster = $0 }
                    ),
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
        let canChoose = canMeetRequirements(choice)
        let isCombatChoice = event.eventType == .combat &&
                             choice.id == event.choices.first?.id &&
                             event.monsterCard != nil

        return Button(action: {
            if canChoose {
                selectedChoice = choice

                // Check if this is a combat choice
                if isCombatChoice {
                    initiateCombat(choice: choice)
                } else {
                    resultMessage = choice.consequences.message ?? "Выбор сделан."
                    showingResult = true
                }
            }
        }) {
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
        }
        .disabled(!canChoose)
    }

    func requirementsView(_ requirements: EventRequirements, canMeet: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let minFaith = requirements.minimumFaith {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                    Text("Требуется: \(minFaith) веры")
                        .font(.caption2)
                    Text("(у вас: \(player.faith))")
                        .font(.caption2)
                        .foregroundColor(player.faith >= minFaith ? .green : .red)
                }
                .foregroundColor(.secondary)
            }

            if let minHealth = requirements.minimumHealth {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                    Text("Требуется: \(minHealth) здоровья")
                        .font(.caption2)
                    Text("(у вас: \(player.health))")
                        .font(.caption2)
                        .foregroundColor(player.health >= minHealth ? .green : .red)
                }
                .foregroundColor(.secondary)
            }

            if let reqBalance = requirements.requiredBalance {
                let playerBalanceEnum = getBalanceEnum(player.balance)
                let meetsRequirement = playerBalanceEnum == reqBalance

                HStack(spacing: 4) {
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.caption2)
                    Text("Требуется путь: \(balanceText(reqBalance))")
                        .font(.caption2)
                    Text("(ваш: \(balanceText(playerBalanceEnum)))")
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
                    Text("Вера: \(faithChange > 0 ? "+" : "")\(faithChange)")
                        .font(.caption2)
                }
                .foregroundColor(faithChange > 0 ? .green : .orange)
            }

            if let healthChange = consequences.healthChange, healthChange != 0 {
                HStack(spacing: 4) {
                    Image(systemName: healthChange > 0 ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                    Text("Здоровье: \(healthChange > 0 ? "+" : "")\(healthChange)")
                        .font(.caption2)
                }
                .foregroundColor(healthChange > 0 ? .green : .red)
            }

            if let balanceChange = consequences.balanceChange, balanceChange != 0 {
                HStack(spacing: 4) {
                    Image(systemName: balanceChange > 0 ? "sun.max.fill" : "moon.fill")
                        .font(.caption2)
                    Text("Баланс: \(balanceChange > 0 ? "к Свету" : "к Тьме")")
                        .font(.caption2)
                }
                .foregroundColor(balanceChange > 0 ? .yellow : .purple)
            }

            if let reputationChange = consequences.reputationChange, reputationChange != 0 {
                HStack(spacing: 4) {
                    Image(systemName: reputationChange > 0 ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                        .font(.caption2)
                    Text("Репутация: \(reputationChange > 0 ? "+" : "")\(reputationChange)")
                        .font(.caption2)
                }
                .foregroundColor(reputationChange > 0 ? .green : .red)
            }

            if consequences.addCards != nil {
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.stack.fill.badge.plus")
                        .font(.caption2)
                    Text("Получите карту")
                        .font(.caption2)
                }
                .foregroundColor(.blue)
            }

            if consequences.addCurse != nil {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text("Получите проклятие")
                        .font(.caption2)
                }
                .foregroundColor(.red)
            }
        }
    }

    // MARK: - Combat Management

    func initiateCombat(choice: EventChoice) {
        guard let monster = event.monsterCard else { return }

        // Получить контекст региона для модификаторов боя
        let currentRegion = worldState.getCurrentRegion()
        let regionState = currentRegion?.state ?? .stable
        let combatContext = CombatContext(
            regionState: regionState,
            playerCurses: player.activeCurses.map { $0.type }
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

        // Установить монстра - fullScreenCover покажется автоматически
        combatMonster = adjustedMonster
    }

    func handleCombatEnd(outcome: CombatView.CombatOutcome) {
        // Определяем результат боя
        switch outcome {
        case .victory:
            combatVictory = true
            resultMessage = "Победа! Вы одержали верх в бою."
        case .defeat:
            combatVictory = false
            resultMessage = "Поражение... Вы потерпели неудачу в бою."
        case .fled:
            combatVictory = nil
            resultMessage = "Вы сбежали из боя."
        }

        // Apply non-combat consequences from the choice (if victory)
        if outcome == .victory, let choice = selectedChoice {
            onChoiceSelected(choice)
        }

        // Задержка нужна чтобы fullScreenCover полностью закрылся перед показом alert
        // (combatMonster = nil закроет fullScreenCover автоматически)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            combatMonster = nil
            showingResult = true
        }
    }

    // MARK: - Helpers

    func canMeetRequirements(_ choice: EventChoice) -> Bool {
        guard let requirements = choice.requirements else { return true }
        return requirements.canMeet(with: player, worldState: worldState)
    }

    func balanceText(_ balance: CardBalance) -> String {
        switch balance {
        case .light: return "Света"
        case .neutral: return "Нейтральный"
        case .dark: return "Тьмы"
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

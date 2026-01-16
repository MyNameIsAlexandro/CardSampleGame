import SwiftUI

struct GameBoardView: View {
    @StateObject var gameState: GameState
    var saveSlot: Int?
    var onExit: (() -> Void)?
    @State private var selectedCard: Card?
    @State private var showingDiceRoll = false
    @State private var combatResult: CombatResult?
    @State private var showingRules = false
    @State private var showingPauseMenu = false
    @State private var showingSaveConfirmation = false
    @State private var showingEnemyAttack = false
    @State private var showingWorldMap = false
    @State private var enemyDamage: Int = 0
    @StateObject private var saveManager = SaveManager.shared

    struct CombatResult {
        let diceRoll: Int
        let total: Int
        let defense: Int
        let success: Bool
        let damage: Int
    }

    // Custom initializer to accept external GameState instance
    init(gameState: GameState, saveSlot: Int? = nil, onExit: (() -> Void)? = nil) {
        _gameState = StateObject(wrappedValue: gameState)
        self.saveSlot = saveSlot
        self.onExit = onExit
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main game view
                VStack(spacing: 0) {
                    // Top bar
                    topBar
                        .frame(height: 95)
                        .background(Color(UIColor.systemBackground))
                        .shadow(radius: 2)

                    // Main game area (scrollable)
                    ScrollView {
                        VStack(spacing: 16) {
                            // Current encounter or exploration
                            encounterArea
                                .padding(.horizontal)

                            // Market section
                            marketView
                                .padding(.horizontal)

                            // Deck info
                            deckInfoView
                                .padding(.horizontal)

                            // Space for hand
                            Color.clear.frame(height: 120)
                        }
                        .padding(.vertical)
                    }

                    Divider()

                    // Fixed player hand at bottom
                    PlayerHandView(
                        player: gameState.currentPlayer,
                        selectedCard: $selectedCard,
                        onCardPlay: playCard
                    )
                    .frame(height: 120)
                    .background(Color(UIColor.secondarySystemBackground))
                }

                // Pause menu overlay
                if showingPauseMenu {
                    pauseMenuOverlay
                }

                // Victory screen
                if gameState.isVictory {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    VictoryView(
                        encountersDefeated: gameState.encountersDefeated,
                        turnsTaken: gameState.turnNumber,
                        onDismiss: {
                            onExit?()
                        }
                    )
                    .padding(20)
                }

                // Defeat screen
                if gameState.isDefeat {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    DefeatView(
                        encountersDefeated: gameState.encountersDefeated,
                        turnsTaken: gameState.turnNumber,
                        onDismiss: {
                            onExit?()
                        }
                    )
                    .padding(20)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            setupAutoSave()
        }
        .onDisappear {
            autoSaveOnExit()
        }
        .onChange(of: gameState.currentPhase) { newPhase in
            if newPhase == .enemyTurn {
                // Enemy attacks during their phase
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let encounter = gameState.activeEncounter {
                        let damage = encounter.power ?? 3
                        enemyDamage = damage
                        gameState.enemyPhaseAction()
                        showingEnemyAttack = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingRules) {
            RulesView()
        }
        .sheet(isPresented: $showingWorldMap) {
            WorldMapView(worldState: gameState.worldState, player: gameState.currentPlayer)
        }
        .alert(combatResult?.success == true ? "Успех!" : "Провал", isPresented: $showingDiceRoll) {
            Button(L10n.buttonOk.localized, role: .cancel) {
                combatResult = nil
            }
        } message: {
            if let result = combatResult {
                if result.success {
                    Text("Бросок: \(result.diceRoll) + Сила: \(result.total - result.diceRoll) = \(result.total)\nЗащита врага: \(result.defense)\nУрон: \(result.damage)")
                } else {
                    Text("Бросок: \(result.diceRoll) + Сила: \(result.total - result.diceRoll) = \(result.total)\nЗащита врага: \(result.defense)\nВраг атакует вас!")
                }
            }
        }
        .alert(L10n.uiGameSaved.localized, isPresented: $showingSaveConfirmation) {
            Button(L10n.buttonOk.localized, role: .cancel) { }
        } message: {
            Text(L10n.uiProgressSaved.localized)
        }
        .alert("Атака врага!", isPresented: $showingEnemyAttack) {
            Button(L10n.buttonOk.localized, role: .cancel) { }
        } message: {
            Text("Враг атакует вас и наносит \(enemyDamage) урона!\nВаше здоровье: \(gameState.currentPlayer.health)")
        }
    }

    // MARK: - Top Bar

    var topBar: some View {
        VStack(spacing: 4) {
            HStack(spacing: 12) {
                // Pause/Menu button
                Button(action: { showingPauseMenu = true }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title3)
                        .foregroundColor(.blue)
                        .padding(8)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.turnLabel.localized(with: gameState.turnNumber))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(phaseText)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(phaseColor)
                }

                Spacer()

                // Player resources - compact with icons only
                HStack(spacing: 8) {
                    // Actions
                    HStack(spacing: 2) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                        Text("\(gameState.actionsRemaining)")
                            .font(.system(size: 13))
                            .fontWeight(.bold)
                    }

                    // Health
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                        Text("\(gameState.currentPlayer.health)")
                            .font(.system(size: 13))
                            .fontWeight(.bold)
                    }

                    // Faith
                    HStack(spacing: 2) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)
                        Text("\(gameState.currentPlayer.faith)")
                            .font(.system(size: 13))
                            .fontWeight(.bold)
                    }
                }

                // Next phase button
                Button(action: {
                    gameState.nextPhase()
                }) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
                .padding(4)
            }
            .padding(.horizontal)

            // Phase progress bar
            PhaseProgressBar(currentPhase: gameState.currentPhase)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
        }
    }

    func resourceBadge(icon: String, value: String, color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(value)
                .font(.caption2)
                .fontWeight(.bold)
            if !label.isEmpty {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(6)
    }

    // MARK: - Encounter Area

    var encounterArea: some View {
        Group {
            if let encounter = gameState.activeEncounter {
                VStack(spacing: 12) {
                    Text(L10n.uiActiveEncounter.localized)
                        .font(.headline)
                        .foregroundColor(.red)

                    CardView(card: encounter)
                        .frame(width: 180, height: 280)

                    HStack(spacing: 16) {
                        Button(action: rollDice) {
                            Label(L10n.uiRoll.localized, systemImage: "dice.fill")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }

                        if let roll = gameState.diceRoll {
                            Text(L10n.uiResult.localized(with: roll))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red, lineWidth: 2)
                        )
                )
            } else if gameState.currentPhase == .exploration {
                Button(action: {
                    gameState.drawEncounter()
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                        Text(L10n.uiExplore.localized)
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Market View

    var marketView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cart.fill")
                    .font(.title3)
                    .foregroundColor(.orange)
                Text("Рынок")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text("\(gameState.currentPlayer.faith)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
            }

            if gameState.marketCards.isEmpty {
                Text("Нет карт для покупки")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(gameState.marketCards) { card in
                            MarketCardView(
                                card: card,
                                canAfford: gameState.currentPlayer.faith >= (card.cost ?? 0),
                                onPurchase: {
                                    if gameState.purchaseCard(card) {
                                        // Card purchased successfully
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Deck Info

    var deckInfoView: some View {
        HStack(spacing: 12) {
            DeckPileView(
                title: L10n.uiEncounters.localized,
                count: gameState.encounterDeck.count,
                color: .red
            )

            DeckPileView(
                title: L10n.uiYourDeck.localized,
                count: gameState.currentPlayer.deck.count,
                color: .blue
            )

            DeckPileView(
                title: L10n.uiDiscard.localized,
                count: gameState.currentPlayer.discard.count,
                color: .gray
            )
        }
    }

    // MARK: - Pause Menu

    var pauseMenuOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    showingPauseMenu = false
                }

            VStack(spacing: 16) {
                Text(L10n.uiPauseMenu.localized)
                    .font(.title2)
                    .fontWeight(.bold)

                Button(action: {
                    showingPauseMenu = false
                }) {
                    Label(L10n.uiResume.localized, systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                Button(action: {
                    showingRules = true
                    showingPauseMenu = false
                }) {
                    Label(L10n.uiRules.localized, systemImage: "book.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                Button(action: {
                    showingWorldMap = true
                    showingPauseMenu = false
                }) {
                    Label("Карта Мира", systemImage: "map.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.cyan)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                if let slot = saveSlot {
                    Button(action: {
                        saveManager.saveGame(to: slot, gameState: gameState)
                        showingSaveConfirmation = true
                        showingPauseMenu = false
                    }) {
                        Label(L10n.uiSaveGame.localized, systemImage: "tray.and.arrow.down.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }

                Button(action: {
                    showingPauseMenu = false
                    onExit?()
                }) {
                    Label(L10n.uiExit.localized, systemImage: "house.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding(30)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 20)
            .padding(40)
        }
    }

    // MARK: - Helper Properties

    var phaseText: String {
        switch gameState.currentPhase {
        case .setup: return L10n.phaseSetup.localized
        case .exploration: return L10n.phaseExploration.localized
        case .encounter: return L10n.phaseEncounter.localized
        case .playerTurn: return L10n.phasePlayerTurn.localized
        case .enemyTurn: return L10n.phaseEnemyTurn.localized
        case .endTurn: return L10n.phaseEndTurn.localized
        case .gameOver: return L10n.phaseGameOver.localized
        }
    }

    var phaseColor: Color {
        switch gameState.currentPhase {
        case .setup: return .gray
        case .exploration: return .blue
        case .encounter: return .orange
        case .playerTurn: return .green
        case .enemyTurn: return .red
        case .endTurn: return .purple
        case .gameOver: return .black
        }
    }

    var balanceIcon: String {
        let balance = gameState.currentPlayer.balance
        if balance >= 70 {              // Light path (70-100)
            return "sun.max.fill"
        } else if balance <= 30 {       // Dark path (0-30)
            return "moon.fill"
        } else {                        // Neutral (30-70)
            return "circle.lefthalf.filled"
        }
    }

    var balanceColor: Color {
        let balance = gameState.currentPlayer.balance
        if balance >= 70 {              // Light path (70-100)
            return .yellow
        } else if balance <= 30 {       // Dark path (0-30)
            return .purple
        } else {                        // Neutral (30-70)
            return .gray
        }
    }

    // MARK: - Helper Functions

    func rollDice() {
        guard let encounter = gameState.activeEncounter else { return }

        // Check if player has actions remaining
        guard gameState.useAction() else {
            // Show alert that no actions left
            return
        }

        // Roll dice
        let diceResult = gameState.rollDice(sides: 6, count: 1)

        // Calculate total (dice + player power)
        let playerPower = gameState.currentPlayer.strength
        let total = diceResult + playerPower

        // Get encounter defense (or use default 10 if not specified)
        let encounterDefense = encounter.defense ?? 10

        // Combat resolution
        let success = total >= encounterDefense
        var damageDealt = 0

        if success {
            // Success! Deal damage to encounter
            damageDealt = max(1, total - encounterDefense + 3) // Base 3 damage + excess
            if var updatedEncounter = gameState.activeEncounter {
                let currentHealth = updatedEncounter.health ?? 10
                updatedEncounter.health = max(0, currentHealth - damageDealt)
                gameState.activeEncounter = updatedEncounter

                // Check if encounter defeated
                if updatedEncounter.health == 0 {
                    gameState.defeatEncounter()
                }
            }
        }
        // Enemy attacks during enemy phase, not immediately after player attack

        // Store combat result for display
        combatResult = CombatResult(
            diceRoll: diceResult,
            total: total,
            defense: encounterDefense,
            success: success,
            damage: damageDealt
        )

        showingDiceRoll = true
    }

    func playCard(_ card: Card) {
        // Check if player has actions remaining
        guard gameState.useAction() else {
            // TODO: Show alert that no actions left
            return
        }

        // Check if player has enough faith
        guard let cost = card.cost else {
            gameState.currentPlayer.playCard(card)
            applyCardEffects(card)
            return
        }

        if gameState.currentPlayer.spendFaith(cost) {
            gameState.currentPlayer.playCard(card)
            applyCardEffects(card)
        } else {
            // Refund action if couldn't spend faith
            gameState.actionsRemaining += 1
        }
    }

    func applyCardEffects(_ card: Card) {
        for ability in card.abilities {
            switch ability.effect {
            case .heal(let amount):
                gameState.currentPlayer.heal(amount)

            case .damage(let amount, _):
                if var encounter = gameState.activeEncounter, let health = encounter.health {
                    encounter.health = max(0, health - amount)
                    gameState.activeEncounter = encounter
                    if encounter.health == 0 {
                        // Encounter defeated!
                        gameState.defeatEncounter()
                    }
                }

            case .drawCards(let count):
                gameState.currentPlayer.drawCards(count: count)

            case .gainFaith(let amount):
                gameState.currentPlayer.gainFaith(amount)

            case .removeCurse(let type):
                gameState.currentPlayer.removeCurse(type: type)

            case .shiftBalance(let towards, let amount):
                gameState.currentPlayer.shiftBalance(towards: towards, amount: amount)

            default:
                break
            }
        }
    }

    // MARK: - Auto-Save Functions

    func setupAutoSave() {
        guard let slot = saveSlot else { return }

        gameState.onAutoSave = { [weak saveManager, weak gameState] in
            guard let saveManager = saveManager,
                  let gameState = gameState else { return }
            saveManager.saveGame(to: slot, gameState: gameState)
        }
    }

    func autoSaveOnExit() {
        guard let slot = saveSlot else { return }
        saveManager.saveGame(to: slot, gameState: gameState)
    }
}

// MARK: - Victory/Defeat Screens

struct VictoryView: View {
    let encountersDefeated: Int
    let turnsTaken: Int
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "crown.fill")
                .font(.system(size: 80))
                .foregroundColor(.yellow)

            Text(L10n.uiVictoryTitle.localized)
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Вы защитили земли от тьмы!")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                StatRow(label: "Побеждено столкновений", value: "\(encountersDefeated)")
                StatRow(label: "Ходов сделано", value: "\(turnsTaken)")
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)

            Button(action: onDismiss) {
                Text(L10n.uiReturnMenu.localized)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding(40)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .shadow(radius: 20)
    }
}

struct DefeatView: View {
    let encountersDefeated: Int
    let turnsTaken: Int
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)

            Text(L10n.uiDefeatTitle.localized)
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Тьма одержала победу...")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                StatRow(label: "Побеждено столкновений", value: "\(encountersDefeated)")
                StatRow(label: "Ходов выжито", value: "\(turnsTaken)")
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)

            Button(action: onDismiss) {
                Text(L10n.uiReturnMenu.localized)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding(40)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .shadow(radius: 20)
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.bold)
        }
    }
}

// MARK: - Deck Pile View

struct DeckPileView: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                ForEach(0..<min(count, 3), id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.7))
                        .frame(width: 50, height: 70)
                        .offset(x: CGFloat(index) * 2, y: CGFloat(index) * -2)
                }
            }
            .frame(width: 60, height: 80)

            Text(title)
                .font(.caption2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            Text("\(count)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Market Card View

struct MarketCardView: View {
    let card: Card
    let canAfford: Bool
    let onPurchase: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Rarity badge
            HStack {
                rarityBadge
                Spacer()
                // Cost badge
                HStack(spacing: 2) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                    Text("\(card.cost ?? 0)")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(canAfford ? Color.yellow.opacity(0.3) : Color.gray.opacity(0.3))
                .foregroundColor(canAfford ? .yellow : .gray)
                .cornerRadius(8)
            }

            // Card name
            Text(card.name)
                .font(.subheadline)
                .fontWeight(.bold)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(height: 32, alignment: .top)

            // Card type
            Text(cardTypeText)
                .font(.caption2)
                .foregroundColor(.secondary)

            // Card stats
            HStack(spacing: 8) {
                if let power = card.power {
                    HStack(spacing: 2) {
                        Image(systemName: "bolt.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text("\(power)")
                            .font(.caption)
                    }
                }
                if let defense = card.defense {
                    HStack(spacing: 2) {
                        Image(systemName: "shield.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text("\(defense)")
                            .font(.caption)
                    }
                }
            }

            Spacer()

            // Purchase button
            Button(action: onPurchase) {
                Text("Купить")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(canAfford ? Color.green : Color.gray)
                    .cornerRadius(6)
            }
            .disabled(!canAfford)
        }
        .padding(8)
        .frame(width: 120, height: 180)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(rarityBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(rarityBorderColor, lineWidth: 2)
                )
        )
    }

    var cardTypeText: String {
        switch card.type {
        case .resource: return "Ресурс"
        case .attack: return "Атака"
        case .defense: return "Защита"
        case .special: return "Особая"
        default: return card.type.rawValue
        }
    }

    var rarityBadge: some View {
        Text(rarityText)
            .font(.system(size: 8))
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(rarityBorderColor)
            .cornerRadius(4)
    }

    var rarityText: String {
        switch card.rarity {
        case .common: return "Обычная"
        case .uncommon: return "Необычная"
        case .rare: return "Редкая"
        case .epic: return "Эпическая"
        case .legendary: return "Легендарная"
        }
    }

    var rarityBackgroundColor: Color {
        switch card.rarity {
        case .common: return Color(UIColor.tertiarySystemBackground)
        case .uncommon: return Color.green.opacity(0.1)
        case .rare: return Color.blue.opacity(0.1)
        case .epic: return Color.purple.opacity(0.1)
        case .legendary: return Color.orange.opacity(0.1)
        }
    }

    var rarityBorderColor: Color {
        switch card.rarity {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }
}

// MARK: - Phase Progress Bar

struct PhaseProgressBar: View {
    let currentPhase: GamePhase

    let phases: [(phase: GamePhase, name: String, color: Color)] = [
        (.exploration, "Исследование", .blue),
        (.encounter, "Встреча", .orange),
        (.playerTurn, "Ход игрока", .green),
        (.enemyTurn, "Ход врага", .red),
        (.endTurn, "Конец хода", .purple)
    ]

    var body: some View {
        VStack(spacing: 4) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                        .cornerRadius(2)

                    // Progress indicator
                    Rectangle()
                        .fill(currentPhaseColor)
                        .frame(width: progressWidth(totalWidth: geometry.size.width), height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)

            // Phase indicators
            HStack(spacing: 0) {
                ForEach(Array(phases.enumerated()), id: \.offset) { index, phaseInfo in
                    VStack(spacing: 2) {
                        Circle()
                            .fill(phaseInfo.phase == currentPhase ? phaseInfo.color : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(phaseInfo.color, lineWidth: phaseInfo.phase == currentPhase ? 2 : 0)
                            )

                        Text(phaseInfo.name)
                            .font(.system(size: 8))
                            .foregroundColor(phaseInfo.phase == currentPhase ? phaseInfo.color : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    var currentPhaseColor: Color {
        phases.first(where: { $0.phase == currentPhase })?.color ?? .gray
    }

    func progressWidth(totalWidth: CGFloat) -> CGFloat {
        guard let currentIndex = phases.firstIndex(where: { $0.phase == currentPhase }) else {
            return 0
        }
        let progress = CGFloat(currentIndex + 1) / CGFloat(phases.count)
        return totalWidth * progress
    }
}

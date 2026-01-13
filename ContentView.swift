import SwiftUI

struct ContentView: View {
    @State private var showingGame = false
    @State private var showingRules = false
    @State private var showingSaveSlots = false
    @State private var showingStatistics = false
    @State private var selectedCharacterIndex = 0
    @State private var selectedSaveSlot: Int?
    @StateObject private var gameState = GameState(players: [])
    @StateObject private var saveManager = SaveManager.shared

    // Using Twilight Marches characters
    let characters = TwilightMarchesCards.createGuardians()

    var body: some View {
        NavigationView {
            if showingGame {
                GameBoardView(
                    gameState: gameState,
                    saveSlot: selectedSaveSlot,
                    onExit: {
                        showingGame = false
                        showingSaveSlots = false
                    }
                )
            } else if showingSaveSlots {
                saveSlotSelectionView
            } else {
                characterSelectionView
            }
        }
    }

    var characterSelectionView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Scrollable content
                ScrollView {
                    VStack(spacing: 20) {
                        // Header with rules and statistics buttons
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tmGameTitle.localized)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .minimumScaleFactor(0.7)
                                    .lineLimit(1)
                                Text(L10n.tmGameSubtitle.localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button(action: { showingStatistics = true }) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.title3)
                                    .padding(8)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(8)
                            }
                            Button(action: { showingRules = true }) {
                                Label(L10n.rulesButton.localized, systemImage: "book.fill")
                                    .font(.headline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        Text(L10n.characterSelectTitle.localized)
                            .font(.title2)
                            .foregroundColor(.secondary)

                        // Character cards scroll
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                ForEach(Array(characters.enumerated()), id: \.element.id) { index, character in
                                    CompactCardView(
                                        card: character,
                                        isSelected: selectedCharacterIndex == index,
                                        onTap: {
                                            selectedCharacterIndex = index
                                        }
                                    )
                                    .frame(width: min(geometry.size.width * 0.65, 240), height: 280)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                        }
                        .frame(height: 320)

                        // Character stats
                        if selectedCharacterIndex < characters.count {
                            let character = characters[selectedCharacterIndex]
                            VStack(alignment: .leading, spacing: 16) {
                                Text(L10n.characterStats.localized)
                                    .font(.headline)

                                Text(character.description)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                HStack(spacing: 24) {
                                    if let health = character.health {
                                        StatDisplay(icon: "heart.fill", label: L10n.statHealth.localized, value: health, color: .red)
                                    }
                                    if let power = character.power {
                                        StatDisplay(icon: "sword.fill", label: L10n.statPower.localized, value: power, color: .orange)
                                    }
                                    if let defense = character.defense {
                                        StatDisplay(icon: "shield.fill", label: L10n.statDefense.localized, value: defense, color: .blue)
                                    }
                                }

                                if !character.abilities.isEmpty {
                                    Divider()
                                    Text(L10n.characterAbilities.localized)
                                        .font(.headline)

                                    ForEach(character.abilities) { ability in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(ability.name)
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.orange)
                                            Text(ability.description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }

                        // Extra space for button
                        Color.clear.frame(height: 90)
                    }
                    .padding(.bottom, 20)
                }

                // Fixed button at bottom with shadow
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.clear, Color(UIColor.systemBackground)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 30)

                    Button(action: { showingSaveSlots = true }) {
                        Text(L10n.buttonStartAdventure.localized)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                    .background(Color(UIColor.systemBackground))
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingRules) {
            RulesView()
        }
        .sheet(isPresented: $showingStatistics) {
            StatisticsView()
        }
    }

    var saveSlotSelectionView: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Button(action: { showingSaveSlots = false }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Назад")
                    }
                    .foregroundColor(.blue)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Выбор слота")
                        .font(.title2)
                        .fontWeight(.bold)
                    if selectedCharacterIndex < characters.count {
                        Text(characters[selectedCharacterIndex].name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()

            // Save slots
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(1...3, id: \.self) { slotNumber in
                        SaveSlotCard(
                            slotNumber: slotNumber,
                            saveData: saveManager.loadGame(from: slotNumber),
                            onNewGame: { startGame(in: slotNumber) },
                            onLoadGame: { loadGame(from: slotNumber) },
                            onDelete: {
                                saveManager.deleteSave(from: slotNumber)
                            }
                        )
                    }
                }
                .padding()
            }
        }
        .navigationBarHidden(true)
    }

    func startGame(in slot: Int) {
        let selectedCharacter = characters[selectedCharacterIndex]

        // Create player with selected character
        let player = Player(
            name: selectedCharacter.name,
            health: selectedCharacter.health ?? 10,
            maxHealth: selectedCharacter.health ?? 10,
            maxHandSize: 7,
            strength: selectedCharacter.power ?? 0,
            dexterity: 0,
            constitution: 0,
            intelligence: 0,
            wisdom: 0,
            charisma: 0
        )

        // Build player's deck with Twilight Marches cards
        player.deck = TwilightMarchesCards.createFullDeck()
        player.shuffleDeck()

        // Initialize game state with Twilight Marches encounters
        gameState.players = [player]
        gameState.encounterDeck = TwilightMarchesCards.createEncounterDeck()
        gameState.encounterDeck.shuffle()

        gameState.startGame()

        // Save to selected slot
        selectedSaveSlot = slot
        saveManager.saveGame(to: slot, gameState: gameState)

        showingGame = true
        showingSaveSlots = false
    }

    func loadGame(from slot: Int) {
        guard let saveData = saveManager.loadGame(from: slot) else { return }

        // Find the character
        if let characterIndex = characters.firstIndex(where: { $0.name == saveData.characterName }) {
            selectedCharacterIndex = characterIndex
        }

        // Create player from save data
        let player = Player(
            name: saveData.characterName,
            health: saveData.health,
            maxHealth: saveData.maxHealth,
            maxHandSize: 7,
            strength: 0,
            dexterity: 0,
            constitution: 0,
            intelligence: 0,
            wisdom: 0,
            charisma: 0
        )

        // Set player resources
        player.faith = saveData.faith
        player.balance = saveData.balance

        // Build player's deck
        player.deck = TwilightMarchesCards.createFullDeck()
        player.shuffleDeck()

        // Initialize game state
        gameState.players = [player]
        gameState.encounterDeck = TwilightMarchesCards.createEncounterDeck()
        gameState.encounterDeck.shuffle()
        gameState.turnNumber = saveData.turnNumber
        gameState.encountersDefeated = saveData.encountersDefeated

        gameState.startGame()

        selectedSaveSlot = slot
        showingGame = true
        showingSaveSlots = false
    }
}

struct StatDisplay: View {
    let icon: String
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text("\(value)")
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct SaveSlotCard: View {
    let slotNumber: Int
    let saveData: GameSave?
    let onNewGame: () -> Void
    let onLoadGame: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteAlert = false
    @State private var showingOverwriteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Слот \(slotNumber)")
                    .font(.headline)
                Spacer()
                if saveData != nil {
                    Button(action: { showingDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }

            if let save = saveData {
                // Existing save
                VStack(alignment: .leading, spacing: 8) {
                    Text(save.characterName)
                        .font(.title3)
                        .fontWeight(.bold)

                    HStack(spacing: 16) {
                        Label("\(save.health)/\(save.maxHealth)", systemImage: "heart.fill")
                            .foregroundColor(.red)
                        Label("\(save.faith)", systemImage: "sparkles")
                            .foregroundColor(.yellow)
                        Label("\(save.balance)", systemImage: "scale.3d")
                            .foregroundColor(.purple)
                    }
                    .font(.subheadline)

                    HStack {
                        Text("Ход: \(save.turnNumber)")
                        Text("•")
                        Text("Побед: \(save.encountersDefeated)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    Text(save.formattedDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Divider()

                    HStack(spacing: 12) {
                        Button(action: onLoadGame) {
                            Text("Загрузить")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }

                        Button(action: { showingOverwriteAlert = true }) {
                            Text("Новая игра")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
            } else {
                // Empty slot
                VStack(spacing: 12) {
                    Image(systemName: "square.dashed")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)

                    Text("Пустой слот")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button(action: onNewGame) {
                        Text("Начать новую игру")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .alert("Удалить сохранение?", isPresented: $showingDeleteAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Удалить", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Это действие нельзя отменить.")
        }
        .alert("Перезаписать сохранение?", isPresented: $showingOverwriteAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Перезаписать", role: .destructive) {
                onNewGame()
            }
        } message: {
            Text("Текущее сохранение будет потеряно.")
        }
    }
}

#Preview {
    ContentView()
}

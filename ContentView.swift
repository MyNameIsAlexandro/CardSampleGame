import SwiftUI

struct ContentView: View {
    @State private var showingGame = false
    @State private var showingRules = false
    @State private var selectedCharacterIndex = 0
    @StateObject private var gameState = GameState(players: [])

    let characters = SampleCards.createCharacterDeck()

    var body: some View {
        NavigationView {
            if !showingGame {
                characterSelectionView
            } else {
                GameBoardView(gameState: gameState)
            }
        }
    }

    var characterSelectionView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Scrollable content
                ScrollView {
                    VStack(spacing: 20) {
                        // Header with rules button
                        HStack {
                            Text(L10n.gameTitle.localized)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            Spacer()
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
                                    .frame(width: min(geometry.size.width * 0.65, 240))
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(height: 280)

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

                    Button(action: startGame) {
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
    }

    func startGame() {
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

        // Build player's deck
        player.deck = SampleCards.createFullDeck()
        player.shuffleDeck()

        // Initialize game state
        gameState.players = [player]
        gameState.encounterDeck = SampleCards.createEncounterDeck()
        gameState.encounterDeck.shuffle()

        gameState.startGame()
        showingGame = true
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

#Preview {
    ContentView()
}

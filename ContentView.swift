import SwiftUI

struct ContentView: View {
    @State private var showingGame = false
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
        VStack(spacing: 20) {
            Text("Card Adventure Game")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()

            Text("Select Your Character")
                .font(.title2)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(Array(characters.enumerated()), id: \.element.id) { index, character in
                        CardView(
                            card: character,
                            isSelected: selectedCharacterIndex == index,
                            onTap: {
                                selectedCharacterIndex = index
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 350)

            // Character stats
            if selectedCharacterIndex < characters.count {
                let character = characters[selectedCharacterIndex]
                VStack(alignment: .leading, spacing: 12) {
                    Text("Character Stats")
                        .font(.headline)

                    Text(character.description)
                        .font(.body)
                        .foregroundColor(.secondary)

                    HStack(spacing: 20) {
                        if let health = character.health {
                            StatDisplay(icon: "heart.fill", label: "Health", value: health, color: .red)
                        }
                        if let power = character.power {
                            StatDisplay(icon: "sword.fill", label: "Power", value: power, color: .orange)
                        }
                        if let defense = character.defense {
                            StatDisplay(icon: "shield.fill", label: "Defense", value: defense, color: .blue)
                        }
                    }

                    if !character.abilities.isEmpty {
                        Text("Abilities")
                            .font(.headline)
                            .padding(.top, 8)

                        ForEach(character.abilities) { ability in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ability.name)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                Text(ability.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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

            Spacer()

            Button(action: startGame) {
                Text("Start Adventure")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding()
        }
        .navigationBarHidden(true)
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

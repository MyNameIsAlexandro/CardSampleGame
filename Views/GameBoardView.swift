import SwiftUI

struct GameBoardView: View {
    @StateObject var gameState: GameState
    @State private var selectedCard: Card?
    @State private var showingDiceRoll = false

    var body: some View {
        VStack(spacing: 0) {
            // Game status bar
            HStack {
                Text(L10n.turnLabel.localized(with: gameState.turnNumber))
                    .font(.headline)

                Spacer()

                Text(phaseText)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(phaseColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)

                Spacer()

                Button(action: {
                    gameState.nextPhase()
                }) {
                    Text(L10n.buttonNextPhase.localized)
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .shadow(radius: 2)

            // Main game area
            ScrollView {
                VStack(spacing: 20) {
                    // Active encounter
                    if let encounter = gameState.activeEncounter {
                        VStack {
                            Text(L10n.encounterActive.localized)
                                .font(.title2)
                                .fontWeight(.bold)

                            CardView(card: encounter)
                                .padding()

                            HStack(spacing: 16) {
                                Button(action: {
                                    rollDice()
                                }) {
                                    Label(L10n.buttonRollDice.localized, systemImage: "dice.fill")
                                        .padding()
                                        .background(Color.orange)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }

                                if let roll = gameState.diceRoll {
                                    Text(L10n.diceResult.localized(with: roll))
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                    } else if gameState.currentPhase == .exploration {
                        Button(action: {
                            gameState.drawEncounter()
                        }) {
                            VStack {
                                Image(systemName: "questionmark.circle.fill")
                                    .font(.system(size: 60))
                                Text(L10n.buttonExplore.localized)
                                    .font(.title2)
                            }
                            .frame(width: 200, height: 200)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(12)
                        }
                    }

                    // Encounter deck info
                    HStack(spacing: 20) {
                        DeckPileView(
                            title: L10n.deckEncounters.localized,
                            count: gameState.encounterDeck.count,
                            color: .red
                        )

                        DeckPileView(
                            title: L10n.deckLocations.localized,
                            count: gameState.locationDeck.count,
                            color: .teal
                        )
                    }
                }
                .padding()
            }

            Divider()

            // Current player's hand
            PlayerHandView(
                player: gameState.currentPlayer,
                selectedCard: $selectedCard,
                onCardPlay: { card in
                    gameState.currentPlayer.playCard(card)
                }
            )
            .frame(maxHeight: 450)
        }
        .alert(L10n.diceRollTitle.localized, isPresented: $showingDiceRoll) {
            Button(L10n.buttonOk.localized, role: .cancel) { }
        } message: {
            if let roll = gameState.diceRoll {
                Text(L10n.diceRollMessage.localized(with: roll))
            }
        }
    }

    var phaseText: String {
        switch gameState.currentPhase {
        case .setup: return L10n.phaseSetup.localized
        case .exploration: return L10n.phaseExploration.localized
        case .encounter: return L10n.phaseEncounter.localized
        case .combat: return L10n.phaseCombat.localized
        case .endTurn: return L10n.phaseEndTurn.localized
        case .gameOver: return L10n.phaseGameOver.localized
        }
    }

    var phaseColor: Color {
        switch gameState.currentPhase {
        case .setup: return .gray
        case .exploration: return .blue
        case .encounter: return .orange
        case .combat: return .red
        case .endTurn: return .green
        case .gameOver: return .black
        }
    }

    func rollDice() {
        _ = gameState.rollDice(sides: 6, count: 1)
        showingDiceRoll = true
    }
}

struct DeckPileView: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        VStack {
            ZStack {
                ForEach(0..<min(count, 3), id: \.self) { index in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.7))
                        .frame(width: 80, height: 120)
                        .offset(x: CGFloat(index) * 2, y: CGFloat(index) * -2)
                }
            }

            Text(title)
                .font(.caption)
                .fontWeight(.bold)
            Text(L10n.deckCards.localized(with: count))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

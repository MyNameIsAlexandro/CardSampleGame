import SwiftUI

struct PlayerHandView: View {
    @ObservedObject var player: Player
    @Binding var selectedCard: Card?
    var onCardPlay: ((Card) -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            // Player info
            HStack {
                VStack(alignment: .leading) {
                    Text(player.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("\(player.health) / \(player.maxHealth)")
                            .font(.headline)
                    }
                }

                Spacer()

                // Deck info
                VStack(alignment: .trailing, spacing: 4) {
                    Text(L10n.playerDeckRemaining.localized(with: player.deck.count))
                        .font(.caption)

                    Text(L10n.playerDiscardPile.localized(with: player.discard.count))
                        .font(.caption)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)

            // Hand of cards
            if player.hand.isEmpty {
                Text("No cards in hand")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(player.hand) { card in
                            CardView(
                                card: card,
                                isSelected: selectedCard?.id == card.id,
                                onTap: {
                                    if selectedCard?.id == card.id {
                                        selectedCard = nil
                                    } else {
                                        selectedCard = card
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // Action buttons
            if let selected = selectedCard {
                HStack(spacing: 16) {
                    Button(action: {
                        onCardPlay?(selected)
                        selectedCard = nil
                    }) {
                        Label("Play Card", systemImage: "play.fill")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }

                    Button(action: {
                        selectedCard = nil
                    }) {
                        Label("Cancel", systemImage: "xmark")
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

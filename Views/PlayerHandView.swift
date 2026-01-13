import SwiftUI

struct PlayerHandView: View {
    @ObservedObject var player: Player
    @Binding var selectedCard: Card?
    var onCardPlay: ((Card) -> Void)?

    var body: some View {
        VStack(spacing: 4) {
            // Compact deck info
            HStack(spacing: 16) {
                Text(player.name)
                    .font(.caption)
                    .fontWeight(.bold)

                Spacer()

                // Deck count
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.caption2)
                    Text("\(player.deck.count)")
                        .font(.caption2)
                }
                .foregroundColor(.blue)

                // Discard count
                HStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                        .font(.caption2)
                    Text("\(player.discard.count)")
                        .font(.caption2)
                }
                .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color(UIColor.secondarySystemBackground))

            // Hand of cards
            if player.hand.isEmpty {
                Text("Нет карт в руке")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(player.hand) { card in
                            HandCardView(
                                card: card,
                                isSelected: selectedCard?.id == card.id,
                                onTap: {
                                    if selectedCard?.id == card.id {
                                        onCardPlay?(card)
                                        selectedCard = nil
                                    } else {
                                        selectedCard = card
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

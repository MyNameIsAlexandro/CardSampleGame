import SwiftUI
import TwilightEngine

struct PlayerHandView: View {
    @ObservedObject var engine: TwilightGameEngine
    @Binding var selectedCard: Card?
    var onCardPlay: ((Card) -> Void)?

    var body: some View {
        VStack(spacing: 4) {
            // Play card button (shown when card is selected)
            if let selected = selectedCard {
                HStack(spacing: 12) {
                    Button(action: {
                        onCardPlay?(selected)
                        selectedCard = nil
                    }) {
                        Label(L10n.combatPlayCard.localized, systemImage: "play.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.green)
                            .cornerRadius(8)
                    }

                    Button(action: {
                        selectedCard = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color(UIColor.tertiarySystemBackground))
            }

            // Compact deck info
            HStack(spacing: 16) {
                Text(engine.playerName)
                    .font(.caption)
                    .fontWeight(.bold)

                Spacer()

                // Deck count
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.caption2)
                    Text("\(engine.playerDeck.count)")
                        .font(.caption2)
                }
                .foregroundColor(.blue)

                // Discard count
                HStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                        .font(.caption2)
                    Text("\(engine.playerDiscard.count)")
                        .font(.caption2)
                }
                .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color(UIColor.secondarySystemBackground))

            // Hand of cards
            if engine.playerHand.isEmpty {
                Text(L10n.noCardsInHand.localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(engine.playerHand) { card in
                            HandCardView(
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
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

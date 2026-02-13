/// Файл: Views/PlayerHandView.swift
/// Назначение: Содержит реализацию файла PlayerHandView.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine

/// Панель руки игрока в бою: выбор карты, быстрые счетчики и play-action.
struct PlayerHandView: View {
    @ObservedObject var vm: GameEngineObservable
    @Binding var selectedCard: Card?
    var onCardPlay: ((Card) -> Void)?

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            // Play card button (shown when card is selected)
            if let selected = selectedCard {
                HStack(spacing: Spacing.md) {
                    Button(action: {
                        onCardPlay?(selected)
                        selectedCard = nil
                    }) {
                        Label(L10n.combatPlayCard.localized, systemImage: "play.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                            .background(AppColors.success)
                            .cornerRadius(CornerRadius.md)
                    }

                    Button(action: {
                        selectedCard = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(AppColors.secondary)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xxs)
                .background(AppColors.backgroundTertiary)
            }

            // Compact deck info
            HStack(spacing: Spacing.lg) {
                Text(vm.engine.player.name)
                    .font(.caption)
                    .fontWeight(.bold)

                Spacer()

                // Deck count
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.caption2)
                    Text("\(vm.engine.deck.playerDeck.count)")
                        .font(.caption2)
                }
                .foregroundColor(AppColors.primary)

                // Discard count
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "trash.fill")
                        .font(.caption2)
                    Text("\(vm.engine.deck.playerDiscard.count)")
                        .font(.caption2)
                }
                .foregroundColor(AppColors.secondary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xxs)
            .background(AppColors.cardBackground)

            // Hand of cards
            if vm.engine.deck.playerHand.isEmpty {
                Text(L10n.noCardsInHand.localized)
                    .font(.caption)
                    .foregroundColor(AppColors.muted)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(vm.engine.deck.playerHand) { card in
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
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                }
            }
        }
    }
}

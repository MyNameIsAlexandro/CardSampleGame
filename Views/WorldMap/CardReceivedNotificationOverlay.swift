/// Файл: Views/WorldMap/CardReceivedNotificationOverlay.swift
/// Назначение: Содержит реализацию файла CardReceivedNotificationOverlay.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI

struct CardReceivedNotificationOverlay: View {
    @Binding var isPresented: Bool
    let cardNames: [String]

    var body: some View {
        ZStack {
            Color.black.opacity(Opacity.medium)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            VStack(spacing: Spacing.xl) {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(size: Sizes.iconHero))
                        .foregroundColor(AppColors.faith)

                    Text(L10n.cardsReceived.localized)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text(L10n.addedToDeck.localized)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(Opacity.high))
                }

                VStack(spacing: Spacing.md) {
                    ForEach(cardNames, id: \.self) { cardName in
                        HStack {
                            Image(systemName: "rectangle.stack.badge.plus")
                                .foregroundColor(AppColors.faith)
                            Text(cardName)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.smd)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(AppColors.dark.opacity(Opacity.mediumHigh))
                        )
                    }
                }

                Button(action: dismiss) {
                    Text(L10n.buttonGreat.localized)
                        .font(.headline)
                        .foregroundColor(AppColors.backgroundSystem)
                        .frame(minWidth: Sizes.buttonMinWidth)
                        .padding()
                        .background(AppColors.primary)
                        .cornerRadius(CornerRadius.lg)
                }
            }
            .padding(Spacing.xxl)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.xxl)
                    .fill(AppColors.backgroundSystem.opacity(Opacity.almostOpaque))
                    .shadow(radius: Spacing.xl)
            )
            .transition(.scale.combined(with: .opacity))
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: AnimationDuration.slow)) {
            isPresented = false
        }
    }
}

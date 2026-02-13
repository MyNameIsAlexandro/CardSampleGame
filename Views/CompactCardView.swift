/// Файл: Views/CompactCardView.swift
/// Назначение: Содержит реализацию файла CompactCardView.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine

/// Компактная карточка для экранов выбора (герой/сущность).
/// Использует единый `Card`->UI mapping из `CardPresentation.swift`.
struct CompactCardView: View {
    let card: Card
    var isSelected: Bool = false
    var onTap: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Text(card.name)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(card.uiHeaderColor)

            ZStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(
                                colors: [
                                    card.uiHeaderColor.opacity(Opacity.light),
                                    card.uiHeaderColor.opacity(Opacity.mediumHigh),
                                ]
                            ),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Image(systemName: card.uiIcon)
                    .font(.system(size: Sizes.iconRegion + Spacing.smd))
                    .foregroundColor(.white.opacity(Opacity.almostOpaque))
            }
            .frame(height: Sizes.cardHeightMedium)

            VStack(spacing: Spacing.sm) {
                Text(card.uiLocalizedType)
                    .font(.caption)
                    .foregroundColor(AppColors.muted)

                HStack(spacing: Spacing.xl) {
                    if let health = card.health {
                        VStack(spacing: Spacing.xxxs) {
                            Image(systemName: "heart.fill")
                                .font(.title3)
                                .foregroundColor(AppColors.health)
                            Text("\(health)")
                                .font(.headline)
                                .fontWeight(.bold)
                            Text(L10n.cardStatHealth.localized)
                                .font(.system(size: Sizes.tinyCaption))
                                .foregroundColor(AppColors.muted)
                        }
                    }
                    if let power = card.power {
                        VStack(spacing: Spacing.xxxs) {
                            Image(systemName: "bolt.fill")
                                .font(.title3)
                                .foregroundColor(AppColors.power)
                            Text("\(power)")
                                .font(.headline)
                                .fontWeight(.bold)
                            Text(L10n.cardStatStrength.localized)
                                .font(.system(size: Sizes.tinyCaption))
                                .foregroundColor(AppColors.muted)
                        }
                    }
                    if let defense = card.defense {
                        VStack(spacing: Spacing.xxxs) {
                            Image(systemName: "shield.fill")
                                .font(.title3)
                                .foregroundColor(AppColors.defense)
                            Text("\(defense)")
                                .font(.headline)
                                .fontWeight(.bold)
                            Text(L10n.cardStatDefense.localized)
                                .font(.system(size: Sizes.tinyCaption))
                                .foregroundColor(AppColors.muted)
                        }
                    }
                }

                Circle()
                    .fill(card.uiRarityColor)
                    .frame(width: Spacing.xs, height: Spacing.xs)
            }
            .padding(.vertical, Spacing.smd)
            .frame(maxWidth: .infinity)
            .background(AppColors.cardBackground)
        }
        .frame(height: Sizes.cardHeightMedium + Sizes.cardHeightMedium)
        .background(AppColors.backgroundSystem)
        .cornerRadius(CornerRadius.xl)
        .shadow(
            color: isSelected ? card.uiHeaderColor.opacity(Opacity.medium) : .black.opacity(Opacity.faint),
            radius: isSelected ? 10 : 5
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .stroke(isSelected ? card.uiHeaderColor : Color.clear, lineWidth: 3)
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: AnimationDuration.slow, dampingFraction: 0.7), value: isSelected)
        .onTapGesture {
            onTap?()
        }
    }
}

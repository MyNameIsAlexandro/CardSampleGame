/// Файл: Views/HandCardView.swift
/// Назначение: Содержит реализацию файла HandCardView.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine

/// Мини-карточка для руки игрока в бою.
/// Изолирована от логики движка и рендерит только UI-представление.
struct HandCardView: View {
    let card: Card
    var isSelected: Bool = false
    var onTap: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Text(card.name)
                .font(.system(size: Spacing.smd))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xxxs)
                .padding(.horizontal, Spacing.xxxs)
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
                    .font(.system(size: Sizes.iconLarge))
                    .foregroundColor(.white.opacity(Opacity.almostOpaque))
            }
            .frame(height: Sizes.iconHero + 5)

            VStack(spacing: Spacing.xxxs) {
                if let cost = card.cost {
                    HStack(spacing: Spacing.xxxs) {
                        Image(systemName: "star.fill")
                            .font(.system(size: Spacing.sm))
                            .foregroundColor(AppColors.faith)
                        Text("\(cost)")
                            .font(.system(size: Sizes.tinyCaption))
                            .fontWeight(.bold)
                    }
                }
                if let power = card.power {
                    HStack(spacing: Spacing.xxxs) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: Spacing.sm))
                            .foregroundColor(AppColors.health)
                        Text("\(power)")
                            .font(.system(size: Sizes.tinyCaption))
                            .fontWeight(.bold)
                    }
                }
                if let defense = card.defense {
                    HStack(spacing: Spacing.xxxs) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: Spacing.sm))
                            .foregroundColor(AppColors.defense)
                        Text("\(defense)")
                            .font(.system(size: Sizes.tinyCaption))
                            .fontWeight(.bold)
                    }
                }
            }
            .padding(.vertical, Spacing.xxxs)
            .frame(maxWidth: .infinity)
            .background(AppColors.cardBackground)
        }
        .frame(width: Sizes.cardWidthSmall + 5, height: Sizes.cardHeightSmall + Spacing.lg - 1)
        .background(AppColors.backgroundSystem)
        .cornerRadius(CornerRadius.md)
        .shadow(
            color: isSelected ? card.uiHeaderColor.opacity(Opacity.mediumHigh) : .black.opacity(Opacity.faint),
            radius: isSelected ? 6 : 3
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(isSelected ? card.uiHeaderColor : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: AnimationDuration.fast + 0.05, dampingFraction: 0.7), value: isSelected)
        .onTapGesture {
            onTap?()
        }
    }
}

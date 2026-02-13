/// Файл: Views/CardView.swift
/// Назначение: Содержит реализацию файла CardView.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine

/// Подробное представление карты с полным описанием, статами и редкостью.
struct CardView: View {
    let card: Card
    var isSelected: Bool = false
    var onTap: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack {
                    Text(card.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Spacer()
                    if let cost = card.cost {
                        Text("\(cost)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.faith)
                            .padding(Spacing.xs)
                            .background(Circle().fill(AppColors.backgroundSystem.opacity(Opacity.mediumHigh)))
                    }
                }

                Text(card.uiLocalizedType)
                    .font(.caption)
                    .foregroundColor(.white.opacity(Opacity.high))
            }
            .padding(Spacing.md)
            .background(card.uiHeaderColor)

            ZStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [card.uiColor.opacity(Opacity.light), card.uiColor]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                VStack {
                    Image(systemName: card.uiIcon)
                        .font(.system(size: Sizes.iconRegion))
                        .foregroundColor(.white.opacity(Opacity.almostOpaque))
                }
            }
            .frame(height: Sizes.cardHeightSmall + Spacing.xl)

            if hasStats {
                HStack(spacing: Spacing.lg) {
                    if let power = card.power {
                        CardStatBadge(icon: "bolt.fill", value: power, color: AppColors.power)
                    }
                    if let defense = card.defense {
                        CardStatBadge(icon: "shield.fill", value: defense, color: AppColors.defense)
                    }
                    if let health = card.health {
                        CardStatBadge(icon: "heart.fill", value: health, color: AppColors.health)
                    }
                    Spacer()
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(AppColors.backgroundSystem.opacity(Opacity.faint))
            }

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(card.description)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(card.abilities) { ability in
                        VStack(alignment: .leading, spacing: Spacing.xxxs) {
                            Text(ability.name)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.power)
                            Text(ability.description)
                                .font(.caption2)
                                .foregroundColor(AppColors.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, Spacing.xxs)
                    }

                    if !card.traits.isEmpty {
                        HStack {
                            ForEach(card.traits, id: \.self) { trait in
                                Text(trait.localized)
                                    .font(.caption2)
                                    .padding(.horizontal, Spacing.xs)
                                    .padding(.vertical, Spacing.xxxs)
                                    .background(Capsule().fill(AppColors.secondary.opacity(Opacity.light)))
                            }
                        }
                        .padding(.top, Spacing.xxs)
                    }
                }
                .padding(Spacing.md)
            }

            HStack {
                Spacer()
                Circle()
                    .fill(card.uiRarityColor)
                    .frame(width: Spacing.sm, height: Spacing.sm)
                Text(card.uiLocalizedRarity)
                    .font(.caption2)
                    .foregroundColor(AppColors.muted)
            }
            .padding(Spacing.sm)
        }
        .frame(height: Sizes.cardHeightLarge + Sizes.cardHeightMedium)
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.lg)
        .shadow(isSelected ? AppShadows.lg : AppShadows.md)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(isSelected ? AppColors.primary : .clear, lineWidth: 3)
        )
        .onTapGesture {
            onTap?()
        }
    }

    var hasStats: Bool {
        card.power != nil || card.defense != nil || card.health != nil
    }
}

/// Небольшой бейдж характеристики карты (атака/защита/здоровье).
struct CardStatBadge: View {
    let icon: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(.caption)
            Text("\(value)")
                .font(.caption)
                .fontWeight(.bold)
        }
        .foregroundColor(color)
    }
}

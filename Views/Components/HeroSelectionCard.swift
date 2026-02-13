/// Файл: Views/Components/HeroSelectionCard.swift
/// Назначение: Содержит реализацию файла HeroSelectionCard.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine

// MARK: - Hero Selection Card (data-driven)

struct HeroSelectionCard: View {
    let hero: HeroDefinition
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Hero icon/name header
            VStack(spacing: Spacing.xxs) {
                Image(systemName: hero.icon)
                    .font(.system(size: Sizes.iconXL))

                Text(hero.name.localized)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
            .background(AppColors.dark.opacity(Opacity.high))
            .foregroundColor(.white)

            // Stats
            Text(L10n.cardTypeCharacter.localized)
                .font(.caption)
                .foregroundColor(AppColors.muted)

            HStack(spacing: Spacing.md) {
                StatMini(icon: "heart.fill", value: hero.baseStats.health, color: AppColors.health)
                StatMini(icon: "bolt.fill", value: hero.baseStats.strength, color: AppColors.power)
                StatMini(icon: "shield.fill", value: hero.baseStats.constitution, color: AppColors.defense)
            }
            .padding(.bottom, Spacing.sm)
        }
        .background(AppColors.backgroundSystem)
        .cornerRadius(CornerRadius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .stroke(isSelected ? AppColors.primary : AppColors.secondary.opacity(Opacity.light), lineWidth: isSelected ? 3 : 1)
        )
        .shadow(radius: isSelected ? 8 : 2)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .onTapGesture {
            onTap()
        }
    }
}

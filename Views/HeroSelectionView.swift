import SwiftUI
import TwilightEngine

/// Экран выбора героя при начале новой игры
/// Герои загружаются из HeroRegistry (data-driven)
struct HeroSelectionView: View {
    let onHeroSelected: (String) -> Void  // Возвращает heroId

    @State private var selectedHeroId: String?

    /// Все доступные герои из реестра
    private var availableHeroes: [HeroDefinition] {
        HeroRegistry.shared.availableHeroes()
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Заголовок
                VStack(spacing: Spacing.sm) {
                    Text("Выберите героя")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Каждый герой имеет уникальные характеристики и способности")
                        .font(.subheadline)
                        .foregroundColor(AppColors.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, Spacing.xl)
                .padding(.bottom, Spacing.lg)

                // Список героев
                ScrollView {
                    VStack(spacing: Spacing.md) {
                        ForEach(availableHeroes, id: \.id) { hero in
                            HeroCard(
                                hero: hero,
                                isSelected: selectedHeroId == hero.id
                            ) {
                                withAnimation(.easeInOut(duration: AnimationDuration.fast)) {
                                    selectedHeroId = hero.id
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, Sizes.cardHeightSmall)  // Место для кнопки
                }

                Spacer()

                // Кнопка подтверждения
                VStack(spacing: Spacing.sm) {
                    if let heroId = selectedHeroId,
                       let hero = HeroRegistry.shared.hero(id: heroId) {
                        Button(action: {
                            onHeroSelected(heroId)
                        }) {
                            HStack {
                                Text(hero.icon)
                                Text("Начать игру за \(hero.name.localized)")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.primary)
                            .foregroundColor(.white)
                            .cornerRadius(CornerRadius.lg)
                        }
                        .padding(.horizontal)
                    } else {
                        Text("Выберите героя")
                            .foregroundColor(AppColors.muted)
                            .padding()
                    }
                }
                .padding(.bottom, Spacing.xl)
                .background(
                    Color(UIColor.systemBackground)
                        .shadow(radius: 5)
                )
            }
            .background(AppColors.cardBackground)
            .navigationBarHidden(true)
        }
    }
}

/// Карточка героя
struct HeroCard: View {
    let hero: HeroDefinition
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Заголовок
            HStack {
                Text(hero.icon)
                    .font(.title)

                VStack(alignment: .leading, spacing: Spacing.xxxs) {
                    Text(hero.name.localized)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(hero.description.localized)
                        .font(.caption)
                        .foregroundColor(AppColors.muted)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(AppColors.primary)
                }
            }

            // Характеристики
            let stats = hero.baseStats
            HStack(spacing: Spacing.lg) {
                StatBadge(icon: "heart.fill", value: stats.health, label: "HP", color: AppColors.health)
                StatBadge(icon: "hand.raised.fill", value: stats.strength, label: "Сила", color: AppColors.power)
                StatBadge(icon: "sparkles", value: stats.faith, label: "Вера", color: AppColors.faith)
                StatBadge(icon: "brain.head.profile", value: stats.intelligence, label: "Инт", color: AppColors.dark)
            }

            // Особая способность
            HStack(spacing: Spacing.sm) {
                Image(systemName: "star.fill")
                    .foregroundColor(AppColors.faith)
                    .font(.caption)

                Text(hero.specialAbility.description.localized)
                    .font(.caption)
                    .foregroundColor(AppColors.muted)
            }
            .padding(Spacing.sm)
            .background(AppColors.faith.opacity(0.1))
            .cornerRadius(CornerRadius.md)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(Color(UIColor.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(isSelected ? AppColors.primary : AppColors.secondary.opacity(Opacity.light), lineWidth: isSelected ? 3 : 1)
                )
        )
        .onTapGesture {
            onTap()
        }
    }
}

/// Бейдж характеристики
struct StatBadge: View {
    let icon: String
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.xxxs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)

            Text("\(value)")
                .font(.caption)
                .fontWeight(.bold)

            Text(label)
                .font(.system(size: Spacing.sm))
                .foregroundColor(AppColors.muted)
        }
        .frame(minWidth: Sizes.iconXL)
    }
}

#Preview {
    HeroSelectionView { heroId in
        print("Selected: \(heroId)")
    }
}

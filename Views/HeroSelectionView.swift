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
                VStack(spacing: 8) {
                    Text("Выберите героя")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Каждый герой имеет уникальные характеристики и способности")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Список героев
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(availableHeroes, id: \.id) { hero in
                            HeroCard(
                                hero: hero,
                                isSelected: selectedHeroId == hero.id
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedHeroId = hero.id
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100)  // Место для кнопки
                }

                Spacer()

                // Кнопка подтверждения
                VStack(spacing: 8) {
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
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    } else {
                        Text("Выберите героя")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .padding(.bottom, 20)
                .background(
                    Color(UIColor.systemBackground)
                        .shadow(radius: 5)
                )
            }
            .background(Color(UIColor.secondarySystemBackground))
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
        VStack(alignment: .leading, spacing: 12) {
            // Заголовок
            HStack {
                Text(hero.icon)
                    .font(.title)

                VStack(alignment: .leading, spacing: 2) {
                    Text(hero.name.localized)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(hero.description.localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }

            // Характеристики
            let stats = hero.baseStats
            HStack(spacing: 16) {
                StatBadge(icon: "heart.fill", value: stats.health, label: "HP", color: .red)
                StatBadge(icon: "hand.raised.fill", value: stats.strength, label: "Сила", color: .orange)
                StatBadge(icon: "sparkles", value: stats.faith, label: "Вера", color: .yellow)
                StatBadge(icon: "brain.head.profile", value: stats.intelligence, label: "Инт", color: .purple)
            }

            // Особая способность
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)

                Text(hero.specialAbility.description.localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 3 : 1)
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
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)

            Text("\(value)")
                .font(.caption)
                .fontWeight(.bold)

            Text(label)
                .font(.system(size: 8))
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 40)
    }
}

#Preview {
    HeroSelectionView { heroId in
        print("Selected: \(heroId)")
    }
}

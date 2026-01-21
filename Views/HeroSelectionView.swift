import SwiftUI

/// Экран выбора класса героя при начале новой игры
struct HeroSelectionView: View {
    let onHeroSelected: (HeroClass) -> Void

    @State private var selectedClass: HeroClass?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Заголовок
                VStack(spacing: 8) {
                    Text(L10n.heroSelectTitle.localized)
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text(L10n.heroSelectSubtitle.localized)
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
                        ForEach(HeroClass.allCases, id: \.self) { heroClass in
                            HeroClassCard(
                                heroClass: heroClass,
                                isSelected: selectedClass == heroClass
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedClass = heroClass
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
                    if let selected = selectedClass {
                        Button(action: {
                            onHeroSelected(selected)
                        }) {
                            HStack {
                                Text(selected.icon)
                                Text(L10n.heroStartGame.localized(with: selected.rawValue))
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
                        Text(L10n.heroSelectClass.localized)
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

/// Карточка класса героя
struct HeroClassCard: View {
    let heroClass: HeroClass
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Заголовок
            HStack {
                Text(heroClass.icon)
                    .font(.title)

                VStack(alignment: .leading, spacing: 2) {
                    Text(heroClass.rawValue)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(heroClass.description)
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
            let stats = heroClass.baseStats
            HStack(spacing: 16) {
                StatBadge(icon: "heart.fill", value: stats.health, label: "HP", color: .red)
                StatBadge(icon: "hand.raised.fill", value: stats.strength, label: L10n.cardStatStrength.localized, color: .orange)
                StatBadge(icon: "sparkles", value: stats.faith, label: L10n.tmResourceFaith.localized, color: .yellow)
                StatBadge(icon: "brain.head.profile", value: stats.intelligence, label: L10n.statIntelligence.localized, color: .purple)
            }

            // Особая способность
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)

                Text(heroClass.specialAbility)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(8)

            // Стартовый путь
            HStack(spacing: 8) {
                Image(systemName: "rectangle.stack.fill")
                    .foregroundColor(deckPathColor(heroClass.startingDeckType))
                    .font(.caption)

                Text(L10n.heroPath.localized(with: deckPathName(heroClass.startingDeckType)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
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

    func deckPathName(_ path: DeckPath) -> String {
        switch path {
        case .light: return L10n.pathLight.localized
        case .dark: return L10n.pathDark.localized
        case .balance: return L10n.pathBalance.localized
        }
    }

    func deckPathColor(_ path: DeckPath) -> Color {
        switch path {
        case .light: return .yellow
        case .dark: return .purple
        case .balance: return .gray
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
    HeroSelectionView { heroClass in
        print("Selected: \(heroClass.rawValue)")
    }
}

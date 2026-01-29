import SwiftUI
import TwilightEngine

/// Card component for enemy selection in Battle Arena mode
struct EnemySelectionCard: View {
    let enemy: EnemyDefinition
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Enemy type icon
            ZStack {
                Circle()
                    .fill(enemyTypeColor.opacity(Opacity.faint))
                    .frame(width: Sizes.touchTarget, height: Sizes.touchTarget)
                Image(systemName: enemyTypeIcon)
                    .font(.title3)
                    .foregroundColor(enemyTypeColor)
            }

            // Info
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(enemy.name.resolved)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: Spacing.md) {
                    Label("\(enemy.health)", systemImage: "heart.fill")
                        .foregroundColor(AppColors.health)
                    Label("\(enemy.power)", systemImage: "bolt.fill")
                        .foregroundColor(AppColors.power)
                    if let will = enemy.will, will > 0 {
                        Label("\(will)", systemImage: "sparkle")
                            .foregroundColor(AppColors.spirit)
                    }
                }
                .font(.caption)
            }

            Spacer()

            // Difficulty stars
            HStack(spacing: Spacing.xxxs) {
                ForEach(0..<enemy.difficulty, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(AppColors.faith)
                }
            }
        }
        .padding(Spacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(isSelected ? AppColors.danger : Color.clear, lineWidth: 2)
        )
        .onTapGesture { onTap() }
    }

    private var enemyTypeIcon: String {
        switch enemy.enemyType {
        case .beast: return "pawprint.fill"
        case .spirit: return "wind"
        case .undead: return "flame.fill"
        case .demon: return "tornado"
        case .human: return "person.fill"
        case .boss: return "crown.fill"
        }
    }

    private var enemyTypeColor: Color {
        switch enemy.enemyType {
        case .beast: return .brown
        case .spirit: return .cyan
        case .undead: return .gray
        case .demon: return .purple
        case .human: return .orange
        case .boss: return AppColors.danger
        }
    }
}

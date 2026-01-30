import SwiftUI
import TwilightEngine

/// Dual health bar for enemies: red HP bar + blue Spirit/Will bar (if enemy has will).
/// Engine-First: reads from CombatState or direct engine properties.
struct DualHealthBar: View {
    let currentHP: Int
    let maxHP: Int
    let currentWill: Int
    let maxWill: Int

    /// Whether this enemy has a Spirit track
    var hasSpiritTrack: Bool {
        maxWill > 0
    }

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            // Body (HP) bar
            healthBar(
                label: "HP",
                current: currentHP,
                max: maxHP,
                color: AppColors.health,
                icon: "heart.fill"
            )

            // Spirit (Will) bar — only if enemy has will
            if hasSpiritTrack {
                healthBar(
                    label: "WP",
                    current: currentWill,
                    max: maxWill,
                    color: AppColors.spirit,
                    icon: "sparkles"
                )
            }
        }
    }

    private func healthBar(label: String, current: Int, max: Int, color: Color, icon: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: Sizes.iconSmall)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    Capsule()
                        .fill(color.opacity(Opacity.faint))

                    // Fill
                    Capsule()
                        .fill(color)
                        .frame(width: max > 0 ? geo.size.width * CGFloat(current) / CGFloat(max) : 0)
                        .animation(.easeInOut(duration: AnimationDuration.normal), value: current)
                }
            }
            .frame(height: Sizes.progressMedium)

            Text("\(current)/\(max)")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(color)
                .frame(width: Sizes.healthBarLabel, alignment: .trailing)
        }
    }
}

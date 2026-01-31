import SwiftUI
import TwilightEngine

/// Dual health bar for enemies: red HP bar + blue Spirit/Will bar (if enemy has will).
/// Engine-First: reads from CombatState or direct engine properties.
struct DualHealthBar: View {
    let currentHP: Int
    let maxHP: Int
    let currentWill: Int
    let maxWill: Int

    @State private var ghostHP: Int?
    @State private var ghostWill: Int?
    @State private var prevHP: Int?
    @State private var prevWill: Int?

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
                icon: "heart.fill",
                ghostValue: ghostHP
            )

            // Spirit (Will) bar — only if enemy has will
            if hasSpiritTrack {
                healthBar(
                    label: "WP",
                    current: currentWill,
                    max: maxWill,
                    color: AppColors.spirit,
                    icon: "sparkles",
                    ghostValue: ghostWill
                )
            }
        }
        .onAppear {
            prevHP = currentHP
            prevWill = currentWill
        }
        .onChange(of: currentHP) { newValue in
            if let old = prevHP, newValue < old {
                ghostHP = old
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        ghostHP = nil
                    }
                }
            }
            prevHP = newValue
        }
        .onChange(of: currentWill) { newValue in
            if let old = prevWill, newValue < old {
                ghostWill = old
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        ghostWill = nil
                    }
                }
            }
            prevWill = newValue
        }
    }

    private func healthBar(label: String, current: Int, max: Int, color: Color, icon: String, ghostValue: Int?) -> some View {
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

                    // Ghost bar (old value lingering)
                    if let ghost = ghostValue {
                        Capsule()
                            .fill(color.opacity(Opacity.light))
                            .frame(width: max > 0 ? geo.size.width * CGFloat(ghost) / CGFloat(max) : 0)
                            .animation(.easeOut(duration: 0.5), value: ghostValue)
                    }

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

import SwiftUI
import TwilightEngine

/// Unified Hero Panel - displays hero stats consistently across all screens
/// Inspired by Arkham Horror LCG investigator cards but with unique Twilight Marches style
/// Engine-First Architecture: reads all data from TwilightGameEngine
struct HeroPanel: View {
    @ObservedObject var engine: TwilightGameEngine

    /// Compact mode for screens with limited space (like combat header)
    var compact: Bool = false

    /// Show hero portrait/avatar
    var showAvatar: Bool = true

    var body: some View {
        if compact {
            compactPanel
        } else {
            fullPanel
        }
    }

    // MARK: - Full Panel (for main screens like WorldMap, RegionDetail)

    var fullPanel: some View {
        HStack(spacing: Spacing.md) {
            // Hero Avatar
            if showAvatar {
                heroAvatar
            }

            // Hero Info
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                // Name and class
                HStack {
                    Text(engine.playerName)
                        .font(.headline)
                        .fontWeight(.bold)
                    Text(heroClass)
                        .font(.caption)
                        .foregroundColor(AppColors.muted)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.xxxs)
                        .background(AppColors.secondary.opacity(Opacity.faint))
                        .cornerRadius(CornerRadius.sm)
                }

                // Stats row
                HStack(spacing: Spacing.md) {
                    // Health
                    statBadge(
                        icon: "heart.fill",
                        value: "\(engine.playerHealth)/\(engine.playerMaxHealth)",
                        color: healthColor,
                        label: nil
                    )

                    // Faith
                    statBadge(
                        icon: "sparkles",
                        value: "\(engine.playerFaith)",
                        color: AppColors.faith,
                        label: nil
                    )

                    // Strength
                    statBadge(
                        icon: "hand.raised.fill",
                        value: "\(engine.playerStrength)",
                        color: AppColors.power,
                        label: nil
                    )

                    // Balance indicator
                    balanceIndicator
                }
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.smd)
        .background(heroPanelBackground)
    }

    // MARK: - Compact Panel (for combat, events with limited space)

    var compactPanel: some View {
        HStack(spacing: Spacing.sm) {
            // Mini avatar
            if showAvatar {
                ZStack {
                    Circle()
                        .fill(balanceGradient)
                        .frame(width: Sizes.iconLarge, height: Sizes.iconLarge)

                    Text(heroInitials)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }

            // Compact stats
            HStack(spacing: Spacing.sm) {
                // Health
                HStack(spacing: Spacing.xxxs) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundColor(AppColors.health)
                    Text("\(engine.playerHealth)")
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                // Faith
                HStack(spacing: Spacing.xxxs) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundColor(AppColors.faith)
                    Text("\(engine.playerFaith)")
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                // Balance (small icon only)
                Image(systemName: balanceIcon)
                    .font(.caption2)
                    .foregroundColor(balanceColor)
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(AppColors.cardBackground.opacity(Opacity.almostOpaque))
        .cornerRadius(CornerRadius.md)
    }

    // MARK: - Hero Avatar

    var heroAvatar: some View {
        ZStack {
            // Background circle with balance gradient
            Circle()
                .fill(balanceGradient)
                .frame(width: Sizes.iconHero, height: Sizes.iconHero)

            // Inner circle
            Circle()
                .fill(Color(UIColor.systemBackground))
                .frame(width: Sizes.touchTarget, height: Sizes.touchTarget)

            // Hero initials or icon
            Text(heroInitials)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(balanceColor)
        }
    }

    // MARK: - Stat Badge

    func statBadge(icon: String, value: String, color: Color, label: String?) -> some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if let label = label {
                    Text(label)
                        .font(.system(size: 9))
                        .foregroundColor(AppColors.muted)
                }
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(color.opacity(0.15))
        .cornerRadius(Spacing.xs)
    }

    // MARK: - Balance Indicator

    var balanceIndicator: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: balanceIcon)
                .font(.caption)
                .foregroundColor(balanceColor)

            Text(balanceText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(balanceColor)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(balanceColor.opacity(0.15))
        .cornerRadius(Spacing.xs)
    }

    // MARK: - Background

    var heroPanelBackground: some View {
        ZStack {
            // Base background
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(AppColors.cardBackground)

            // Subtle balance-colored border
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(balanceColor.opacity(Opacity.light), lineWidth: 1)
        }
    }

    // MARK: - Computed Properties

    var heroClass: String {
        // In data-driven architecture, hero role comes from hero definition
        // For now, return localized default or hero name
        return L10n.heroClassDefault.localized
    }

    var heroInitials: String {
        let name = engine.playerName
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1)) + String(words[1].prefix(1))
        }
        return String(name.prefix(2)).uppercased()
    }

    var healthColor: Color {
        let percentage = Double(engine.playerHealth) / Double(max(engine.playerMaxHealth, 1))
        if percentage > 0.6 {
            return AppColors.success
        } else if percentage > 0.3 {
            return AppColors.warning
        } else {
            return AppColors.danger
        }
    }

    var balanceIcon: String {
        let balance = engine.playerBalance
        if balance >= 70 {
            return "sun.max.fill"      // Light path (70-100)
        } else if balance <= 30 {
            return "moon.fill"          // Dark path (0-30)
        } else {
            return "circle.lefthalf.filled"  // Neutral (30-70)
        }
    }

    var balanceColor: Color {
        let balance = engine.playerBalance
        if balance >= 70 {
            return AppColors.light      // Light path
        } else if balance <= 30 {
            return AppColors.dark       // Dark path
        } else {
            return AppColors.neutral    // Neutral
        }
    }

    var balanceText: String {
        let balance = engine.playerBalance
        if balance >= 70 {
            return L10n.balanceLight.localized
        } else if balance <= 30 {
            return L10n.balanceDark.localized
        } else {
            return L10n.balanceNeutral.localized
        }
    }

    var balanceGradient: LinearGradient {
        let balance = engine.playerBalance
        if balance >= 70 {
            return LinearGradient(
                colors: [AppColors.light.opacity(Opacity.high), AppColors.power.opacity(Opacity.mediumHigh)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if balance <= 30 {
            return LinearGradient(
                colors: [AppColors.dark.opacity(Opacity.high), Color.indigo.opacity(Opacity.mediumHigh)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [AppColors.neutral.opacity(Opacity.mediumHigh), AppColors.neutral.opacity(Opacity.medium)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Preview

struct HeroPanel_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Spacing.xl) {
            // Full panel
            HeroPanel(engine: previewEngine)
                .padding()

            // Compact panel
            HeroPanel(engine: previewEngine, compact: true)
                .padding()

            // Full panel without avatar
            HeroPanel(engine: previewEngine, showAvatar: false)
                .padding()
        }
        .background(Color(UIColor.systemBackground))
    }

    static var previewEngine: TwilightGameEngine {
        let engine = TwilightGameEngine()
        // Preview data would be set here
        return engine
    }
}

import SwiftUI

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
        HStack(spacing: 12) {
            // Hero Avatar
            if showAvatar {
                heroAvatar
            }

            // Hero Info
            VStack(alignment: .leading, spacing: 4) {
                // Name and class
                HStack {
                    Text(engine.playerName)
                        .font(.headline)
                        .fontWeight(.bold)
                    Text(heroClass)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }

                // Stats row
                HStack(spacing: 12) {
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
                        color: .yellow,
                        label: nil
                    )

                    // Strength
                    statBadge(
                        icon: "hand.raised.fill",
                        value: "\(engine.legacyPlayer?.strength ?? 1)",
                        color: .orange,
                        label: nil
                    )

                    // Balance indicator
                    balanceIndicator
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(heroPanelBackground)
    }

    // MARK: - Compact Panel (for combat, events with limited space)

    var compactPanel: some View {
        HStack(spacing: 8) {
            // Mini avatar
            if showAvatar {
                ZStack {
                    Circle()
                        .fill(balanceGradient)
                        .frame(width: 32, height: 32)

                    Text(heroInitials)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }

            // Compact stats
            HStack(spacing: 8) {
                // Health
                HStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundColor(.red)
                    Text("\(engine.playerHealth)")
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                // Faith
                HStack(spacing: 2) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundColor(.yellow)
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
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(UIColor.secondarySystemBackground).opacity(0.9))
        .cornerRadius(8)
    }

    // MARK: - Hero Avatar

    var heroAvatar: some View {
        ZStack {
            // Background circle with balance gradient
            Circle()
                .fill(balanceGradient)
                .frame(width: 50, height: 50)

            // Inner circle
            Circle()
                .fill(Color(UIColor.systemBackground))
                .frame(width: 44, height: 44)

            // Hero initials or icon
            Text(heroInitials)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(balanceColor)
        }
    }

    // MARK: - Stat Badge

    func statBadge(icon: String, value: String, color: Color, label: String?) -> some View {
        HStack(spacing: 4) {
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
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .cornerRadius(6)
    }

    // MARK: - Balance Indicator

    var balanceIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: balanceIcon)
                .font(.caption)
                .foregroundColor(balanceColor)

            Text(balanceText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(balanceColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(balanceColor.opacity(0.15))
        .cornerRadius(6)
    }

    // MARK: - Background

    var heroPanelBackground: some View {
        ZStack {
            // Base background
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))

            // Subtle balance-colored border
            RoundedRectangle(cornerRadius: 12)
                .stroke(balanceColor.opacity(0.3), lineWidth: 1)
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
            return .green
        } else if percentage > 0.3 {
            return .orange
        } else {
            return .red
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
            return .yellow              // Light path
        } else if balance <= 30 {
            return .purple              // Dark path
        } else {
            return .gray                // Neutral
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
                colors: [.yellow.opacity(0.8), .orange.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if balance <= 30 {
            return LinearGradient(
                colors: [.purple.opacity(0.8), .indigo.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [.gray.opacity(0.6), .gray.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Preview

struct HeroPanel_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
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

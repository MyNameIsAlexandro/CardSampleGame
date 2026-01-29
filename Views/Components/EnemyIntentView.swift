import SwiftUI
import TwilightEngine

/// Displays enemy intent (what the enemy will do this turn).
/// Part of Active Defense combat system - shown BEFORE player acts.
struct EnemyIntentView: View {
    let intent: EnemyIntent

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Intent icon
            ZStack {
                Circle()
                    .fill(intentColor.opacity(Opacity.light))
                    .frame(width: Sizes.iconLarge, height: Sizes.iconLarge)

                Image(systemName: intentIcon)
                    .font(.system(size: Sizes.iconSmall))
                    .foregroundColor(intentColor)
            }

            // Intent details
            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(intentTitle)
                    .font(.caption.bold())
                    .foregroundColor(intentColor)

                Text(intent.description)
                    .font(.caption2)
                    .foregroundColor(AppColors.muted)
            }

            Spacer()

            // Value badge (for attack/heal)
            if shouldShowValueBadge {
                Text("\(intent.value)")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(intentColor)
                    .cornerRadius(CornerRadius.sm)
            }
        }
        .padding(Spacing.sm)
        .background(intentColor.opacity(Opacity.faint))
        .cornerRadius(CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .strokeBorder(intentColor.opacity(Opacity.medium), lineWidth: 1)
        )
    }

    // MARK: - Computed Properties

    private var intentIcon: String {
        switch intent.type {
        case .attack: return "burst.fill"
        case .ritual: return "moon.stars.fill"
        case .block: return "shield.fill"
        case .buff: return "arrow.up.circle.fill"
        case .heal: return "heart.fill"
        case .summon: return "person.2.fill"
        }
    }

    private var intentTitle: String {
        switch intent.type {
        case .attack: return L10n.combatIntentAttack.localized
        case .ritual: return L10n.combatIntentRitual.localized
        case .block: return L10n.combatIntentBlock.localized
        case .buff: return L10n.combatIntentBuff.localized
        case .heal: return L10n.combatIntentHeal.localized
        case .summon: return L10n.combatIntentSummon.localized
        }
    }

    private var intentColor: Color {
        switch intent.type {
        case .attack: return AppColors.danger
        case .ritual: return AppColors.resonanceNav
        case .block: return AppColors.defense
        case .buff: return AppColors.warning
        case .heal: return AppColors.success
        case .summon: return AppColors.dark
        }
    }

    private var shouldShowValueBadge: Bool {
        switch intent.type {
        case .attack, .heal: return true
        case .ritual, .block, .buff, .summon: return false
        }
    }
}

/// Compact version of EnemyIntentView for HUD display
struct EnemyIntentBadge: View {
    let intent: EnemyIntent

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: intentIcon)
                .font(.caption)
            Text("\(intent.value)")
                .font(.caption.bold())
        }
        .foregroundColor(.white)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(intentColor)
        .cornerRadius(CornerRadius.sm)
    }

    private var intentIcon: String {
        switch intent.type {
        case .attack: return "burst.fill"
        case .ritual: return "moon.stars.fill"
        case .block: return "shield.fill"
        case .buff: return "arrow.up.circle.fill"
        case .heal: return "heart.fill"
        case .summon: return "person.2.fill"
        }
    }

    private var intentColor: Color {
        switch intent.type {
        case .attack: return AppColors.danger
        case .ritual: return AppColors.resonanceNav
        case .block: return AppColors.defense
        case .buff: return AppColors.warning
        case .heal: return AppColors.success
        case .summon: return AppColors.dark
        }
    }
}

#Preview("Enemy Intent - Attack") {
    VStack(spacing: Spacing.lg) {
        EnemyIntentView(intent: .attack(damage: 8))
        EnemyIntentView(intent: .ritual(resonanceShift: -5))
        EnemyIntentView(intent: .block(reduction: 3))
        EnemyIntentView(intent: .heal(amount: 5))
    }
    .padding()
}

#Preview("Enemy Intent Badge") {
    HStack(spacing: Spacing.md) {
        EnemyIntentBadge(intent: .attack(damage: 8))
        EnemyIntentBadge(intent: .ritual(resonanceShift: -5))
        EnemyIntentBadge(intent: .heal(amount: 5))
    }
    .padding()
}

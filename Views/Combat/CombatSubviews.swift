import SwiftUI
import TwilightEngine

// MARK: - Enemy Panel

/// Shows enemy intent, name, and dual health bars
struct EnemyPanel: View {
    let enemy: EncounterEnemyState?
    let intent: EnemyIntent?

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Intent badge
            if let intent = intent {
                EnemyIntentBadge(intent: intent)
                    .transition(.scale.combined(with: .opacity))
            }

            // Enemy name
            if let enemy = enemy {
                Text(enemy.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primary)

                // Dual health bars
                DualHealthBar(
                    currentHP: enemy.hp,
                    maxHP: enemy.maxHp,
                    currentWill: enemy.wp ?? 0,
                    maxWill: enemy.maxWp ?? 0
                )
                .padding(.horizontal, Spacing.xl)
            } else {
                Text("---")
                    .font(.title2)
                    .foregroundColor(AppColors.muted)
            }
        }
        .padding(.vertical, Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(AppColors.backgroundTertiary)
    }
}

// MARK: - Round Info Bar

struct RoundInfoBar: View {
    let round: Int
    let phase: EncounterPhase

    var body: some View {
        HStack {
            Label(L10n.encounterRoundLabel.localized(with: round), systemImage: "clock")
                .font(.subheadline)
                .fontWeight(.semibold)

            Spacer()

            Text(phaseLabel)
                .font(.subheadline)
                .foregroundColor(phaseColor)
                .fontWeight(.medium)
        }
        .padding(.horizontal)
        .padding(.vertical, Spacing.xs)
        .background(AppColors.backgroundSystem)
    }

    private var phaseLabel: String {
        switch phase {
        case .intent: return L10n.encounterPhaseIntent.localized
        case .playerAction: return L10n.encounterPhasePlayerAction.localized
        case .enemyResolution: return L10n.encounterPhaseEnemyResolution.localized
        case .roundEnd: return L10n.encounterPhaseRoundEnd.localized
        }
    }

    private var phaseColor: Color {
        switch phase {
        case .playerAction: return AppColors.success
        case .enemyResolution: return AppColors.danger
        default: return AppColors.muted
        }
    }
}

// MARK: - Hero Health Bar

struct HeroHealthBar: View {
    let currentHP: Int
    let maxHP: Int

    private var fraction: CGFloat {
        maxHP > 0 ? CGFloat(currentHP) / CGFloat(maxHP) : 0
    }

    private var barColor: Color {
        if fraction > 0.5 { return AppColors.success }
        if fraction > 0.25 { return AppColors.warning }
        return AppColors.danger
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "heart.fill")
                .foregroundColor(barColor)
                .font(.subheadline)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                    Capsule()
                        .fill(barColor)
                        .frame(width: geo.size.width * fraction)
                        .animation(.easeInOut(duration: 0.3), value: currentHP)
                }
            }
            .frame(height: 10)

            Text("\(currentHP)/\(maxHP)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.secondary)
                .monospacedDigit()
        }
    }
}

// MARK: - Action Bar

/// Three equal-weight action buttons: Attack, Influence, Wait
struct ActionBar: View {
    let canAct: Bool
    let hasSpiritTrack: Bool
    let onAttack: () -> Void
    let onInfluence: () -> Void
    let onWait: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            actionButton(
                title: L10n.encounterActionAttack.localized,
                icon: "flame.fill",
                color: AppColors.danger,
                action: onAttack
            )

            actionButton(
                title: L10n.encounterActionInfluence.localized,
                icon: "bubble.left.fill",
                color: Color.blue,
                action: onInfluence
            )
            .disabled(!hasSpiritTrack)
            .opacity(hasSpiritTrack ? 1.0 : 0.4)

            actionButton(
                title: L10n.encounterActionWait.localized,
                icon: "hourglass",
                color: AppColors.secondary,
                action: onWait
            )
        }
        .padding(.horizontal)
        .disabled(!canAct)
        .opacity(canAct ? 1.0 : 0.5)
    }

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.xxs) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(color)
            .cornerRadius(CornerRadius.lg)
        }
    }
}

// MARK: - Fate Deck Bar

struct FateDeckBar: View {
    let drawCount: Int
    let discardCount: Int
    let onFlee: () -> Void

    var body: some View {
        HStack {
            Label("\(drawCount)", systemImage: "rectangle.portrait.on.rectangle.portrait.fill")
                .font(.caption)
                .foregroundColor(AppColors.muted)

            Label("\(discardCount)", systemImage: "tray.full.fill")
                .font(.caption)
                .foregroundColor(AppColors.muted)

            Spacer()

            Button(action: onFlee) {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "figure.walk")
                    Text(L10n.encounterActionFlee.localized)
                }
                .font(.caption)
                .foregroundColor(AppColors.muted)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - Combat Over View

struct CombatOverView: View {
    let result: EncounterResult
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            VStack(spacing: Spacing.lg) {
                Image(systemName: iconName)
                    .font(.system(size: 60))
                    .foregroundColor(outcomeColor)

                Text(outcomeTitle)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(outcomeColor)

                Text(outcomeSummary)
                    .font(.body)
                    .foregroundColor(AppColors.secondary)
                    .multilineTextAlignment(.center)

                Button(action: onDismiss) {
                    Text(L10n.encounterOutcomeContinue.localized)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.primary)
                        .cornerRadius(CornerRadius.lg)
                }
                .padding(.horizontal, Spacing.xl)
            }
            .padding(Spacing.xl)
            .background(AppColors.backgroundTertiary)
            .cornerRadius(CornerRadius.xl)
            .padding(.horizontal, Spacing.xl)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.6))
    }

    private var iconName: String {
        switch result.outcome {
        case .victory(.pacified): return "heart.circle.fill"
        case .victory: return "checkmark.circle.fill"
        case .defeat: return "xmark.circle.fill"
        case .escaped: return "figure.walk.circle.fill"
        }
    }

    private var outcomeColor: Color {
        switch result.outcome {
        case .victory: return AppColors.success
        case .defeat: return AppColors.danger
        case .escaped: return AppColors.warning
        }
    }

    private var outcomeTitle: String {
        switch result.outcome {
        case .victory(.pacified): return L10n.encounterOutcomePacified.localized
        case .victory: return L10n.encounterOutcomeVictory.localized
        case .defeat: return L10n.encounterOutcomeDefeat.localized
        case .escaped: return L10n.encounterOutcomeEscaped.localized
        }
    }

    private var outcomeSummary: String {
        let hp = result.transaction.hpDelta
        if hp < 0 {
            return L10n.encounterOutcomeHpLost.localized(with: -hp)
        } else if hp > 0 {
            return L10n.encounterOutcomeHpGained.localized(with: hp)
        }
        return ""
    }
}

// MARK: - Combat Log View

struct CombatLogView: View {
    let entries: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(entries.suffix(5).enumerated()), id: \.offset) { _, entry in
                Text(entry)
                    .font(.caption2)
                    .foregroundColor(AppColors.muted)
            }
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

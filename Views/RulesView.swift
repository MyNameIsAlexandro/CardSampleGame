import SwiftUI

struct RulesView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xxl) {
                    // Game Objective
                    RuleSection(
                        icon: "target",
                        color: AppColors.primary,
                        title: L10n.rulesObjectiveTitle.localized,
                        content: L10n.rulesObjectiveContent.localized
                    )

                    // Game Phases
                    RuleSection(
                        icon: "arrow.triangle.2.circlepath",
                        color: AppColors.power,
                        title: L10n.rulesPhasesTitle.localized,
                        content: L10n.rulesPhasesContent.localized
                    )

                    VStack(alignment: .leading, spacing: Spacing.md) {
                        PhaseCard(
                            phase: L10n.phaseExploration.localized,
                            description: L10n.rulesPhaseExploration.localized,
                            color: AppColors.primary
                        )
                        PhaseCard(
                            phase: L10n.phaseEncounter.localized,
                            description: L10n.rulesPhaseEncounter.localized,
                            color: AppColors.power
                        )
                        PhaseCard(
                            phase: L10n.phasePlayerTurn.localized,
                            description: L10n.rulesPhasePlayerTurn.localized,
                            color: AppColors.success
                        )
                        PhaseCard(
                            phase: L10n.phaseEnemyTurn.localized,
                            description: L10n.rulesPhaseEnemyTurn.localized,
                            color: AppColors.danger
                        )
                        PhaseCard(
                            phase: L10n.phaseEndTurn.localized,
                            description: L10n.rulesPhaseEndTurn.localized,
                            color: AppColors.dark
                        )
                    }
                    .padding(.leading, Spacing.sm)

                    // Card Types
                    RuleSection(
                        icon: "rectangle.stack.fill",
                        color: AppColors.dark,
                        title: L10n.rulesCardsTitle.localized,
                        content: L10n.rulesCardsContent.localized
                    )

                    // Resources
                    RuleSection(
                        icon: "star.fill",
                        color: AppColors.cardTypeResource,
                        title: L10n.rulesResourcesTitle.localized,
                        content: L10n.rulesResourcesContent.localized
                    )

                    // Actions
                    RuleSection(
                        icon: "bolt.fill",
                        color: AppColors.power,
                        title: L10n.rulesActionsTitle.localized,
                        content: L10n.rulesActionsContent.localized
                    )

                    // Dice Rolls
                    RuleSection(
                        icon: "dice.fill",
                        color: AppColors.success,
                        title: L10n.rulesDiceTitle.localized,
                        content: L10n.rulesDiceContent.localized
                    )

                    // Victory Conditions
                    RuleSection(
                        icon: "trophy.fill",
                        color: AppColors.faith,
                        title: L10n.rulesVictoryTitle.localized,
                        content: L10n.rulesVictoryContent.localized
                    )

                    // Tips
                    RuleSection(
                        icon: "lightbulb.fill",
                        color: AppColors.info,
                        title: L10n.rulesTipsTitle.localized,
                        content: L10n.rulesTipsContent.localized
                    )
                }
                .padding()
            }
            .navigationTitle(L10n.rulesTitle.localized)
            .background(AppColors.backgroundSystem)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColors.backgroundSystem, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(AppColors.primary)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.muted)
                    }
                }
            }
        }
    }
}

struct RuleSection: View {
    let icon: String
    let color: Color
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Text(content)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.lg)
    }
}

struct PhaseCard: View {
    let phase: String
    let description: String
    let color: Color

    var body: some View {
        HStack(spacing: Spacing.md) {
            Circle()
                .fill(color)
                .frame(width: Spacing.md, height: Spacing.md)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(phase)
                    .font(.headline)
                    .foregroundColor(color)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(AppColors.muted)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundTertiary)
        .cornerRadius(CornerRadius.md)
    }
}

#Preview {
    RulesView()
}

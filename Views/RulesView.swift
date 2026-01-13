import SwiftUI

struct RulesView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Game Objective
                    RuleSection(
                        icon: "target",
                        color: .blue,
                        title: L10n.rulesObjectiveTitle.localized,
                        content: L10n.rulesObjectiveContent.localized
                    )

                    // Game Phases
                    RuleSection(
                        icon: "arrow.triangle.2.circlepath",
                        color: .orange,
                        title: L10n.rulesPhasesTitle.localized,
                        content: L10n.rulesPhasesContent.localized
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        PhaseCard(
                            phase: L10n.phaseExploration.localized,
                            description: L10n.rulesPhaseExploration.localized,
                            color: .blue
                        )
                        PhaseCard(
                            phase: L10n.phaseEncounter.localized,
                            description: L10n.rulesPhaseEncounter.localized,
                            color: .orange
                        )
                        PhaseCard(
                            phase: L10n.phaseCombat.localized,
                            description: L10n.rulesPhaseCombat.localized,
                            color: .red
                        )
                        PhaseCard(
                            phase: L10n.phaseEndTurn.localized,
                            description: L10n.rulesPhaseEndTurn.localized,
                            color: .green
                        )
                    }
                    .padding(.leading, 8)

                    // Card Types
                    RuleSection(
                        icon: "rectangle.stack.fill",
                        color: .purple,
                        title: L10n.rulesCardsTitle.localized,
                        content: L10n.rulesCardsContent.localized
                    )

                    // Resources
                    RuleSection(
                        icon: "star.fill",
                        color: .pink,
                        title: L10n.rulesResourcesTitle.localized,
                        content: L10n.rulesResourcesContent.localized
                    )

                    // Dice Rolls
                    RuleSection(
                        icon: "dice.fill",
                        color: .green,
                        title: L10n.rulesDiceTitle.localized,
                        content: L10n.rulesDiceContent.localized
                    )

                    // Victory Conditions
                    RuleSection(
                        icon: "trophy.fill",
                        color: .yellow,
                        title: L10n.rulesVictoryTitle.localized,
                        content: L10n.rulesVictoryContent.localized
                    )

                    // Tips
                    RuleSection(
                        icon: "lightbulb.fill",
                        color: .cyan,
                        title: L10n.rulesTipsTitle.localized,
                        content: L10n.rulesTipsContent.localized
                    )
                }
                .padding()
            }
            .navigationTitle(L10n.rulesTitle.localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
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
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct PhaseCard: View {
    let phase: String
    let description: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(phase)
                    .font(.headline)
                    .foregroundColor(color)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

#Preview {
    RulesView()
}

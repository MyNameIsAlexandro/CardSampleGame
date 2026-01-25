import SwiftUI
import TwilightEngine

struct StatisticsView: View {
    @StateObject private var saveManager = SaveManager.shared
    @Environment(\.dismiss) var dismiss

    var allSaves: [EngineSave] {
        saveManager.allSaves
    }

    var longestSurvival: Int {
        allSaves.map { $0.currentDay }.max() ?? 0
    }

    var totalGames: Int {
        allSaves.count
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Spacing.xxl) {
                    // Header
                    VStack(spacing: Spacing.sm) {
                        Text("📊 " + L10n.statsTitle.localized)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text(L10n.statsGameName.localized)
                            .font(.title3)
                            .foregroundColor(AppColors.muted)
                    }
                    .padding(.top)

                    // Overall Statistics
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        Text(L10n.statsGeneral.localized)
                            .font(.headline)

                        HStack(spacing: Spacing.lg) {
                            StatCard(
                                icon: "gamecontroller.fill",
                                title: L10n.statsGamesCount.localized,
                                value: "\(totalGames)",
                                color: AppColors.primary
                            )

                            StatCard(
                                icon: "clock.fill",
                                title: L10n.statsLongestSurvival.localized,
                                value: L10n.statsTurnsCount.localized(with: longestSurvival),
                                color: AppColors.success
                            )
                        }
                    }
                    .padding()
                    .background(AppColors.cardBackground)
                    .cornerRadius(CornerRadius.lg)

                    // Game Records
                    if !allSaves.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.lg) {
                            Text(L10n.statsHistory.localized)
                                .font(.headline)

                            ForEach(Array(allSaves.enumerated()), id: \.element.savedAt) { index, save in
                                GameRecordCard(slot: index + 1, save: save)
                            }
                        }
                        .padding()
                        .background(AppColors.cardBackground)
                        .cornerRadius(CornerRadius.lg)
                    } else {
                        VStack(spacing: Spacing.md) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: Sizes.iconRegion))
                                .foregroundColor(AppColors.muted)
                            Text(L10n.statsNoSaves.localized)
                                .font(.headline)
                                .foregroundColor(AppColors.muted)
                            Text(L10n.statsStartHint.localized)
                                .font(.subheadline)
                                .foregroundColor(AppColors.muted)
                                .multilineTextAlignment(.center)
                        }
                        .padding(Sizes.iconXL)
                        .background(AppColors.cardBackground)
                        .cornerRadius(CornerRadius.lg)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Text(L10n.statsDone.localized)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(AppColors.muted)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(Spacing.smd)
    }
}

struct GameRecordCard: View {
    let slot: Int
    let save: EngineSave

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(save.playerName)
                        .font(.headline)
                    Text(L10n.uiSlotNumber.localized(with: slot))
                        .font(.caption)
                        .foregroundColor(AppColors.muted)
                }

                Spacer()

                Text(formatDate(save.savedAt))
                    .font(.caption)
                    .foregroundColor(AppColors.muted)
            }

            Divider()

            HStack(spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(L10n.statsResources.localized)
                        .font(.caption)
                        .foregroundColor(AppColors.muted)
                    HStack(spacing: Spacing.md) {
                        Label("\(save.playerHealth)/\(save.playerMaxHealth)", systemImage: "heart.fill")
                            .foregroundColor(AppColors.health)
                        Label("\(save.playerFaith)", systemImage: "sparkles")
                            .foregroundColor(AppColors.faith)
                        Label("\(save.playerBalance)", systemImage: "scale.3d")
                            .foregroundColor(AppColors.dark)
                    }
                    .font(.caption)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    Text(L10n.statsProgress.localized)
                        .font(.caption)
                        .foregroundColor(AppColors.muted)
                    Text(L10n.dayNumber.localized(with: save.currentDay))
                        .font(.headline)
                }
            }
        }
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(Spacing.smd)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    StatisticsView()
}

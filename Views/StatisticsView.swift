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
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("📊 " + L10n.statsTitle.localized)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text(L10n.statsGameName.localized)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)

                    // Overall Statistics
                    VStack(alignment: .leading, spacing: 16) {
                        Text(L10n.statsGeneral.localized)
                            .font(.headline)

                        HStack(spacing: 16) {
                            StatCard(
                                icon: "gamecontroller.fill",
                                title: L10n.statsGamesCount.localized,
                                value: "\(totalGames)",
                                color: .blue
                            )

                            StatCard(
                                icon: "clock.fill",
                                title: L10n.statsLongestSurvival.localized,
                                value: L10n.statsTurnsCount.localized(with: longestSurvival),
                                color: .green
                            )
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)

                    // Game Records
                    if !allSaves.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(L10n.statsHistory.localized)
                                .font(.headline)

                            ForEach(Array(allSaves.enumerated()), id: \.element.savedAt) { index, save in
                                GameRecordCard(slot: index + 1, save: save)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            Text(L10n.statsNoSaves.localized)
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text(L10n.statsStartHint.localized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(40)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
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
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(10)
    }
}

struct GameRecordCard: View {
    let slot: Int
    let save: EngineSave

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(save.playerName)
                        .font(.headline)
                    Text(L10n.uiSlotNumber.localized(with: slot))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(formatDate(save.savedAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.statsResources.localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 12) {
                        Label("\(save.playerHealth)/\(save.playerMaxHealth)", systemImage: "heart.fill")
                            .foregroundColor(.red)
                        Label("\(save.playerFaith)", systemImage: "sparkles")
                            .foregroundColor(.yellow)
                        Label("\(save.playerBalance)", systemImage: "scale.3d")
                            .foregroundColor(.purple)
                    }
                    .font(.caption)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(L10n.statsProgress.localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(L10n.dayNumber.localized(with: save.currentDay))
                        .font(.headline)
                }
            }
        }
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(10)
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

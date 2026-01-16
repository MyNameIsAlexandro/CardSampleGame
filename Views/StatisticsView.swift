import SwiftUI

struct StatisticsView: View {
    @StateObject private var saveManager = SaveManager.shared
    @Environment(\.dismiss) var dismiss

    var allSaves: [GameSave] {
        [1, 2, 3].compactMap { saveManager.loadGame(from: $0) }
    }

    var bestEncountersDefeated: Int {
        allSaves.map { $0.encountersDefeated }.max() ?? 0
    }

    var longestSurvival: Int {
        allSaves.map { $0.turnNumber }.max() ?? 0
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
                        Text("📊 Статистика")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Twilight Marches")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)

                    // Overall Statistics
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Общая статистика")
                            .font(.headline)

                        HStack(spacing: 16) {
                            StatCard(
                                icon: "gamecontroller.fill",
                                title: "Игр",
                                value: "\(totalGames)",
                                color: .blue
                            )

                            StatCard(
                                icon: "trophy.fill",
                                title: "Лучший результат",
                                value: "\(bestEncountersDefeated)",
                                color: .orange
                            )

                            StatCard(
                                icon: "clock.fill",
                                title: "Дольше всего",
                                value: "\(longestSurvival) ходов",
                                color: .green
                            )
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)

                    // Leaderboard
                    if !allSaves.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Таблица лидеров")
                                .font(.headline)

                            ForEach(Array(allSaves.sorted(by: { $0.encountersDefeated > $1.encountersDefeated }).enumerated()), id: \.element.id) { index, save in
                                LeaderboardRow(
                                    rank: index + 1,
                                    save: save
                                )
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)

                        // Detailed Game Records
                        VStack(alignment: .leading, spacing: 16) {
                            Text("История игр")
                                .font(.headline)

                            ForEach(allSaves.sorted(by: { $0.timestamp > $1.timestamp })) { save in
                                GameRecordCard(save: save)
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
                            Text("Пока нет сохранённых игр")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Начните новую игру, чтобы увидеть статистику")
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
                        Text("Готово")
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

struct LeaderboardRow: View {
    let rank: Int
    let save: GameSave

    var rankIcon: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(rank)."
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(rankIcon)
                .font(.title2)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(save.characterName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 8) {
                    Label("\(save.encountersDefeated)", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Label("\(save.turnNumber)", systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Слот \(save.slotNumber)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(save.formattedDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

struct GameRecordCard: View {
    let save: GameSave

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(save.characterName)
                        .font(.headline)
                    Text("Слот \(save.slotNumber)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(save.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ресурсы")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 12) {
                        Label("\(save.health)/\(save.maxHealth)", systemImage: "heart.fill")
                            .foregroundColor(.red)
                        Label("\(save.faith)", systemImage: "sparkles")
                            .foregroundColor(.yellow)
                        Label("\(save.balance)", systemImage: "scale.3d")
                            .foregroundColor(.purple)
                    }
                    .font(.caption)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Прогресс")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 12) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(save.encountersDefeated)")
                                .font(.headline)
                            Text("побед")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(save.turnNumber)")
                                .font(.headline)
                            Text("ходов")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(10)
    }
}

#Preview {
    StatisticsView()
}

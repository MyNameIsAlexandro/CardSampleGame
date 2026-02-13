/// Файл: Views/StatisticsView.swift
/// Назначение: Содержит реализацию файла StatisticsView.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine

struct StatisticsView: View {
    @StateObject private var saveManager = SaveManager.shared
    @StateObject private var profileManager = ProfileManager.shared
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

                    // Combat Lifetime
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        Text(L10n.achievementsCategoryCombat.localized)
                            .font(.headline)

                        VStack(spacing: Spacing.lg) {
                            HStack(spacing: Spacing.lg) {
                                StatCard(
                                    icon: "crossed.swords",
                                    title: "Total Fights",
                                    value: "\(profileManager.profile.combatStats.totalFights)",
                                    color: AppColors.primary
                                )

                                StatCard(
                                    icon: "checkmark.seal.fill",
                                    title: "Victories",
                                    value: "\(profileManager.profile.combatStats.totalVictories)",
                                    color: AppColors.success
                                )

                                StatCard(
                                    icon: "xmark.seal.fill",
                                    title: "Defeats",
                                    value: "\(profileManager.profile.combatStats.totalDefeats)",
                                    color: AppColors.danger
                                )
                            }

                            HStack(spacing: Spacing.lg) {
                                StatCard(
                                    icon: "figure.run",
                                    title: "Fled",
                                    value: "\(profileManager.profile.combatStats.totalFlees)",
                                    color: AppColors.warning
                                )

                                StatCard(
                                    icon: "bolt.fill",
                                    title: "Damage Dealt",
                                    value: "\(profileManager.profile.combatStats.totalDamageDealt)",
                                    color: AppColors.power
                                )

                                StatCard(
                                    icon: "shield.lefthalf.filled",
                                    title: "Damage Taken",
                                    value: "\(profileManager.profile.combatStats.totalDamageTaken)",
                                    color: AppColors.health
                                )
                            }
                        }
                    }
                    .padding()
                    .background(AppColors.cardBackground)
                    .cornerRadius(CornerRadius.lg)

                    // Knowledge
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        Text(L10n.bestiaryKnowledge.localized)
                            .font(.headline)

                        HStack(spacing: Spacing.lg) {
                            StatCard(
                                icon: "eye.fill",
                                title: "Encountered",
                                value: "\(profileManager.profile.creatureKnowledge.values.filter { $0.level >= .encountered }.count)",
                                color: AppColors.primary
                            )

                            StatCard(
                                icon: "book.fill",
                                title: "Studied",
                                value: "\(profileManager.profile.creatureKnowledge.values.filter { $0.level >= .studied }.count)",
                                color: AppColors.info
                            )

                            StatCard(
                                icon: "star.fill",
                                title: "Mastered",
                                value: "\(profileManager.profile.creatureKnowledge.values.filter { $0.level == .mastered }.count)",
                                color: AppColors.rarityLegendary
                            )
                        }
                    }
                    .padding()
                    .background(AppColors.cardBackground)
                    .cornerRadius(CornerRadius.lg)

                    // Meta
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        Text(L10n.achievementsCategoryMastery.localized)
                            .font(.headline)

                        HStack(spacing: Spacing.lg) {
                            StatCard(
                                icon: "arrow.circlepath",
                                title: "Total Playthroughs",
                                value: "\(profileManager.profile.totalPlaythroughs)",
                                color: AppColors.primary
                            )

                            StatCard(
                                icon: "trophy.fill",
                                title: "Achievements",
                                value: "\(AchievementEngine.unlockedCount(profile: profileManager.profile))",
                                color: AppColors.rarityLegendary
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
            .background(AppColors.backgroundSystem)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColors.backgroundSystem, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(AppColors.primary)
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
        .background(AppColors.backgroundTertiary)
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
        .background(AppColors.backgroundTertiary)
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

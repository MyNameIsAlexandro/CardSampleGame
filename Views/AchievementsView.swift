/// Файл: Views/AchievementsView.swift
/// Назначение: Содержит реализацию файла AchievementsView.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI

struct AchievementsView: View {
    @StateObject private var profileManager = ProfileManager.shared
    @Environment(\.dismiss) var dismiss

    private var unlockedIds: Set<String> {
        Set(profileManager.profile.achievements.keys)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Spacing.xxl) {
                    // Progress header
                    VStack(spacing: Spacing.sm) {
                        Text("\(AchievementEngine.unlockedCount(profile: profileManager.profile))/\(AchievementEngine.totalCount)")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.primary)

                        Text(L10n.achievementsUnlocked.localized)
                            .font(.caption)
                            .foregroundColor(AppColors.muted)

                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(AppColors.muted.opacity(Opacity.faint))
                                    .frame(height: Sizes.progressMedium)
                                    .cornerRadius(CornerRadius.sm)

                                let progress = AchievementEngine.totalCount > 0
                                    ? CGFloat(AchievementEngine.unlockedCount(profile: profileManager.profile)) / CGFloat(AchievementEngine.totalCount)
                                    : 0

                                Rectangle()
                                    .fill(AppColors.primary)
                                    .frame(width: geo.size.width * progress, height: Sizes.progressMedium)
                                    .cornerRadius(CornerRadius.sm)
                            }
                        }
                        .frame(height: Sizes.progressMedium)
                        .padding(.horizontal, Spacing.xl)
                    }
                    .padding(.top)

                    // Categories
                    ForEach(AchievementCategory.allCases, id: \.self) { category in
                        let achievements = AchievementDefinition.all.filter { $0.category == category }

                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text(categoryName(category))
                                .font(.headline)
                                .foregroundColor(AppColors.primary)
                                .padding(.horizontal)

                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: Spacing.md),
                                GridItem(.flexible(), spacing: Spacing.md)
                            ], spacing: Spacing.md) {
                                ForEach(achievements, id: \.id) { achievement in
                                    AchievementCard(
                                        achievement: achievement,
                                        isUnlocked: unlockedIds.contains(achievement.id),
                                        unlockedAt: profileManager.profile.achievements[achievement.id]?.unlockedAt
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, Spacing.xl)
            }
            .background(AppColors.backgroundSystem)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColors.backgroundSystem, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(AppColors.primary)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(L10n.achievementsTitle.localized)
                        .font(.headline)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.statsDone.localized) { dismiss() }
                }
            }
        }
    }

    private func categoryName(_ category: AchievementCategory) -> String {
        switch category {
        case .combat: return L10n.achievementsCategoryCombat.localized
        case .exploration: return L10n.achievementsCategoryExploration.localized
        case .knowledge: return L10n.achievementsCategoryKnowledge.localized
        case .mastery: return L10n.achievementsCategoryMastery.localized
        }
    }
}

struct AchievementCard: View {
    let achievement: AchievementDefinition
    let isUnlocked: Bool
    let unlockedAt: Date?

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: achievement.icon)
                .font(.title2)
                .foregroundColor(isUnlocked ? AppColors.warning : AppColors.muted.opacity(Opacity.light))

            Text(achievement.titleKey.localized)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(isUnlocked ? .white : AppColors.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(achievement.descriptionKey.localized)
                .font(.caption2)
                .foregroundColor(AppColors.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if let date = unlockedAt {
                Text(formatDate(date))
                    .font(.caption2)
                    .foregroundColor(AppColors.primary.opacity(Opacity.mediumHigh))
            }
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: Sizes.cardWidthLarge)
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(isUnlocked ? AppColors.warning.opacity(Opacity.medium) : Color.clear, lineWidth: 1)
        )
        .opacity(isUnlocked ? Opacity.opaque : Opacity.mediumHigh)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

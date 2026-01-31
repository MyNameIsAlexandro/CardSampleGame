import Foundation

// MARK: - Achievement Engine

struct AchievementEngine {

    /// Evaluate all achievements against current profile, return newly unlocked IDs
    static func evaluateNewUnlocks(profile: PlayerProfile) -> [String] {
        var newlyUnlocked: [String] = []

        for definition in AchievementDefinition.all {
            // Skip already unlocked
            guard profile.achievements[definition.id] == nil else { continue }

            // Check condition
            if definition.condition(profile) {
                newlyUnlocked.append(definition.id)
            }
        }

        return newlyUnlocked
    }

    /// Get achievement definition by ID
    static func definition(for id: String) -> AchievementDefinition? {
        AchievementDefinition.all.first { $0.id == id }
    }

    /// Get all achievements in a category
    static func achievements(in category: AchievementCategory) -> [AchievementDefinition] {
        AchievementDefinition.all.filter { $0.category == category }
    }

    /// Count unlocked achievements
    static func unlockedCount(profile: PlayerProfile) -> Int {
        profile.achievements.count
    }

    /// Total achievements available
    static var totalCount: Int {
        AchievementDefinition.all.count
    }
}

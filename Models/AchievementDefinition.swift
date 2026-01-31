import Foundation

// MARK: - Achievement Category

enum AchievementCategory: String, Codable, CaseIterable {
    case combat
    case exploration
    case knowledge
    case mastery
}

// MARK: - Achievement Definition

struct AchievementDefinition: Identifiable {
    let id: String
    let titleKey: String      // L10n key
    let descriptionKey: String // L10n key
    let icon: String           // SF Symbol name
    let category: AchievementCategory
    let condition: (PlayerProfile) -> Bool

    // MARK: - All Achievements (~15)

    static let all: [AchievementDefinition] = [
        // Combat
        AchievementDefinition(
            id: "first_blood",
            titleKey: "achievement.first.blood.title",
            descriptionKey: "achievement.first.blood.desc",
            icon: "flame.fill",
            category: .combat,
            condition: { $0.combatStats.totalVictories >= 1 }
        ),
        AchievementDefinition(
            id: "beast_slayer",
            titleKey: "achievement.beast.slayer.title",
            descriptionKey: "achievement.beast.slayer.desc",
            icon: "pawprint.fill",
            category: .combat,
            condition: { $0.combatStats.totalVictories >= 10 }
        ),
        AchievementDefinition(
            id: "battle_hardened",
            titleKey: "achievement.battle.hardened.title",
            descriptionKey: "achievement.battle.hardened.desc",
            icon: "shield.fill",
            category: .combat,
            condition: { $0.combatStats.totalFights >= 25 }
        ),
        AchievementDefinition(
            id: "pacifist",
            titleKey: "achievement.pacifist.title",
            descriptionKey: "achievement.pacifist.desc",
            icon: "leaf.fill",
            category: .combat,
            condition: { $0.combatStats.totalPacifications >= 5 }
        ),
        AchievementDefinition(
            id: "spirit_whisperer",
            titleKey: "achievement.spirit.whisperer.title",
            descriptionKey: "achievement.spirit.whisperer.desc",
            icon: "wind",
            category: .combat,
            condition: { $0.combatStats.totalPacifications >= 10 }
        ),
        AchievementDefinition(
            id: "fate_weaver",
            titleKey: "achievement.fate.weaver.title",
            descriptionKey: "achievement.fate.weaver.desc",
            icon: "sparkles",
            category: .combat,
            condition: { $0.combatStats.totalFateCardsDrawn >= 50 }
        ),

        // Exploration
        AchievementDefinition(
            id: "survivor",
            titleKey: "achievement.survivor.title",
            descriptionKey: "achievement.survivor.desc",
            icon: "sun.max.fill",
            category: .exploration,
            condition: { $0.longestSurvival >= 30 }
        ),
        AchievementDefinition(
            id: "enduring",
            titleKey: "achievement.enduring.title",
            descriptionKey: "achievement.enduring.desc",
            icon: "hourglass",
            category: .exploration,
            condition: { $0.longestSurvival >= 50 }
        ),
        AchievementDefinition(
            id: "veteran",
            titleKey: "achievement.veteran.title",
            descriptionKey: "achievement.veteran.desc",
            icon: "star.fill",
            category: .exploration,
            condition: { $0.totalPlaythroughs >= 3 }
        ),

        // Knowledge
        AchievementDefinition(
            id: "curious_mind",
            titleKey: "achievement.curious.mind.title",
            descriptionKey: "achievement.curious.mind.desc",
            icon: "book.fill",
            category: .knowledge,
            condition: { profile in
                profile.creatureKnowledge.values.filter { $0.level >= .encountered }.count >= 3
            }
        ),
        AchievementDefinition(
            id: "scholar",
            titleKey: "achievement.scholar.title",
            descriptionKey: "achievement.scholar.desc",
            icon: "text.book.closed.fill",
            category: .knowledge,
            condition: { profile in
                profile.creatureKnowledge.values.filter { $0.level >= .studied }.count >= 3
            }
        ),
        AchievementDefinition(
            id: "master_tracker",
            titleKey: "achievement.master.tracker.title",
            descriptionKey: "achievement.master.tracker.desc",
            icon: "magnifyingglass",
            category: .knowledge,
            condition: { profile in
                let total = profile.creatureKnowledge.count
                let mastered = profile.creatureKnowledge.values.filter { $0.level == .mastered }.count
                return total > 0 && mastered == total
            }
        ),

        // Mastery
        AchievementDefinition(
            id: "card_master",
            titleKey: "achievement.card.master.title",
            descriptionKey: "achievement.card.master.desc",
            icon: "rectangle.stack.fill",
            category: .mastery,
            condition: { $0.combatStats.totalCardsPlayed >= 100 }
        ),
        AchievementDefinition(
            id: "destroyer",
            titleKey: "achievement.destroyer.title",
            descriptionKey: "achievement.destroyer.desc",
            icon: "bolt.fill",
            category: .mastery,
            condition: { $0.combatStats.totalDamageDealt >= 500 }
        ),
        AchievementDefinition(
            id: "iron_will",
            titleKey: "achievement.iron.will.title",
            descriptionKey: "achievement.iron.will.desc",
            icon: "heart.fill",
            category: .mastery,
            condition: { $0.combatStats.totalDamageTaken >= 500 }
        ),
    ]
}

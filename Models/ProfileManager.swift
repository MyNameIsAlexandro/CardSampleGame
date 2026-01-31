import Foundation

// MARK: - Profile Manager

final class ProfileManager: ObservableObject {
    static let shared = ProfileManager()

    private static let storageKey = "twilight_profile"

    @Published private(set) var profile: PlayerProfile

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(PlayerProfile.self, from: data) {
            self.profile = decoded
        } else {
            self.profile = PlayerProfile()
        }
    }

    // MARK: - Persistence

    func save() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    // MARK: - Encounter Recording

    func recordEncounter(enemyId: String, day: Int, outcome: EncounterOutcomeType) {
        profile.recordEncounter(enemyId: enemyId, day: day, outcome: outcome)
        save()
    }

    func recordPlaythroughEnd(daysSurvived: Int) {
        profile.recordPlaythroughEnd(daysSurvived: daysSurvived)
        save()
    }

    func recordCombatStats(damageDealt: Int, damageTaken: Int, cardsPlayed: Int, fateCardsDrawn: Int) {
        profile.combatStats.totalDamageDealt += damageDealt
        profile.combatStats.totalDamageTaken += damageTaken
        profile.combatStats.totalCardsPlayed += cardsPlayed
        profile.combatStats.totalFateCardsDrawn += fateCardsDrawn
        save()
    }

    // MARK: - Achievements

    func recordAchievement(_ id: String) {
        guard profile.achievements[id] == nil else { return }
        profile.achievements[id] = AchievementRecord(achievementId: id, unlockedAt: Date())
        save()
    }

    // MARK: - Query

    func knowledgeLevel(for enemyId: String) -> KnowledgeLevel {
        profile.creatureKnowledge[enemyId]?.level ?? .unknown
    }

    func knowledge(for enemyId: String) -> CreatureKnowledge {
        profile.creatureKnowledge[enemyId] ?? CreatureKnowledge()
    }

    // MARK: - Reset (for settings)

    func resetProfile() {
        profile = PlayerProfile()
        save()
    }

    // MARK: - Testing support

    #if DEBUG
    /// Replace profile for testing — do NOT use in production
    func _setProfileForTesting(_ newProfile: PlayerProfile) {
        profile = newProfile
        save()
    }
    #endif
}

/// Файл: CardSampleGameTests/GateTests/ProfileGateTests.swift
/// Назначение: Содержит реализацию файла ProfileGateTests.swift.
/// Зона ответственности: Фиксирует проверяемый контракт и не содержит production-логики.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import CardSampleGame

/// Gate tests for Epic 13: PlayerProfile system
/// Validates persistence, knowledge progression, achievement tracking, and profile management
@MainActor
final class ProfileGateTests: XCTestCase {

    // MARK: - 1. PlayerProfile Codable Round-Trip

    func testPlayerProfileCodableRoundTrip() throws {
        // Given: A PlayerProfile with populated data
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        var profile = PlayerProfile()
        profile.totalPlaythroughs = 5
        profile.lastPlayedAt = Date(timeIntervalSince1970: 1704067200)

        var combatStats = CombatLifetimeStats()
        combatStats.totalFights = 20
        combatStats.totalVictories = 15
        combatStats.totalDefeats = 3
        combatStats.totalFlees = 2
        combatStats.totalDamageDealt = 450
        combatStats.totalDamageTaken = 180
        combatStats.totalCardsPlayed = 120
        combatStats.totalFateCardsDrawn = 45
        profile.combatStats = combatStats

        profile.achievements["first_blood"] = AchievementRecord(
            achievementId: "first_blood",
            unlockedAt: Date(timeIntervalSince1970: 1704067200)
        )

        var knowledge = CreatureKnowledge()
        knowledge.timesEncountered = 3
        knowledge.timesDefeated = 2
        knowledge.firstMetDay = 1
        knowledge.lastMetDay = 5
        knowledge.recalculateLevel()
        profile.creatureKnowledge["goblin_scout"] = knowledge

        // When: Encoding to JSON and decoding back
        let jsonData = try encoder.encode(profile)
        let decodedProfile = try decoder.decode(PlayerProfile.self, from: jsonData)

        // Then: All fields match
        XCTAssertEqual(decodedProfile.totalPlaythroughs, 5)
        XCTAssertEqual(decodedProfile.combatStats.totalFights, 20)
        XCTAssertEqual(decodedProfile.combatStats.totalVictories, 15)
        XCTAssertEqual(decodedProfile.combatStats.totalDefeats, 3)
        XCTAssertEqual(decodedProfile.combatStats.totalFlees, 2)
        XCTAssertEqual(decodedProfile.combatStats.totalDamageDealt, 450)
        XCTAssertEqual(decodedProfile.combatStats.totalDamageTaken, 180)
        XCTAssertEqual(decodedProfile.combatStats.totalCardsPlayed, 120)
        XCTAssertEqual(decodedProfile.combatStats.totalFateCardsDrawn, 45)

        XCTAssertEqual(decodedProfile.achievements.count, 1)
        XCTAssertNotNil(decodedProfile.achievements["first_blood"])

        let decodedKnowledge = decodedProfile.creatureKnowledge["goblin_scout"]
        XCTAssertNotNil(decodedKnowledge)
        XCTAssertEqual(decodedKnowledge?.timesEncountered, 3)
        XCTAssertEqual(decodedKnowledge?.timesDefeated, 2)
        XCTAssertEqual(decodedKnowledge?.level, .studied)
    }

    // MARK: - 2. CreatureKnowledge Level Progression

    func testCreatureKnowledgeLevelProgression_Encountered() throws {
        var knowledge = CreatureKnowledge()
        knowledge.timesEncountered = 1
        knowledge.recalculateLevel()
        XCTAssertEqual(knowledge.level, .encountered)
    }

    func testCreatureKnowledgeLevelProgression_Studied() throws {
        var knowledge = CreatureKnowledge()
        knowledge.timesEncountered = 3
        knowledge.recalculateLevel()
        XCTAssertEqual(knowledge.level, .studied)
    }

    func testCreatureKnowledgeLevelProgression_MasteredViaVictories() throws {
        var knowledge = CreatureKnowledge()
        knowledge.timesEncountered = 5
        knowledge.timesDefeated = 5
        knowledge.recalculateLevel()
        XCTAssertEqual(knowledge.level, .mastered)
    }

    func testCreatureKnowledgeLevelProgression_MasteredViaPacifications() throws {
        var knowledge = CreatureKnowledge()
        knowledge.timesEncountered = 3
        knowledge.timesPacified = 3
        knowledge.recalculateLevel()
        XCTAssertEqual(knowledge.level, .mastered)
    }

    // MARK: - 3. CreatureKnowledge discoveredTraits

    func testCreatureKnowledge_DiscoveredTraits_Encountered() throws {
        var knowledge = CreatureKnowledge()
        knowledge.timesEncountered = 1
        knowledge.recalculateLevel()
        XCTAssertEqual(knowledge.level, .encountered)
        // Encountered level has empty discoveredTraits (name/type/description shown by UI based on level)
        XCTAssertTrue(knowledge.discoveredTraits.isEmpty)
    }

    func testCreatureKnowledge_DiscoveredTraits_Studied() throws {
        var knowledge = CreatureKnowledge()
        knowledge.timesEncountered = 3
        knowledge.recalculateLevel()
        XCTAssertEqual(knowledge.level, .studied)
        XCTAssertTrue(knowledge.discoveredTraits.contains("stats"))
        XCTAssertTrue(knowledge.discoveredTraits.contains("abilities"))
        XCTAssertTrue(knowledge.discoveredTraits.contains("lore"))
        XCTAssertEqual(knowledge.discoveredTraits.count, 3)
    }

    func testCreatureKnowledge_DiscoveredTraits_Mastered() throws {
        var knowledge = CreatureKnowledge()
        knowledge.timesEncountered = 5
        knowledge.timesDefeated = 5
        knowledge.recalculateLevel()
        XCTAssertEqual(knowledge.level, .mastered)
        XCTAssertTrue(knowledge.discoveredTraits.contains("stats"))
        XCTAssertTrue(knowledge.discoveredTraits.contains("abilities"))
        XCTAssertTrue(knowledge.discoveredTraits.contains("lore"))
        XCTAssertTrue(knowledge.discoveredTraits.contains("weaknesses"))
        XCTAssertTrue(knowledge.discoveredTraits.contains("tactics"))
        XCTAssertEqual(knowledge.discoveredTraits.count, 5)
    }

    // MARK: - 4. AchievementEngine Evaluation

    func testAchievementEngine_EvaluateNewUnlocks() throws {
        var profile = PlayerProfile()
        profile.combatStats.totalVictories = 1

        let newAchievements = AchievementEngine.evaluateNewUnlocks(profile: profile)

        // first_blood requires totalVictories >= 1
        XCTAssertTrue(newAchievements.contains("first_blood"),
                      "first_blood should unlock with 1 victory")
    }

    // MARK: - 5. AchievementEngine No Double-Unlock

    func testAchievementEngine_NoDoubleUnlock() throws {
        var profile = PlayerProfile()
        profile.combatStats.totalVictories = 1
        profile.achievements["first_blood"] = AchievementRecord(
            achievementId: "first_blood",
            unlockedAt: Date()
        )

        let newAchievements = AchievementEngine.evaluateNewUnlocks(profile: profile)

        XCTAssertFalse(newAchievements.contains("first_blood"),
                      "Already-unlocked achievement should not appear in new unlocks")
    }

    // MARK: - 6. ProfileManager Persistence

    #if DEBUG
    func testProfileManager_Persistence() throws {
        var testProfile = PlayerProfile()
        testProfile.totalPlaythroughs = 42
        testProfile.combatStats.totalVictories = 30

        var knowledge = CreatureKnowledge()
        knowledge.timesEncountered = 5
        knowledge.timesDefeated = 5
        knowledge.recalculateLevel()
        testProfile.creatureKnowledge["test_enemy"] = knowledge

        ProfileManager.shared._setProfileForTesting(testProfile)
        ProfileManager.shared.save()

        let loadedProfile = ProfileManager.shared.profile
        XCTAssertEqual(loadedProfile.totalPlaythroughs, 42)
        XCTAssertEqual(loadedProfile.combatStats.totalVictories, 30)
        XCTAssertEqual(loadedProfile.creatureKnowledge["test_enemy"]?.level, .mastered)
    }
    #endif

    // MARK: - 7. KnowledgeLevel Ordering

    func testKnowledgeLevel_Ordering() throws {
        XCTAssertLessThan(KnowledgeLevel.unknown, KnowledgeLevel.encountered)
        XCTAssertLessThan(KnowledgeLevel.encountered, KnowledgeLevel.studied)
        XCTAssertLessThan(KnowledgeLevel.studied, KnowledgeLevel.mastered)
        XCTAssertEqual(KnowledgeLevel.unknown.rawValue, 0)
        XCTAssertEqual(KnowledgeLevel.mastered.rawValue, 3)
    }

    // MARK: - 8. Empty Profile Defaults

    func testEmptyProfile_Defaults() throws {
        let profile = PlayerProfile()
        XCTAssertEqual(profile.totalPlaythroughs, 0)
        XCTAssertTrue(profile.creatureKnowledge.isEmpty)
        XCTAssertTrue(profile.achievements.isEmpty)
        XCTAssertEqual(profile.combatStats.totalFights, 0)
        XCTAssertEqual(profile.combatStats.totalVictories, 0)
        XCTAssertEqual(profile.combatStats.totalDefeats, 0)
        XCTAssertEqual(profile.combatStats.totalFlees, 0)
        XCTAssertEqual(profile.combatStats.totalDamageDealt, 0)
        XCTAssertEqual(profile.combatStats.totalDamageTaken, 0)
        XCTAssertEqual(profile.combatStats.totalCardsPlayed, 0)
        XCTAssertEqual(profile.combatStats.totalFateCardsDrawn, 0)
    }
}

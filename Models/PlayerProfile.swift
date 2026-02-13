/// Файл: Models/PlayerProfile.swift
/// Назначение: Содержит реализацию файла PlayerProfile.swift.
/// Зона ответственности: Описывает предметные модели и их инварианты.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import Foundation

// MARK: - Knowledge Level

enum KnowledgeLevel: Int, Codable, Equatable, Comparable, CaseIterable, Sendable {
    case unknown = 0
    case encountered = 1  // 1st meeting
    case studied = 2      // 3 encounters
    case mastered = 3     // 5 victories OR 3 pacifications

    static func < (lhs: KnowledgeLevel, rhs: KnowledgeLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Creature Knowledge

struct CreatureKnowledge: Codable, Equatable, Sendable {
    var level: KnowledgeLevel = .unknown
    var timesEncountered: Int = 0
    var timesDefeated: Int = 0
    var timesPacified: Int = 0
    var timesLostTo: Int = 0
    var firstMetDay: Int = 0
    var lastMetDay: Int = 0
    var discoveredTraits: Set<String> = []  // "stats", "abilities", "weaknesses", "lore", "tactics"

    /// Recalculate knowledge level based on encounter history
    mutating func recalculateLevel() {
        if timesEncountered == 0 {
            level = .unknown
            discoveredTraits = []
            return
        }

        // Mastered: 5 victories OR 3 pacifications
        if timesDefeated >= 5 || timesPacified >= 3 {
            level = .mastered
            discoveredTraits = ["stats", "abilities", "weaknesses", "lore", "tactics"]
            return
        }

        // Studied: 3+ encounters
        if timesEncountered >= 3 {
            level = .studied
            discoveredTraits = ["stats", "abilities", "lore"]
            return
        }

        // Encountered: at least 1
        level = .encountered
        discoveredTraits = []
    }
}

// MARK: - Combat Lifetime Stats

struct CombatLifetimeStats: Codable, Equatable, Sendable {
    var totalFights: Int = 0
    var totalVictories: Int = 0
    var totalDefeats: Int = 0
    var totalFlees: Int = 0
    var totalPacifications: Int = 0
    var totalDamageDealt: Int = 0
    var totalDamageTaken: Int = 0
    var totalCardsPlayed: Int = 0
    var totalFateCardsDrawn: Int = 0
}

// MARK: - Achievement Record

struct AchievementRecord: Codable, Equatable, Sendable {
    let achievementId: String
    let unlockedAt: Date
}

// MARK: - Meta State (reserved for future meta-game)

struct MetaState: Codable, Equatable, Sendable {
    // Empty for now — architectural placeholder
}

// MARK: - Player Profile

struct PlayerProfile: Codable, Equatable, Sendable {
    var creatureKnowledge: [String: CreatureKnowledge] = [:]
    var combatStats: CombatLifetimeStats = CombatLifetimeStats()
    var achievements: [String: AchievementRecord] = [:]
    var totalPlaythroughs: Int = 0
    var longestSurvival: Int = 0
    var lastPlayedAt: Date?
    var metaState: MetaState = MetaState()

    /// Record an encounter with an enemy
    mutating func recordEncounter(enemyId: String, day: Int, outcome: EncounterOutcomeType) {
        var knowledge = creatureKnowledge[enemyId] ?? CreatureKnowledge()
        knowledge.timesEncountered += 1
        knowledge.lastMetDay = day
        if knowledge.firstMetDay == 0 { knowledge.firstMetDay = day }

        switch outcome {
        case .defeated:
            knowledge.timesDefeated += 1
            combatStats.totalVictories += 1
        case .pacified:
            knowledge.timesPacified += 1
            combatStats.totalPacifications += 1
        case .lost:
            knowledge.timesLostTo += 1
            combatStats.totalDefeats += 1
        case .fled:
            combatStats.totalFlees += 1
        }

        combatStats.totalFights += 1
        knowledge.recalculateLevel()
        creatureKnowledge[enemyId] = knowledge
    }

    /// Record playthrough end
    mutating func recordPlaythroughEnd(daysSurvived: Int) {
        totalPlaythroughs += 1
        longestSurvival = max(longestSurvival, daysSurvived)
        lastPlayedAt = Date()
    }
}

// MARK: - Encounter Outcome Type (for profile tracking)

enum EncounterOutcomeType: String, Codable, Sendable {
    case defeated   // player killed enemy
    case pacified   // player pacified enemy
    case lost       // player lost
    case fled       // player fled
}

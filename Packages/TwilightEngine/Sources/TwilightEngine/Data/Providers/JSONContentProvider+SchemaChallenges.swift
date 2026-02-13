/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Data/Providers/JSONContentProvider+SchemaChallenges.swift
/// Назначение: Содержит реализацию файла JSONContentProvider+SchemaChallenges.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// JSON-схема мини-испытаний (challenge), используемых в квестах/ивентах.
struct JSONChallenge: Codable {
    public let id: String
    public let challengeKind: String?
    public let difficulty: Int?
    public let titleKey: String?
    public let descriptionKey: String?
    public let enemyData: JSONCombatData?
    public let requirements: JSONChoiceRequirements?
    public let rewards: JSONChallengeRewards?
    public let penalties: JSONChallengePenalties?
    public let isBoss: Bool?

    public func toDefinition() -> MiniGameChallengeDefinition {
        let kind: MiniGameChallengeKind
        switch challengeKind?.lowercased() {
        case "combat": kind = .combat
        case "ritual": kind = .ritual
        case "exploration": kind = .exploration
        case "dialogue": kind = .dialogue
        case "puzzle": kind = .puzzle
        default: kind = .combat
        }

        return MiniGameChallengeDefinition(
            id: id,
            challengeKind: kind,
            difficulty: difficulty ?? 5,
            enemyId: enemyData?.enemyId
        )
    }
}

/// JSON-награды за успешное прохождение challenge.
struct JSONChallengeRewards: Codable {
    public let victoryFaith: Int?
    public let victoryBalance: Int?
    public let setFlags: [String: Bool]?
    public let discoverRegion: Bool?
    public let findArtifact: Bool?
}

/// JSON-штрафы за провал challenge.
struct JSONChallengePenalties: Codable {
    public let defeatHealth: Int?
    public let defeatTension: Int?
    public let faithCost: Int?
    public let healthCost: Int?
    public let tensionGain: Int?
}

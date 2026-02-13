/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Data/Providers/JSONContentProvider+SchemaEvents.swift
/// Назначение: Содержит реализацию файла JSONContentProvider+SchemaEvents.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

/// Базовая схема типа события (`event_kind`) в JSON.
/// Поддерживает строковый формат (`inline`) и object-формат (`{"mini_game":"combat"}`).
enum JSONEventKind: Codable {
    case inline
    case miniGame(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // Try string first (e.g., "inline")
        if let stringValue = try? container.decode(String.self) {
            if stringValue == "inline" {
                self = .inline
            } else {
                // Treat other strings as mini_game type
                self = .miniGame(stringValue)
            }
            return
        }

        // Try object (e.g., {"mini_game": "combat"})
        if let dictValue = try? container.decode([String: String].self),
           let miniGameType = dictValue["mini_game"] {
            self = .miniGame(miniGameType)
            return
        }

        // Default to inline
        self = .inline
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .inline:
            try container.encode("inline")
        case .miniGame(let type):
            try container.encode(["mini_game": type])
        }
    }

    public func toEventKind() -> EventKind {
        switch self {
        case .inline:
            return .inline
        case .miniGame(let type):
            switch type.lowercased() {
            case "combat": return .miniGame(.combat)
            case "ritual": return .miniGame(.ritual)
            case "exploration": return .miniGame(.exploration)
            case "dialogue": return .miniGame(.dialogue)
            case "puzzle": return .miniGame(.puzzle)
            default: return .miniGame(.combat)
            }
        }
    }
}

struct JSONEvent: Codable {
    public let id: String
    public let title: LocalizedString
    public let body: LocalizedString
    public let eventKind: JSONEventKind?
    public let eventType: String?
    public let poolIds: [String]?
    public let availability: JSONAvailability?
    public let weight: Int?
    public let isOneTime: Bool?
    public let isInstant: Bool?
    public let cooldown: Int?
    public let choices: [JSONChoice]?
    public let combatData: JSONCombatData?
    public let miniGameChallenge: JSONMiniGameChallenge?

    enum CodingKeys: String, CodingKey {
        case id, title, body, availability, weight, choices, combatData
        case eventKind = "event_kind"
        case eventType = "event_type"
        case poolIds = "pool_ids"
        case isOneTime = "is_one_time"
        case isInstant = "is_instant"
        case cooldown
        case miniGameChallenge = "mini_game_challenge"
    }

    public func toDefinition() -> EventDefinition {
        let kind: EventKind
        // Prefer eventKind (can be string or object), fall back to eventType (legacy string)
        if let ek = eventKind {
            kind = ek.toEventKind()
        } else if let et = eventType {
            switch et.lowercased() {
            case "combat": kind = .miniGame(.combat)
            case "ritual": kind = .miniGame(.ritual)
            case "exploration": kind = .miniGame(.exploration)
            default: kind = .inline
            }
        } else {
            kind = .inline
        }

        let avail = availability?.toAvailability() ?? .always

        let choiceDefs = choices?.map { $0.toDefinition() } ?? []

        // Create MiniGameChallengeDefinition from JSON mini_game_challenge
        let challenge: MiniGameChallengeDefinition?
        if let json = miniGameChallenge, let enemyId = json.enemyId {
            challenge = MiniGameChallengeDefinition(
                id: "challenge_\(enemyId)",
                challengeKind: .combat,
                difficulty: json.difficulty ?? 1,
                enemyId: enemyId,
                victoryConsequences: json.rewards?.toConsequences() ?? .none,
                defeatConsequences: json.penalties?.toConsequences() ?? .none
            )
        } else {
            challenge = nil
        }

        return EventDefinition(
            id: id,
            title: .inline(title),
            body: .inline(body),
            eventKind: kind,
            availability: avail,
            poolIds: poolIds ?? [],
            weight: weight ?? 10,
            isOneTime: isOneTime ?? false,
            choices: choiceDefs,
            miniGameChallenge: challenge
        )
    }
}

/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Data/Providers/CodeContentProvider+JSONLoading.swift
/// Назначение: Содержит реализацию файла CodeContentProvider+JSONLoading.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - JSON Event Loading Structures

/// Simplified event_kind that can be either "inline" string or {"mini_game": "combat"} object
public enum JSONEventKindForLoading: Codable {
    case inline
    case miniGame(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = stringValue == "inline" ? .inline : .miniGame(stringValue)
            return
        }
        if let dictValue = try? container.decode([String: String].self),
           let miniGameType = dictValue["mini_game"] {
            self = .miniGame(miniGameType)
            return
        }
        self = .inline
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .inline: try container.encode("inline")
        case .miniGame(let type): try container.encode(["mini_game": type])
        }
    }

    public func toEventKind() -> EventKind {
        switch self {
        case .inline: return .inline
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

/// JSON structure for loading events from file
public struct JSONEventForLoading: Codable {
    public let id: String
    public let title: LocalizedString
    public let body: LocalizedString
    public let eventKind: JSONEventKindForLoading?
    public let eventType: String?
    public let poolIds: [String]?
    public let availability: JSONAvailabilityForLoading?
    public let weight: Int?
    public let isOneTime: Bool?
    public let isInstant: Bool?
    public let cooldown: Int?
    public let choices: [JSONChoiceForLoading]?
    public let miniGameChallenge: JSONMiniGameChallengeForLoading?

    enum CodingKeys: String, CodingKey {
        case id, title, body, availability, weight, choices
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
        if let ek = eventKind { kind = ek.toEventKind() }
        else if let et = eventType {
            switch et.lowercased() {
            case "combat": kind = .miniGame(.combat)
            case "ritual": kind = .miniGame(.ritual)
            case "exploration": kind = .miniGame(.exploration)
            default: kind = .inline
            }
        } else { kind = .inline }

        let avail = availability?.toAvailability() ?? .always
        let choiceDefs = choices?.map { $0.toDefinition() } ?? []

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
        } else { challenge = nil }

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

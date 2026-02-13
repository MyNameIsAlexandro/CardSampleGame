/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Data/Definitions/EventDefinition+Kind.swift
/// Назначение: Содержит реализацию файла EventDefinition+Kind.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Event Kind

/// Classification of event kinds (Engine-specific, distinct from legacy EventType)
/// Reference: Docs/EVENT_MODULE_ARCHITECTURE.md, Section 2
public enum EventKind: Codable, Hashable {
    /// Inline event - resolves within main game flow
    case inline

    /// Mini-game event - dispatches to external module
    case miniGame(MiniGameKind)

    /// All mini-game kinds
    public enum MiniGameKind: String, Codable, Hashable {
        case combat
        case ritual
        case exploration
        case dialogue
        case puzzle
    }

    // MARK: - Custom Codable

    /// Coding keys for JSON object format
    /// Note: When decoder uses convertFromSnakeCase, the JSON key "mini_game"
    /// is already converted to "miniGame", so we use that directly
    private enum CodingKeys: String, CodingKey {
        case miniGame
        // Alternative key for when convertFromSnakeCase is NOT used
        case miniGameSnake = "mini_game"
    }

    public init(from decoder: Decoder) throws {
        // Try decoding as a simple string first: "inline"
        if let container = try? decoder.singleValueContainer(),
           let stringValue = try? container.decode(String.self) {
            if stringValue == "inline" {
                self = .inline
            } else if let miniGameKind = MiniGameKind(rawValue: stringValue) {
                // Handle direct mini-game string: "combat", "ritual", etc.
                self = .miniGame(miniGameKind)
            } else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unknown event kind: \(stringValue)"
                )
            }
            return
        }

        // Try decoding as object: {"mini_game": "combat"}
        // Try both key formats to support convertFromSnakeCase and regular decoding
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let miniGameString: String
        if let value = try container.decodeIfPresent(String.self, forKey: .miniGame) {
            miniGameString = value
        } else if let value = try container.decodeIfPresent(String.self, forKey: .miniGameSnake) {
            miniGameString = value
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.miniGame,
                DecodingError.Context(codingPath: container.codingPath, debugDescription: "Neither 'miniGame' nor 'mini_game' found")
            )
        }

        if let miniGameKind = MiniGameKind(rawValue: miniGameString) {
            self = .miniGame(miniGameKind)
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .miniGame,
                in: container,
                debugDescription: "Unknown mini-game kind: \(miniGameString)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .inline:
            var container = encoder.singleValueContainer()
            try container.encode("inline")
        case .miniGame(let kind):
            // Always encode with snake_case for JSON compatibility
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(kind.rawValue, forKey: .miniGameSnake)
        }
    }
}

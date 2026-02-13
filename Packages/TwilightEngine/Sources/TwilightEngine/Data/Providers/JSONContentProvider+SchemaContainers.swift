/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Data/Providers/JSONContentProvider+SchemaContainers.swift
/// Назначение: Содержит реализацию файла JSONContentProvider+SchemaContainers.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - JSON Schema Containers

/// Container for regions.json
struct RegionsContainer: Codable {
    public let version: String?
    public let description: String?
    public let regions: [JSONRegion]
}

/// Container for anchors.json
struct AnchorsContainer: Codable {
    public let version: String?
    public let description: String?
    public let anchors: [JSONAnchor]
}

/// Container for quests.json
struct QuestsContainer: Codable {
    public let version: String?
    public let description: String?
    public let quests: [JSONQuest]
}

/// Container for challenges.json
struct ChallengesContainer: Codable {
    public let version: String?
    public let description: String?
    public let challenges: [JSONChallenge]
}

/// Container for event pool files
struct EventPoolContainer: Codable {
    public let version: String?
    public let poolId: String?
    public let description: String?
    public let events: [JSONEvent]
}


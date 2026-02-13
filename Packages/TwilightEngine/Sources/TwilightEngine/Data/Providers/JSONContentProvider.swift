/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Data/Providers/JSONContentProvider.swift
/// Назначение: Содержит реализацию файла JSONContentProvider.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - JSON Content Provider
// Reference: Docs/MIGRATION_PLAN.md, Feature A3 / EPIC D
// Phase 5 Implementation - Real cartridge-data-driven

/// Content provider that loads definitions from JSON files.
/// This is the "cartridge" approach - content as external data.
public class JSONContentProvider: ContentProvider {
    // MARK: - Configuration

    /// Base path for content JSON files
    public let contentPath: String

    /// Bundle containing content (nil = main bundle)
    public let bundle: Bundle

    // MARK: - Cached Definitions (internal for @testable import)

    private(set) var regions: [String: RegionDefinition] = [:]
    private(set) var anchors: [String: AnchorDefinition] = [:]
    private(set) var events: [String: EventDefinition] = [:]
    private(set) var quests: [String: QuestDefinition] = [:]
    private(set) var miniGameChallenges: [String: MiniGameChallengeDefinition] = [:]

    // MARK: - Event Indices (internal for @testable import)

    private(set) var eventsByPool: [String: [EventDefinition]] = [:]
    private(set) var eventsByRegion: [String: [EventDefinition]] = [:]

    // MARK: - Loading State

    private(set) var isLoaded: Bool = false
    private(set) var loadErrors: [String] = []

    // MARK: - Initialization

    public init(contentPath: String = "Content", bundle: Bundle? = nil) {
        self.contentPath = contentPath
        self.bundle = bundle ?? Bundle.main
    }

    /// Initialize and load content
    convenience init(loadImmediately: Bool, contentPath: String = "Content", bundle: Bundle? = nil) {
        self.init(contentPath: contentPath, bundle: bundle)
        if loadImmediately {
            do {
                try loadAllContent()
            } catch {
                loadErrors.append("Failed to load content: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Loading

    /// Load all content from JSON files
    public func loadAllContent() throws {
        loadErrors.removeAll()

        // Load regions (files are at bundle root after Xcode copies them)
        if let regionsURL = bundle.url(forResource: "regions", withExtension: "json") {
            try loadRegions(from: regionsURL)
        } else {
            loadErrors.append("regions.json not found")
        }

        // Load anchors
        if let anchorsURL = bundle.url(forResource: "anchors", withExtension: "json") {
            try loadAnchors(from: anchorsURL)
        } else {
            loadErrors.append("anchors.json not found")
        }

        // Load quests
        if let questsURL = bundle.url(forResource: "quests", withExtension: "json") {
            try loadQuests(from: questsURL)
        } else {
            loadErrors.append("quests.json not found")
        }

        // Load challenges
        if let challengesURL = bundle.url(forResource: "challenges", withExtension: "json") {
            try loadChallenges(from: challengesURL)
        } else {
            loadErrors.append("challenges.json not found")
        }

        // Load event pools
        try loadEventPools()

        // Build indices
        buildEventIndices()

        isLoaded = true
    }

    /// Reload content (for development hot-reload)
    public func reloadContent() throws {
        regions.removeAll()
        anchors.removeAll()
        events.removeAll()
        quests.removeAll()
        miniGameChallenges.removeAll()
        eventsByPool.removeAll()
        eventsByRegion.removeAll()
        isLoaded = false

        try loadAllContent()
    }

    // MARK: - Individual Loaders

    private func loadRegions(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let container = try JSONDecoder().decode(RegionsContainer.self, from: data)
        for region in container.regions {
            regions[region.id] = region.toDefinition()
        }
    }

    private func loadAnchors(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let container = try JSONDecoder().decode(AnchorsContainer.self, from: data)
        for anchor in container.anchors {
            anchors[anchor.id] = anchor.toDefinition()
        }
    }

    private func loadQuests(from url: URL) throws {
        let data = try Data(contentsOf: url)
        // quests.json can be either a container with "quests" array or a direct array
        do {
            let container = try JSONDecoder().decode(QuestsContainer.self, from: data)
            for quest in container.quests {
                quests[quest.id] = quest.toDefinition()
            }
        } catch {
            // Try direct array format (like events.json)
            let questArray = try JSONDecoder().decode([JSONQuest].self, from: data)
            for quest in questArray {
                quests[quest.id] = quest.toDefinition()
            }
        }
    }

    private func loadChallenges(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let container = try JSONDecoder().decode(ChallengesContainer.self, from: data)
        for challenge in container.challenges {
            miniGameChallenges[challenge.id] = challenge.toDefinition()
        }
    }

    private func loadEventPools() throws {
        // Events are now in events.json with pool_ids field, not separate pool files
        // Load events.json which contains all events with their pool associations
        if let eventsURL = bundle.url(forResource: "events", withExtension: "json") {
            try loadEvents(from: eventsURL)
        } else {
            loadErrors.append("events.json not found")
        }
    }

    private func loadEvents(from url: URL) throws {
        let data = try Data(contentsOf: url)
        // events.json is a direct array, not wrapped in a container
        let eventArray = try JSONDecoder().decode([JSONEvent].self, from: data)
        for event in eventArray {
            let definition = event.toDefinition()
            events[definition.id] = definition
        }
    }

    private func loadEventPool(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let container = try JSONDecoder().decode(EventPoolContainer.self, from: data)
        for event in container.events {
            let definition = event.toDefinition()
            events[definition.id] = definition
        }
    }

    private func buildEventIndices() {
        eventsByPool.removeAll()
        eventsByRegion.removeAll()

        for event in events.values {
            // Index by pool
            for poolId in event.poolIds {
                eventsByPool[poolId, default: []].append(event)
            }

            // Index by region (from availability)
            if let regionIds = event.availability.regionIds {
                for regionId in regionIds {
                    eventsByRegion[regionId, default: []].append(event)
                }
            }
        }
    }

    // MARK: - ContentProvider Implementation

    public func getAllRegionDefinitions() -> [RegionDefinition] {
        return Array(regions.values)
    }

    public func getRegionDefinition(id: String) -> RegionDefinition? {
        return regions[id]
    }

    public func getAllAnchorDefinitions() -> [AnchorDefinition] {
        return Array(anchors.values)
    }

    public func getAnchorDefinition(id: String) -> AnchorDefinition? {
        return anchors[id]
    }

    public func getAnchorDefinition(forRegion regionId: String) -> AnchorDefinition? {
        return anchors.values.first { $0.regionId == regionId }
    }

    public func getAllEventDefinitions() -> [EventDefinition] {
        return Array(events.values)
    }

    public func getEventDefinition(id: String) -> EventDefinition? {
        return events[id]
    }

    public func getEventDefinitions(forRegion regionId: String) -> [EventDefinition] {
        guard let region = regions[regionId] else { return [] }

        var result: [EventDefinition] = []
        for poolId in region.eventPoolIds {
            result.append(contentsOf: eventsByPool[poolId] ?? [])
        }
        result.append(contentsOf: eventsByRegion[regionId] ?? [])

        var seen = Set<String>()
        return result.filter { seen.insert($0.id).inserted }
    }

    public func getEventDefinitions(forPool poolId: String) -> [EventDefinition] {
        return eventsByPool[poolId] ?? []
    }

    public func getAllQuestDefinitions() -> [QuestDefinition] {
        return Array(quests.values)
    }

    public func getQuestDefinition(id: String) -> QuestDefinition? {
        return quests[id]
    }

    public func getAllMiniGameChallenges() -> [MiniGameChallengeDefinition] {
        return Array(miniGameChallenges.values)
    }

    public func getMiniGameChallenge(id: String) -> MiniGameChallengeDefinition? {
        return miniGameChallenges[id]
    }

    public func validate() -> [ContentValidationError] {
        let validator = ContentValidator(provider: self)
        return validator.validate()
    }
}


/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/Data/Providers/CodeContentProvider.swift
/// Назначение: Содержит реализацию файла CodeContentProvider.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Code Content Provider
// Reference: Docs/MIGRATION_PLAN.md, Feature A3
// Adapter for existing TwilightMarchesConfig content

/// Content provider that loads definitions from Swift code.
/// This is an adapter for the existing TwilightMarchesConfig.swift content.
/// Will be replaced/augmented by JSONContentProvider in Phase 5.
public class CodeContentProvider: ContentProvider {
    // MARK: - Cached Definitions

    private var regions: [String: RegionDefinition] = [:]
    private var anchors: [String: AnchorDefinition] = [:]
    private var events: [String: EventDefinition] = [:]
    private var quests: [String: QuestDefinition] = [:]
    private var miniGameChallenges: [String: MiniGameChallengeDefinition] = [:]

    // MARK: - Event Pool Index

    private var eventsByPool: [String: [EventDefinition]] = [:]
    private var eventsByRegion: [String: [EventDefinition]] = [:]

    // MARK: - Initialization

    public init() {
        loadContent()
    }

    /// Load all content from code definitions
    private func loadContent() {
        loadRegions()
        loadAnchors()
        loadEvents()
        loadQuests()
        loadMiniGameChallenges()
        buildEventIndices()
    }

    // MARK: - Content Loading (Override in subclass for actual content)

    /// Load region definitions
    /// Subclass should override to provide actual regions
    public func loadRegions() {
        // Default implementation - subclass overrides with actual content
        // Example region for testing (uses generic IDs, not game-specific):
        let testRegion = RegionDefinition(
            id: "test_region",
            title: .inline(LocalizedString(en: "Test Region", ru: "Тестовый Регион")),
            description: .inline(LocalizedString(en: "A test region", ru: "Тестовый регион")),
            regionType: "test",
            neighborIds: ["test_neighbor"],
            initiallyDiscovered: true,
            anchorId: "test_anchor",
            eventPoolIds: ["pool_common"],
            initialState: .stable
        )
        regions[testRegion.id] = testRegion
    }

    /// Load anchor definitions
    public func loadAnchors() {
        // Default implementation - subclass overrides (uses generic IDs, not game-specific)
        let testAnchor = AnchorDefinition(
            id: "test_anchor",
            title: .inline(LocalizedString(en: "Test Anchor", ru: "Тестовый Якорь")),
            description: .inline(LocalizedString(en: "A test anchor", ru: "Тестовый якорь")),
            regionId: "test_region"
        )
        anchors[testAnchor.id] = testAnchor
    }

    /// Load event definitions
    public func loadEvents() {
        // Default implementation - subclass overrides
        let testEvent = EventDefinition(
            id: "event_test",
            title: .inline(LocalizedString(en: "Test Event", ru: "Тестовое Событие")),
            body: .inline(LocalizedString(en: "A test event", ru: "Тестовое событие")),
            eventKind: .inline,
            poolIds: ["pool_common"],
            choices: [
                ChoiceDefinition(
                    id: "choice_a",
                    label: .inline(LocalizedString(en: "Choice A", ru: "Выбор А")),
                    consequences: ChoiceConsequences(resourceChanges: ["faith": -2])
                ),
                ChoiceDefinition(
                    id: "choice_b",
                    label: .inline(LocalizedString(en: "Choice B", ru: "Выбор Б")),
                    consequences: ChoiceConsequences(resourceChanges: ["health": -3])
                )
            ]
        )
        events[testEvent.id] = testEvent
    }

    /// Load quest definitions
    public func loadQuests() {
        // Default implementation - subclass overrides
        let testQuest = QuestDefinition(
            id: "quest_test",
            title: .inline(LocalizedString(en: "Test Quest", ru: "Тестовое Задание")),
            description: .inline(LocalizedString(en: "A test quest", ru: "Тестовое задание")),
            objectives: [
                ObjectiveDefinition(
                    id: "obj_1",
                    description: .inline(LocalizedString(en: "Objective 1", ru: "Цель 1")),
                    completionCondition: .manual,
                    nextObjectiveId: "obj_2"
                ),
                ObjectiveDefinition(
                    id: "obj_2",
                    description: .inline(LocalizedString(en: "Objective 2", ru: "Цель 2")),
                    completionCondition: .manual
                )
            ]
        )
        quests[testQuest.id] = testQuest
    }

    /// Load mini-game challenge definitions
    public func loadMiniGameChallenges() {
        // Default implementation - subclass overrides
        let testCombat = MiniGameChallengeDefinition(
            id: "combat_test",
            challengeKind: .combat,
            difficulty: 5
        )
        miniGameChallenges[testCombat.id] = testCombat
    }

    /// Build event indices for fast lookup
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

    // MARK: - JSON Event Loading Utility

    /// Load events from a JSON file URL
    /// - Parameter url: URL to the events.json file
    /// - Throws: Decoding errors
    public func loadEventsFromJSON(url: URL) throws {
        let data = try Data(contentsOf: url)
        let jsonEvents = try JSONDecoder().decode([JSONEventForLoading].self, from: data)
        for jsonEvent in jsonEvents {
            events[jsonEvent.id] = jsonEvent.toDefinition()
        }
        buildEventIndices()
    }

    // MARK: - Registration (for building content)

    public func registerRegion(_ region: RegionDefinition) {
        regions[region.id] = region
    }

    public func registerAnchor(_ anchor: AnchorDefinition) {
        anchors[anchor.id] = anchor
    }

    public func registerEvent(_ event: EventDefinition) {
        events[event.id] = event
    }

    public func registerQuest(_ quest: QuestDefinition) {
        quests[quest.id] = quest
    }

    public func registerMiniGameChallenge(_ challenge: MiniGameChallengeDefinition) {
        miniGameChallenges[challenge.id] = challenge
    }

    public func rebuildIndices() {
        buildEventIndices()
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
        // Get events from region's pools
        guard let region = regions[regionId] else { return [] }

        var result: [EventDefinition] = []
        for poolId in region.eventPoolIds {
            result.append(contentsOf: eventsByPool[poolId] ?? [])
        }

        // Add events specifically for this region
        result.append(contentsOf: eventsByRegion[regionId] ?? [])

        // Remove duplicates while preserving order
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
